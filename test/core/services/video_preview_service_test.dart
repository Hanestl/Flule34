import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/video_preview_service.dart';

void main() {
  test('视频已有预览地址时不会发起搜索', () async {
    var searches = 0;
    final resolver = VideoPreviewResolver(
      search: (_) async {
        searches += 1;
        return const <VideoItem>[];
      },
      persist: ({required videoId, required previewUrl}) async {},
    );

    final result = await resolver.resolve(
      const VideoItem(
        id: '1',
        title: '测试',
        slug: 'test',
        previewUrl: 'https://example.com/preview.mp4',
      ),
    );

    expect(result, 'https://example.com/preview.mp4');
    expect(searches, 0);
  });

  test('旧索引按标题搜索并只接受视频 ID 完全一致的结果', () async {
    final persisted = <String, String?>{};
    final resolver = VideoPreviewResolver(
      search: (query) async => const <VideoItem>[
        VideoItem(
          id: 'wrong',
          title: '同名视频',
          slug: 'same-title',
          previewUrl: 'https://example.com/wrong.mp4',
        ),
        VideoItem(
          id: '4514001',
          title: '目标视频',
          slug: 'target-video',
          previewUrl: 'https://example.com/correct.mp4',
        ),
      ],
      persist: ({required videoId, required previewUrl}) async {
        persisted[videoId] = previewUrl;
      },
    );

    final result = await resolver.resolve(
      const VideoItem(id: '4514001', title: '目标视频', slug: 'target-video'),
    );

    expect(result, 'https://example.com/correct.mp4');
    expect(persisted, {'4514001': 'https://example.com/correct.mp4'});
  });

  test('标题没有命中时使用 slug 作为后备查询', () async {
    final queries = <String>[];
    final resolver = VideoPreviewResolver(
      search: (query) async {
        queries.add(query);
        if (query == 'renamed video') {
          return const <VideoItem>[
            VideoItem(
              id: '2',
              title: '新标题',
              slug: 'renamed-video',
              previewUrl: 'https://example.com/renamed.mp4',
            ),
          ];
        }
        return const <VideoItem>[];
      },
      persist: ({required videoId, required previewUrl}) async {},
    );

    final result = await resolver.resolve(
      const VideoItem(id: '2', title: '旧标题', slug: 'renamed-video'),
    );

    expect(queries, ['旧标题', 'renamed video']);
    expect(result, 'https://example.com/renamed.mp4');
  });

  test('同一视频的并发补全会复用在途请求', () async {
    final completer = Completer<List<VideoItem>>();
    var searches = 0;
    final resolver = VideoPreviewResolver(
      search: (_) {
        searches += 1;
        return completer.future;
      },
      persist: ({required videoId, required previewUrl}) async {},
    );
    const video = VideoItem(id: '3', title: '并发', slug: 'concurrent');

    final first = resolver.resolve(video);
    final second = resolver.resolve(video);
    completer.complete(const <VideoItem>[
      VideoItem(
        id: '3',
        title: '并发',
        slug: 'concurrent',
        previewUrl: 'https://example.com/concurrent.mp4',
      ),
    ]);

    expect(await first, 'https://example.com/concurrent.mp4');
    expect(await second, 'https://example.com/concurrent.mp4');
    expect(searches, 1);
  });

  test('失效地址会清除缓存和持久化记录', () async {
    final persisted = <String?>[];
    var searches = 0;
    final resolver = VideoPreviewResolver(
      search: (_) async {
        searches += 1;
        return const <VideoItem>[
          VideoItem(
            id: '4',
            title: '刷新',
            slug: 'refresh',
            previewUrl: 'https://example.com/new.mp4',
          ),
        ];
      },
      persist: ({required videoId, required previewUrl}) async {
        persisted.add(previewUrl);
      },
    );

    expect(
      await resolver.resolve(
        const VideoItem(
          id: '4',
          title: '刷新',
          slug: 'refresh',
          previewUrl: 'https://example.com/old.mp4',
        ),
      ),
      'https://example.com/old.mp4',
    );
    await resolver.invalidate('4');
    final refreshed = await resolver.resolve(
      const VideoItem(id: '4', title: '刷新', slug: 'refresh'),
      forceRefresh: true,
    );

    expect(refreshed, 'https://example.com/new.mp4');
    expect(searches, 1);
    expect(persisted, [null, 'https://example.com/new.mp4']);
  });

  test('预览控制器每次打开都会生成新请求并支持关闭', () {
    final controller = VideoPreviewController();
    addTearDown(controller.dispose);
    const video = VideoItem(id: '5', title: '控制器', slug: 'controller');
    var opened = 0;

    controller.show(video, onOpen: () => opened += 1);
    final firstSerial = controller.request!.serial;
    controller.show(video, onOpen: () => opened += 1);

    expect(controller.request!.serial, greaterThan(firstSerial));
    controller.open();
    expect(controller.request, isNull);
    expect(opened, 0);
  });

  test('打开预览会在关闭窗口后执行原视频卡片行为', () async {
    final controller = VideoPreviewController();
    addTearDown(controller.dispose);
    var destination = '';

    controller.show(
      const VideoItem(id: '6', title: '播放列表视频', slug: 'playlist-video'),
      onOpen: () => destination = 'playlist-player',
    );
    controller.open();
    await Future<void>.delayed(Duration.zero);

    expect(controller.request, isNull);
    expect(destination, 'playlist-player');
  });
}
