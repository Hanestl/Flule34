import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/app/router/route_names.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/search/data/search_history_repository.dart';
import 'package:flule34/features/search/search_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/localized_translation_text.dart';

import '../../helpers/test_session_harness.dart';

PredictivePrefetchService _createPrefetch(
  Rule34VideoApi api,
  SessionStore sessionStore,
) {
  final service = PredictivePrefetchService(
    api: api,
    sessionStore: sessionStore,
  );
  addTearDown(service.dispose);
  return service;
}

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
            prefetchService: _createPrefetch(api, harness.sessionStore),
            historyRepository: SearchHistoryRepository(
              harness.database,
              harness.sessionStore,
              settings,
            ),
            translationService: TranslationService.fromDictionary(
              settingsRepository: settings,
              dictionary: const {},
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
            prefetchService: _createPrefetch(api, harness.sessionStore),
            historyRepository: SearchHistoryRepository(
              harness.database,
              harness.sessionStore,
              settings,
            ),
            translationService: TranslationService.fromDictionary(
              settingsRepository: settings,
              dictionary: const {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'example');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('筛选与排序'));
    await tester.pumpAndSettle();
    expect(find.text('必须同时包含'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('发布时间'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final uploadPeriodTile = find.ancestor(
      of: find.text('发布时间'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: uploadPeriodTile,
        matching: find.byType(DropdownButton<UploadPeriod>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('过去 1 周').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('仅显示已验证上传者'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('仅显示已验证上传者'));
    await tester.scrollUntilVisible(
      find.text('最低点赞率'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('最低点赞率'), findsOneWidget);
    expect(find.text('最低投票数'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

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
          home: SearchPage(
            api: api,
            historyRepository: historyRepository,
            prefetchService: _createPrefetch(api, harness.sessionStore),
            translationService: TranslationService.fromDictionary(
              settingsRepository: settings,
              dictionary: const {},
            ),
          ),
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

  testWidgets('中文标签反查只在选择后解析英文标签', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final translationService = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );
    addTearDown(translationService.dispose);
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => SearchPage(
            api: api,
            historyRepository: SearchHistoryRepository(
              harness.database,
              harness.sessionStore,
              settings,
            ),
            prefetchService: _createPrefetch(api, harness.sessionStore),
            translationService: translationService,
          ),
        ),
        GoRoute(
          path: '/collection/:kind/:id',
          name: AppRouteNames.collection,
          builder: (context, state) => const Text('标签集合'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), '足交');
    await tester.pump();

    expect(find.text('足交 · footjob'), findsOneWidget);
    expect(api.suggestionQueries, isEmpty);

    await tester.tap(find.text('足交 · footjob'));
    await tester.pumpAndSettle();
    expect(api.suggestionQueries, contains('footjob'));
    expect(find.text('标签集合'), findsOneWidget);
  });

  testWidgets('中文标题搜索合并网站直搜和已学习标题反查', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.database.upsertLearnedTranslation(
      kind: 'title',
      canonicalName: 'video-1',
      sourceText: 'MOM BREAKER',
      translation: '母亲终结者',
      videoSlug: 'mom-breaker',
    );
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final translationService = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: harness.database,
      dictionary: const {},
    );
    addTearDown(translationService.dispose);
    await translationService.initialize();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
        translationServiceProvider.overrideWithValue(translationService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchPage(
              api: api,
              historyRepository: SearchHistoryRepository(
                harness.database,
                harness.sessionStore,
                settings,
              ),
              prefetchService: _createPrefetch(api, harness.sessionStore),
              translationService: translationService,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '母亲终结者');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(api.videoQueries, contains('母亲终结者'));
    expect(api.videoQueries, contains('MOM BREAKER'));
    expect(find.byType(LocalizedTranslationText), findsWidgets);
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

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class _FakeSearchApi extends Rule34VideoApi {
  _FakeSearchApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  SearchFilters lastFilters = const SearchFilters();
  final List<String> suggestionQueries = [];
  final List<String> videoQueries = [];

  @override
  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec, {
    int page = 1,
  }) async {
    return const [];
  }

  @override
  Future<List<SearchSuggestion>> searchSuggestions(
    String query,
    SearchSuggestionKind kind,
  ) async {
    if (kind == SearchSuggestionKind.tag) {
      suggestionQueries.add(query);
      if (query == 'footjob') {
        return const [
          SearchSuggestion(
            id: '42',
            title: 'footjob',
            total: 123,
            kind: SearchSuggestionKind.tag,
          ),
        ];
      }
    }
    return const [];
  }

  @override
  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    lastFilters = filters;
    videoQueries.add(query);
    if (query == 'MOM BREAKER' && page == 1) {
      return const [
        VideoItem(id: 'video-1', title: 'MOM BREAKER', slug: 'mom-breaker'),
      ];
    }
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
