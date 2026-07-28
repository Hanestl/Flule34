import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/subscription_activity_index.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('关注流扫描全部订阅并与最近更新排序复用同一批请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final subscriptions = List.generate(
      20,
      (index) => SubscriptionItem(
        title: '作者 $index',
        path: '/models/$index/',
        kind: SubscriptionKind.model,
      ),
    );
    final calls = <String>[];
    final store = MemorySubscriptionActivityStore();
    final index = SubscriptionActivityIndex(
      sessionStore: harness.sessionStore,
      store: store,
      pageSize: 10,
      concurrency: 4,
      loadSubscriptions: ({force = false, cancelToken}) async => subscriptions,
      loadSubscriptionVideos: (subscription, page, {cancelToken}) async {
        calls.add('${subscription.path}:$page');
        if (page > 1) {
          return const [];
        }
        final sourceIndex = int.parse(
          subscription.path.split('/').where((part) => part.isNotEmpty).last,
        );
        return [
          VideoItem(
            id: '$sourceIndex',
            title: '视频 $sourceIndex',
            slug: 'video-$sourceIndex',
            publishedLabel: '${20 - sourceIndex} hours ago',
          ),
        ];
      },
    );
    addTearDown(index.dispose);

    await index.refresh(force: true);
    final videos = await index.loadFollowingPage(1);
    final callsAfterScan = calls.length;
    final ages = index.updatedAgeByPath;
    await index.loadFollowingPage(1);

    expect(callsAfterScan, 20);
    expect(calls.length, callsAfterScan);
    expect(videos.map((video) => video.id), [
      '19',
      '18',
      '17',
      '16',
      '15',
      '14',
      '13',
      '12',
      '11',
      '10',
    ]);
    expect(ages['/models/19/'], const Duration(hours: 1).inSeconds);
    expect(ages, hasLength(20));
  });

  test('空订阅源和重复视频不会阻止后续订阅参与关注流', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final subscriptions = List.generate(
      12,
      (index) => SubscriptionItem(
        title: '来源 $index',
        path: '/models/$index/',
        kind: SubscriptionKind.model,
      ),
    );
    final requested = <int>[];
    final index = SubscriptionActivityIndex(
      sessionStore: harness.sessionStore,
      store: MemorySubscriptionActivityStore(),
      pageSize: 5,
      concurrency: 3,
      loadSubscriptions: ({force = false, cancelToken}) async => subscriptions,
      loadSubscriptionVideos: (subscription, page, {cancelToken}) async {
        final sourceIndex = int.parse(
          subscription.path.split('/').where((part) => part.isNotEmpty).last,
        );
        requested.add(sourceIndex);
        if (sourceIndex == 2 || sourceIndex == 3) {
          return const [];
        }
        return [
          VideoItem(
            id: sourceIndex < 6 ? 'shared' : '$sourceIndex',
            title: '来源 $sourceIndex',
            slug: 'source-$sourceIndex',
            publishedLabel: '${12 - sourceIndex} days ago',
          ),
        ];
      },
    );
    addTearDown(index.dispose);

    await index.refresh(force: true);
    final videos = await index.loadFollowingPage(1);

    expect(requested.toSet(), containsAll(List.generate(12, (index) => index)));
    expect(videos.any((video) => video.id == '11'), isTrue);
    expect(videos.map((video) => video.id).toSet().length, videos.length);
  });

  test('按账号保存的关注快照可在新索引实例中立即恢复', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final store = MemorySubscriptionActivityStore();
    final first = SubscriptionActivityIndex(
      sessionStore: harness.sessionStore,
      store: store,
      pageSize: 1,
      loadSubscriptions: ({force = false, cancelToken}) async => const [
        SubscriptionItem(
          title: '作者',
          path: '/models/artist/',
          kind: SubscriptionKind.model,
        ),
      ],
      loadSubscriptionVideos: (subscription, page, {cancelToken}) async =>
          const [
            VideoItem(
              id: '1',
              title: '缓存视频',
              slug: 'cached',
              publishedLabel: '1 hour ago',
            ),
          ],
    );
    addTearDown(first.dispose);
    await first.refresh(force: true);

    final restored = SubscriptionActivityIndex(
      sessionStore: harness.sessionStore,
      store: store,
      loadSubscriptions: ({force = false, cancelToken}) async => const [],
      loadSubscriptionVideos: (subscription, page, {cancelToken}) async =>
          const [],
    );
    addTearDown(restored.dispose);
    await restored.loadStored();

    expect(restored.cachedVideos.single.title, '缓存视频');
    expect(restored.updatedAgeByPath['/models/artist/'], isNotNull);
  });
}
