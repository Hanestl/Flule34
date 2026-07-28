import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/video_models.dart';

typedef VideoPreviewSearch = Future<List<VideoItem>> Function(String query);
typedef VideoPreviewPersist =
    Future<void> Function({
      required String videoId,
      required String? previewUrl,
    });

final class VideoPreviewResolver {
  VideoPreviewResolver({required this.search, required this.persist});

  final VideoPreviewSearch search;
  final VideoPreviewPersist persist;

  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};

  Future<String?> resolve(VideoItem video, {bool forceRefresh = false}) {
    final directUrl = _validUrl(video.previewUrl);
    if (!forceRefresh && directUrl != null) {
      _cache[video.id] = directUrl;
      return Future<String?>.value(directUrl);
    }
    final cached = _cache[video.id];
    if (!forceRefresh && cached != null) {
      return Future<String?>.value(cached);
    }

    final pendingKey = '${video.id}:${forceRefresh ? 1 : 0}';
    return _pending.putIfAbsent(pendingKey, () async {
      try {
        if (forceRefresh) {
          _cache.remove(video.id);
        }
        return await _lookup(video);
      } finally {
        _pending.remove(pendingKey);
      }
    });
  }

  Future<void> invalidate(String videoId) async {
    _cache.remove(videoId);
    try {
      await persist(videoId: videoId, previewUrl: null);
    } catch (_) {
      // 播放地址失效时优先允许重新解析，持久层清理失败不阻断预览。
    }
  }

  Future<String?> _lookup(VideoItem video) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final query in lookupQueries(video)) {
      try {
        final results = await search(query);
        for (final result in results) {
          if (result.id != video.id) {
            continue;
          }
          final previewUrl = _validUrl(result.previewUrl);
          if (previewUrl == null) {
            continue;
          }
          _cache[video.id] = previewUrl;
          try {
            await persist(videoId: video.id, previewUrl: previewUrl);
          } catch (_) {
            // 预览本身已经可用，数据库写回失败不应让用户看不到视频。
          }
          return previewUrl;
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    return null;
  }

  @visibleForTesting
  static List<String> lookupQueries(VideoItem video) {
    final result = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) {
        return;
      }
      result.add(normalized);
    }

    add(video.title);
    add(video.slug.replaceAll(RegExp(r'[-_]+'), ' '));
    return result;
  }

  String? _validUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    return uri.toString();
  }
}

@immutable
final class VideoPreviewRequest {
  const VideoPreviewRequest({
    required this.video,
    required this.serial,
    required this.onOpen,
  });

  final VideoItem video;
  final int serial;
  final VoidCallback onOpen;
}

final class VideoPreviewController extends ChangeNotifier {
  VideoPreviewRequest? get request => _request;
  VideoPreviewRequest? _request;
  int _serial = 0;

  void show(VideoItem video, {required VoidCallback onOpen}) {
    _serial += 1;
    _request = VideoPreviewRequest(
      video: video,
      serial: _serial,
      onOpen: onOpen,
    );
    notifyListeners();
  }

  void open() {
    final onOpen = _request?.onOpen;
    if (onOpen == null) {
      return;
    }
    hide();
    scheduleMicrotask(onOpen);
  }

  void hide() {
    if (_request == null) {
      return;
    }
    _request = null;
    notifyListeners();
  }
}
