import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/video_feed.dart';

void main() {
  testWidgets('下一页加载失败时在列表底部提供原位重试', (tester) async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    var allowPageTwo = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: VideoFeed(
              loadPage: (page) async {
                if (page == 1) {
                  return const [
                    VideoItem(id: '1', title: '第一页', slug: 'first'),
                    VideoItem(id: '2', title: '第一页 2', slug: 'first-2'),
                    VideoItem(id: '3', title: '第一页 3', slug: 'first-3'),
                    VideoItem(id: '4', title: '第一页 4', slug: 'first-4'),
                    VideoItem(id: '5', title: '第一页 5', slug: 'first-5'),
                  ];
                }
                if (page == 2 && !allowPageTwo) {
                  throw Exception('分页网络错误');
                }
                if (page == 2) {
                  return const [
                    VideoItem(id: '6', title: '第二页', slug: 'second'),
                  ];
                }
                return const [];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -5000),
      10000,
    );
    await tester.pumpAndSettle();

    expect(find.text('重试加载下一页'), findsOneWidget);
    expect(find.textContaining('分页网络错误'), findsOneWidget);
    allowPageTwo = true;
    await tester.tap(find.text('重试加载下一页'));
    await tester.pumpAndSettle();

    expect(find.text('第二页'), findsOneWidget);
  });

  testWidgets('收藏和历史样式的视频流提供搜索与筛选入口', (tester) async {
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
          home: Scaffold(
            body: VideoFeed(
              showSearchAndFilters: true,
              searchHint: '搜索收藏的视频',
              loadPage: (page) async => page == 1
                  ? const [
                      VideoItem(id: '1', title: 'Hydra 精选', slug: 'hydra'),
                      VideoItem(id: '2', title: '其他视频', slug: 'other'),
                      VideoItem(id: '3', title: '填充 3', slug: 'fill-3'),
                      VideoItem(id: '4', title: '填充 4', slug: 'fill-4'),
                      VideoItem(id: '5', title: '填充 5', slug: 'fill-5'),
                      VideoItem(id: '6', title: '填充 6', slug: 'fill-6'),
                      VideoItem(id: '7', title: '填充 7', slug: 'fill-7'),
                      VideoItem(id: '8', title: '填充 8', slug: 'fill-8'),
                    ]
                  : const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索收藏的视频'), findsOneWidget);
    expect(find.byTooltip('筛选'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'Hydra');
    await tester.pump();

    expect(find.text('Hydra 精选'), findsOneWidget);
    expect(find.text('其他视频'), findsNothing);
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  _MemorySettingsStore({Map<String, String> strings = const {}})
    : _strings = Map.of(strings);

  final Map<String, String> _strings;
  final Map<String, bool> _bools = {};

  @override
  Future<bool?> readBool(String key) async => _bools[key];

  @override
  Future<String?> readString(String key) async => _strings[key];

  @override
  Future<void> writeBool(String key, bool value) async {
    _bools[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _strings[key] = value;
  }
}
