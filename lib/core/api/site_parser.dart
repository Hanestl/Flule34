import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/video_models.dart';

class SiteParser {
  static const _baseUri = 'https://rule34video.com/';

  static List<VideoItem> videoList(String source) {
    final document = html_parser.parse(source);
    final result = <String, VideoItem>{};

    for (final card in document.querySelectorAll('div.item.thumb')) {
      final link =
          card.querySelector('a.th.js-open-popup') ??
          card.querySelector('a.th[href*="/video/"]');
      final href = link?.attributes['href'];
      final match = RegExp(r'/video/(\d+)/([^/]+)/?').firstMatch(href ?? '');
      if (match == null) {
        continue;
      }

      final image = card.querySelector('img.thumb');
      final title =
          _clean(link?.attributes['title']) ??
          _clean(image?.attributes['alt']) ??
          '未命名视频';
      final text = card.text.replaceAll(RegExp(r'\s+'), ' ');
      final thumbnail = _url(
        image?.attributes['data-webp'] ?? image?.attributes['data-original'],
      );
      final preview = _url(
        card.querySelector('div.img.wrap_image')?.attributes['data-preview'],
      );

      result[match.group(1)!] = VideoItem(
        id: match.group(1)!,
        slug: match.group(2)!,
        title: title,
        thumbnailUrl: thumbnail,
        previewUrl: preview,
        duration: _clean(card.querySelector('.thumb_title')?.text),
        views: _number(
          RegExp(
            r'([\d,]+)\s*views?',
            caseSensitive: false,
          ).firstMatch(text)?.group(1),
        ),
        rating: _number(RegExp(r'(\d{1,3})\s*%').firstMatch(text)?.group(1)),
      );
    }

    return result.values.toList(growable: false);
  }

  static VideoDetails videoDetails({
    required String source,
    required VideoItem fallback,
  }) {
    final document = html_parser.parse(source);
    final schema = _videoSchema(document);
    final flashTitle = _flashValue(source, 'video_title');
    final schemaTitle = _string(schema?['name']);
    final thumbnail =
        _url(_flashValue(source, 'preview_url')) ??
        _url(_string(schema?['thumbnailUrl']));
    final video = fallback.copyWith(
      title: flashTitle ?? schemaTitle,
      thumbnailUrl: thumbnail,
      duration:
          _flashValue(source, 'video_duration') ??
          _isoDuration(_string(schema?['duration'])) ??
          fallback.duration,
      views: _viewsFromSchema(schema) ?? fallback.views,
    );

    return VideoDetails(
      video: video,
      description:
          _clean(_string(schema?['description'])) ??
          _clean(
            document
                .querySelector('meta[name="description"]')
                ?.attributes['content'],
          ),
      categories: _split(_flashValue(source, 'video_categories')),
      tags: _split(_flashValue(source, 'video_tags')),
      models: _split(_flashValue(source, 'video_models')),
      sources: _sources(source),
      isFavorite: document.querySelector('a.delete.button_fav') != null,
    );
  }

  static List<TagSuggestion> tagSuggestions(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map>()
        .map((item) {
          return TagSuggestion(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            total: _number(item['total']?.toString()) ?? 0,
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }

  static List<PlaylistItem> playlists(String source) {
    final document = html_parser.parse(source);
    final result = <String, PlaylistItem>{};
    for (final link in document.querySelectorAll(
      'a[href*="/playlists/"], a[href*="/my/playlists/"]',
    )) {
      final href = link.attributes['href'];
      final match = RegExp(
        r'/(?:my/)?playlists/(\d+)(?:/([^/]+))?/?',
      ).firstMatch(href ?? '');
      if (match == null) {
        continue;
      }
      final container = _closestItem(link) ?? link.parent;
      final text = container?.text.replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final image =
          container?.querySelector('img') ?? link.querySelector('img');
      final title =
          _clean(link.attributes['title']) ??
          _clean(image?.attributes['alt']) ??
          _clean(container?.querySelector('.title')?.text) ??
          _clean(link.text) ??
          '未命名播放列表';
      final resolved = Uri.parse(_baseUri).resolve(href!).path;
      result[match.group(1)!] = PlaylistItem(
        id: match.group(1)!,
        title: title,
        path: resolved.endsWith('/') ? resolved : '$resolved/',
        thumbnailUrl: _url(
          image?.attributes['data-webp'] ??
              image?.attributes['data-original'] ??
              image?.attributes['src'],
        ),
        videoCount: _number(
          RegExp(
            r'([\d,]+)\s*videos?',
            caseSensitive: false,
          ).firstMatch(text)?.group(1),
        ),
        views: _number(
          RegExp(
            r'([\d,]+)\s*views?',
            caseSensitive: false,
          ).firstMatch(text)?.group(1),
        ),
      );
    }
    return result.values.toList(growable: false);
  }

  static String? genericError(String source) {
    return _clean(
      html_parser.parse(source).querySelector('.generic-error')?.text,
    );
  }

  static dom.Element? _closestItem(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      if (current.localName == 'div' && current.classes.contains('item')) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  static String? userId(String source) {
    return RegExp(
      r'''(?:["']?userId["']?)\s*:\s*["']?(\d+)["']?''',
      caseSensitive: false,
    ).firstMatch(source)?.group(1);
  }

  static List<VideoSource> _sources(String source) {
    const fields = <(String, String)>[
      ('video_url', 'video_url_text'),
      ('video_alt_url', 'video_alt_url_text'),
      ('video_alt_url2', 'video_alt_url2_text'),
      ('video_alt_url3', 'video_alt_url3_text'),
    ];
    final result = <String, VideoSource>{};
    for (final field in fields) {
      final url = _url(_flashValue(source, field.$1));
      if (url == null) {
        continue;
      }
      final label =
          _flashValue(source, field.$2) ??
          RegExp(
            r'_(\d+p?)\.mp4',
            caseSensitive: false,
          ).firstMatch(url)?.group(1) ??
          'MP4';
      result[url] = VideoSource(
        label: label,
        url: url,
        isHd: label.contains('720') || label.contains('1080'),
      );
    }
    return result.values.toList(growable: false);
  }

  static Map<String, dynamic>? _videoSchema(dom.Document document) {
    for (final element in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        final decoded = jsonDecode(element.text);
        final video = _findVideoSchema(decoded);
        if (video != null) {
          return video;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findVideoSchema(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['@type'] == 'VideoObject') {
        return decoded;
      }
      final graph = decoded['@graph'];
      if (graph is List) {
        for (final item in graph) {
          final result = _findVideoSchema(item);
          if (result != null) {
            return result;
          }
        }
      }
    }
    if (decoded is List) {
      for (final item in decoded) {
        final result = _findVideoSchema(item);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  static String? _flashValue(String source, String key) {
    final expression = RegExp(
      "(?:[\"']?${RegExp.escape(key)}[\"']?)\\s*:\\s*([\"'])(.*?)\\1",
      dotAll: true,
    );
    final value = expression.firstMatch(source)?.group(2);
    if (value == null) {
      return null;
    }
    final unicode = RegExp(r'\\u([0-9a-fA-F]{4})');
    final decoded = value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAllMapped(unicode, (match) {
          return String.fromCharCode(int.parse(match.group(1)!, radix: 16));
        });
    return _clean(html_parser.parseFragment(decoded).text);
  }

  static int? _viewsFromSchema(Map<String, dynamic>? schema) {
    final statistics = schema?['interactionStatistic'];
    if (statistics is! List) {
      return null;
    }
    for (final item in statistics.whereType<Map>()) {
      final interaction = item['interactionType'];
      final type = interaction is Map ? interaction['@type']?.toString() : null;
      if (type == 'WatchAction') {
        return _number(item['userInteractionCount']?.toString());
      }
    }
    return null;
  }

  static String? _isoDuration(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static List<String> _split(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    return value
        .split(',')
        .map(_clean)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _url(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null || cleaned.startsWith('data:')) {
      return null;
    }
    final uri = Uri.tryParse(cleaned);
    if (uri == null) {
      return null;
    }
    return uri.hasScheme
        ? uri.toString()
        : Uri.parse(_baseUri).resolveUri(uri).toString();
  }

  static String? _clean(String? value) {
    final trimmed = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _string(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value?.toString();
  }

  static int? _number(String? value) {
    return int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
