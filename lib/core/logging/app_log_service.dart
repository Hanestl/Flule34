import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/error_redaction.dart';

enum AppLogLevel { debug, info, warning, error }

final class DebugLogSnapshot {
  const DebugLogSnapshot({
    required this.content,
    required this.fileCount,
    required this.totalBytes,
    required this.truncated,
  });

  final String content;
  final int fileCount;
  final int totalBytes;
  final bool truncated;
}

final class AppLogService extends ChangeNotifier {
  AppLogService({
    Future<Directory> Function()? supportDirectory,
    this._preferences,
    MethodChannel? nativeChannel,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _nativeChannel =
           nativeChannel ?? const MethodChannel('com.hanestl.flule34/app_log');

  static const enabledPreferenceKey = 'flule34.settings.debug_logging_enabled';
  static const retentionDaysPreferenceKey =
      'flule34.settings.debug_log_retention_days';
  static const maxRetentionDays = 7;
  static const maxFileBytes = 2 * 1024 * 1024;
  static const _directoryName = 'flule34_logs';

  final Future<Directory> Function() _supportDirectory;
  final SharedPreferencesAsync? _preferences;
  final MethodChannel _nativeChannel;

  Directory? _directory;
  Future<void> _writeTail = Future<void>.value();
  bool _initialized = false;
  bool _enabled = false;
  int _retentionDays = 3;

  bool get isInitialized => _initialized;
  bool get enabled => _enabled;
  int get retentionDays => _retentionDays;

  Future<void> initialize({
    bool? enabledOverride,
    int? retentionDaysOverride,
  }) async {
    if (_initialized) {
      return;
    }
    try {
      final root = await _supportDirectory();
      _directory = Directory(
        '${root.path}${Platform.pathSeparator}$_directoryName',
      );
      await _directory!.create(recursive: true);
      final preferences =
          enabledOverride == null || retentionDaysOverride == null
          ? _preferences ?? SharedPreferencesAsync()
          : null;
      _enabled =
          enabledOverride ??
          await preferences!.getBool(enabledPreferenceKey) ??
          false;
      _retentionDays = _normalizeRetention(
        retentionDaysOverride ??
            int.tryParse(
              await preferences!.getString(retentionDaysPreferenceKey) ?? '',
            ) ??
            3,
      );
      _initialized = true;
      await _cleanupExpiredFiles();
      await _syncNativeConfiguration();
      if (_enabled) {
        await info('app', '调试日志已启动，保留 $_retentionDays 天。');
      }
    } catch (error, stackTrace) {
      _initialized = true;
      debugPrint('调试日志初始化失败：$error\n$stackTrace');
    }
  }

  Future<void> configure({
    required bool enabled,
    required int retentionDays,
  }) async {
    final nextRetention = _normalizeRetention(retentionDays);
    final changed = _enabled != enabled || _retentionDays != nextRetention;
    _enabled = enabled;
    _retentionDays = nextRetention;
    if (_initialized) {
      await _cleanupExpiredFiles();
      await _syncNativeConfiguration();
      if (_enabled && changed) {
        await info('settings', '调试日志已开启，保留 $_retentionDays 天。');
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> debug(String category, String message) {
    return record(AppLogLevel.debug, category, message);
  }

  Future<void> info(String category, String message) {
    return record(AppLogLevel.info, category, message);
  }

  Future<void> warning(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return record(
      AppLogLevel.warning,
      category,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> error(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return record(
      AppLogLevel.error,
      category,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> record(
    AppLogLevel level,
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled || _directory == null) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      final now = DateTime.now();
      final file = File(
        '${_directory!.path}${Platform.pathSeparator}'
        'dart-${_datePart(now)}.log',
      );
      if (await file.exists() && await file.length() >= maxFileBytes) {
        return;
      }
      final buffer = StringBuffer()
        ..write(now.toIso8601String())
        ..write(' ')
        ..write(level.name.toUpperCase())
        ..write(' ')
        ..write(_singleLine(category))
        ..write(' ')
        ..writeln(_multiline(message));
      if (error != null) {
        buffer.writeln(
          'error: ${_multiline(redactSensitiveText(error, maxLength: 12000))}',
        );
      }
      if (stackTrace != null) {
        buffer.writeln(
          'stack: ${_multiline(redactSensitiveText(stackTrace, maxLength: 24000))}',
        );
      }
      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: level == AppLogLevel.error,
      );
    });
  }

  Future<DebugLogSnapshot> snapshot({int maxCharacters = 240000}) async {
    await _writeTail;
    final files = await _logFiles();
    var totalBytes = 0;
    final sections = <String>[];
    for (final file in files) {
      totalBytes += await file.length();
      try {
        sections.add(
          '===== ${file.uri.pathSegments.last} =====\n${await file.readAsString()}',
        );
      } on FileSystemException catch (error) {
        sections.add('===== ${file.uri.pathSegments.last} =====\n读取失败：$error');
      }
    }
    var content = sections.join('\n');
    var truncated = false;
    if (content.length > maxCharacters) {
      content =
          '（日志过长，仅显示末尾 $maxCharacters 个字符）\n'
          '${content.substring(content.length - maxCharacters)}';
      truncated = true;
    }
    return DebugLogSnapshot(
      content: content,
      fileCount: files.length,
      totalBytes: totalBytes,
      truncated: truncated,
    );
  }

  Future<void> clear() async {
    await _writeTail;
    final files = await _logFiles();
    for (final file in files) {
      try {
        await file.delete();
      } on FileSystemException {
        // 尽力清理；单个文件失败不阻止其余文件删除。
      }
    }
  }

  Future<void> flush() => _writeTail;

  Future<void> _cleanupExpiredFiles() async {
    final directory = _directory;
    if (directory == null || !await directory.exists()) {
      return;
    }
    final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.log')) {
        continue;
      }
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException {
        // 清理失败不影响正常记录。
      }
    }
  }

  Future<List<File>> _logFiles() async {
    final directory = _directory;
    if (directory == null || !await directory.exists()) {
      return const [];
    }
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.log')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _syncNativeConfiguration() async {
    try {
      await _nativeChannel.invokeMethod<void>('configure', {
        'enabled': _enabled,
        'retentionDays': _retentionDays,
      });
    } on MissingPluginException {
      // Widget/单元测试或非 Android 平台没有原生通道。
    } on PlatformException catch (error) {
      debugPrint('同步原生日志设置失败：${error.message ?? error.code}');
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _writeTail.then((_) => action()).catchError((Object error) {
      debugPrint('写入调试日志失败：$error');
    });
    _writeTail = next;
    return next;
  }

  int _normalizeRetention(int value) => value.clamp(1, maxRetentionDays);

  String _datePart(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  String _singleLine(String value) {
    return redactSensitiveText(
      value,
      maxLength: 1200,
    ).replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  }

  String _multiline(String value) {
    return redactSensitiveText(value, maxLength: 24000)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', '\n  ')
        .trimRight();
  }
}

final sharedAppLogService = AppLogService();
