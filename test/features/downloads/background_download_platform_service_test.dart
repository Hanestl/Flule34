import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/features/downloads/data/background_download_platform_service.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';

void main() {
  final task = DownloadTask(
    taskId: 'download-progress-test',
    url: 'https://example.com/video.mp4',
  );

  test('暂停等负数状态进度不会覆盖已保存的下载进度', () {
    for (final sentinel in const [
      progressFailed,
      progressCanceled,
      progressNotFound,
      progressWaitingToRetry,
      progressPaused,
    ]) {
      expect(
        BackgroundDownloadPlatformService.progressEventForUpdate(
          TaskProgressUpdate(task, sentinel, 1024),
        ),
        isNull,
      );
    }
  });

  test('真实进度仍会换算为已下载字节', () {
    final event = BackgroundDownloadPlatformService.progressEventForUpdate(
      TaskProgressUpdate(task, 0.625, 800),
    );

    expect(event, isA<DownloadProgressEvent>());
    expect(event?.bytesDownloaded, 500);
    expect(event?.totalBytes, 800);
  });
}
