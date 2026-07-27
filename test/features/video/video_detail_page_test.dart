import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/core/services/network_status_service.dart';
import 'package:flule34/core/services/screen_wake_lock_service.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/video/video_detail_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('全屏内部路由不会触发详情页暂停策略', () {
    expect(shouldPauseVideoForRoutePush(true), isFalse);
    expect(shouldPauseVideoForRoutePush(false), isTrue);
  });

  testWidgets('视频详情固定播放器并只读展示评分', (tester) async {
    final originalPlatform = VideoPlayerPlatform.instance;
    final platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() async {
      VideoPlayerPlatform.instance = originalPlatform;
      await platform.close();
    });
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _FakeVideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        rule34VideoApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
        networkStatusServiceProvider.overrideWithValue(
          _FakeNetworkStatusService(),
        ),
        screenWakeLockServiceProvider.overrideWithValue(
          _FakeScreenWakeLockService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('喜欢'), findsNothing);
    expect(find.text('不喜欢'), findsNothing);
    expect(find.text('播放列表'), findsNothing);
    expect(find.text('入库'), findsOneWidget);
    expect(find.text('3D · ↑12 ↓3'), findsOneWidget);
    expect(find.textContaining('评论'), findsNothing);
    expect(find.text('播放'), findsNothing);
    final playerFinder = find.byKey(const ValueKey('inline-video-player'));
    expect(playerFinder, findsOneWidget);
    final playerTop = tester.getTopLeft(playerFinder).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(playerFinder).dy, playerTop);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('视频详情加载失败后可原位重试且不会因重建重复请求', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _RetryVideoApi(harness.sessionStore);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        downloadPlatformServiceProvider.overrideWithValue(
          _FakeDownloadPlatformService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoDetailPage(api: api, video: _video),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('详情暂时不可用'), findsOneWidget);
    expect(api.detailLoads, 1);
    await tester.pump();
    expect(api.detailLoads, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('此视频未提供可直接播放的 MP4 源。'), findsOneWidget);
    expect(api.detailLoads, 2);
  });
}

final class _FakeNetworkStatusService implements NetworkStatusService {
  @override
  Future<NetworkClass> current() async => NetworkClass.wifi;
}

final class _FakeScreenWakeLockService implements ScreenWakeLockService {
  @override
  Future<void> setEnabled(bool enabled) async {}
}

const _video = VideoItem(id: '123', title: '测试视频', slug: 'test-video');

const _details = VideoDetails(
  video: _video,
  sources: [
    VideoSource(
      label: '720p',
      url: 'https://example.com/video.mp4',
      isHd: true,
    ),
  ],
  categories: ['3D'],
  tags: ['example'],
  models: ['Artist'],
  metadataItems: [
    VideoMetadataItem(
      id: '1',
      title: '3D',
      path: '/categories/1/3d/',
      kind: DiscoveryKind.category,
      upScore: 12,
      downScore: 3,
    ),
  ],
  isFavorite: false,
);

class _FakeVideoApi extends Rule34VideoApi {
  _FakeVideoApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(VideoItem video) async {
    detailLoads += 1;
    return _details;
  }

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}

class _RetryVideoApi extends Rule34VideoApi {
  _RetryVideoApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(VideoItem video) async {
    detailLoads += 1;
    if (detailLoads == 1) {
      throw const ApiException('详情暂时不可用');
    }
    return const VideoDetails(
      video: _video,
      sources: [],
      categories: [],
      tags: [],
      models: [],
      isFavorite: false,
    );
  }

  @override
  void close() {}
}

final class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast();

  int playCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    Timer.run(() {
      if (!_events.isClosed) {
        _events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(minutes: 2),
            size: const Size(1280, 720),
          ),
        );
      }
    });
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> play(int playerId) async {
    playCount += 1;
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration value) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setVolume(int playerId, double value) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double value) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> dispose(int playerId) async {}

  Future<void> close() => _events.close();
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

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  @override
  Stream<DownloadPlatformEvent> get events => const Stream.empty();

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async => true;

  @override
  void dispose() {}

  @override
  Future<bool> enqueue(DownloadRequest request) async => true;

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<bool> ensureSharedStoragePermission() async => true;

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async =>
      const DownloadFileInspection(exists: true, readable: true);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMaxConcurrent(int value) async {}

  @override
  Future<bool> openFile(String fileUri) async => true;
}
