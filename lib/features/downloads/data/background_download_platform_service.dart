import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/services.dart';

import '../../../core/logging/app_log_service.dart';
import '../../../core/security/error_redaction.dart';
import '../domain/download_models.dart';

final class BackgroundDownloadPlatformService
    implements DownloadPlatformService {
  BackgroundDownloadPlatformService({
    int maxConcurrent = 2,
    AppLogService? logService,
  }) : this._(maxConcurrent, logService);

  BackgroundDownloadPlatformService._(this._maxConcurrent, this._logs);

  static const _group = 'flule34-downloads';
  static const _privateDirectory = 'downloads';
  static const _publicDirectory = 'Flule34';
  static const _mediaStoreInspectionDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 120),
    Duration(milliseconds: 350),
    Duration(milliseconds: 800),
  ];
  static const _storageChannel = MethodChannel(
    'com.hanestl.flule34/storage_access',
  );

  final FileDownloader _downloader = FileDownloader();
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
  final Set<String> _finalizing = {};
  final AppLogService? _logs;
  int _maxConcurrent;
  bool _initialized = false;

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await setMaxConcurrent(_maxConcurrent);
    _downloader
        .registerCallbacks(
          group: _group,
          taskStatusCallback: _onStatus,
          taskProgressCallback: _onProgress,
        )
        .configureNotificationForGroup(
          _group,
          running: const TaskNotification(
            '正在下载 {displayName}',
            '{progress} · {networkSpeed} · 剩余 {timeRemaining}',
          ),
          complete: const TaskNotification('下载完成', '{displayName}'),
          error: const TaskNotification('下载失败', '{displayName}'),
          paused: const TaskNotification('下载已暂停', '{displayName}'),
          canceled: const TaskNotification('下载已取消', '{displayName}'),
          progressBar: true,
          tapOpensFile: false,
        );
    await _downloader.start(autoCleanDatabase: false);
    await _downloader.trackTasksInGroup(_group);
    await _downloader.rescheduleKilledTasks();
    _initialized = true;
  }

  @override
  Future<void> setMaxConcurrent(int value) async {
    _maxConcurrent = value.clamp(1, 4);
    await _downloader.configure(
      globalConfig: (
        Config.holdingQueue,
        (_maxConcurrent, _maxConcurrent, _maxConcurrent),
      ),
    );
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    final permissions = _downloader.permissions;
    final current = await permissions.status(PermissionType.notifications);
    if (current == PermissionStatus.granted) {
      return true;
    }
    return await permissions.request(PermissionType.notifications) ==
        PermissionStatus.granted;
  }

  @override
  Future<bool> ensureSharedStoragePermission() async {
    final permissions = _downloader.permissions;
    final current = await permissions.status(
      PermissionType.androidSharedStorage,
    );
    if (current == PermissionStatus.granted) {
      return true;
    }
    return await permissions.request(PermissionType.androidSharedStorage) ==
        PermissionStatus.granted;
  }

  @override
  Future<bool> enqueue(DownloadRequest request) async {
    final accepted = await _downloader.enqueue(
      DownloadTask(
        taskId: request.id,
        url: request.url,
        filename: request.filename,
        headers: request.headers,
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _privateDirectory,
        group: _group,
        updates: Updates.statusAndProgress,
        requiresWiFi: request.requiresWiFi,
        retries: 2,
        allowPause: true,
        priority: 0,
        metaData: request.metadata,
        displayName: request.displayName,
      ),
    );
    unawaited(
      _logs?.info(
        'downloads',
        '后台任务 ${request.id} ${accepted ? '已加入队列' : '被系统拒绝'}。',
      ),
    );
    return accepted;
  }

  @override
  Future<bool> cancel(String taskId) {
    return _downloader.cancelTaskWithId(taskId);
  }

  @override
  Future<bool> openFile(String fileUri) {
    return _downloader.uri.openFile(Uri.parse(fileUri), mimeType: 'video/mp4');
  }

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async {
    try {
      final result = await _storageChannel.invokeMapMethod<String, Object?>(
        'inspectFile',
        {'uri': fileUri},
      );
      return DownloadFileInspection(
        exists: result?['exists'] == true,
        readable: result?['readable'] == true,
        name: result?['name'] as String?,
        size: switch (result?['size']) {
          final int value => value,
          final num value => value.toInt(),
          _ => null,
        },
      );
    } on PlatformException catch (error, stackTrace) {
      unawaited(
        _logs?.warning(
          'downloads',
          '无法读取下载文件元数据。',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return const DownloadFileInspection(exists: false, readable: false);
    }
  }

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    await _downloader.cancelTaskWithId(taskId);
    if (deleteExternalFile && fileUri != null) {
      final inspection = await inspectFile(fileUri);
      if (inspection.exists) {
        try {
          if (!await _downloader.uri.deleteFile(Uri.parse(fileUri))) {
            return false;
          }
        } on Exception {
          return false;
        }
      }
    }
    if (task is DownloadTask) {
      try {
        final file = File(await task.filePath());
        if (await file.exists()) {
          await file.delete();
        }
      } on FileSystemException {
        return false;
      }
    }
    await _downloader.database.deleteRecordWithId(taskId);
    return true;
  }

  void _onStatus(TaskStatusUpdate update) {
    unawaited(_emitStatus(update));
  }

  Future<void> _emitStatus(TaskStatusUpdate update) async {
    final taskId = update.task.taskId;
    final state = _mapStatus(update.status);
    if (state == DownloadTaskState.complete) {
      if (!_finalizing.add(taskId)) {
        return;
      }
      try {
        await _finalizeCompletedTask(update.task);
      } finally {
        _finalizing.remove(taskId);
      }
      return;
    }
    _events.add(
      DownloadStatusEvent(
        taskId: taskId,
        state: state,
        errorMessage: update.exception == null
            ? null
            : redactSensitiveText(update.exception),
      ),
    );
    unawaited(
      _logs?.info(
        'downloads',
        '任务 $taskId 状态变为 ${state.storageValue}'
            '${update.exception == null ? '' : '，发生异常'}。',
      ),
    );
  }

  Future<void> _finalizeCompletedTask(Task task) async {
    final taskId = task.taskId;
    try {
      final Uri? finalUri;
      int? sourceBytes;
      if (task is UriDownloadTask) {
        finalUri = task.fileUri;
      } else if (task is DownloadTask) {
        if (!await ensureSharedStoragePermission()) {
          throw StateError('系统未授予公共下载目录写入权限。');
        }
        final sourceFile = File(await task.filePath());
        if (await sourceFile.exists()) {
          sourceBytes = await sourceFile.length();
        }
        finalUri = await _downloader.uri.moveToSharedStorage(
          task,
          SharedStorage.downloads,
          directory: _publicDirectory,
          mimeType: 'video/mp4',
        );
      } else {
        finalUri = null;
      }
      if (finalUri == null) {
        throw StateError('无法将视频保存到 Download/Flule34。');
      }
      final inspection = await _inspectFinalizedFile(finalUri);
      if (!inspection.exists || !inspection.readable) {
        unawaited(
          _logs?.warning('downloads', '任务 $taskId 已写入公共目录，但系统暂未返回可读的文件元数据。'),
        );
      }
      await _downloader.database.deleteRecordWithId(taskId);
      _events.add(
        DownloadStatusEvent(
          taskId: taskId,
          state: DownloadTaskState.complete,
          filePath: finalUri.toString(),
          actualBytes: inspection.size ?? sourceBytes,
        ),
      );
      unawaited(_logs?.info('downloads', '任务 $taskId 已保存到 Download/Flule34。'));
    } catch (error, stackTrace) {
      _events.add(
        DownloadStatusEvent(
          taskId: taskId,
          state: DownloadTaskState.failed,
          errorMessage: redactSensitiveText(error),
        ),
      );
      unawaited(
        _logs?.error(
          'downloads',
          '任务 $taskId 完成后的公共目录保存失败。',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DownloadFileInspection> _inspectFinalizedFile(Uri uri) async {
    var inspection = const DownloadFileInspection(
      exists: false,
      readable: false,
    );
    for (final delay in _mediaStoreInspectionDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      inspection = await inspectFile(uri.toString());
      if (inspection.exists && inspection.readable) {
        return inspection;
      }
    }
    return inspection;
  }

  void _onProgress(TaskProgressUpdate update) {
    final hasTotal = update.hasExpectedFileSize && update.expectedFileSize > 0;
    final progress = update.progress.clamp(0.0, 1.0);
    _events.add(
      DownloadProgressEvent(
        taskId: update.task.taskId,
        bytesDownloaded: hasTotal
            ? (update.expectedFileSize * progress).round()
            : 0,
        totalBytes: hasTotal ? update.expectedFileSize : null,
      ),
    );
  }

  DownloadTaskState _mapStatus(TaskStatus status) => switch (status) {
    TaskStatus.enqueued => DownloadTaskState.queued,
    TaskStatus.running => DownloadTaskState.running,
    TaskStatus.complete => DownloadTaskState.complete,
    TaskStatus.notFound => DownloadTaskState.notFound,
    TaskStatus.failed => DownloadTaskState.failed,
    TaskStatus.canceled => DownloadTaskState.canceled,
    TaskStatus.waitingToRetry => DownloadTaskState.waitingToRetry,
    TaskStatus.paused => DownloadTaskState.paused,
  };

  @override
  void dispose() {
    _downloader.unregisterCallbacks(group: _group);
    unawaited(_events.close());
  }
}
