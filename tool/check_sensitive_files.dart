import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final files = (await _git([
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ])).split('\n').where((path) => path.isNotEmpty).toList(growable: false);
  final forbiddenNames = RegExp(
    r'(^|/)(key\.properties|\.env(?:\..+)?|.+\.(?:jks|keystore|pem|p12|pfx))$',
    caseSensitive: false,
  );
  final forbiddenFiles = files
      .where(forbiddenNames.hasMatch)
      .toList(growable: false);
  if (forbiddenFiles.isNotEmpty) {
    stderr.writeln('发现禁止纳入仓库的敏感文件：');
    forbiddenFiles.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }

  final patterns = <RegExp>[
    RegExp(r'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'),
    RegExp(r'PHPSESSID=[A-Za-z0-9]{24,}'),
    RegExp(
      r'ANDROID_KEYSTORE_BASE64\s*[:=]\s*[A-Za-z0-9+/]{40,}',
      caseSensitive: false,
    ),
    RegExp(r'client[_-]?secret\s*[:=]\s*\S{16,}', caseSensitive: false),
  ];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() > 5 * 1024 * 1024) {
      continue;
    }
    final bytes = await file.readAsBytes();
    if (bytes.contains(0)) {
      continue;
    }
    final source = utf8.decode(bytes, allowMalformed: true);
    for (final pattern in patterns) {
      if (pattern.hasMatch(source)) {
        stderr.writeln('发现疑似敏感内容：$path（规则：${pattern.pattern}）');
        exitCode = 1;
        return;
      }
    }
  }
  stdout.writeln('敏感文件与高风险凭据模式检查通过。');
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  return result.stdout.toString();
}
