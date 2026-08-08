import 'dart:convert';
import 'dart:io';

const _inputFile = 'tool/data/deepseek_translation_review.json';
const _outputFile = 'tool/data/manual_translation_review.json';
const _reportFile = 'docs/manual_translation_review.md';

const _manualApproved = <String, Map<String, String>>{
  'tag': {
    '02 (darling in the franxx)': '02（DARLING in the FRANXX）',
    'zero two (darling in the franxx)': '02（DARLING in the FRANXX）',
  },
  'category': {
    'Astria Ascending': '星位继承者',
    'Hi-Fi Rush': '完美音浪',
    'Hifi Rush': '完美音浪',
    'the catillac cats': '卡提拉克猫',
    'the oblongs': '奥布隆一家',
  },
};

Future<void> main() async {
  final source =
      jsonDecode(await File(_inputFile).readAsString(encoding: utf8))
          as Map<String, dynamic>;
  final rawReview = source['review'];
  if (rawReview is! List) {
    throw const FormatException('审计文件缺少 review 数组。');
  }

  final approved = <Map<String, dynamic>>[];
  final keepEnglish = <Map<String, dynamic>>[];
  for (final raw in rawReview) {
    if (raw is! Map) {
      throw const FormatException('复核条目不是对象。');
    }
    final item = Map<String, dynamic>.from(raw);
    final kind = item['kind']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final translation = _manualApproved[kind]?[name];
    if (translation != null) {
      approved.add({
        'kind': kind,
        'name': name,
        'action': 'translate',
        'chinese': translation,
        'confidence': 1.0,
        'note': '人工核验通过：有明确通行中文译名。',
      });
    } else {
      keepEnglish.add({
        'kind': kind,
        'name': name,
        'action': 'keep',
        'chinese': name,
        'confidence': 1.0,
        'note': '人工核验：未确认有可靠中文译名，保留英文原文。',
      });
    }
  }

  final output = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'reviewedCount': rawReview.length,
    'approvedCount': approved.length,
    'keepEnglishCount': keepEnglish.length,
    'approved': approved,
    'keepEnglish': keepEnglish,
  };
  await File(_outputFile).writeAsString(
    const JsonEncoder.withIndent('  ').convert(output),
    encoding: utf8,
  );
  final report = StringBuffer()
    ..writeln('# 内置译文人工复核报告')
    ..writeln()
    ..writeln('- 生成时间：${output['generatedAt']}')
    ..writeln('- 复核总数：${rawReview.length}')
    ..writeln('- 人工补译：${approved.length}')
    ..writeln('- 确认保留英文：${keepEnglish.length}')
    ..writeln()
    ..writeln('## 人工补译')
    ..writeln()
    ..writeln('| 类型 | 英文原文 | 中文译文 |')
    ..writeln('| --- | --- | --- |');
  for (final item in approved) {
    report.writeln(
      '| ${item['kind']} | ${item['name']} | ${item['chinese']} |',
    );
  }
  report
    ..writeln()
    ..writeln('其余条目因属于专有名词、用户名、缩写、拼写异常或缺少可靠通行译名，保留英文原文。');
  await File(_reportFile).writeAsString(report.toString(), encoding: utf8);
  stdout.writeln('人工复核结果：$_outputFile');
  stdout.writeln('人工复核报告：$_reportFile');
  stdout.writeln('复核总数：${rawReview.length}');
  stdout.writeln('人工补译：${approved.length}');
  stdout.writeln('保留英文：${keepEnglish.length}');
}
