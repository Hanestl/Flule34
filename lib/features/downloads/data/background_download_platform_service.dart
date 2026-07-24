import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import '../domain/download_models.dart';

final class BackgroundDownloadPlatformService
    implements DownloadPlatformService {
  BackgroundDownloadPlatformService({FileDownloader? downloader})
    : _downloader = downloader ?? FileDownloader();

  static const _group = 'flule34_downloads';

  final FileDownloader _downloader;
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
  bool _initialized = false;

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
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
          tapOpensFile: true,
        );
    await _downloader.start(autoCleanDatabase: false);
    _initialized = true;
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
  Future<bool> enqueue(DownloadRequest request) {
    return _downloader.enqueue(
      DownloadTask(
        taskId: request.id,
        url: request.url,
        filename: request.filename,
        headers: request.headers,
        directory: request.directory,
        baseDirectory: BaseDirectory.applicationDocuments,
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
  }

  @override
  Future<bool> pause(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    return task is DownloadTask && await _downloader.pause(task);
  }

  @override
  Future<bool> resume(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    return task is DownloadTask && await _downloader.resume(task);
  }

  @override
  Future<bool> cancel(String taskId) {
    return _downloader.cancelTaskWithId(taskId);
  }

  @override
  Future<bool> openFile(String filePath) {
    return _downloader.openFile(filePath: filePath, mimeType: 'video/mp4');
  }

  void _onStatus(TaskStatusUpdate update) {
    unawaited(_emitStatus(update));
  }

  Future<void> _emitStatus(TaskStatusUpdate update) async {
    final state = _mapStatus(update.status);
    final filePath = state == DownloadTaskState.complete
        ? await update.task.filePath()
        : null;
    _events.add(
      DownloadStatusEvent(
        taskId: update.task.taskId,
        state: state,
        filePath: filePath,
        errorMessage: update.exception?.toString(),
      ),
    );
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
