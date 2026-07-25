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
    required this.directoryUri,
    required this.displayName,
    required this.metadata,
    required this.headers,
    this.requiresWiFi = false,
  });

  final String id;
  final String url;
  final String filename;
  final Uri directoryUri;
  final String displayName;
  final String metadata;
  final Map<String, String> headers;
  final bool requiresWiFi;
}

final class DownloadDirectorySelection {
  const DownloadDirectorySelection({required this.uri, required this.label});

  final Uri uri;
  final String label;
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

  Future<void> setMaxConcurrent(int value);

  Future<bool> ensureNotificationPermission();

  Future<DownloadDirectorySelection?> pickDefaultDirectory();

  Future<DownloadDirectorySelection?> pickCustomDirectory();

  Future<Uri?> activateDirectory(Uri uri);

  Future<bool> enqueue(DownloadRequest request);

  Future<bool> pause(String taskId);

  Future<bool> resume(String taskId);

  Future<bool> cancel(String taskId);

  Future<bool> openFile(String fileUri);

  Future<bool> delete({required String taskId, String? fileUri});

  void dispose();
}
