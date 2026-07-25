import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/video_feed.dart';

void main() {
  testWidgets('整页被关键词隐藏时仍可继续查找后续内容', (tester) async {
    final settings = AppSettingsRepository(
      _MemorySettingsStore(
        strings: const {'flule34.settings.hidden_keywords': 'hidden'},
      ),
    );
    addTearDown(settings.dispose);
    await settings.load();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    var loads = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: VideoFeed(
              loadPage: (page) async {
                loads += 1;
                return switch (page) {
                  1 => const [
                    VideoItem(
                      id: '1',
                      title: 'hidden video',
                      slug: 'hidden-video',
                    ),
                  ],
                  2 => const [
                    VideoItem(
                      id: '2',
                      title: 'visible video',
                      slug: 'visible-video',
                    ),
                  ],
                  _ => const [],
                };
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前加载的视频都被隐藏标题关键词过滤了。'), findsOneWidget);
    expect(find.text('hidden video'), findsNothing);
    await tester.tap(find.text('继续查找未隐藏内容'));
    await tester.pumpAndSettle();

    expect(find.text('visible video'), findsOneWidget);
    expect(loads, 2);
  });

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
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();

    expect(find.text('重试加载下一页'), findsOneWidget);
    expect(find.textContaining('分页网络错误'), findsOneWidget);
    allowPageTwo = true;
    await tester.tap(find.text('重试加载下一页'));
    await tester.pumpAndSettle();

    expect(find.text('第二页'), findsOneWidget);
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
