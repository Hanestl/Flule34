import 'dart:async';

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
import 'package:flule34/features/video/video_player_page.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('播放器支持跳转、倍速和全屏切换', (tester) async {
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
          home: VideoPlayerPage(api: api, video: _video, sources: [_source]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.byTooltip('前进 10 秒'), findsOneWidget);
    expect(find.byTooltip('播放选项'), findsOneWidget);
    expect(find.byTooltip('全屏'), findsOneWidget);

    await tester.tap(find.byTooltip('播放'));
    await tester.pump();
    expect(platform.playCount, 1);

    await tester.tap(find.byTooltip('前进 10 秒'));
    await tester.pump();
    expect(platform.position, const Duration(seconds: 10));

    await tester.tap(find.byTooltip('播放选项'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('1.5x'));
    await tester.pump();
    expect(platform.speed, 1.5);

    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

    final contentSize = tester.getSize(
      find.byKey(const ValueKey('video-content-aspect-ratio')),
    );
    expect(contentSize.width / contentSize.height, closeTo(16 / 9, 0.001));

    final playerRect = tester.getRect(
      find.byKey(const ValueKey('video-content-aspect-ratio')),
    );
    await tester.tapAt(playerRect.center);
    await tester.pump(const Duration(milliseconds: 400));
    final hiddenControls = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.fullscreen_exit),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(hiddenControls.opacity, 0);

    await tester.tapAt(playerRect.center);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pumpAndSettle();
    expect(find.byTooltip('全屏'), findsOneWidget);

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
}
