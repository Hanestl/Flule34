import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/app/router/app_router.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import 'helpers/test_session_harness.dart';

void main() {
  testWidgets('底部导航使用四栏结构且搜索不占一级入口', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('媒体库'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '搜索'), findsNothing);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('内容取向'), findsOneWidget);
    expect(find.text('时长'), findsOneWidget);
    expect(find.text('发布时间'), findsOneWidget);
    expect(find.text('Flule34'), findsNothing);
    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();
    expect(find.text('探索内容'), findsOneWidget);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('搜索全部标签'), findsOneWidget);
    expect(find.text('没有匹配的已加载内容。'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('播放设置'), findsOneWidget);
    await tester.tap(find.text('播放设置'));
    await tester.pumpAndSettle();
    expect(find.text('默认播放清晰度'), findsOneWidget);
    expect(find.text('网络播放策略'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('关于 Flule34'), 300);
    expect(find.text('关于 Flule34'), findsOneWidget);
  });
}

class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  Future<List<VideoItem>> loadFeed(
    FeedKind kind,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    return const [];
  }

  @override
  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec, {
    int page = 1,
  }) async {
    return const [];
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
