import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/logging/app_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('调试日志会脱敏、停止记录并支持清除', () async {
    final root = await Directory.systemTemp.createTemp('flule34_logs_test_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final service = AppLogService(supportDirectory: () async => root);
    await service.initialize(enabledOverride: true, retentionDaysOverride: 3);

    await service.error(
      'test',
      '下载失败 Cookie: PHPSESSID=secret-cookie',
      error: 'Authorization: Bearer secret-token',
    );
    final first = await service.snapshot();

    expect(first.content, contains('<redacted>'));
    expect(first.content, isNot(contains('secret-cookie')));
    expect(first.content, isNot(contains('secret-token')));

    await service.configure(enabled: false, retentionDays: 3);
    await service.info('test', '不应写入的新消息');
    final stopped = await service.snapshot();
    expect(stopped.content, isNot(contains('不应写入的新消息')));

    await service.clear();
    final cleared = await service.snapshot();
    expect(cleared.fileCount, 0);
    expect(cleared.content, isEmpty);
  });
}
