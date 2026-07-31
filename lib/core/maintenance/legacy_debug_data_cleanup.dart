import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearLegacyDebugLoggingData({
  Future<Directory> Function()? supportDirectory,
  Future<void> Function()? clearPreferences,
}) async {
  try {
    final root = await (supportDirectory ?? getApplicationSupportDirectory)();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}flule34_logs',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await (clearPreferences ?? _clearLegacyPreferences)();
  } on Object {
    // 旧版本调试数据清理失败不能阻止 App 启动。
  }
}

Future<void> _clearLegacyPreferences() async {
  final store = SharedPreferencesAsync();
  await store.remove('flule34.settings.debug_logging_enabled');
  await store.remove('flule34.settings.debug_log_retention_days');
}
