import 'dart:collection';
import 'dart:convert';

final class TranslationCatalogStats {
  const TranslationCatalogStats({
    required this.inputRows,
    required this.emptyRows,
    required this.identityRows,
    required this.nonChineseRows,
    required this.duplicateRows,
    required this.normalizedEnglishRows,
    required this.englishEchoRows,
    required this.uniqueEntries,
  });

  final int inputRows;
  final int emptyRows;
  final int identityRows;
  final int nonChineseRows;
  final int duplicateRows;
  final int normalizedEnglishRows;
  final int englishEchoRows;
  final int uniqueEntries;
}

final class TranslationCatalogBuildResult {
  const TranslationCatalogBuildResult({
    required this.translations,
    required this.stats,
  });

  final Map<String, String> translations;
  final TranslationCatalogStats stats;

  String toJson() {
    return '${const JsonEncoder.withIndent('  ').convert(translations)}\n';
  }

  String toMarkdownReport({
    required String sourceCommit,
    required String sourceSha256,
  }) {
    return '''# Rule34Video 中文标签词表报告

此文件由 `dart run tool/build_translation_catalog.dart` 自动生成，请勿手工编辑。

## 来源

- 仓库：`sanfangx/Flule34`
- 提交：`$sourceCommit`
- 原始 CSV SHA-256：`$sourceSha256`
- 原始格式：`ID,Name,ChineseName,VideoCount`

## 清洗结果

| 指标 | 数量 |
| --- | ---: |
| 原始数据行 | ${stats.inputRows} |
| 最终唯一词条 | ${stats.uniqueEntries} |
| 删除空值行 | ${stats.emptyRows} |
| 删除中英文相同行 | ${stats.identityRows} |
| 删除不含中文字符的译文 | ${stats.nonChineseRows} |
| 删除重复行 | ${stats.duplicateRows} |
| 英文键发生归一化的行 | ${stats.normalizedEnglishRows} |
| 译文保留完整英文原文 | ${stats.englishEchoRows} |

## 规则

- 英文键转为小写；
- 下划线转换为空格；
- 连续空白折叠为单个空格；
- 译文必须包含至少一个中日韩统一表意文字；
- 同一英文键和相同译文只保留一条；
- 同一英文键若出现不同译文，生成过程直接失败，禁止静默覆盖；
- 输出按英文键排序，保证结果稳定。
''';
  }
}

TranslationCatalogBuildResult buildTranslationCatalog(String csvSource) {
  final rows = parseCsv(csvSource);
  if (rows.isEmpty) {
    throw const FormatException('CSV 为空。');
  }

  final header = rows.first
      .map((value) => value.replaceFirst('\ufeff', '').trim().toLowerCase())
      .toList(growable: false);
  final nameIndex = header.indexOf('name');
  final chineseIndex = header.indexOf('chinesename');
  if (nameIndex < 0 || chineseIndex < 0) {
    throw FormatException('CSV 缺少 Name 或 ChineseName 列：${rows.first}');
  }

  final translations = SplayTreeMap<String, String>();
  var emptyRows = 0;
  var identityRows = 0;
  var nonChineseRows = 0;
  var duplicateRows = 0;
  var normalizedEnglishRows = 0;
  var englishEchoRows = 0;
  final conflicts = <String>[];

  for (final row in rows.skip(1)) {
    if (row.every((value) => value.trim().isEmpty)) {
      continue;
    }
    final englishSource = _column(row, nameIndex).trim();
    final chinese = _collapseWhitespace(_column(row, chineseIndex));
    final english = normalizeEnglish(englishSource);
    if (english.isEmpty || chinese.isEmpty) {
      emptyRows += 1;
      continue;
    }
    if (english != englishSource) {
      normalizedEnglishRows += 1;
    }
    if (normalizeEnglish(chinese) == english) {
      identityRows += 1;
      continue;
    }
    if (!_containsCjk(chinese)) {
      nonChineseRows += 1;
      continue;
    }
    if (chinese.toLowerCase().contains(english)) {
      englishEchoRows += 1;
    }

    final existing = translations[english];
    if (existing == null) {
      translations[english] = chinese;
    } else if (existing == chinese) {
      duplicateRows += 1;
    } else {
      conflicts.add('$english => "$existing" / "$chinese"');
    }
  }

  if (conflicts.isNotEmpty) {
    final samples = conflicts.take(20).join('\n');
    throw FormatException('发现 ${conflicts.length} 个翻译冲突，已停止生成：\n$samples');
  }

  return TranslationCatalogBuildResult(
    translations: Map.unmodifiable(translations),
    stats: TranslationCatalogStats(
      inputRows: rows
          .skip(1)
          .where((row) => row.any((value) => value.isNotEmpty))
          .length,
      emptyRows: emptyRows,
      identityRows: identityRows,
      nonChineseRows: nonChineseRows,
      duplicateRows: duplicateRows,
      normalizedEnglishRows: normalizedEnglishRows,
      englishEchoRows: englishEchoRows,
      uniqueEntries: translations.length,
    ),
  );
}

List<List<String>> parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var inQuotes = false;

  void finishField() {
    row.add(field.toString());
    field = StringBuffer();
  }

  void finishRow() {
    finishField();
    rows.add(row);
    row = <String>[];
  }

  for (var index = 0; index < source.length; index += 1) {
    final character = source[index];
    if (character == '"') {
      if (inQuotes && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && character == ',') {
      finishField();
      continue;
    }
    if (!inQuotes && (character == '\n' || character == '\r')) {
      if (character == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index += 1;
      }
      finishRow();
      continue;
    }
    field.write(character);
  }

  if (inQuotes) {
    throw const FormatException('CSV 引号没有闭合。');
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    finishRow();
  }
  while (rows.isNotEmpty && rows.last.every((value) => value.isEmpty)) {
    rows.removeLast();
  }
  return rows;
}

String normalizeEnglish(String value) {
  return _collapseWhitespace(value.toLowerCase().replaceAll('_', ' '));
}

String _collapseWhitespace(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _column(List<String> row, int index) {
  return index < row.length ? row[index] : '';
}

bool _containsCjk(String value) {
  return RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]').hasMatch(value);
}
