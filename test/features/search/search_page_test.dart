import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/search/data/search_history_repository.dart';
import 'package:flule34/features/search/search_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('未登录搜索不会创建匿名历史', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _FakeSearchApi(harness.sessionStore);
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          api: api,
          historyRepository: SearchHistoryRepository(
            harness.database,
            harness.sessionStore,
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

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          api: api,
          historyRepository: SearchHistoryRepository(
            harness.database,
            harness.sessionStore,
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
