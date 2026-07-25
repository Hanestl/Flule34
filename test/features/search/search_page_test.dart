import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/search/data/search_history_repository.dart';
import 'package:flule34/features/search/search_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('未登录搜索不会创建匿名历史', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SearchPage(
            api: api,
            historyRepository: SearchHistoryRepository(
              harness.database,
              harness.sessionStore,
              settings,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      await harness.database.select(harness.database.searchHistories).get(),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('登录后搜索历史和筛选条件形成真实闭环', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SearchPage(
            api: api,
            historyRepository: SearchHistoryRepository(
              harness.database,
              harness.sessionStore,
              settings,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -360),
    );
    await tester.pump();
    await tester.tap(find.text('过去 1 周'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -360),
    );
    await tester.pump();
    await tester.tap(find.text('仅显示已验证上传者'));
    await tester.tap(find.text('应用'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final history = await harness.database
        .select(harness.database.searchHistories)
        .get();
    expect(history.single.displayQuery, 'example');
    expect(api.lastFilters.uploadPeriod, UploadPeriod.pastWeek);
    expect(api.lastFilters.verifiedOnly, isTrue);
    expect(find.text('过去 1 周'), findsOneWidget);
    expect(find.text('已验证上传者'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('关闭搜索历史后不记录新查询', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setSaveSearchHistory(false);
    final repository = SearchHistoryRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );

    await repository.record('example');

    expect(
      await harness.database.select(harness.database.searchHistories).get(),
      isEmpty,
    );
  });

  testWidgets('搜索页打开期间登录会切换到当前账号历史流', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final historyRepository = _TrackingSearchHistoryRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SearchPage(api: api, historyRepository: historyRepository),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('登录后，搜索历史会按账号安全保存。'), findsOneWidget);

    await harness.sessionStore.authenticate('1001');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('登录后，搜索历史会按账号安全保存。'), findsNothing);
    expect(find.text('还没有搜索记录。'), findsOneWidget);
    expect(historyRepository.watchCalls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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

class _FakeSearchApi extends Rule34VideoApi {
  _FakeSearchApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  SearchFilters lastFilters = const SearchFilters();

  @override
  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec,
  ) async {
    return const [];
  }

  @override
  Future<List<SearchSuggestion>> searchSuggestions(
    String query,
    SearchSuggestionKind kind,
  ) async {
    return const [];
  }

  @override
  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    lastFilters = filters;
    return const [];
  }

  @override
  void close() {}
}

final class _TrackingSearchHistoryRepository extends SearchHistoryRepository {
  _TrackingSearchHistoryRepository(
    AppDatabase database,
    this.sessionStore,
    AppSettingsRepository settings,
  ) : super(database, sessionStore, settings);

  final SessionStore sessionStore;
  int watchCalls = 0;

  @override
  Stream<List<SearchHistory>> watch() {
    watchCalls += 1;
    return Stream.value(const []);
  }
}
