import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/api/rule34video_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_log_service.dart';
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
    this._settingsRepository, {
    AppLogService? logService,
  }) : _logs = logService;

  static const _deviceOwnerId = '__flule34_device__';

  final AppDatabase _database;
  final Rule34VideoApi _api;
  final DownloadPlatformService _platformService;
  final AppSettingsRepository _settingsRepository;
  final AppLogService? _logs;

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
    if (!await _platformService.ensureNotificationPermission()) {
      throw const DownloadException('需要通知权限才能可靠显示后台下载进度。');
    }
    if (!await _platformService.ensureSharedStoragePermission()) {
      throw const DownloadException('系统未授予公共下载目录写入权限。');
    }
    final refreshedDetails = await _api.refreshVideoDetails(details.video);
    final refreshedSource = refreshedDetails.sources
        .cast<VideoSource?>()
        .firstWhere(
          (candidate) => candidate?.label.trim() == quality,
          orElse: () => null,
        );
    if (refreshedSource == null) {
      throw DownloadException('刷新后已找不到 $quality 下载源，请重新选择清晰度。');
    }
    final id = _taskId(details.video.id, quality);
    final filename = _filename(details.video, quality);
    final headers = await _headers();
    final now = DateTime.now().toUtc();
    await _database.saveDownloadRecord(
      DownloadRecordsCompanion(
        id: Value(id),
        userId: const Value(_deviceOwnerId),
        videoId: Value(details.video.id),
        title: Value(details.video.title),
        quality: Value(quality),
        thumbnailUrl: Value(
          details.video.highResolutionThumbnailUrl ??
              details.video.thumbnailUrl,
        ),
        fileName: Value(filename),
        state: Value(DownloadTaskState.queued.storageValue),
        taskId: Value(id),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final bool enqueued;
    try {
      enqueued = await _platformService.enqueue(
        DownloadRequest(
          id: id,
          url: refreshedSource.url,
          filename: filename,
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
    } catch (error, stackTrace) {
      await _database.updateDownloadStatus(
        id: id,
        state: DownloadTaskState.failed.storageValue,
        errorMessage: redactSensitiveText(error),
      );
      unawaited(
        _logs?.error(
          'downloads',
          '提交后台下载任务失败。',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      throw DownloadException('提交后台下载任务失败：${redactSensitiveText(error)}');
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

  Future<bool> retry(DownloadRecord record) async {
    final taskId = record.taskId ?? record.id;
    final video = VideoItem(
      id: record.videoId,
      title: record.title,
      slug: 'video',
    );
    try {
      final details = await _api.refreshVideoDetails(video);
      final source = details.sources.cast<VideoSource?>().firstWhere(
        (candidate) => candidate?.label.trim() == record.quality.trim(),
        orElse: () => null,
      );
      if (source == null) {
        throw DownloadException('刷新后已找不到 ${record.quality} 下载源。');
      }
      await _platformService.delete(taskId: taskId, fileUri: record.filePath);
      if (!await _platformService.ensureSharedStoragePermission()) {
        throw const DownloadException('系统未授予公共下载目录写入权限。');
      }
      final filename = _filename(details.video, record.quality);
      final now = DateTime.now().toUtc();
      await _database.saveDownloadRecord(
        DownloadRecordsCompanion(
          id: Value(record.id),
          userId: const Value(_deviceOwnerId),
          videoId: Value(record.videoId),
          title: Value(details.video.title),
          quality: Value(record.quality),
          thumbnailUrl: Value(
            details.video.highResolutionThumbnailUrl ??
                details.video.thumbnailUrl,
          ),
          fileName: Value(filename),
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
          filename: filename,
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

  Future<bool> open(DownloadRecord record) async {
    final validation = await validateFile(record);
    if (!validation.valid) {
      return false;
    }
    final uri = record.filePath;
    return uri == null ? false : _platformService.openFile(uri);
  }

  Future<DownloadFileValidation> validateFile(DownloadRecord record) async {
    if (record.state != DownloadTaskState.complete.storageValue) {
      return const DownloadFileValidation.notApplicable();
    }
    final uri = record.filePath;
    if (uri == null || uri.trim().isEmpty) {
      return const DownloadFileValidation(
        valid: false,
        exists: false,
        readable: false,
        reason: '没有保存完成文件的位置。',
      );
    }
    final inspection = await _platformService.inspectFile(uri);
    if (!inspection.exists) {
      return DownloadFileValidation(
        valid: false,
        exists: false,
        readable: false,
        actualName: inspection.name,
        actualBytes: inspection.size,
        reason: '外部文件已不存在。',
      );
    }
    if (!inspection.readable) {
      return DownloadFileValidation(
        valid: false,
        exists: true,
        readable: false,
        actualName: inspection.name,
        actualBytes: inspection.size,
        reason: '外部文件当前无法读取。',
      );
    }
    final expectedName = record.fileName?.trim();
    if (expectedName != null &&
        expectedName.isNotEmpty &&
        inspection.name != expectedName) {
      return DownloadFileValidation(
        valid: false,
        exists: true,
        readable: true,
        actualName: inspection.name,
        actualBytes: inspection.size,
        reason: '外部文件已被改名。',
      );
    }
    final expectedBytes = record.totalBytes;
    if (expectedBytes != null &&
        expectedBytes > 0 &&
        inspection.size != expectedBytes) {
      return DownloadFileValidation(
        valid: false,
        exists: true,
        readable: true,
        actualName: inspection.name,
        actualBytes: inspection.size,
        reason: '外部文件大小已发生变化。',
      );
    }
    return DownloadFileValidation(
      valid: true,
      exists: true,
      readable: true,
      actualName: inspection.name,
      actualBytes: inspection.size,
    );
  }

  Future<bool> delete(DownloadRecord record, {bool? deleteExternalFile}) async {
    final shouldDeleteExternal =
        deleteExternalFile ??
        (record.state != DownloadTaskState.complete.storageValue ||
            (await validateFile(record)).valid);
    final deleted = await _platformService.delete(
      taskId: record.taskId ?? record.id,
      fileUri: record.filePath,
      deleteExternalFile: shouldDeleteExternal,
    );
    if (!deleted) {
      return false;
    }
    await _database.deleteDownloadRecord(record.id);
    return true;
  }

  Future<DownloadBulkDeleteResult> deleteAll(
    DownloadBulkDeleteMode mode,
  ) async {
    final records = await _database.downloadsForUser(_deviceOwnerId);
    final selected = <DownloadRecord>[];
    if (mode == DownloadBulkDeleteMode.invalidRecords) {
      for (final record in records) {
        if (record.state != DownloadTaskState.complete.storageValue) {
          continue;
        }
        final validation = await validateFile(record);
        if (!validation.valid) {
          selected.add(record);
        }
      }
    } else {
      selected.addAll(records);
    }
    var deleted = 0;
    var failed = 0;
    final deleteExternal = mode == DownloadBulkDeleteMode.filesAndRecords;
    for (final record in selected) {
      if (await delete(record, deleteExternalFile: deleteExternal)) {
        deleted += 1;
      } else {
        failed += 1;
      }
    }
    return DownloadBulkDeleteResult(
      matched: selected.length,
      deleted: deleted,
      failed: failed,
    );
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

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/1.4.0',
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
        if (event.state == DownloadTaskState.complete &&
            event.actualBytes != null) {
          await _database.updateDownloadProgress(
            id: event.taskId,
            bytesDownloaded: event.actualBytes!,
            totalBytes: event.actualBytes,
          );
        }
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
