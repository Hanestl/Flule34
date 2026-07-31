import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/core/services/network_status_service.dart';
import 'package:flule34/core/services/screen_wake_lock_service.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/domain/app_settings.dart';
import 'package:flule34/features/video/video_player_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('跳转第一次被忽略时会重试并以真实位置为准', () async {
    var attempts = 0;
    var actual = Duration.zero;

    final result = await verifyPlayerSeek(
      target: const Duration(minutes: 1, seconds: 45),
      seek: (target) async {
        attempts += 1;
        if (attempts >= 2) {
          actual = target;
        }
      },
      readActualPosition: () async => actual,
      verificationDelays: const [Duration.zero],
    );

    expect(result.matched, isTrue);
    expect(result.position, const Duration(minutes: 1, seconds: 45));
    expect(attempts, 2);
  });

  test('跳转始终失败时回退到播放器真实位置', () async {
    final requested = <Duration>[];

    final result = await verifyPlayerSeek(
      target: const Duration(minutes: 1, seconds: 45),
      seek: (target) async => requested.add(target),
      readActualPosition: () async => const Duration(seconds: 3),
      verificationDelays: const [Duration.zero],
    );

    expect(result.matched, isFalse);
    expect(result.position, const Duration(seconds: 3));
    expect(requested, [
      const Duration(minutes: 1, seconds: 45),
      const Duration(minutes: 1, seconds: 45),
      const Duration(seconds: 3),
    ]);
  });

  test('后台播放通知不暴露视频标题、作者或封面', () {
    final configuration = playbackNotificationConfiguration(
      showNotification: true,
    );

    expect(configuration.showNotification, isTrue);
    expect(configuration.title, '正在播放媒体');
    expect(configuration.author, '点击返回应用');
    expect(configuration.imageUrl, isNull);
    expect(configuration.notificationChannelName, 'flule34_media_private');
  });

  test('下一视频预缓存按网络限制体积并复用正式缓存键', () {
    expect(videoPreCacheSizeForNetwork(NetworkClass.wifi), 16 * 1024 * 1024);
    expect(videoPreCacheSizeForNetwork(NetworkClass.mobile), 6 * 1024 * 1024);
    expect(videoPreCacheSizeForNetwork(NetworkClass.offline), 0);
    expect(videoCacheKey('456', _source), 'flule34_456_720p');
    expect(
      playlistVideoPreCacheSizeForNetwork(NetworkClass.wifi),
      96 * 1024 * 1024,
    );
    expect(
      playlistVideoPreCacheSizeForNetwork(NetworkClass.mobile),
      32 * 1024 * 1024,
    );
    expect(videoBufferingConfiguration.minBufferMs, 45000);
    expect(videoBufferingConfiguration.maxBufferMs, 180000);
    expect(videoBufferingConfiguration.bufferForPlaybackMs, 1500);
    expect(videoBufferingConfiguration.bufferForPlaybackAfterRebufferMs, 8000);
  });

  test('播放器滑动手势先锁定轴向，再计算进度和音量目标', () {
    expect(playerGestureAxisForDelta(const Offset(6, 6)), isNull);
    expect(
      playerGestureAxisForDelta(const Offset(30, 8)),
      PlayerGestureAxis.horizontal,
    );
    expect(
      playerGestureAxisForDelta(const Offset(8, -30)),
      PlayerGestureAxis.vertical,
    );
    expect(
      playerGestureTargetPosition(
        initial: const Duration(minutes: 3),
        duration: const Duration(minutes: 30),
        deltaX: 50,
        width: 100,
      ),
      const Duration(minutes: 8),
    );
    expect(
      playerGestureTargetVolume(initial: 0.4, deltaY: -50, height: 100),
      0.9,
    );
    expect(playerProgressStrokeWidth(false), 3);
    expect(playerProgressStrokeWidth(true), 5);
  });

  test('视频源刷新守卫区分活跃刷新和无人收尾的失败源', () {
    expect(
      sourceRefreshGate(refreshing: true, force: false, previouslyFailed: true),
      SourceRefreshGate.waitForActiveRefresh,
    );
    expect(
      sourceRefreshGate(
        refreshing: false,
        force: false,
        previouslyFailed: true,
      ),
      SourceRefreshGate.rejectFailedUrl,
    );
    expect(
      sourceRefreshGate(refreshing: false, force: true, previouslyFailed: true),
      SourceRefreshGate.proceed,
    );
  });

  test('竖屏保持当前方向时使用真实屏幕比例', () {
    const portrait = Size(1080, 2400);

    expect(
      videoFullScreenAspectRatio(
        portrait,
        FullscreenOrientationPreference.device,
      ),
      closeTo(1080 / 2400, 0.0001),
    );
    expect(
      videoFullScreenAspectRatio(
        portrait,
        FullscreenOrientationPreference.landscape,
      ),
      closeTo(2400 / 1080, 0.0001),
    );
  });

  test('全屏进入默认隐藏控件且退出后恢复显示', () {
    expect(initialVideoControlsVisible(false), isTrue);
    expect(initialVideoControlsVisible(true), isFalse);
    expect(
      videoControlsVisibleAfterFullscreenEvent(
        BetterPlayerEventType.openFullscreen,
        true,
      ),
      isFalse,
    );
    expect(
      videoControlsVisibleAfterFullscreenEvent(
        BetterPlayerEventType.hideFullscreen,
        false,
      ),
      isTrue,
    );
    expect(
      videoControlsUseFullscreenLayoutAfterEvent(
        BetterPlayerEventType.openFullscreen,
        false,
      ),
      isFalse,
    );
    expect(
      videoControlsUseFullscreenLayoutAfterEvent(
        BetterPlayerEventType.hideFullscreen,
        true,
      ),
      isFalse,
    );
    expect(
      videoControlsAnimateOpacityAfterEvent(
        BetterPlayerEventType.openFullscreen,
      ),
      isFalse,
    );
    expect(
      videoControlsAnimateOpacityAfterEvent(
        BetterPlayerEventType.hideFullscreen,
      ),
      isTrue,
    );
  });

  test('缓存区间会合并且不会被瞬时空快照清零', () {
    final first = mergeBufferedRanges(const [], const [
      (start: Duration.zero, end: Duration(seconds: 30)),
    ]);
    final afterEmpty = mergeBufferedRanges(first, const []);
    final extended = mergeBufferedRanges(afterEmpty, const [
      (start: Duration(seconds: 25), end: Duration(seconds: 45)),
    ]);

    expect(afterEmpty, first);
    expect(extended, const [
      (start: Duration.zero, end: Duration(seconds: 45)),
    ]);
  });

  testWidgets('播放器保持 16:9 且不再暴露冗余控制按钮', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const volumeChannel = MethodChannel('com.hanestl.flule34/media_volume');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      volumeChannel,
      (call) async {
        if (call.method == 'current') {
          return 0.5;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        volumeChannel,
        null,
      ),
    );
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
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final handle = VideoPlayerHandle();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        sessionStoreProvider.overrideWithValue(harness.sessionStore),
        rule34VideoApiProvider.overrideWithValue(api),
        appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
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
          home: VideoPlayerPage(
            api: api,
            video: _video,
            sources: [_source],
            handle: handle,
            autoplay: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final playerFinder = find.byKey(const ValueKey('inline-video-player'));
    expect(playerFinder, findsOneWidget);
    final contentSize = tester.getSize(playerFinder);
    expect(contentSize.width / contentSize.height, closeTo(16 / 9, 0.001));
    expect(find.byTooltip('前进 10 秒'), findsNothing);
    expect(find.byTooltip('后退 10 秒'), findsNothing);
    expect(find.byTooltip('静音'), findsNothing);

    for (var attempt = 0; attempt < 10 && platform.playCount == 0; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final panArea = find.byKey(const ValueKey('video-controls-pan-area'));
    final panDetector = tester.widget<GestureDetector>(panArea);
    expect(panDetector.onPanStart, isNotNull);
    expect(panDetector.onPanUpdate, isNotNull);
    expect(panDetector.onPanEnd, isNotNull);
    expect(panDetector.onDoubleTap, isNull);
    final tapArea = find.byKey(const ValueKey('video-controls-tap-area'));
    final tapDetector = tester.widget<GestureDetector>(tapArea);
    expect(tapDetector.onDoubleTap, isNotNull);

    await handle.pause();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    final controlsOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('video-controls-opacity')),
    );
    expect(controlsOpacity.opacity, 0);

    final stateBeforeSwitch = tester.state(find.byType(VideoPlayerPage));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: VideoPlayerPage(
            api: api,
            video: _nextVideo,
            sources: [_nextSource],
            handle: handle,
            autoplay: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      identical(stateBeforeSwitch, tester.state(find.byType(VideoPlayerPage))),
      isTrue,
    );
    expect(find.text('下一条播放器测试'), findsOneWidget);
    await handle.pause();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

const _video = VideoItem(id: '123', title: '播放器测试', slug: 'player-test');

const _source = VideoSource(
  label: '720p',
  url: 'https://example.com/video.mp4',
  isHd: true,
);

const _nextVideo = VideoItem(
  id: '456',
  title: '下一条播放器测试',
  slug: 'next-player-test',
);

const _nextSource = VideoSource(
  label: '1080p',
  url: 'https://example.com/next.mp4',
  isHd: true,
);

class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  void close() {}
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _events =
      StreamController<VideoEvent>.broadcast();

  Duration position = Duration.zero;
  double volume = 1;
  double speed = 1;
  int playCount = 0;
  int pauseCount = 0;

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
  Future<void> pause(int playerId) async {
    pauseCount += 1;
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> setVolume(int playerId, double value) async {
    volume = value;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double value) async {
    speed = value;
  }

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

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
