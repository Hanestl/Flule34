import 'dart:convert';
import 'dart:io';

const _tagAsset = 'assets/translations/rule34video_tags_zh.json';
const _categoryAsset = 'assets/translations/rule34video_categories_zh.json';
const _reviewFile = 'tool/data/deepseek_translation_review.json';
const _manualReviewFile = 'tool/data/manual_translation_review.json';
const _snapshotFile = 'tool/data/site_metadata_snapshot.json';

Future<void> main() async {
  final review =
      jsonDecode(await File(_reviewFile).readAsString(encoding: utf8))
          as Map<String, dynamic>;
  final approved = review['approved'];
  if (approved is! List) {
    throw const FormatException('审计文件缺少 approved 数组。');
  }
  final manualReview =
      jsonDecode(await File(_manualReviewFile).readAsString(encoding: utf8))
          as Map<String, dynamic>;
  final manualApproved = manualReview['approved'];
  if (manualApproved is! List) {
    throw const FormatException('人工复核文件缺少 approved 数组。');
  }

  final tags = <String, String>{
    ..._readMap(await File(_tagAsset).readAsString(encoding: utf8)),
  };
  final categories = <String, String>{};
  final snapshot =
      jsonDecode(await File(_snapshotFile).readAsString(encoding: utf8))
          as Map<String, dynamic>;
  final siteCategories = snapshot['categories'];
  if (siteCategories is! List) {
    throw const FormatException('网站快照缺少 categories 数组。');
  }
  for (final item in siteCategories) {
    if (item is! Map) {
      continue;
    }
    final name = item['name']?.toString() ?? '';
    final key = _normalize(name);
    final inherited = tags[key];
    if (key.isNotEmpty && inherited != null) {
      categories[key] = inherited;
    }
  }
  for (final item in [...approved, ...manualApproved]) {
    if (item is! Map) {
      throw const FormatException('approved 条目不是对象。');
    }
    final kind = item['kind']?.toString();
    final name = item['name']?.toString() ?? '';
    final chinese = item['chinese']?.toString().trim() ?? '';
    if ((kind != 'tag' && kind != 'category') ||
        name.trim().isEmpty ||
        chinese.isEmpty) {
      throw FormatException('approved 条目无效：$item');
    }
    final target = kind == 'tag' ? tags : categories;
    final key = _normalize(name);
    if (kind == 'tag' && target.containsKey(key) && target[key] != chinese) {
      throw FormatException('译文冲突：$kind/$name');
    }
    target[key] = chinese;
  }

  await File(_tagAsset).writeAsString(
    const JsonEncoder.withIndent('  ').convert(_sorted(tags)),
    encoding: utf8,
  );
  await File(_categoryAsset).writeAsString(
    const JsonEncoder.withIndent('  ').convert(_sorted(categories)),
    encoding: utf8,
  );
  stdout.writeln('标签内置词条：${tags.length}');
  stdout.writeln('分类内置词条：${categories.length}');
  stdout.writeln('标签新增：${tags.length - 7599}');
}

Map<String, String> _readMap(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('内置词表不是 JSON 对象。');
  }
  return decoded.map(
    (key, value) =>
        MapEntry(_normalize(key.toString()), value.toString().trim()),
  );
}

Map<String, String> _sorted(Map<String, String> source) {
  final entries = source.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return <String, String>{for (final entry in entries) entry.key: entry.value};
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');
