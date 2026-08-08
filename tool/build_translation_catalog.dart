import 'dart:convert';
import 'dart:io';

import 'translation_catalog.dart';

const sourceCommit = '65a05094f4d86c8021c66d06717133e9994b7478';
const sourceSha256 =
    'fbea8c77f3074184d8a4d20e079deb7157f9f186c43d22c9a376cdcd0dd14315';
const sourceUrl =
    'https://raw.githubusercontent.com/sanfangx/Flule34/'
    '$sourceCommit/assets/tags/rule34video_tags_zh.csv';
const defaultOutput = 'assets/translations/rule34video_tags_zh.json';
const defaultReport = 'docs/translation_catalog.md';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final source = options.inputPath == null
      ? await _downloadSource()
      : await File(options.inputPath!).readAsString(encoding: utf8);
  final result = buildTranslationCatalog(source);

  final output = File(options.outputPath);
  final report = File(options.reportPath);
  await output.parent.create(recursive: true);
  await report.parent.create(recursive: true);
  await output.writeAsString(result.toJson(), encoding: utf8);
  await report.writeAsString(
    result.toMarkdownReport(
      sourceCommit: sourceCommit,
      sourceSha256: sourceSha256,
    ),
    encoding: utf8,
  );

  stdout.writeln('词表生成完成：${output.path}');
  stdout.writeln('质量报告：${report.path}');
  stdout.writeln('原始行：${result.stats.inputRows}');
  stdout.writeln('最终词条：${result.stats.uniqueEntries}');
  stdout.writeln('重复行：${result.stats.duplicateRows}');
  stdout.writeln('相同译文：${result.stats.identityRows}');
  stdout.writeln('无中文译文：${result.stats.nonChineseRows}');
  stdout.writeln('保留完整英文原文：${result.stats.englishEchoRows}');
}

Future<String> _downloadSource() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(sourceUrl));
    request.headers.set(HttpHeaders.userAgentHeader, 'Flule34 catalog builder');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        '下载词表失败：HTTP ${response.statusCode}',
        uri: Uri.parse(sourceUrl),
      );
    }
    return utf8.decode(
      await response.fold<List<int>>([], (all, bytes) {
        all.addAll(bytes);
        return all;
      }),
    );
  } finally {
    client.close(force: true);
  }
}

final class _Options {
  const _Options({
    required this.inputPath,
    required this.outputPath,
    required this.reportPath,
  });

  final String? inputPath;
  final String outputPath;
  final String reportPath;

  static _Options parse(List<String> arguments) {
    String? inputPath;
    var outputPath = defaultOutput;
    var reportPath = defaultReport;
    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      String nextValue() {
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument 缺少路径参数。');
        }
        index += 1;
        return arguments[index];
      }

      switch (argument) {
        case '--input':
          inputPath = nextValue();
        case '--output':
          outputPath = nextValue();
        case '--report':
          reportPath = nextValue();
        default:
          throw FormatException('未知参数：$argument');
      }
    }
    return _Options(
      inputPath: inputPath,
      outputPath: outputPath,
      reportPath: reportPath,
    );
  }
}
