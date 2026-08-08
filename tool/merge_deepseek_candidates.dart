import 'dart:convert';
import 'dart:io';

const _approvalThreshold = 0.8;

Future<void> main() async {
  final directory = Directory('tool/data');
  final files = await directory
      .list()
      .where((entity) => entity is File)
      .cast<File>()
      .where(
        (file) =>
            RegExp(
              r'^deepseek_trial_(tag|category)_\d+_\d+\.json$',
            ).hasMatch(file.uri.pathSegments.last) &&
            !file.uri.pathSegments.last.endsWith('_0_20.json'),
      )
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));

  final grouped = <String, List<Map<String, dynamic>>>{
    'tag': <Map<String, dynamic>>[],
    'category': <Map<String, dynamic>>[],
  };
  for (final file in files) {
    final decoded = jsonDecode(await file.readAsString(encoding: utf8));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('候选文件不是 JSON 对象：${file.path}');
    }
    final kind = decoded['kind']?.toString();
    final items = decoded['items'];
    if (!grouped.containsKey(kind) || items is! List) {
      throw FormatException('候选文件结构无效：${file.path}');
    }
    for (final item in items) {
      if (item is! Map) {
        throw FormatException('候选条目不是对象：${file.path}');
      }
      grouped[kind]!.add(Map<String, dynamic>.from(item));
    }
  }

  final all = <Map<String, dynamic>>[];
  final approved = <Map<String, dynamic>>[];
  final keepEnglish = <Map<String, dynamic>>[];
  final review = <Map<String, dynamic>>[];
  for (final entry in grouped.entries) {
    final seen = <String>{};
    for (final item in entry.value) {
      final name = item['name']?.toString();
      if (name == null || name.isEmpty || !seen.add(name)) {
        throw FormatException('存在空名称或重复名称：${entry.key}/$name');
      }
      final normalized = <String, dynamic>{
        'kind': entry.key,
        'name': name,
        'action': item['action'],
        'chinese': item['chinese'],
        'confidence': item['confidence'],
        'note': item['note'] ?? '',
      };
      all.add(normalized);
      final action = item['action']?.toString();
      final confidence = item['confidence'] is num
          ? (item['confidence'] as num).toDouble()
          : 0;
      final chinese = item['chinese']?.toString().trim() ?? '';
      if (action == 'translate' &&
          confidence >= _approvalThreshold &&
          _containsCjk(chinese)) {
        approved.add(normalized);
      } else if (action == 'keep') {
        keepEnglish.add(normalized);
      } else {
        review.add(normalized);
      }
    }
  }

  int byName(Map<String, dynamic> left, Map<String, dynamic> right) =>
      '${left['kind']}:${left['name']}'.compareTo(
        '${right['kind']}:${right['name']}',
      );
  all.sort(byName);
  approved.sort(byName);
  keepEnglish.sort(byName);
  review.sort(byName);

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'approvalThreshold': _approvalThreshold,
    'sourceFileCount': files.length,
    'allCount': all.length,
    'approvedCount': approved.length,
    'keepEnglishCount': keepEnglish.length,
    'reviewCount': review.length,
    'approved': approved,
    'keepEnglish': keepEnglish,
    'review': review,
  };
  final reportFile = File('tool/data/deepseek_translation_review.json');
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    encoding: utf8,
  );

  final markdown = StringBuffer()
    ..writeln('# DeepSeek 翻译候选审计报告')
    ..writeln()
    ..writeln('- 生成时间：${report['generatedAt']}')
    ..writeln('- 候选批次数：${files.length}')
    ..writeln('- 候选总数：${all.length}')
    ..writeln('- 可纳入内置词表：${approved.length}')
    ..writeln('- 建议保留英文：${keepEnglish.length}')
    ..writeln('- 待人工复核：${review.length}')
    ..writeln()
    ..writeln('## 处理规则')
    ..writeln()
    ..writeln(
      '仅接受 action=translate、置信度不低于 '
      '$_approvalThreshold 且中文结果含中日韩统一表意文字的条目。',
    )
    ..writeln('正式内置词表由 apply_approved_translations.dart 按本报告的可纳入项生成。');
  final markdownFile = File('docs/deepseek_translation_review.md');
  await markdownFile.writeAsString(markdown.toString(), encoding: utf8);

  stdout.writeln('候选文件：${reportFile.path}');
  stdout.writeln('候选总数：${all.length}');
  stdout.writeln('可纳入：${approved.length}');
  stdout.writeln('保留英文：${keepEnglish.length}');
  stdout.writeln('待复核：${review.length}');
}

bool _containsCjk(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);
