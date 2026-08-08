import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearLegacyDebugLoggingData({
  Future<Directory> Function()? supportDirectory,
  Future<void> Function()? clearPreferences,
}) async {
  try {
    // 旧版本的调试日志配置可以清理，但不能再删除新日志目录。
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
