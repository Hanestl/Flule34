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

  test('下载配置使用较短连接超时和不含内容信息的合并通知', () {
    expect(
      BackgroundDownloadPlatformService.requestTimeout,
      const Duration(seconds: 15),
    );
    expect(
      BackgroundDownloadPlatformService.notificationGroupId,
      'flule34-background-tasks',
    );
    final notification = BackgroundDownloadPlatformService.runningNotification;
    expect(notification.title, '后台任务进行中');
    expect(notification.body, '正在处理');
    expect('${notification.title}${notification.body}', isNot(contains('{')));
  });

  test('协程取消与网络异常会转换为可理解的提示', () {
    expect(
      BackgroundDownloadPlatformService.displayErrorFor(
        'TaskException: v8.uO: g1 was cancelled;job=g1{Cancelling}',
      ),
      '下载任务被系统中断，请重试。',
    );
    expect(
      BackgroundDownloadPlatformService.displayErrorFor(
        'SocketException: Connection reset by peer',
      ),
      '网络连接中断，请检查网络后重试。',
    );
  });
}
