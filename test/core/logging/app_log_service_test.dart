import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/logging/app_log_service.dart';

void main() {
  test('启动会清理旧日志且内部记录接口不再落盘', () async {
    final root = await Directory.systemTemp.createTemp('flule34-log-cleanup-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final logs = Directory('${root.path}${Platform.pathSeparator}flule34_logs');
    await logs.create(recursive: true);
    await File(
      '${logs.path}${Platform.pathSeparator}legacy.log',
    ).writeAsString('legacy');
    var preferencesCleared = false;
    final service = AppLogService(
      supportDirectory: () async => root,
      clearPreferences: () async => preferencesCleared = true,
    );

    await service.initialize();
    await service.error('test', '不会写入文件', error: StateError('test'));

    expect(await logs.exists(), isFalse);
    expect(preferencesCleared, isTrue);
    expect(root.listSync(), isEmpty);
  });
}
