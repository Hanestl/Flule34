enum DownloadTaskState {
  queued,
  running,
  complete,
  notFound,
  failed,
  canceled,
  waitingToRetry,
  paused;

  String get storageValue => switch (this) {
    DownloadTaskState.queued => 'queued',
    DownloadTaskState.running => 'running',
    DownloadTaskState.complete => 'complete',
    DownloadTaskState.notFound => 'not_found',
    DownloadTaskState.failed => 'failed',
    DownloadTaskState.canceled => 'canceled',
    DownloadTaskState.waitingToRetry => 'waiting_to_retry',
    DownloadTaskState.paused => 'paused',
  };

  bool get isActive => switch (this) {
    DownloadTaskState.queued ||
    DownloadTaskState.running ||
    DownloadTaskState.waitingToRetry ||
    DownloadTaskState.paused => true,
    _ => false,
  };
}

final class DownloadRequest {
  const DownloadRequest({
    required this.id,
    required this.url,
    required this.filename,
    required this.directory,
    required this.displayName,
    required this.metadata,
    required this.headers,
    this.requiresWiFi = false,
  });

  final String id;
  final String url;
  final String filename;
  final String directory;
  final String displayName;
  final String metadata;
  final Map<String, String> headers;
  final bool requiresWiFi;
}

sealed class DownloadPlatformEvent {
  const DownloadPlatformEvent({required this.taskId});

  final String taskId;
}

final class DownloadStatusEvent extends DownloadPlatformEvent {
  const DownloadStatusEvent({
    required super.taskId,
    required this.state,
    this.filePath,
    this.errorMessage,
  });

  final DownloadTaskState state;
  final String? filePath;
  final String? errorMessage;
}

final class DownloadProgressEvent extends DownloadPlatformEvent {
  const DownloadProgressEvent({
    required super.taskId,
    required this.bytesDownloaded,
    this.totalBytes,
  });

  final int bytesDownloaded;
  final int? totalBytes;
}

abstract interface class DownloadPlatformService {
  Stream<DownloadPlatformEvent> get events;

  Future<void> initialize();

  Future<bool> ensureNotificationPermission();

  Future<bool> enqueue(DownloadRequest request);

  Future<bool> pause(String taskId);

  Future<bool> resume(String taskId);

  Future<bool> cancel(String taskId);

  Future<bool> openFile(String filePath);

  void dispose();
}
