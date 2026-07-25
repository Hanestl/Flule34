import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/api/rule34video_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/video_models.dart';
import '../../../core/security/error_redaction.dart';
import '../../settings/data/app_settings_repository.dart';
import '../domain/download_models.dart';

final class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DownloadRepository {
  DownloadRepository(
    this._database,
    this._api,
    this._platformService,
    this._settingsRepository,
  );

  static const _deviceOwnerId = '__flule34_device__';

  final AppDatabase _database;
  final Rule34VideoApi _api;
  final DownloadPlatformService _platformService;
  final AppSettingsRepository _settingsRepository;

  StreamSubscription<DownloadPlatformEvent>? _eventSubscription;
  final Set<String> _automaticRefreshAttempts = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _database.recordAuthenticatedAccount(
      _deviceOwnerId,
      displayName: '本机下载',
    );
    _settingsRepository.addListener(_onSettingsChanged);
    _eventSubscription = _platformService.events.listen(_onPlatformEvent);
    await _platformService.setMaxConcurrent(
      _settingsRepository.settings.downloadConcurrentTasks,
    );
    await _platformService.initialize();
    _initialized = true;
  }

  Stream<List<DownloadRecord>> watchCurrentUserDownloads() {
    return _database.watchDownloads(_deviceOwnerId);
  }

  Future<DownloadDirectorySelection?> chooseDownloadDirectory({
    bool useDefault = false,
  }) async {
    final selection = useDefault
        ? await _platformService.pickDefaultDirectory()
        : await _platformService.pickCustomDirectory();
    if (selection == null) {
      return null;
    }
    await _settingsRepository.setDownloadDirectory(
      uri: selection.uri.toString(),
      label: selection.label,
    );
    return selection;
  }

  Future<String> enqueueVideo({
    required VideoDetails details,
    required VideoSource source,
  }) async {
    final quality = source.label.trim();
    final existing = await _database.findVideoDownload(
      userId: _deviceOwnerId,
      videoId: details.video.id,
      quality: quality,
    );
    if (existing != null &&
        existing.state != DownloadTaskState.canceled.storageValue) {
      throw DownloadException('$quality 已在下载管理中。');
    }
    final refreshedDetails = await _api.loadVideoDetails(details.video);
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
    final directory = await _downloadDirectory();
    final id = _taskId(details.video.id, quality);
    final headers = await _headers();
    final now = DateTime.now().toUtc();
    await _database.saveDownloadRecord(
      DownloadRecordsCompanion(
        id: Value(id),
        userId: const Value(_deviceOwnerId),
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
        url: refreshedSource.url,
        filename: _filename(details.video, quality),
        directoryUri: directory,
        displayName: details.video.title,
        metadata: jsonEncode({
          'recordId': id,
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

  Future<bool> pause(String id) => _knownAction(id, _platformService.pause);

  Future<bool> resume(String id) => _knownAction(id, _platformService.resume);

  Future<bool> retry(DownloadRecord record) async {
    final taskId = record.taskId ?? record.id;
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
      await _platformService.delete(taskId: taskId, fileUri: record.filePath);
      final directory = await _downloadDirectory();
      final now = DateTime.now().toUtc();
      await _database.saveDownloadRecord(
        DownloadRecordsCompanion(
          id: Value(record.id),
          userId: const Value(_deviceOwnerId),
          videoId: Value(record.videoId),
          title: Value(details.video.title),
          quality: Value(record.quality),
          state: Value(DownloadTaskState.queued.storageValue),
          bytesDownloaded: const Value(0),
          totalBytes: const Value(null),
          filePath: const Value(null),
          errorMessage: const Value(null),
          taskId: Value(taskId),
          createdAt: Value(record.createdAt),
          updatedAt: Value(now),
          completedAt: const Value(null),
        ),
      );
      final enqueued = await _platformService.enqueue(
        DownloadRequest(
          id: taskId,
          url: source.url,
          filename: _filename(details.video, record.quality),
          directoryUri: directory,
          displayName: details.video.title,
          metadata: jsonEncode({
            'recordId': record.id,
            'videoId': record.videoId,
            'quality': record.quality,
          }),
          headers: await _headers(),
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
    final success = await _knownAction(id, _platformService.cancel);
    if (success) {
      await _database.updateDownloadStatus(
        id: id,
        state: DownloadTaskState.canceled.storageValue,
      );
    }
    return success;
  }

  Future<bool> open(DownloadRecord record) {
    final uri = record.filePath;
    return uri == null ? Future.value(false) : _platformService.openFile(uri);
  }

  Future<bool> delete(DownloadRecord record) async {
    final deleted = await _platformService.delete(
      taskId: record.taskId ?? record.id,
      fileUri: record.filePath,
    );
    if (!deleted) {
      return false;
    }
    await _database.deleteDownloadRecord(record.id);
    return true;
  }

  Future<bool> _knownAction(
    String id,
    Future<bool> Function(String id) action,
  ) async {
    if (await _database.findDownloadRecord(id) == null) {
      return false;
    }
    return action(id);
  }

  Future<Uri> _downloadDirectory() async {
    final saved = _settingsRepository.settings.downloadDirectoryUri.trim();
    if (saved.isEmpty) {
      final selected = await chooseDownloadDirectory(useDefault: true);
      if (selected == null) {
        throw const DownloadException(
          '首次下载需要授权 Downloads 目录；请选择 Downloads，App 会创建 Flule34 文件夹。',
        );
      }
      return selected.uri;
    }
    final activated = await _platformService.activateDirectory(
      Uri.parse(saved),
    );
    if (activated == null) {
      throw const DownloadException('下载目录授权已失效，请在下载设置中重新选择。');
    }
    return activated;
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/1.1',
    };
    final cookie = await _api.sessionCookieHeader();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    return headers;
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
          if (record != null) {
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

  String _taskId(String videoId, String quality) {
    final safeQuality = quality.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
    return 'flule34_${videoId}_$safeQuality';
  }

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
    _settingsRepository.removeListener(_onSettingsChanged);
    unawaited(_eventSubscription?.cancel());
    _platformService.dispose();
  }
}
