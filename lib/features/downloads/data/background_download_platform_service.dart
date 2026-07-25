import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import '../../../core/security/error_redaction.dart';
import '../domain/download_models.dart';

final class BackgroundDownloadPlatformService
    implements DownloadPlatformService {
  BackgroundDownloadPlatformService({int maxConcurrent = 2})
    : this._(maxConcurrent);

  BackgroundDownloadPlatformService._(this._maxConcurrent);

  static const _group = 'flule34-downloads';

  final FileDownloader _downloader = FileDownloader();
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
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
  Future<DownloadDirectorySelection?> pickDefaultDirectory() async {
    final parent = await _downloader.uri.pickDirectory(
      startLocation: SharedStorage.downloads,
      persistedUriPermission: true,
    );
    if (parent == null) {
      return null;
    }
    final directory = await _downloader.uri.createDirectory(
      parent,
      'Flule34',
      persistedUriPermission: true,
    );
    return DownloadDirectorySelection(
      uri: directory,
      label: 'Downloads/Flule34',
    );
  }

  @override
  Future<DownloadDirectorySelection?> pickCustomDirectory() async {
    final directory = await _downloader.uri.pickDirectory(
      startLocation: SharedStorage.downloads,
      persistedUriPermission: true,
    );
    if (directory == null) {
      return null;
    }
    return DownloadDirectorySelection(
      uri: directory,
      label: _directoryLabel(directory),
    );
  }

  @override
  Future<Uri?> activateDirectory(Uri uri) {
    return _downloader.uri.activate(uri);
  }

  @override
  Future<bool> enqueue(DownloadRequest request) {
    return _downloader.enqueue(
      UriDownloadTask(
        taskId: request.id,
        url: request.url,
        filename: request.filename,
        headers: request.headers,
        directoryUri: request.directoryUri,
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
  Future<bool> openFile(String fileUri) {
    return _downloader.uri.openFile(Uri.parse(fileUri), mimeType: 'video/mp4');
  }

  @override
  Future<bool> delete({required String taskId, String? fileUri}) async {
    final record = await _downloader.database.recordForId(taskId);
    final task = record?.task;
    await _downloader.cancelTaskWithId(taskId);
    final resolvedUri =
        fileUri ?? (task is UriDownloadTask ? task.fileUri?.toString() : null);
    if (resolvedUri != null) {
      try {
        if (!await _downloader.uri.deleteFile(Uri.parse(resolvedUri))) {
          return false;
        }
      } on Exception {
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
    final state = _mapStatus(update.status);
    final fileUri =
        state == DownloadTaskState.complete && update.task is UriDownloadTask
        ? (update.task as UriDownloadTask).fileUri?.toString()
        : null;
    _events.add(
      DownloadStatusEvent(
        taskId: update.task.taskId,
        state: state,
        filePath: fileUri,
        errorMessage: update.exception == null
            ? null
            : redactSensitiveText(update.exception),
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

  String _directoryLabel(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return '自定义目录';
    }
    final decoded = Uri.decodeComponent(uri.pathSegments.last);
    final name = decoded.contains(':') ? decoded.split(':').last : decoded;
    final normalized = name.replaceAll('/', ' / ').trim();
    return normalized.isEmpty ? '自定义目录' : normalized;
  }

  @override
  void dispose() {
    _downloader.unregisterCallbacks(group: _group);
    unawaited(_events.close());
  }
}
