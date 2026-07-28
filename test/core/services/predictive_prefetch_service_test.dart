import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('前台任务会阻止预测任务启动，并取消不相关的后台请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(milliseconds: 5),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);
    final foreground = Completer<void>();

    final foregroundFuture = service.runForeground(
      'foreground:test',
      () => foreground.future,
    );
    service.scheduleStartup();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(api.calls, isEmpty);

    foreground.complete();
    await foregroundFuture;
    await api.favoritesStarted.future.timeout(const Duration(seconds: 1));
    expect(api.calls.first, 'favorites');
    final firstToken = api.favoritesTokens.single;
    expect(firstToken.isCancelled, isFalse);

    await service.runForeground(
      PredictivePrefetchKey.video('9'),
      () async => const VideoItem(id: '9', title: '前台视频', slug: 'front'),
    );

    expect(firstToken.isCancelled, isTrue);
  });

  test('首页候选视频会按照可见顺序逐个预测加载详情', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _PrefetchApi(harness.sessionStore);
    final service = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
      idleDelay: const Duration(milliseconds: 1),
      interJobDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);

    service.offerLikelyVideos(const [
      VideoItem(id: '1', title: '第一条', slug: 'first'),
      VideoItem(id: '2', title: '第二条', slug: 'second'),
      VideoItem(id: '3', title: '第三条', slug: 'third'),
      VideoItem(id: '4', title: '第四条', slug: 'fourth'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(api.calls, ['video:1', 'video:2', 'video:3']);
  });
}

final class _PrefetchApi extends Rule34VideoApi {
  _PrefetchApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  final List<String> calls = [];
  final Completer<void> favoritesStarted = Completer<void>();
  final List<CancelToken> favoritesTokens = [];

  @override
  Future<void> prefetchFavorites({required CancelToken cancelToken}) async {
    calls.add('favorites');
    favoritesTokens.add(cancelToken);
    if (!favoritesStarted.isCompleted) {
      favoritesStarted.complete();
    }
    await cancelToken.whenCancel;
    throw const RequestCancelledException();
  }

  @override
  Future<void> prefetchHistory({required CancelToken cancelToken}) async {
    calls.add('history');
  }

  @override
  Future<void> prefetchPlaylists({required CancelToken cancelToken}) async {
    calls.add('playlists');
  }

  @override
  Future<void> prefetchSubscriptions({required CancelToken cancelToken}) async {
    calls.add('subscriptions');
  }

  @override
  Future<void> prefetchVideoDetails(
    VideoItem video, {
    required CancelToken cancelToken,
  }) async {
    calls.add('video:${video.id}');
  }

  @override
  void close() {}
}
