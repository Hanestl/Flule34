import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultBaseUrl = 'https://api.deepseek.com';
const _defaultModel = 'deepseek-v4-flash';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final apiKey = Platform.environment['DEEPSEEK_API_KEY']?.trim();
  if (apiKey == null || apiKey.isEmpty) {
    throw StateError('请通过环境变量 DEEPSEEK_API_KEY 提供 API Key。');
  }

  final sourceFile = File('tool/data/site_translation_candidates.json');
  if (!sourceFile.existsSync()) {
    throw StateError('找不到网站差集文件，请先运行 snapshot_site_metadata.dart。');
  }
  final source =
      jsonDecode(await sourceFile.readAsString(encoding: utf8))
          as Map<String, dynamic>;
  final rawEntries =
      source[options.kind == 'tag' ? 'missingTags' : 'missingCategories'];
  if (rawEntries is! List) {
    throw StateError('差集文件缺少 ${options.kind} 条目。');
  }

  final entries = rawEntries
      .skip(options.offset)
      .take(options.limit)
      .whereType<Map<String, dynamic>>()
      .map(
        (entry) => <String, String>{
          'name': entry['name']?.toString() ?? '',
          'slug': entry['slug']?.toString() ?? '',
        },
      )
      .where((entry) => entry['name']!.isNotEmpty)
      .toList(growable: false);
  if (entries.isEmpty) {
    throw StateError('指定范围没有可翻译条目。');
  }

  final client = HttpClient();
  try {
    final result = await _translateBatch(
      client,
      apiKey: apiKey,
      baseUrl: options.baseUrl,
      model: options.model,
      kind: options.kind,
      entries: entries,
    );
    final outputPath =
        options.outputPath ??
        'tool/data/deepseek_trial_${options.kind}_'
            '${options.offset}_${entries.length}.json';
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'provider': 'deepseek',
        'model': options.model,
        'kind': options.kind,
        'offset': options.offset,
        'items': result,
      }),
      encoding: utf8,
    );
    stdout.writeln('候选译文已写入：$outputPath');
    stdout.writeln('条目数：${result.length}');
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, dynamic>>> _translateBatch(
  HttpClient client, {
  required String apiKey,
  required String baseUrl,
  required String model,
  required String kind,
  required List<Map<String, String>> entries,
}) async {
  final input = const JsonEncoder().convert(entries);
  final system =
      '''
你是 Flule34 中文词库的专业编辑。当前处理的是${kind == 'tag' ? 'Rule34Video 标签' : 'Rule34Video 分类'}。
请把英文条目生成简洁、准确、适合中国用户阅读和搜索的简体中文候选译名。

必须输出合法 JSON，格式严格为：
{"items":[{"name":"原英文名","action":"translate|keep|review","chinese":"中文结果","confidence":0.0,"note":"简短说明"}]}

规则：
1. 每个输入条目必须恰好输出一次，name 必须原样保留。
2. 普通性癖、动作、外观、场景等描述词应翻译成自然简洁的中文。
3. 艺术家名、用户名、角色名、作品名、游戏名、系列名、品牌名等专有名词，默认 action=keep，chinese 保留英文；有明确通行中文名时可 action=translate。
4. 无法确认含义、拼写异常或可能误导搜索时，action=review；chinese 可以保留英文，不要臆造解释。
5. 不要添加括号、解释性长句、营销文案或多个候选；不要翻译成繁体中文。
6. confidence 必须是 0 到 1 之间的小数。
''';
  final user = '请处理下面这批条目，并仅返回上述 JSON：\n$input';

  final payload = <String, Object?>{
    'model': model,
    'messages': [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ],
    'thinking': {'type': 'disabled'},
    'temperature': 0.1,
    'max_tokens': 6000,
    'response_format': {'type': 'json_object'},
  };

  final uri = Uri.parse(baseUrl).resolve('/chat/completions');
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt += 1) {
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('DeepSeek 返回 HTTP ${response.statusCode}：$body');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final content = decoded['choices']?[0]?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const FormatException('DeepSeek 返回内容为空。');
      }
      final result = jsonDecode(content) as Map<String, dynamic>;
      return _validateResult(result, entries);
    } on Object catch (error) {
      lastError = error;
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }
  throw StateError('DeepSeek 批量翻译失败：$lastError');
}

List<Map<String, dynamic>> _validateResult(
  Map<String, dynamic> result,
  List<Map<String, String>> entries,
) {
  final rawItems = result['items'];
  if (rawItems is! List || rawItems.length != entries.length) {
    throw FormatException(
      '返回条目数不匹配：期望 ${entries.length}，实际 ${rawItems is List ? rawItems.length : '非数组'}。',
    );
  }
  final expected = entries.map((entry) => entry['name']!).toSet();
  final seen = <String>{};
  final validated = <Map<String, dynamic>>[];
  for (final raw in rawItems) {
    if (raw is! Map) {
      throw const FormatException('返回条目不是对象。');
    }
    final item = Map<String, dynamic>.from(raw);
    final name = item['name']?.toString();
    final action = item['action']?.toString();
    final chinese = item['chinese']?.toString();
    final confidence = item['confidence'];
    if (name == null || !expected.contains(name) || !seen.add(name)) {
      throw FormatException('返回了未知或重复条目：$name');
    }
    if (action != 'translate' && action != 'keep' && action != 'review') {
      throw FormatException('action 无效：$action');
    }
    if (chinese == null || chinese.trim().isEmpty) {
      throw const FormatException('chinese 不能为空。');
    }
    final confidenceNumber = confidence is num ? confidence.toDouble() : -1;
    if (confidenceNumber < 0 || confidenceNumber > 1) {
      throw FormatException('confidence 无效：$confidence');
    }
    validated.add({
      'name': name,
      'action': action,
      'chinese': chinese.trim(),
      'confidence': confidenceNumber,
      'note': item['note']?.toString() ?? '',
    });
  }
  if (seen.length != expected.length) {
    throw const FormatException('返回结果缺少条目。');
  }
  return validated;
}

final class _Options {
  const _Options({
    required this.kind,
    required this.offset,
    required this.limit,
    required this.baseUrl,
    required this.model,
    required this.outputPath,
  });

  final String kind;
  final int offset;
  final int limit;
  final String baseUrl;
  final String model;
  final String? outputPath;

  static _Options parse(List<String> arguments) {
    var kind = 'tag';
    var offset = 0;
    var limit = 20;
    var baseUrl =
        Platform.environment['DEEPSEEK_BASE_URL']?.trim() ?? _defaultBaseUrl;
    var model = Platform.environment['DEEPSEEK_MODEL']?.trim() ?? _defaultModel;
    String? outputPath;
    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      String nextValue() {
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument 缺少参数。');
        }
        index += 1;
        return arguments[index];
      }

      switch (argument) {
        case '--kind':
          kind = nextValue();
        case '--offset':
          offset = int.parse(nextValue());
        case '--limit':
          limit = int.parse(nextValue());
        case '--base-url':
          baseUrl = nextValue();
        case '--model':
          model = nextValue();
        case '--output':
          outputPath = nextValue();
        default:
          throw FormatException('未知参数：$argument');
      }
    }
    if (kind != 'tag' && kind != 'category') {
      throw FormatException('kind 必须是 tag 或 category。');
    }
    if (offset < 0 || limit < 1 || limit > 50) {
      throw const FormatException('offset/limit 范围无效。');
    }
    return _Options(
      kind: kind,
      offset: offset,
      limit: limit,
      baseUrl: baseUrl,
      model: model,
      outputPath: outputPath,
    );
  }
}
