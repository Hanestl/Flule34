import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class AppLogService {
  AppLogService({
    Future<Directory> Function()? supportDirectory,
    Future<void> Function()? clearPreferences,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _clearPreferences = clearPreferences ?? _clearLegacyPreferences;

  final Future<Directory> Function() _supportDirectory;
  final Future<void> Function() _clearPreferences;
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      final root = await _supportDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}flule34_logs',
      );
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await _clearPreferences();
    } on Object {
      // 旧日志清理失败不能阻止 App 启动。
    }
  }

  Future<void> debug(String category, String message) => Future<void>.value();

  Future<void> info(String category, String message) => Future<void>.value();

  Future<void> warning(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => Future<void>.value();

  Future<void> error(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => Future<void>.value();
}

final sharedAppLogService = AppLogService();

Future<void> _clearLegacyPreferences() async {
  final preferences = SharedPreferencesAsync();
  await preferences.remove('flule34.settings.debug_logging_enabled');
  await preferences.remove('flule34.settings.debug_log_retention_days');
}
