import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/discover/discovery_directory_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('发现目录支持正确分页和全站服务端搜索', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _PagedDirectoryApi(harness.sessionStore);

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryDirectoryPage(
          api: api,
          spec: const DiscoveryDirectorySpec(
            title: '标签',
            path: '/tags/',
            kind: DiscoveryKind.tag,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一页标签 1'), findsOneWidget);
    expect(find.text('搜索全部标签'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();

    expect(find.text('第二页标签'), findsOneWidget);
    expect(api.pages, containsAllInOrder([1, 2]));

    await tester.enterText(find.byType(SearchBar), 'tifa');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('tifa lockhart (final fantasy)'), findsOneWidget);
    expect(find.text('第一页标签 1'), findsNothing);
    expect(api.searches, ['tifa']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _PagedDirectoryApi extends Rule34VideoApi {
  _PagedDirectoryApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  final List<int> pages = [];
  final List<String> searches = [];

  @override
  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec, {
    int page = 1,
  }) async {
    pages.add(page);
    if (page == 1) {
      return List.generate(
        12,
        (index) => ContentCollectionItem(
          id: '${index + 1}',
          title: '第一页标签 ${index + 1}',
          path: '/tags/${index + 1}/',
          kind: DiscoveryKind.tag,
        ),
      );
    }
    if (page == 2) {
      return const [
        ContentCollectionItem(
          id: '20',
          title: '第二页标签',
          path: '/tags/20/',
          kind: DiscoveryKind.tag,
        ),
      ];
    }
    return const [];
  }

  @override
  Future<List<SearchSuggestion>> searchSuggestions(
    String query,
    SearchSuggestionKind kind,
  ) async {
    searches.add(query);
    return const [
      SearchSuggestion(
        id: '369',
        title: 'tifa lockhart (final fantasy)',
        total: 5442,
        kind: SearchSuggestionKind.tag,
      ),
    ];
  }

  @override
  void close() {}
}
