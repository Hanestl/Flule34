import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/video_list_filters.dart';
import '../models/video_models.dart';
import '../session/session_store.dart';

final class SubscriptionActivityException implements Exception {
  const SubscriptionActivityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SubscriptionActivityCancelledException
    extends SubscriptionActivityException {
  const SubscriptionActivityCancelledException() : super('后台订阅整理已让位于当前操作。');
}

typedef SubscriptionListLoader =
    Future<List<SubscriptionItem>> Function({
      bool force,
      CancelToken? cancelToken,
    });

typedef SubscriptionVideoLoader =
    Future<List<VideoItem>> Function(
      SubscriptionItem subscription,
      int page, {
      CancelToken? cancelToken,
    });

abstract interface class SubscriptionActivityStore {
  Future<String?> read(String userId);

  Future<void> write(String userId, String value);

  Future<void> remove(String userId);
}

final class MemorySubscriptionActivityStore
    implements SubscriptionActivityStore {
  final Map<String, String> _values = {};
  int writeCount = 0;

  @override
  Future<String?> read(String userId) async => _values[userId];

  @override
  Future<void> write(String userId, String value) async {
    writeCount += 1;
    _values[userId] = value;
  }

  @override
  Future<void> remove(String userId) async {
    _values.remove(userId);
  }
}

final class SubscriptionActivityIndex extends ChangeNotifier {
  SubscriptionActivityIndex({
    required this.sessionStore,
    required this.loadSubscriptions,
    required this.loadSubscriptionVideos,
    required this.store,
    this.concurrency = 6,
    this.pageSize = 30,
    this.cacheTtl = const Duration(minutes: 5),
  }) : assert(concurrency > 0),
       assert(pageSize > 0);

  static const _storedVideoLimit = 360;

  final SessionStore sessionStore;
  final SubscriptionListLoader loadSubscriptions;
  final SubscriptionVideoLoader loadSubscriptionVideos;
  final SubscriptionActivityStore store;
  final int concurrency;
  final int pageSize;
  final Duration cacheTtl;

  final Map<String, _SourceState> _sources = {};
  final Map<String, String?> _latestPublishedByPath = {};
  List<VideoItem> _videos = const [];
  Future<void>? _loadStoredRequest;
  Future<void>? _scanRequest;
  String? _userId;
  DateTime? _refreshedAt;
  Object? _lastError;
  var _operation = 0;
  var _revision = 0;
  var _scannedSources = 0;
  var _totalSources = 0;
  var _scanHadFailures = false;
  var _disposed = false;

  bool get isScanning => _scanRequest != null;
  int get scannedSources => _scannedSources;
  int get totalSources => _totalSources;
  int get revision => _revision;
  Object? get lastError => _lastError;
  List<VideoItem> get cachedVideos => List.unmodifiable(_videos);

  Map<String, int?> get updatedAgeByPath => {
    for (final entry in _latestPublishedByPath.entries)
      entry.key: publishedAgeSeconds(entry.value),
  };

  bool get _isFresh {
    final refreshedAt = _refreshedAt;
    if (refreshedAt == null) {
      return false;
    }
    final ttl = _scanHadFailures ? const Duration(minutes: 1) : cacheTtl;
    return DateTime.now().difference(refreshedAt) < ttl;
  }

  void invalidate() {
    _refreshedAt = null;
    _scanHadFailures = false;
    _notify();
  }

  Future<void> loadStored() {
    _syncUser();
    if (_userId == null) {
      return Future.value();
    }
    return _loadStoredRequest ??= _readStored().whenComplete(() {
      _loadStoredRequest = null;
    });
  }

  Future<void> refresh({
    bool force = false,
    bool refreshSubscriptions = false,
    CancelToken? cancelToken,
  }) async {
    await loadStored();
    if (_userId == null) {
      return;
    }
    if (!force && _isFresh) {
      return;
    }
    final existing = _scanRequest;
    if (existing != null) {
      return existing;
    }
    late final Future<void> request;
    request =
        _scanFirstPages(
          refreshSubscriptions: refreshSubscriptions,
          cancelToken: cancelToken,
        ).whenComplete(() {
          if (identical(_scanRequest, request)) {
            _scanRequest = null;
            _notify();
          }
        });
    _scanRequest = request;
    _notify();
    return request;
  }

  Future<List<VideoItem>> loadFollowingPage(
    int page, {
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    if (page < 1) {
      return const [];
    }
    await loadStored();
    if (force || !_isFresh) {
      await refresh(
        force: force,
        refreshSubscriptions: force,
        cancelToken: cancelToken,
      );
    }
    if (page > 1 && _sources.isEmpty) {
      await refresh(force: true, cancelToken: cancelToken);
    }
    final targetCount = page * pageSize;
    final userId = _userId;
    var attempts = 0;
    while (_videos.length < targetCount &&
        _sources.values.any((source) => !source.exhausted) &&
        attempts < 3) {
      final added = await _loadNextSourcePages(cancelToken: cancelToken);
      attempts += 1;
      if (added == 0 && _lastError != null) {
        throw const SubscriptionActivityException('部分订阅暂时无法读取，请稍后重试。');
      }
    }
    if (attempts > 0 && userId != null) {
      await _persist(userId);
    }
    final start = (page - 1) * pageSize;
    if (start >= _videos.length) {
      if (_sources.values.any((source) => !source.exhausted)) {
        throw const SubscriptionActivityException('更早的关注内容仍在整理，请重试加载。');
      }
      return const [];
    }
    final end = (start + pageSize).clamp(0, _videos.length);
    return List.unmodifiable(_videos.sublist(start, end));
  }

  Future<void> _readStored() async {
    final userId = _userId;
    final operation = _operation;
    if (userId == null) {
      return;
    }
    try {
      final raw = await store.read(userId);
      if (raw == null || raw.isEmpty || operation != _operation) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final videos = (decoded['videos'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _videoFromJson(Map<String, dynamic>.from(item)))
          .whereType<VideoItem>()
          .toList(growable: false);
      final latestRaw = decoded['latestPublishedByPath'];
      final latest = <String, String?>{};
      if (latestRaw is Map) {
        for (final entry in latestRaw.entries) {
          if (entry.key is String &&
              (entry.value == null || entry.value is String)) {
            latest[entry.key as String] = entry.value as String?;
          }
        }
      }
      final refreshedAt = DateTime.tryParse(
        decoded['refreshedAt']?.toString() ?? '',
      );
      if (operation != _operation || _userId != userId) {
        return;
      }
      _videos = _sortVideos(videos);
      _latestPublishedByPath
        ..clear()
        ..addAll(latest);
      _refreshedAt = refreshedAt;
      _revision += 1;
      _notify();
    } on Object {
      await store.remove(userId);
    }
  }

  Future<void> _scanFirstPages({
    required bool refreshSubscriptions,
    CancelToken? cancelToken,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final operation = ++_operation;
    final previousVideos = _videos;
    final previousLatest = Map<String, String?>.from(_latestPublishedByPath);
    _lastError = null;
    _scanHadFailures = false;
    _scannedSources = 0;
    try {
      final subscriptions = await loadSubscriptions(
        force: refreshSubscriptions,
        cancelToken: cancelToken,
      );
      _throwIfCancelled(cancelToken);
      if (!_isCurrent(userId, operation)) {
        return;
      }
      _totalSources = subscriptions.length;
      _notify();
      if (subscriptions.isEmpty) {
        _sources.clear();
        _videos = const [];
        _latestPublishedByPath.clear();
        _refreshedAt = DateTime.now();
        _revision += 1;
        await _persist(userId);
        return;
      }

      final freshVideos = <String, VideoItem>{};
      final freshLatest = <String, String?>{};
      final freshSources = <String, _SourceState>{};
      var failures = 0;
      for (
        var offset = 0;
        offset < subscriptions.length;
        offset += concurrency
      ) {
        _throwIfCancelled(cancelToken);
        final batch = subscriptions
            .skip(offset)
            .take(concurrency)
            .toList(growable: false);
        final results = await Future.wait(
          batch.map(
            (subscription) =>
                _loadSource(subscription, 1, cancelToken: cancelToken),
          ),
        );
        if (!_isCurrent(userId, operation)) {
          return;
        }
        for (final result in results) {
          final path = result.subscription.path;
          if (result.error != null) {
            failures += 1;
            freshLatest[path] = previousLatest[path];
            freshSources[path] = _SourceState(
              subscription: result.subscription,
              nextPage: 1,
              exhausted: false,
            );
            continue;
          }
          for (final video in result.videos) {
            freshVideos[video.id] = video;
          }
          freshLatest[path] = _newestPublishedLabel(result.videos);
          freshSources[path] = _SourceState(
            subscription: result.subscription,
            nextPage: 2,
            exhausted: result.videos.isEmpty,
          );
        }
        _scannedSources = (offset + batch.length).clamp(
          0,
          subscriptions.length,
        );
        _notify();
      }
      if (failures > 0) {
        for (final video in previousVideos) {
          freshVideos.putIfAbsent(video.id, () => video);
        }
      }
      _sources
        ..clear()
        ..addAll(freshSources);
      _videos = _sortVideos(freshVideos.values);
      _latestPublishedByPath
        ..clear()
        ..addAll(freshLatest);
      _refreshedAt = DateTime.now();
      _scanHadFailures = failures > 0;
      _lastError = failures > 0
          ? SubscriptionActivityException('有 $failures 个订阅暂时无法读取。')
          : null;
      _revision += 1;
      await _persist(userId);
    } on Object catch (error) {
      if (cancelToken?.isCancelled == true) {
        throw const SubscriptionActivityCancelledException();
      }
      if (_isCurrent(userId, operation)) {
        _lastError = error;
      }
      rethrow;
    }
  }

  Future<int> _loadNextSourcePages({CancelToken? cancelToken}) async {
    final userId = _userId;
    if (userId == null) {
      return 0;
    }
    final active = _sources.values
        .where((source) => !source.exhausted)
        .toList(growable: false);
    if (active.isEmpty) {
      return 0;
    }
    final merged = <String, VideoItem>{
      for (final video in _videos) video.id: video,
    };
    var added = 0;
    var failures = 0;
    for (var offset = 0; offset < active.length; offset += concurrency) {
      _throwIfCancelled(cancelToken);
      final batch = active
          .skip(offset)
          .take(concurrency)
          .toList(growable: false);
      final results = await Future.wait(
        batch.map(
          (source) => _loadSource(
            source.subscription,
            source.nextPage,
            cancelToken: cancelToken,
          ),
        ),
      );
      for (final result in results) {
        final source = _sources[result.subscription.path];
        if (source == null) {
          continue;
        }
        if (result.error != null) {
          failures += 1;
          continue;
        }
        source
          ..nextPage += 1
          ..exhausted = result.videos.isEmpty;
        if (source.nextPage == 2) {
          _latestPublishedByPath[source.subscription.path] =
              _newestPublishedLabel(result.videos);
        }
        for (final video in result.videos) {
          if (!merged.containsKey(video.id)) {
            merged[video.id] = video;
            added += 1;
          }
        }
      }
    }
    _videos = _sortVideos(merged.values);
    _scanHadFailures = failures > 0;
    _lastError = failures > 0
        ? SubscriptionActivityException('有 $failures 个订阅暂时无法继续读取。')
        : null;
    _revision += 1;
    _notify();
    return added;
  }

  Future<_SourceResult> _loadSource(
    SubscriptionItem subscription,
    int page, {
    CancelToken? cancelToken,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      _throwIfCancelled(cancelToken);
      try {
        final videos = await loadSubscriptionVideos(
          subscription,
          page,
          cancelToken: cancelToken,
        );
        return _SourceResult(subscription: subscription, videos: videos);
      } on Object catch (error) {
        if (cancelToken?.isCancelled == true) {
          throw const SubscriptionActivityCancelledException();
        }
        lastError = error;
      }
    }
    return _SourceResult(
      subscription: subscription,
      videos: const [],
      error: lastError,
    );
  }

  Future<void> _persist(String userId) async {
    if (_userId != userId) {
      return;
    }
    final storedVideos = _videos
        .take(_storedVideoLimit)
        .map(_videoToJson)
        .toList(growable: false);
    await store.write(
      userId,
      jsonEncode({
        'refreshedAt': _refreshedAt?.toUtc().toIso8601String(),
        'videos': storedVideos,
        'latestPublishedByPath': _latestPublishedByPath,
      }),
    );
  }

  void onSessionChanged() {
    _syncUser();
  }

  void _syncUser() {
    final userId = sessionStore.currentUserId;
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    _operation += 1;
    _sources.clear();
    _latestPublishedByPath.clear();
    _videos = const [];
    _loadStoredRequest = null;
    _scanRequest = null;
    _refreshedAt = null;
    _lastError = null;
    _scanHadFailures = false;
    _scannedSources = 0;
    _totalSources = 0;
    _revision += 1;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operation += 1;
    super.dispose();
  }

  bool _isCurrent(String userId, int operation) {
    return _userId == userId && _operation == operation;
  }

  void _throwIfCancelled(CancelToken? token) {
    if (token?.isCancelled == true) {
      throw const SubscriptionActivityCancelledException();
    }
  }

  static String? _newestPublishedLabel(List<VideoItem> videos) {
    String? result;
    int? resultAge;
    for (final video in videos) {
      final age = publishedAgeSeconds(video.publishedLabel);
      if (age != null && (resultAge == null || age < resultAge)) {
        result = video.publishedLabel;
        resultAge = age;
      }
    }
    return result;
  }

  static List<VideoItem> _sortVideos(Iterable<VideoItem> videos) {
    final result = videos.toList(growable: true);
    result.sort((left, right) {
      final leftAge = publishedAgeSeconds(left.publishedLabel);
      final rightAge = publishedAgeSeconds(right.publishedLabel);
      if (leftAge == null && rightAge == null) {
        return right.id.compareTo(left.id);
      }
      if (leftAge == null) {
        return 1;
      }
      if (rightAge == null) {
        return -1;
      }
      final compared = leftAge.compareTo(rightAge);
      return compared == 0 ? right.id.compareTo(left.id) : compared;
    });
    return List.unmodifiable(result);
  }

  static Map<String, Object?> _videoToJson(VideoItem video) => {
    'id': video.id,
    'title': video.title,
    'slug': video.slug,
    'thumbnailUrl': video.thumbnailUrl,
    'previewUrl': video.previewUrl,
    'duration': video.duration,
    'publishedLabel': video.publishedLabel,
    'views': video.views,
    'rating': video.rating,
    'ratingVotes': video.ratingVotes,
    'isFavorite': video.isFavorite,
  };

  static VideoItem? _videoFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final slug = json['slug'];
    if (id is! String || title is! String || slug is! String) {
      return null;
    }
    return VideoItem(
      id: id,
      title: title,
      slug: slug,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      duration: json['duration'] as String?,
      publishedLabel: json['publishedLabel'] as String?,
      views: json['views'] as int?,
      rating: json['rating'] as int?,
      ratingVotes: json['ratingVotes'] as int?,
      isFavorite: json['isFavorite'] as bool?,
    );
  }
}

final class _SourceState {
  _SourceState({
    required this.subscription,
    required this.nextPage,
    required this.exhausted,
  });

  final SubscriptionItem subscription;
  int nextPage;
  bool exhausted;
}

final class _SourceResult {
  const _SourceResult({
    required this.subscription,
    required this.videos,
    this.error,
  });

  final SubscriptionItem subscription;
  final List<VideoItem> videos;
  final Object? error;
}
