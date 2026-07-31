import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/maintenance/legacy_debug_data_cleanup.dart';

void main() {
  test('启动清理旧日志目录和调试日志设置', () async {
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

    await clearLegacyDebugLoggingData(
      supportDirectory: () async => root,
      clearPreferences: () async => preferencesCleared = true,
    );

    expect(await logs.exists(), isFalse);
    expect(preferencesCleared, isTrue);
  });
}
