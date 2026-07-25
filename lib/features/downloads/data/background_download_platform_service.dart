import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../domain/download_models.dart';

final class BackgroundDownloadPlatformService
    implements DownloadPlatformService {
  BackgroundDownloadPlatformService({
    FileDownloader? downloader,
    int maxConcurrent = 2,
  }) : _downloader = downloader ?? FileDownloader(),
       _maxConcurrent = maxConcurrent.clamp(1, 4);

  static const _group = 'flule34_downloads';

  final FileDownloader _downloader;
  int _maxConcurrent;
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
          tapOpensFile: true,
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

  @override
  Future<String?> exportToDownloads(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    if (task is! DownloadTask) {
      return null;
    }
    final source = File(await task.filePath());
    if (!await source.exists()) {
      return null;
    }
    final exportDirectory = Directory(
      '${source.parent.path}${Platform.pathSeparator}.flule34-export-${DateTime.now().microsecondsSinceEpoch}',
    );
    final temporaryCopy = File(
      '${exportDirectory.path}${Platform.pathSeparator}${task.filename}',
    );
    try {
      await exportDirectory.create();
      await source.copy(temporaryCopy.path);
      return await _downloader.moveFileToSharedStorage(
        temporaryCopy.path,
        SharedStorage.downloads,
        directory: 'Flule34',
        mimeType: 'video/mp4',
      );
    } on FileSystemException {
      return null;
    } finally {
      try {
        if (await temporaryCopy.exists()) {
          await temporaryCopy.delete();
        }
        if (await exportDirectory.exists()) {
          await exportDirectory.delete();
        }
      } on FileSystemException {
        // 临时目录位于 App 私有目录；清理失败不会影响原始下载文件。
      }
    }
  }

  @override
  Future<bool> delete({
    required String taskId,
    required String directory,
    String? filePath,
  }) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    if (task != null && _normalize(task.directory) != _normalize(directory)) {
      return false;
    }

    await _downloader.cancelTaskWithId(taskId);
    final resolvedPath = filePath ?? await task?.filePath();
    if (resolvedPath != null) {
      final normalizedPath = _normalize(resolvedPath);
      final normalizedDirectory = _normalize(directory);
      final isInsideDirectory =
          normalizedPath.startsWith('$normalizedDirectory/') ||
          normalizedPath.contains('/$normalizedDirectory/');
      if (!isInsideDirectory) {
        return false;
      }
      final file = File(resolvedPath);
      try {
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

  String _normalize(String value) {
    return value.replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
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
