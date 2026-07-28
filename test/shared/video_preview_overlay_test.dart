import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/video_preview_service.dart';
import 'package:flule34/shared/video_preview_overlay.dart';

void main() {
  testWidgets('纯画面预览窗口避让底部导航并可点外部关闭', (tester) async {
    final navigation = _NavigationListenable();
    addTearDown(navigation.dispose);
    final resolver = VideoPreviewResolver(
      search: (_) async => const <VideoItem>[],
      persist: ({required videoId, required previewUrl}) async {},
    );
    final container = ProviderContainer(
      overrides: [videoPreviewResolverProvider.overrideWithValue(resolver)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => VideoPreviewOverlay(
            navigationListenable: navigation,
            bottomInsetBuilder: (_) => 80,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Center(child: Text('内容页'))),
        ),
      ),
    );

    container
        .read(videoPreviewControllerProvider)
        .show(
          const VideoItem(
            id: 'missing',
            title: '没有预览的视频',
            slug: 'missing-preview',
          ),
          onOpen: () {},
        );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-preview-panel')), findsOneWidget);
    expect(find.text('没有预览的视频'), findsNothing);
    expect(find.text('暂时无法预览'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    final safeArea = tester.widget<SafeArea>(
      find.byKey(const Key('video-preview-safe-area')),
    );
    expect(safeArea.minimum.bottom, 92);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-preview-panel')), findsNothing);
    expect(find.text('内容页'), findsOneWidget);
  });

  testWidgets('路由变化会自动关闭预览窗口', (tester) async {
    final navigation = _NavigationListenable();
    addTearDown(navigation.dispose);
    final resolver = VideoPreviewResolver(
      search: (_) async => const <VideoItem>[],
      persist: ({required videoId, required previewUrl}) async {},
    );
    final container = ProviderContainer(
      overrides: [videoPreviewResolverProvider.overrideWithValue(resolver)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => VideoPreviewOverlay(
            navigationListenable: navigation,
            bottomInsetBuilder: (_) => 0,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('内容页')),
        ),
      ),
    );
    container
        .read(videoPreviewControllerProvider)
        .show(
          const VideoItem(id: 'route', title: '路由预览', slug: 'route-preview'),
          onOpen: () {},
        );
    await tester.pump();
    expect(find.byKey(const Key('video-preview-panel')), findsOneWidget);

    navigation.changed();
    await tester.pump();

    expect(find.byKey(const Key('video-preview-panel')), findsNothing);
  });

  testWidgets('点击预览画面会执行原视频卡片行为', (tester) async {
    final navigation = _NavigationListenable();
    addTearDown(navigation.dispose);
    final resolver = VideoPreviewResolver(
      search: (_) async => const <VideoItem>[],
      persist: ({required videoId, required previewUrl}) async {},
    );
    final container = ProviderContainer(
      overrides: [videoPreviewResolverProvider.overrideWithValue(resolver)],
    );
    addTearDown(container.dispose);
    var destination = '';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => VideoPreviewOverlay(
            navigationListenable: navigation,
            bottomInsetBuilder: (_) => 0,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('内容页')),
        ),
      ),
    );
    container
        .read(videoPreviewControllerProvider)
        .show(
          const VideoItem(
            id: 'playlist-video',
            title: '播放列表视频',
            slug: 'playlist-video',
          ),
          onOpen: () => destination = 'playlist-player',
        );
    await tester.pump();

    await tester.tap(find.byKey(const Key('video-preview-panel')));
    await tester.pump();

    expect(destination, 'playlist-player');
    expect(find.byKey(const Key('video-preview-panel')), findsNothing);
  });
}

final class _NavigationListenable extends ChangeNotifier {
  void changed() => notifyListeners();
}
