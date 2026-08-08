import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _baseUri = 'https://rule34video.com';
const _userAgent = 'Flule34 translation catalog snapshot/1.0';
const _requestDelay = Duration(milliseconds: 300);

Future<void> main() async {
  final outputDirectory = Directory('tool/data');
  await outputDirectory.create(recursive: true);

  final client = HttpClient()..userAgent = _userAgent;
  try {
    final tags = await _snapshotCollection(
      client,
      kind: 'tag',
      firstPath: '/tags/',
      itemsSelector: '#list_tags_tags_list_items',
      pathSegment: 'tags',
      asyncPagination: true,
      titleSelectors: const ['.name', '.thumb_title', '.title'],
    );
    final categories = await _snapshotCollection(
      client,
      kind: 'category',
      firstPath: '/categories/',
      itemsSelector: '#list_categories_categories_list_items',
      pathSegment: 'categories',
      titleSelectors: const ['.name', '.thumb_title', '.title'],
    );

    final builtInFile = File('assets/translations/rule34video_tags_zh.json');
    final builtIn = builtInFile.existsSync()
        ? (jsonDecode(await builtInFile.readAsString(encoding: utf8))
              as Map<String, dynamic>)
        : <String, dynamic>{};
    final builtInKeys = builtIn.keys.map(_normalize).toSet();

    final now = DateTime.now().toUtc();
    final snapshot = <String, Object?>{
      'generatedAt': now.toIso8601String(),
      'source': _baseUri,
      'tags': tags,
      'categories': categories,
    };
    final candidates = <String, Object?>{
      'generatedAt': now.toIso8601String(),
      'source': _baseUri,
      'builtInTagEntryCount': builtInKeys.length,
      'missingTags': tags
          .where((entry) => !builtInKeys.contains(_normalize(entry['name']!)))
          .toList(growable: false),
      'missingCategories': categories
          .where((entry) => !builtInKeys.contains(_normalize(entry['name']!)))
          .toList(growable: false),
    };

    final snapshotPath = File('tool/data/site_metadata_snapshot.json');
    final candidatesPath = File('tool/data/site_translation_candidates.json');
    await snapshotPath.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      encoding: utf8,
    );
    await candidatesPath.writeAsString(
      const JsonEncoder.withIndent('  ').convert(candidates),
      encoding: utf8,
    );

    stdout.writeln('网站元数据快照：${snapshotPath.path}');
    stdout.writeln('待翻译差集：${candidatesPath.path}');
    stdout.writeln('标签总数：${tags.length}');
    stdout.writeln('分类总数：${categories.length}');
    stdout.writeln('缺失标签：${(candidates['missingTags']! as List).length}');
    stdout.writeln('缺失分类：${(candidates['missingCategories']! as List).length}');
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, String>>> _snapshotCollection(
  HttpClient client, {
  required String kind,
  required String firstPath,
  required String itemsSelector,
  required String pathSegment,
  bool asyncPagination = false,
  required List<String> titleSelectors,
}) async {
  final first = await _get(client, firstPath);
  final firstDocument = html_parser.parse(first);
  final pages = _pageNumbers(firstDocument, kind, pathSegment);
  final maxPage = pages.isEmpty ? 1 : pages.reduce((a, b) => a > b ? a : b);
  final byName = <String, Map<String, String>>{};

  for (var page = 1; page <= maxPage; page += 1) {
    final source = page == 1
        ? first
        : await _get(
            client,
            asyncPagination ? '/$pathSegment/' : '/$pathSegment/$page/',
            query: asyncPagination
                ? <String, String>{
                    'mode': 'async',
                    'function': 'get_block',
                    'block_id': 'list_tags_tags_list',
                    'section': 'All',
                    'sort_by': 'tag',
                    'from': '$page',
                  }
                : null,
          );
    final document = html_parser.parse(source);
    final container = document.querySelector(itemsSelector);
    if (container == null) {
      continue;
    }
    for (final link in container.querySelectorAll('a')) {
      final href = link.attributes['href'];
      final match = RegExp('/$pathSegment/([^/]+)/?\$').firstMatch(href ?? '');
      if (match == null) {
        continue;
      }
      final name = _itemTitle(
        link,
        titleSelectors,
        stripNestedText: kind == 'tag',
      );
      final slug = match.group(1)!.trim();
      if (slug.isEmpty || name.isEmpty) {
        continue;
      }
      byName[_normalize(slug)] = <String, String>{
        'name': name,
        'slug': slug,
        'path': '/$pathSegment/$slug/',
      };
    }
    stdout.writeln('$kind 第 $page/$maxPage 页，累计 ${byName.length} 条');
  }

  final result = byName.values.toList(growable: false)
    ..sort((left, right) => left['name']!.compareTo(right['name']!));
  return result;
}

Set<int> _pageNumbers(dynamic document, String kind, String pathSegment) {
  final pages = <int>{1};
  for (final link in document.querySelectorAll(
    'div.pagination[id*="_pagination"] a',
  )) {
    final href = link.attributes['href'] ?? '';
    final parameters = link.attributes['data-parameters'] ?? '';
    final match =
        RegExp(r'from:(\d+)').firstMatch(parameters) ??
        RegExp('/$pathSegment/(\\d+)/?\$').firstMatch(href);
    if (match != null) {
      pages.add(int.parse(match.group(1)!));
    }
  }
  return pages;
}

String _itemTitle(
  dom.Element link,
  List<String> selectors, {
  bool stripNestedText = false,
}) {
  if (stripNestedText) {
    final directText = link.nodes
        .whereType<dom.Text>()
        .map((node) => node.data)
        .join(' ');
    if (_cleanText(directText).isNotEmpty) {
      return _cleanText(directText);
    }
  }
  final container = _closestItem(link);
  for (final selector in selectors) {
    final value = container?.querySelector(selector)?.text;
    if (value != null && _cleanText(value).isNotEmpty) {
      return _cleanText(value);
    }
  }
  return _cleanText(link.text);
}

dom.Element? _closestItem(dom.Element link) {
  dom.Element? current = link;
  while (current != null) {
    if (current.localName == 'div' && current.classes.contains('item')) {
      return current;
    }
    current = current.parent;
  }
  return link.parent;
}

Future<String> _get(
  HttpClient client,
  String path, {
  Map<String, String>? query,
}) async {
  final uri = Uri.parse('$_baseUri$path').replace(queryParameters: query);
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, 'text/html');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('请求 $uri 失败：HTTP ${response.statusCode}');
  }
  await Future<void>.delayed(_requestDelay);
  return body;
}

String _cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');
