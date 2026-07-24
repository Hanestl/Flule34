import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/api/rule34video_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/video_models.dart';
import '../../../core/session/session_store.dart';
import '../../settings/data/app_settings_repository.dart';
import '../domain/download_models.dart';

final class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AccountDataClearResult {
  const AccountDataClearResult({
    required this.deletedDownloads,
    required this.failedDownloads,
  });

  final int deletedDownloads;
  final int failedDownloads;

  bool get isComplete => failedDownloads == 0;
}

final class DownloadRepository {
  DownloadRepository(
    this._database,
    this._sessionStore,
    this._api,
    this._platformService,
    this._settingsRepository,
  );

  final AppDatabase _database;
  final SessionStore _sessionStore;
  final Rule34VideoApi _api;
  final DownloadPlatformService _platformService;
  final AppSettingsRepository _settingsRepository;

  StreamSubscription<DownloadPlatformEvent>? _eventSubscription;
  String? _observedUserId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _observedUserId = _sessionStore.currentUserId;
    _sessionStore.addListener(_onSessionChanged);
    _eventSubscription = _platformService.events.listen(_onPlatformEvent);
    await _platformService.initialize();
    _initialized = true;
  }

  Stream<List<DownloadRecord>> watchCurrentUserDownloads() {
    final userId = _sessionStore.currentUserId;
    return userId == null
        ? Stream.value(const <DownloadRecord>[])
        : _database.watchDownloads(userId);
  }

  Future<String> enqueueVideo({
    required VideoDetails details,
    required VideoSource source,
  }) async {
    final userId = _requireUserId();
    final quality = source.label.trim();
    final existing = await _database.findVideoDownload(
      userId: userId,
      videoId: details.video.id,
      quality: quality,
    );
    if (existing != null) {
      throw DownloadException('$quality 已在当前账号的下载列表中。');
    }
    if (!await _platformService.ensureNotificationPermission()) {
      throw const DownloadException('需要通知权限才能可靠显示后台下载进度。');
    }

    final id = _taskId(userId, details.video.id, quality);
    final cookie = await _api.sessionCookieHeader();
    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/0.1',
    };
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    final now = DateTime.now().toUtc();
    await _database.saveDownloadRecord(
      DownloadRecordsCompanion(
        id: Value(id),
        userId: Value(userId),
        videoId: Value(details.video.id),
        title: Value(details.video.title),
        quality: Value(quality),
        state: Value(DownloadTaskState.queued.storageValue),
        taskId: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final enqueued = await _platformService.enqueue(
      DownloadRequest(
        id: id,
        url: source.url,
        filename: _filename(details.video, quality),
        directory: _directoryForUser(userId),
        displayName: details.video.title,
        metadata: jsonEncode({
          'recordId': id,
          'userId': userId,
          'videoId': details.video.id,
          'quality': quality,
        }),
        headers: headers,
        requiresWiFi: _settingsRepository.settings.wifiOnlyDownloads,
      ),
    );
    if (!enqueued) {
      await _database.updateDownloadStatus(
        id: id,
        state: DownloadTaskState.failed.storageValue,
        errorMessage: '系统未能将任务加入下载队列。',
      );
      throw const DownloadException('系统未能将任务加入下载队列。');
    }
    return id;
  }

  Future<bool> pause(String id) => _ownedAction(id, _platformService.pause);

  Future<bool> resume(String id) => _ownedAction(id, _platformService.resume);

  Future<bool> cancel(String id) async {
    final success = await _ownedAction(id, _platformService.cancel);
    if (success) {
      await _database.updateDownloadStatus(
        id: id,
        state: DownloadTaskState.canceled.storageValue,
      );
    }
    return success;
  }

  Future<bool> open(DownloadRecord record) async {
    _requireOwnedRecord(record);
    final path = record.filePath;
    return path != null && await _platformService.openFile(path);
  }

  Future<bool> delete(DownloadRecord record) async {
    _requireOwnedRecord(record);
    final deleted = await _platformService.delete(
      taskId: record.taskId ?? record.id,
      directory: _directoryForUser(record.userId),
      filePath: record.filePath,
    );
    if (!deleted) {
      return false;
    }
    await _database.deleteDownloadRecord(record.id);
    return true;
  }

  Future<AccountDataClearResult> clearCurrentUserData() async {
    final userId = _requireUserId();
    final records = await _database.watchDownloads(userId).first;
    var deleted = 0;
    var failed = 0;
    for (final record in records) {
      if (await delete(record)) {
        deleted += 1;
      } else {
        failed += 1;
      }
    }
    await _database.deletePlaybackPositionsForUser(userId);
    return AccountDataClearResult(
      deletedDownloads: deleted,
      failedDownloads: failed,
    );
  }

  Future<bool> _ownedAction(
    String id,
    Future<bool> Function(String id) action,
  ) async {
    final record = await _database.findDownloadRecord(id);
    if (record == null) {
      return false;
    }
    _requireOwnedRecord(record);
    return action(id);
  }

  void _onPlatformEvent(DownloadPlatformEvent event) {
    unawaited(_persistEvent(event));
  }

  Future<void> _persistEvent(DownloadPlatformEvent event) async {
    switch (event) {
      case DownloadStatusEvent():
        await _database.updateDownloadStatus(
          id: event.taskId,
          state: event.state.storageValue,
          filePath: event.filePath,
          errorMessage: event.errorMessage,
          completedAt: event.state == DownloadTaskState.complete
              ? DateTime.now().toUtc()
              : null,
        );
      case DownloadProgressEvent():
        await _database.updateDownloadProgress(
          id: event.taskId,
          bytesDownloaded: event.bytesDownloaded,
          totalBytes: event.totalBytes,
        );
    }
  }

  void _onSessionChanged() {
    final nextUserId = _sessionStore.currentUserId;
    final previousUserId = _observedUserId;
    _observedUserId = nextUserId;
    if (previousUserId != null && previousUserId != nextUserId) {
      unawaited(_cancelActiveForUser(previousUserId));
    }
  }

  Future<void> _cancelActiveForUser(String userId) async {
    final active = await _database.activeDownloads(userId);
    await Future.wait(
      active.map((record) => _platformService.cancel(record.id)),
    );
  }

  String _requireUserId() {
    final userId = _sessionStore.currentUserId;
    if (userId == null) {
      throw const DownloadException('请先登录后再下载视频。');
    }
    return userId;
  }

  void _requireOwnedRecord(DownloadRecord record) {
    if (record.userId != _requireUserId()) {
      throw const DownloadException('不能操作其他账号的下载任务。');
    }
  }

  String _taskId(String userId, String videoId, String quality) {
    final safeQuality = quality.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
    return 'flule34_${userId}_${videoId}_$safeQuality';
  }

  String _directoryForUser(String userId) => 'downloads/$userId';

  String _filename(VideoItem video, String quality) {
    final sanitized = video.title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final title = sanitized.isEmpty ? 'video' : sanitized;
    final shortened = title.length > 72 ? title.substring(0, 72).trim() : title;
    return '${shortened}_${video.id}_$quality.mp4';
  }

  void dispose() {
    _sessionStore.removeListener(_onSessionChanged);
    unawaited(_eventSubscription?.cancel());
    _platformService.dispose();
  }
}
