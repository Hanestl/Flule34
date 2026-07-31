import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/video_card.dart';

import '../helpers/test_session_harness.dart';

void main() {
  testWidgets('视频卡片按网页信息架构展示元数据', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: VideoItem(
                id: '123',
                title: 'MOM BREAKER',
                slug: 'mom-breaker',
                duration: '2:34',
                publishedLabel: '23 minutes ago',
                rating: 100,
                ratingVotes: 2,
                views: 256,
              ),
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('MOM BREAKER'), findsOneWidget);
    expect(find.text('23 minutes ago'), findsOneWidget);
    expect(find.text('100% (2)'), findsOneWidget);
    expect(find.text('256'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);

    final durationPosition = tester.widget<Positioned>(
      find
          .ancestor(of: find.text('2:34'), matching: find.byType(Positioned))
          .first,
    );
    expect(durationPosition.left, 8);
    expect(durationPosition.right, isNull);
    expect(tester.widget<Text>(find.text('2:34')).style?.color, Colors.white);
  });

  testWidgets('双列紧凑卡片保留发布时间和带图标的质量信息', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 230,
              child: VideoCard(
                compact: true,
                video: VideoItem(
                  id: '123',
                  title: '两行标题也必须保留发布时间和其他元数据',
                  slug: 'compact-card',
                  duration: '2:34',
                  publishedLabel: '23 minutes ago',
                  rating: 98,
                  ratingVotes: 25,
                  views: 1200,
                ),
                onTap: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('23 minutes ago'), findsOneWidget);
    expect(find.text('98% (25)'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('登录状态下操作菜单无需等待收藏和清晰度请求', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _DelayedRule34VideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: VideoItem(id: '123', title: '测试', slug: 'test'),
              onTap: _noop,
              contextActionLabel: '移出此库',
              onContextAction: _contextAction,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('视频操作'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('正在读取收藏状态'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('本地分类库'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('移出此库'), findsOneWidget);
  });

  testWidgets('长按卡片文字一秒后创建预览并继承原点击行为', (tester) async {
    var tapped = false;
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: const VideoItem(
                id: 'preview-1',
                title: '长按预览',
                slug: 'long-press-preview',
                previewUrl: 'https://example.com/preview.mp4',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('长按预览')),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(container.read(videoPreviewControllerProvider).request, isNull);
    await tester.pump(const Duration(milliseconds: 150));

    final controller = container.read(videoPreviewControllerProvider);
    final request = controller.request;
    expect(request?.video.id, 'preview-1');
    expect(tapped, isFalse);
    await gesture.up();

    controller.open();
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('关闭视频预览设置后长按不会创建预览请求', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(appSettingsRepositoryProvider)
        .setVideoPreviewEnabled(false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: VideoItem(
                id: 'preview-disabled',
                title: '预览已关闭',
                slug: 'preview-disabled',
              ),
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('预览已关闭')),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    expect(container.read(videoPreviewControllerProvider).request, isNull);
    await gesture.up();
  });
}

void _noop() {}

Future<void> _contextAction() async {}

final class _MemorySettingsStore implements AppSettingsStore {
  @override
  Future<bool?> readBool(String key) async => null;

  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<void> writeBool(String key, bool value) async {}

  @override
  Future<void> writeString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

final class _DelayedRule34VideoApi extends Rule34VideoApi {
  _DelayedRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  final Completer<bool> favorite = Completer<bool>();
  final Completer<VideoDetails> details = Completer<VideoDetails>();

  @override
  Future<bool> favoriteStatus(VideoItem video) => favorite.future;

  @override
  Future<VideoDetails> loadVideoDetails(VideoItem video) => details.future;

  @override
  void close() {}
}
