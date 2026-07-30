import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/features/downloads/presentation/downloads_list.dart';

void main() {
  test('运行任务在首个微小数据分片阶段仍显示正在连接', () {
    final record = _record(bytesDownloaded: 707, totalBytes: 1024 * 1024);

    expect(isDownloadConnecting(record), isTrue);
    expect(
      downloadStatusText(
        record,
        validation: null,
        validating: false,
        invalid: false,
      ),
      '正在连接',
    );
  });

  test('达到有意义的数据量后显示真实下载进度', () {
    final record = _record(
      bytesDownloaded: meaningfulDownloadProgressBytes,
      totalBytes: 1024 * 1024,
    );

    expect(isDownloadConnecting(record), isFalse);
    expect(
      downloadStatusText(
        record,
        validation: null,
        validating: false,
        invalid: false,
      ),
      '正在下载 · 64.0 KB / 1.0 MB',
    );
  });
}

DownloadRecord _record({
  required int bytesDownloaded,
  required int totalBytes,
}) {
  final now = DateTime(2026, 7, 30);
  return DownloadRecord(
    id: 'download-test',
    userId: 'device',
    videoId: 'video',
    title: '测试视频',
    quality: '1080p',
    state: 'running',
    bytesDownloaded: bytesDownloaded,
    totalBytes: totalBytes,
    createdAt: now,
    updatedAt: now,
  );
}
