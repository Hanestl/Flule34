import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/features/settings/data/app_diagnostics_service.dart';
import 'package:flule34/features/settings/domain/app_settings.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('诊断报告统计设备级下载而不是当前账号下载', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.database.recordAuthenticatedAccount(
      '__flule34_device__',
      displayName: '本机下载',
    );
    await harness.database.saveDownloadRecord(
      DownloadRecordsCompanion(
        id: const Value('task-1'),
        userId: const Value('__flule34_device__'),
        videoId: const Value('4505897'),
        title: const Value('测试视频'),
        quality: const Value('720p'),
        state: const Value('complete'),
      ),
    );
    final service = AppDiagnosticsService(
      harness.database,
      harness.sessionStore,
      AppSettings.defaults,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Flule34',
        packageName: 'com.hanestl.flule34',
        version: '1.1.1',
        buildNumber: '2003',
      ),
    );

    final entries = Map<String, String>.fromEntries(
      (await service.collect()).entries,
    );

    expect(entries['本机下载记录'], '1');
    expect(entries.containsKey('当前账号下载记录'), isFalse);
  });
}
