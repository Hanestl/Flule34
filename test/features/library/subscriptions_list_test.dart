import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/library/subscriptions_list.dart';
import 'package:flule34/features/library/subscription_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('订阅空状态仍可下拉刷新并恢复列表', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _SubscriptionsApi(
      harness.sessionStore,
      responses: const [
        [],
        [
          SubscriptionItem(
            title: 'JuicyNeko',
            path: '/models/juicyneko/',
            kind: SubscriptionKind.model,
          ),
        ],
      ],
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        rule34VideoApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: SubscriptionsList(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有订阅内容。'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 360));
    await tester.pumpAndSettle();

    expect(find.text('JuicyNeko'), findsOneWidget);
    expect(api.loads, 2);
  });

  testWidgets('订阅默认使用两列紧凑卡片且不显示箭头', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _SubscriptionsApi(
      harness.sessionStore,
      responses: const [
        [
          SubscriptionItem(
            title: 'HydraFXX',
            path: '/models/hydrafxx/',
            kind: SubscriptionKind.model,
          ),
          SubscriptionItem(
            title: 'Nagoonimation',
            path: '/models/nagoonimation/',
            kind: SubscriptionKind.model,
          ),
        ],
      ],
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        rule34VideoApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: SubscriptionsList(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('HydraFXX'), findsOneWidget);
    expect(find.text('Nagoonimation'), findsOneWidget);
  });

  testWidgets('订阅卡片可以确认后直接取消订阅', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _SubscriptionsApi(
      harness.sessionStore,
      responses: const [
        [
          SubscriptionItem(
            title: 'HydraFXX',
            path: '/models/hydrafxx/',
            kind: SubscriptionKind.model,
          ),
        ],
      ],
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        rule34VideoApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: SubscriptionsList(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消订阅'));
    await tester.pumpAndSettle();
    expect(find.text('确定取消订阅“HydraFXX”吗？'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(api.unsubscribedPaths, ['/models/hydrafxx/']);
    expect(find.text('HydraFXX'), findsNothing);
    expect(find.text('还没有订阅内容。'), findsOneWidget);
  });

  testWidgets('订阅详情页顶部显示取消订阅入口', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _SubscriptionsApi(harness.sessionStore, responses: const [[]]);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        rule34VideoApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SubscriptionPage(
            api: api,
            subscription: const SubscriptionItem(
              title: 'HydraFXX',
              path: '/models/hydrafxx/',
              kind: SubscriptionKind.model,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('取消订阅'), findsOneWidget);
  });
}

final class _SubscriptionsApi extends Rule34VideoApi {
  _SubscriptionsApi(
    SessionStore sessionStore, {
    required List<List<SubscriptionItem>> responses,
  }) : _responses = List.of(responses),
       super(sessionStore: sessionStore);

  final List<List<SubscriptionItem>> _responses;
  final List<String> unsubscribedPaths = [];
  var loads = 0;

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({bool force = false}) async {
    final index = loads.clamp(0, _responses.length - 1);
    loads += 1;
    return _responses[index];
  }

  @override
  Future<SubscriptionItem> resolveSubscription(
    SubscriptionItem subscription,
  ) async => subscription;

  @override
  Future<List<VideoItem>> loadSubscriptionVideos(
    SubscriptionItem subscription,
    int page, {
    dynamic cancelToken,
  }) async => const [];

  @override
  Future<void> unsubscribeSubscription(SubscriptionItem subscription) async {
    unsubscribedPaths.add(subscription.path);
  }

  @override
  void close() {}
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}
