import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../security/error_redaction.dart';

final class AppLogService {
  AppLogService._({
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? clock,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  static final AppLogService instance = AppLogService._();

  AppLogService.forTesting({
    required Future<Directory> Function() supportDirectory,
    DateTime Function()? clock,
  }) : this._(supportDirectory: supportDirectory, clock: clock);

  static const _directoryName = 'flule34_logs';
  static const _exportDirectoryName = 'flule34_log_exports';
  static const _filePrefix = 'flule34-';
  static const _fileSuffix = '.log';
  static const _retentionDays = 7;
  static const _maxFileBytes = 2 * 1024 * 1024;
  static const _maxTotalBytes = 10 * 1024 * 1024;

  Future<Directory>? _directoryFuture;
  Future<void> _writeChain = Future<void>.value();
  var _cleared = false;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _clock;

  Future<Directory> _directory() {
    return _directoryFuture ??= _supportDirectory().then((root) {
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$_directoryName',
      );
      return directory;
    });
  }

  Future<void> initialize() async {
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      await _purge(directory);
      await _clearExportFiles();
    } on Object {
      // 日志不能阻止应用启动。
    }
  }

  Future<void> info(String message, {String component = 'app'}) =>
      _append('INFO', message, component: component);

  Future<void> warning(String message, {String component = 'app'}) =>
      _append('WARN', message, component: component);

  Future<void> error(
    Object error,
    StackTrace stackTrace, {
    String component = 'app',
  }) {
    final safeError = redactSensitiveText(error, maxLength: 4000);
    final safeStack = redactSensitiveText(stackTrace, maxLength: 12000);
    return _append(
      'ERROR',
      '$safeError\n$safeStack',
      component: component,
      maxMessageLength: 16000,
    );
  }

  Future<void> _append(
    String level,
    String message, {
    required String component,
    int maxMessageLength = 2000,
  }) {
    final operation = _writeChain = _writeChain.then((_) async {
      try {
        if (_cleared) {
          _cleared = false;
        }
        final directory = await _directory();
        await directory.create(recursive: true);
        await _purge(directory);
        final now = _clock();
        final file = File(
          '${directory.path}${Platform.pathSeparator}$_filePrefix${_dateKey(now)}$_fileSuffix',
        );
        if (await file.exists() && await file.length() >= _maxFileBytes) {
          return;
        }
        final safeMessage = redactSensitiveText(
          message,
          maxLength: maxMessageLength,
        ).replaceAll('\r', '');
        final line =
            '${now.toIso8601String()} [$level] [$component] '
            '${safeMessage.replaceAll('\n', '\\n')}\n';
        await file.writeAsString(line, mode: FileMode.append, encoding: utf8);
        await _purge(directory);
      } on Object {
        // 记录失败不能影响业务流程。
      }
    });
    return operation;
  }

  Future<List<File>> _logFiles() async {
    final directory = await _directory();
    if (!await directory.exists()) {
      return const <File>[];
    }
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith(_fileSuffix) &&
          entity.path.contains(_filePrefix)) {
        files.add(entity);
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<void> _purge(Directory directory) async {
    final files = await _logFiles();
    final cutoff = _clock().subtract(const Duration(days: _retentionDays - 1));
    for (final file in files) {
      final key = _dateFromFile(file.path);
      if (key == null ||
          key.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
        try {
          await file.delete();
        } on Object {
          // 单个旧日志删除失败不影响其他文件清理。
        }
      }
    }
    final remaining = await _logFiles();
    var totalBytes = 0;
    for (final file in remaining.reversed) {
      final length = await file.length();
      if (totalBytes + length > _maxTotalBytes) {
        try {
          await file.delete();
        } on Object {
          // 单个日志删除失败不影响后续清理。
        }
      } else {
        totalBytes += length;
      }
    }
  }

  Future<LogStorageInfo> storageInfo() async {
    try {
      final files = await _logFiles();
      var bytes = 0;
      for (final file in files) {
        bytes += await file.length();
      }
      return LogStorageInfo(fileCount: files.length, bytes: bytes);
    } on Object {
      return const LogStorageInfo(fileCount: 0, bytes: 0);
    }
  }

  Future<String> readAll() async {
    await _writeChain;
    final files = await _logFiles();
    final buffer = StringBuffer();
    for (final file in files) {
      buffer.writeln('===== ${file.uri.pathSegments.last} =====');
      buffer.write(await file.readAsString(encoding: utf8));
      if (!buffer.toString().endsWith('\n')) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  Future<File> createExportFile(String content, {String? fileName}) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$_exportDirectoryName',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    final now = _clock();
    final resolvedName =
        fileName ??
        'Flule34-logs-${now.year.toString().padLeft(4, '0')}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}.txt';
    final file = File(
      '${directory.path}${Platform.pathSeparator}$resolvedName',
    );
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file;
  }

  Future<void> clear() async {
    await _writeChain;
    final directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await _clearExportFiles();
    _cleared = true;
  }

  Future<void> _clearExportFiles() async {
    try {
      final root = await getTemporaryDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}$_exportDirectoryName',
      );
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on Object {
      // 临时导出文件清理失败不能影响日志记录和应用启动。
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime? _dateFromFile(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(
      '^${RegExp.escape(_filePrefix)}(\\d{4})-(\\d{2})-(\\d{2})${RegExp.escape(_fileSuffix)}\$',
    ).firstMatch(name);
    if (match == null) {
      return null;
    }
    return DateTime.tryParse(
      '${match.group(1)}-${match.group(2)}-${match.group(3)}',
    );
  }
}

final class LogStorageInfo {
  const LogStorageInfo({required this.fileCount, required this.bytes});

  final int fileCount;
  final int bytes;

  String get formattedSize {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
