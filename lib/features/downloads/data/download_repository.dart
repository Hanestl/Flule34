import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/api/rule34video_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/video_models.dart';
import '../../../core/security/error_redaction.dart';
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
  final Set<String> _automaticRefreshAttempts = {};
  String? _observedUserId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _observedUserId = _sessionStore.currentUserId;
    _sessionStore.addListener(_onSessionChanged);
    _settingsRepository.addListener(_onSettingsChanged);
    _eventSubscription = _platformService.events.listen(_onPlatformEvent);
    await _platformService.setMaxConcurrent(
      _settingsRepository.settings.downloadConcurrentTasks,
    );
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
    _requireCurrentUser(userId);
    if (existing != null) {
      throw DownloadException('$quality 已在当前账号的下载列表中。');
    }
    final refreshedDetails = await _api.loadVideoDetails(details.video);
    _requireCurrentUser(userId);
    final refreshedSource = refreshedDetails.sources
        .cast<VideoSource?>()
        .firstWhere(
          (candidate) => candidate?.label.trim() == quality,
          orElse: () => null,
        );
    if (refreshedSource == null) {
      throw DownloadException('刷新后已找不到 $quality 下载源，请重新选择清晰度。');
    }
    if (!await _platformService.ensureNotificationPermission()) {
      throw const DownloadException('需要通知权限才能可靠显示后台下载进度。');
    }
    _requireCurrentUser(userId);

    final id = _taskId(userId, details.video.id, quality);
    final cookie = await _api.sessionCookieHeader();
    _requireCurrentUser(userId);
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
    if (_sessionStore.currentUserId != userId) {
      await _database.deleteDownloadRecord(id);
      throw const DownloadException('账号已切换，本次下载未加入队列。');
    }

    final enqueued = await _platformService.enqueue(
      DownloadRequest(
        id: id,
        url: refreshedSource.url,
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
    if (_sessionStore.currentUserId != userId) {
      if (enqueued) {
        await _platformService.cancel(id);
      }
      await _database.updateDownloadStatus(
        id: id,
        state: DownloadTaskState.canceled.storageValue,
        errorMessage: '账号已切换，任务已取消。',
      );
      throw const DownloadException('账号已切换，本次下载已取消。');
    }
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

  Future<bool> retry(DownloadRecord record) async {
    _requireOwnedRecord(record);
    final video = VideoItem(
      id: record.videoId,
      title: record.title,
      slug: 'video',
    );
    try {
      final details = await _api.loadVideoDetails(video);
      final source = details.sources.cast<VideoSource?>().firstWhere(
        (candidate) => candidate?.label.trim() == record.quality.trim(),
        orElse: () => null,
      );
      if (source == null) {
        throw DownloadException('刷新后已找不到 ${record.quality} 下载源。');
      }
      await _platformService.delete(
        taskId: record.taskId ?? record.id,
        directory: _directoryForUser(record.userId),
        filePath: record.filePath,
      );
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
          id: Value(record.id),
          userId: Value(record.userId),
          videoId: Value(record.videoId),
          title: Value(details.video.title),
          quality: Value(record.quality),
          state: Value(DownloadTaskState.queued.storageValue),
          bytesDownloaded: const Value(0),
          totalBytes: const Value(null),
          filePath: const Value(null),
          errorMessage: const Value(null),
          taskId: Value(record.taskId ?? record.id),
          createdAt: Value(record.createdAt),
          updatedAt: Value(now),
          completedAt: const Value(null),
        ),
      );
      final enqueued = await _platformService.enqueue(
        DownloadRequest(
          id: record.taskId ?? record.id,
          url: source.url,
          filename: _filename(details.video, record.quality),
          directory: _directoryForUser(record.userId),
          displayName: details.video.title,
          metadata: jsonEncode({
            'recordId': record.id,
            'userId': record.userId,
            'videoId': record.videoId,
            'quality': record.quality,
          }),
          headers: headers,
          requiresWiFi: _settingsRepository.settings.wifiOnlyDownloads,
        ),
      );
      if (!enqueued) {
        throw const DownloadException('系统未能重新加入下载任务。');
      }
      return true;
    } catch (error) {
      await _database.updateDownloadStatus(
        id: record.id,
        state: DownloadTaskState.failed.storageValue,
        errorMessage: redactSensitiveText(error),
      );
      return false;
    }
  }

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

  Future<bool> openExported(String filePath) {
    return _platformService.openFile(filePath);
  }

  Future<String?> export(DownloadRecord record) async {
    _requireOwnedRecord(record);
    if (record.state != DownloadTaskState.complete.storageValue) {
      throw const DownloadException('只能导出已完成的下载。');
    }
    return _platformService.exportToDownloads(record.taskId ?? record.id);
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
        if (event.state == DownloadTaskState.complete) {
          _automaticRefreshAttempts.remove(event.taskId);
        } else if (event.state == DownloadTaskState.failed &&
            _isExpiredSourceError(event.errorMessage) &&
            _automaticRefreshAttempts.add(event.taskId)) {
          final record = await _database.findDownloadRecord(event.taskId);
          if (record != null && record.userId == _sessionStore.currentUserId) {
            unawaited(retry(record));
          }
        }
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

  void _onSettingsChanged() {
    unawaited(
      _platformService.setMaxConcurrent(
        _settingsRepository.settings.downloadConcurrentTasks,
      ),
    );
  }

  bool _isExpiredSourceError(String? message) {
    return RegExp(
      r'\b(?:401|403|404)\b|unauthori[sz]ed|forbidden|not found',
      caseSensitive: false,
    ).hasMatch(message ?? '');
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

  void _requireCurrentUser(String userId) {
    if (_sessionStore.currentUserId != userId) {
      throw const DownloadException('账号已切换，请在当前账号下重新操作。');
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
    _settingsRepository.removeListener(_onSettingsChanged);
    unawaited(_eventSubscription?.cancel());
    _platformService.dispose();
  }
}
