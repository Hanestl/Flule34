import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../api/rule34video_api.dart';
import '../models/video_models.dart';
import '../session/session_store.dart';

abstract final class PredictivePrefetchKey {
  static String video(String id) => 'video:$id';

  static String feed(String scope, int page) => 'feed:$scope:$page';

  static String favorites(int page) => 'library:favorites:$page';

  static String history(int page) => 'library:history:$page';

  static const playlists = 'library:playlists';
  static const subscriptions = 'library:subscriptions';
}

final class PredictivePrefetchService {
  PredictivePrefetchService({
    required this.api,
    required this.sessionStore,
    this.idleDelay = const Duration(milliseconds: 700),
    this.interJobDelay = const Duration(milliseconds: 180),
  });

  final Rule34VideoApi api;
  final SessionStore sessionStore;
  final Duration idleDelay;
  final Duration interJobDelay;
  final ListQueue<_PrefetchJob> _queue = ListQueue();
  final Set<String> _queuedKeys = {};

  Timer? _idleTimer;
  CancelToken? _activeToken;
  _PrefetchJob? _activeJob;
  String? _activeKey;
  String? _knownUserId;
  var _foregroundCount = 0;
  var _disposed = false;

  void scheduleStartup() {
    _syncSessionQueue();
    _scheduleNext();
  }

  void onSessionChanged() {
    if (_knownUserId == sessionStore.currentUserId) {
      return;
    }
    _cancelActive('账号状态发生变化', requeue: false);
    _queue.clear();
    _queuedKeys.clear();
    _syncSessionQueue();
    _scheduleNext();
  }

  void offerLikelyVideos(Iterable<VideoItem> videos) {
    final candidates = videos.take(3).toList(growable: false);
    for (final video in candidates.reversed) {
      _enqueue(
        _PrefetchJob(
          key: PredictivePrefetchKey.video(video.id),
          action: (token) =>
              api.prefetchVideoDetails(video, cancelToken: token),
        ),
        first: true,
      );
    }
    _scheduleNext();
  }

  Future<T> runForeground<T>(
    String key,
    Future<T> Function() operation, {
    Duration? resumeDelay,
  }) async {
    _beginForeground(key);
    try {
      return await operation();
    } finally {
      _endForeground(resumeDelay: resumeDelay);
    }
  }

  void prioritizeForeground({String? adoptKey}) {
    if (_disposed) {
      return;
    }
    _idleTimer?.cancel();
    if (adoptKey != null) {
      _removeQueued(adoptKey);
    }
    if (_activeKey != null && _activeKey != adoptKey) {
      _cancelActive('用户开始了更高优先级的操作');
    }
    _scheduleNext();
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _cancelActive('预加载服务已销毁', requeue: false);
    _queue.clear();
    _queuedKeys.clear();
  }

  void _beginForeground(String key) {
    if (_disposed) {
      return;
    }
    _foregroundCount += 1;
    _idleTimer?.cancel();
    _removeQueued(key);
    if (_activeKey != null && _activeKey != key) {
      _cancelActive('前台内容开始加载');
    }
  }

  void _endForeground({Duration? resumeDelay}) {
    if (_disposed) {
      return;
    }
    if (_foregroundCount > 0) {
      _foregroundCount -= 1;
    }
    _scheduleNext(delay: resumeDelay);
  }

  void _syncSessionQueue() {
    _knownUserId = sessionStore.currentUserId;
    if (!sessionStore.isLoggedIn) {
      return;
    }
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.favorites(1),
        action: (token) => api.prefetchFavorites(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.history(1),
        action: (token) => api.prefetchHistory(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.playlists,
        action: (token) => api.prefetchPlaylists(cancelToken: token),
      ),
    );
    _enqueue(
      _PrefetchJob(
        key: PredictivePrefetchKey.subscriptions,
        action: (token) => api.prefetchSubscriptions(cancelToken: token),
      ),
    );
  }

  void _enqueue(_PrefetchJob job, {bool first = false}) {
    if (_disposed || _queuedKeys.contains(job.key) || _activeKey == job.key) {
      return;
    }
    _queuedKeys.add(job.key);
    if (first) {
      _queue.addFirst(job);
    } else {
      _queue.addLast(job);
    }
  }

  void _removeQueued(String key) {
    if (!_queuedKeys.remove(key)) {
      return;
    }
    _queue.removeWhere((job) => job.key == key);
  }

  void _scheduleNext({Duration? delay}) {
    if (_disposed ||
        _foregroundCount > 0 ||
        _activeKey != null ||
        _queue.isEmpty) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(delay ?? idleDelay, _runNext);
  }

  void _runNext() {
    if (_disposed ||
        _foregroundCount > 0 ||
        _activeKey != null ||
        _queue.isEmpty) {
      return;
    }
    final job = _queue.removeFirst();
    _queuedKeys.remove(job.key);
    final token = CancelToken();
    _activeKey = job.key;
    _activeToken = token;
    _activeJob = job;
    unawaited(
      job
          .action(token)
          .catchError((Object _) {
            // 预测性任务失败或被取消都不应打断前台页面。
          })
          .whenComplete(() {
            if (_disposed || !identical(_activeToken, token)) {
              return;
            }
            _activeKey = null;
            _activeToken = null;
            _activeJob = null;
            _idleTimer?.cancel();
            _idleTimer = Timer(interJobDelay, _scheduleNext);
          }),
    );
  }

  void _cancelActive(String reason, {bool requeue = true}) {
    final token = _activeToken;
    final job = _activeJob;
    _activeToken = null;
    _activeKey = null;
    _activeJob = null;
    if (requeue && job != null) {
      _enqueue(job, first: true);
    }
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
  }
}

final class _PrefetchJob {
  const _PrefetchJob({required this.key, required this.action});

  final String key;
  final Future<void> Function(CancelToken token) action;
}
