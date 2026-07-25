import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/discover/discovery_directory_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('发现目录支持分页、筛选已加载内容和下拉刷新', (tester) async {
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
    expect(find.text('筛选已加载的标签'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();

    expect(find.text('第二页标签'), findsOneWidget);
    expect(api.pages, containsAllInOrder([1, 2]));

    await tester.enterText(find.byType(SearchBar), '第二页');
    await tester.pump();
    expect(find.text('第二页标签'), findsOneWidget);
    expect(find.text('第一页标签 1'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _PagedDirectoryApi extends Rule34VideoApi {
  _PagedDirectoryApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  final List<int> pages = [];

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
  void close() {}
}
