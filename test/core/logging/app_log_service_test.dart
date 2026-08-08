import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/logging/app_log_service.dart';

void main() {
  test('日志自动脱敏、按七天保留并支持清除', () async {
    final root = await Directory.systemTemp.createTemp('flule34-app-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final now = DateTime(2026, 8, 7, 12);
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    )..createSync(recursive: true);
    await File(
      '${directory.path}${Platform.pathSeparator}flule34-2026-07-31.log',
    ).writeAsString('old');
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => now,
    );

    await service.initialize();
    await service.error(
      StateError('password=secret-value'),
      StackTrace.current,
      component: 'test',
    );

    final text = await service.readAll();
    expect(text, contains('[ERROR] [test]'));
    expect(text, isNot(contains('secret-value')));
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}flule34-2026-07-31.log',
      ).exists(),
      isFalse,
    );
    expect((await service.storageInfo()).fileCount, 1);

    await service.clear();
    expect((await service.storageInfo()).fileCount, 0);
  });

  test('错误日志会保留足够长的调用栈用于符号化', () async {
    final root = await Directory.systemTemp.createTemp('flule34-stack-log-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final service = AppLogService.forTesting(
      supportDirectory: () async => root,
      clock: () => DateTime(2026, 8, 8, 12),
    );
    await service.initialize();
    final stack = StackTrace.fromString(
      '${List.generate(180, (index) => '#$index frame-$index').join('\n')}\n'
      'tail-symbolization-marker',
    );
    await service.error(
      StateError('player failure'),
      stack,
      component: 'video',
    );

    final text = await service.readAll();
    expect(text, contains('tail-symbolization-marker'));
    expect(text.length, greaterThan(2000));
  });
}
