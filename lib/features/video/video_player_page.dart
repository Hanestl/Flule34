import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/video_models.dart';
import '../../core/security/error_redaction.dart';
import '../../core/services/network_status_service.dart';
import '../../shared/scroll_to_top_overlay.dart';
import '../../core/services/media_volume_service.dart';
import '../../core/services/screen_wake_lock_service.dart';
import '../playback/data/playback_repository.dart';
import '../settings/domain/app_settings.dart';
import '../settings/domain/quality_selection.dart';

int videoPreCacheSizeForNetwork(NetworkClass network) {
  return switch (network) {
    NetworkClass.wifi => 16 * 1024 * 1024,
    NetworkClass.mobile => 6 * 1024 * 1024,
    NetworkClass.other => 10 * 1024 * 1024,
    NetworkClass.offline => 0,
  };
}

int playlistVideoPreCacheSizeForNetwork(NetworkClass network) {
  return switch (network) {
    NetworkClass.wifi => 96 * 1024 * 1024,
    NetworkClass.mobile => 32 * 1024 * 1024,
    NetworkClass.other => 64 * 1024 * 1024,
    NetworkClass.offline => 0,
  };
}

const videoBufferingConfiguration = BetterPlayerBufferingConfiguration(
  minBufferMs: 45000,
  maxBufferMs: 180000,
  bufferForPlaybackMs: 1500,
  bufferForPlaybackAfterRebufferMs: 8000,
);

final class VerifiedSeekResult {
  const VerifiedSeekResult({required this.position, required this.matched});

  final Duration position;
  final bool matched;
}

Future<VerifiedSeekResult> verifyPlayerSeek({
  required Duration target,
  required Future<void> Function(Duration position) seek,
  required Future<Duration?> Function() readActualPosition,
  List<Duration> verificationDelays = const [
    Duration.zero,
    Duration(milliseconds: 160),
    Duration(milliseconds: 360),
  ],
  int attempts = 2,
  Duration tolerance = const Duration(seconds: 2),
}) async {
  final normalizedTarget = target < Duration.zero ? Duration.zero : target;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await seek(normalizedTarget);
    for (final delay in verificationDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final actual = await readActualPosition();
      if (actual != null && (actual - normalizedTarget).abs() <= tolerance) {
        return VerifiedSeekResult(position: actual, matched: true);
      }
    }
  }
  final actual = await readActualPosition() ?? Duration.zero;
  await seek(actual);
  return VerifiedSeekResult(position: actual, matched: false);
}

BetterPlayerNotificationConfiguration playbackNotificationConfiguration({
  required bool showNotification,
}) {
  return BetterPlayerNotificationConfiguration(
    showNotification: showNotification,
    title: '正在播放媒体',
    author: '点击返回应用',
    imageUrl: null,
    notificationChannelName: 'flule34_media_private',
    activityName: 'MainActivity',
  );
}

String videoCacheKey(String videoId, VideoSource source) {
  final quality = source.label.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
  return 'flule34_${videoId}_$quality';
}

double videoFullScreenAspectRatio(
  Size screenSize,
  FullscreenOrientationPreference preference,
) {
  final current = screenSize.width / screenSize.height;
  if (preference == FullscreenOrientationPreference.landscape && current < 1) {
    return 1 / current;
  }
  return current;
}

bool initialVideoControlsVisible(bool isFullScreen) => !isFullScreen;

bool videoControlsVisibleAfterFullscreenEvent(
  BetterPlayerEventType event,
  bool current,
) {
  return switch (event) {
    BetterPlayerEventType.openFullscreen => false,
    BetterPlayerEventType.hideFullscreen => true,
    _ => current,
  };
}

bool videoControlsUseFullscreenLayoutAfterEvent(
  BetterPlayerEventType event,
  bool current,
) {
  return switch (event) {
    BetterPlayerEventType.hideFullscreen => false,
    _ => current,
  };
}

bool videoControlsAnimateOpacityAfterEvent(BetterPlayerEventType event) {
  return event != BetterPlayerEventType.openFullscreen;
}

enum PlayerGestureAxis { horizontal, vertical }

PlayerGestureAxis? playerGestureAxisForDelta(
  Offset delta, {
  double threshold = 14,
}) {
  if (delta.distance < threshold) {
    return null;
  }
  return delta.dx.abs() >= delta.dy.abs()
      ? PlayerGestureAxis.horizontal
      : PlayerGestureAxis.vertical;
}

Duration playerGestureTargetPosition({
  required Duration initial,
  required Duration duration,
  required double deltaX,
  required double width,
}) {
  if (width <= 0 || duration <= Duration.zero) {
    return initial;
  }
  final span = duration < const Duration(minutes: 10)
      ? duration
      : const Duration(minutes: 10);
  return Duration(
    milliseconds:
        (initial.inMilliseconds + deltaX / width * span.inMilliseconds)
            .round()
            .clamp(0, duration.inMilliseconds),
  );
}

double playerGestureTargetVolume({
  required double initial,
  required double deltaY,
  required double height,
}) {
  if (height <= 0) {
    return initial.clamp(0.0, 1.0).toDouble();
  }
  return (initial - deltaY / height).clamp(0.0, 1.0).toDouble();
}

double playerProgressStrokeWidth(bool active) => active ? 5 : 3;

class VideoPlayerHandle {
  bool get isFullScreen => _isFullScreen?.call() ?? false;

  Future<void> pause() async {
    await _pause?.call();
  }

  Future<void> preCache(VideoDetails details, {bool aggressive = false}) async {
    _pendingPreCache = (details: details, aggressive: aggressive);
    await _preCache?.call(details, aggressive);
  }

  Future<void> stopPreCache() async {
    _pendingPreCache = null;
    await _stopPreCache?.call();
  }

  Future<void> Function()? _pause;
  bool Function()? _isFullScreen;
  Future<void> Function(VideoDetails details, bool aggressive)? _preCache;
  Future<void> Function()? _stopPreCache;
  ({VideoDetails details, bool aggressive})? _pendingPreCache;

  void _attach(
    Future<void> Function() pause,
    bool Function() isFullScreen,
    Future<void> Function(VideoDetails details, bool aggressive) preCache,
    Future<void> Function() stopPreCache,
  ) {
    _pause = pause;
    _isFullScreen = isFullScreen;
    _preCache = preCache;
    _stopPreCache = stopPreCache;
    final pending = _pendingPreCache;
    if (pending != null) {
      unawaited(preCache(pending.details, pending.aggressive));
    }
  }

  void _detach(Future<void> Function() pause) {
    if (_pause == pause) {
      _pause = null;
      _isFullScreen = null;
      _preCache = null;
      _stopPreCache = null;
    }
  }
}

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.api,
    required this.video,
    required this.sources,
    this.embedded = false,
    this.autoplay,
    this.handle,
    this.looping,
    this.resumePlayback = true,
    this.onFinished,
  });

  final Rule34VideoApi api;
  final VideoItem video;
  final List<VideoSource> sources;
  final bool embedded;
  final bool? autoplay;
  final VideoPlayerHandle? handle;
  final bool? looping;
  final bool resumePlayback;
  final VoidCallback? onFinished;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver {
  static const _mediaHeaders = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': 'Flule34 Android/1.4.4',
  };

  BetterPlayerController? _controller;
  ValueNotifier<VideoPlayerValue>? _videoController;
  late final PlaybackRepository _playback;
  late final ScreenWakeLockService _wakeLock;
  late final AppLogService _logs;
  late final ScrollToTopController _scrollToTopController;
  late List<VideoSource> _sources;
  late VideoSource _selectedSource;
  final Set<String> _failedUrls = {};
  var _initializing = true;
  var _refreshingSource = false;
  var _seeking = false;
  var _operation = 0;
  var _lastSavedSecond = -1;
  var _lastKnownPlaying = false;
  var _historyCacheInvalidated = false;
  var _wakeLockEnabled = false;
  var _playbackSpeed = 1.0;
  var _hasPreparedSource = false;
  var _startupLogged = false;
  var _playbackStarted = false;
  var _bufferingCount = 0;
  var _bufferingTotal = Duration.zero;
  DateTime? _bufferingStartedAt;
  late Stopwatch _startupStopwatch;
  String? _error;
  var _finishedNotified = false;
  var _switchingVideo = false;
  final Completer<BetterPlayerController> _controllerReady = Completer();
  BetterPlayerDataSource? _preCacheDataSource;
  String? _preCacheKey;
  var _preCacheOperation = 0;

  bool get _effectiveLooping =>
      widget.looping ??
      ref.read(appSettingsRepositoryProvider).settings.loopPlayback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playback = ref.read(playbackRepositoryProvider);
    _wakeLock = ref.read(screenWakeLockServiceProvider);
    _logs = ref.read(appLogServiceProvider);
    _scrollToTopController = ref.read(scrollToTopControllerProvider);
    _startupStopwatch = Stopwatch()..start();
    _sources = List.of(widget.sources);
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    _selectedSource = selectVideoSource(_sources, settings.playbackQuality);
    widget.handle?._attach(
      _pauseForNavigation,
      () => _controller?.isFullScreen ?? false,
      _preCacheDetails,
      _stopPreCache,
    );
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant VideoPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?._detach(_pauseForNavigation);
      widget.handle?._attach(
        _pauseForNavigation,
        () => _controller?.isFullScreen ?? false,
        _preCacheDetails,
        _stopPreCache,
      );
    }
    if (oldWidget.looping != widget.looping && _controller != null) {
      unawaited(_controller!.setLooping(_effectiveLooping));
    }
    if (oldWidget.video.id != widget.video.id) {
      final previousValue = _videoController?.value;
      if (previousValue?.initialized == true) {
        unawaited(_persistForVideo(oldWidget.video, previousValue!));
      }
      _operation += 1;
      _sources = List.of(widget.sources);
      _selectedSource = selectVideoSource(
        _sources,
        ref.read(appSettingsRepositoryProvider).settings.playbackQuality,
      );
      _failedUrls.clear();
      _initializing = true;
      _refreshingSource = false;
      _switchingVideo = true;
      _error = null;
      _finishedNotified = false;
      _lastSavedSecond = -1;
      _historyCacheInvalidated = false;
      _startupLogged = false;
      _playbackStarted = false;
      _bufferingCount = 0;
      _bufferingTotal = Duration.zero;
      _bufferingStartedAt = null;
      _startupStopwatch = Stopwatch()..start();
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    final networkFuture = _currentNetworkClass();
    final resumeFuture = _resumePosition();
    final network = await networkFuture;
    final resumePosition = await resumeFuture;
    if (!mounted) {
      return;
    }
    final quality = _qualityForNetwork(settings, network);
    _selectedSource = selectVideoSource(_sources, quality);
    unawaited(
      _logs.info(
        'playback',
        '播放器开始准备：video=${widget.video.id}，网络=${network.name}，'
            '清晰度=${_selectedSource.label}，恢复位置=${resumePosition.inSeconds}s。',
      ),
    );
    await _setSource(
      _selectedSource,
      resumeAt: resumePosition,
      shouldPlay: widget.autoplay ?? settings.autoplay,
    );
  }

  Future<NetworkClass> _currentNetworkClass() async {
    try {
      return await ref.read(networkStatusServiceProvider).current();
    } catch (error, stackTrace) {
      unawaited(
        _logs.warning(
          'playback',
          '读取当前网络类型失败，按其他网络处理。',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return NetworkClass.other;
    }
  }

  VideoQualityPreference _qualityForNetwork(
    AppSettings settings,
    NetworkClass network,
  ) {
    if (settings.networkPlaybackPolicy == NetworkPlaybackPolicy.dataSaver) {
      return network == NetworkClass.mobile
          ? VideoQualityPreference.p360
          : VideoQualityPreference.p720;
    }
    if (settings.networkPlaybackPolicy == NetworkPlaybackPolicy.automatic &&
        network == NetworkClass.mobile) {
      final target = settings.playbackQuality.targetHeight;
      return target == null || target > 480
          ? VideoQualityPreference.p480
          : settings.playbackQuality;
    }
    return settings.playbackQuality;
  }

  Future<Duration> _resumePosition() async {
    if (!widget.resumePlayback) {
      return Duration.zero;
    }
    try {
      return await _playback.loadPosition(widget.video.id) ?? Duration.zero;
    } catch (error, stackTrace) {
      unawaited(
        _logs.warning(
          'playback',
          '读取历史播放位置失败，从头播放：video=${widget.video.id}。',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return Duration.zero;
    }
  }

  @override
  void dispose() {
    _scrollToTopController.setSuppressed(false);
    widget.handle?._detach(_pauseForNavigation);
    WidgetsBinding.instance.removeObserver(this);
    _operation += 1;
    _preCacheOperation += 1;
    final preCacheDataSource = _preCacheDataSource;
    final controller = _controller;
    if (preCacheDataSource != null && controller != null) {
      unawaited(controller.stopPreCache(preCacheDataSource));
    }
    final value = _videoController?.value;
    _unbindVideoController();
    if (value != null) {
      unawaited(_persist(value));
    }
    final activeBuffering = _bufferingStartedAt;
    if (activeBuffering != null) {
      _bufferingTotal += DateTime.now().difference(activeBuffering);
    }
    _startupStopwatch.stop();
    unawaited(
      _logs.info(
        'playback',
        '播放器结束：video=${widget.video.id}，缓冲次数=$_bufferingCount，'
            '缓冲总时长=${_bufferingTotal.inMilliseconds}ms。',
      ),
    );
    _controller?.dispose(forceDispose: true);
    unawaited(_updateWakeLock(false));
    super.dispose();
  }

  Future<void> _pauseForNavigation() async {
    final controller = _controller;
    final value = _videoController?.value;
    if (controller == null) {
      return;
    }
    try {
      await controller.pause();
    } on Object {
      // 路由切换不能因为播放器尚在初始化而被阻断。
    }
    if (value?.initialized == true) {
      await _persist(value!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      return;
    }
    final backgroundPlayback = ref
        .read(appSettingsRepositoryProvider)
        .settings
        .backgroundPlayback;
    if (!backgroundPlayback &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      final controller = _controller;
      final value = _videoController?.value;
      if (controller != null && value?.initialized == true) {
        unawaited(controller.pause());
        unawaited(_persist(value!));
      }
    }
  }

  BetterPlayerController _createController() {
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    final screenSize = MediaQuery.sizeOf(context);
    final orientations =
        settings.fullscreenOrientation ==
            FullscreenOrientationPreference.landscape
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const <DeviceOrientation>[];
    return BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: _effectiveLooping,
        aspectRatio: 16 / 9,
        fullScreenAspectRatio: videoFullScreenAspectRatio(
          screenSize,
          settings.fullscreenOrientation,
        ),
        fit: BoxFit.contain,
        expandToFill: true,
        handleLifecycle: false,
        autoDispose: false,
        useRootNavigator: true,
        allowedScreenSleep: !settings.keepScreenAwake,
        deviceOrientationsOnFullScreen: orientations,
        deviceOrientationsAfterFullScreen: const [],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          playerTheme: BetterPlayerTheme.custom,
          controlsHideTime: const Duration(seconds: 3),
          customControlsBuilder: (controller, onVisibilityChanged, _) {
            return _FluleVideoControls(
              controller: controller,
              title: widget.video.title,
              sources: _sources,
              selectedSource: _selectedSource,
              onSourceChanged: _changeSource,
              onSeek: _seekVerified,
              onVisibilityChanged: onVisibilityChanged,
              mediaVolume: ref.read(mediaVolumeServiceProvider),
            );
          },
        ),
        errorBuilder: (context, message) => _PlayerError(
          message: redactSensitiveText(message),
          onRetry: _manualRetry,
        ),
      ),
    )..addEventsListener(_onBetterPlayerEvent);
  }

  Future<bool> _setSource(
    VideoSource source, {
    Duration? resumeAt,
    bool? shouldPlay,
    bool allowRefresh = true,
  }) async {
    final operation = ++_operation;
    final previousValue = _videoController?.value;
    final targetPosition = resumeAt ?? previousValue?.position ?? Duration.zero;
    final continuePlaying =
        shouldPlay ?? previousValue?.isPlaying ?? _lastKnownPlaying;
    final targetSpeed = previousValue?.speed ?? _playbackSpeed;
    if (mounted) {
      setState(() {
        _selectedSource = source;
        _initializing = true;
        _error = null;
      });
    }

    final headers = <String, String>{..._mediaHeaders};
    final cookie = await widget.api.sessionCookieHeader();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    final controller = _controller ??= _createController();
    if (!_controllerReady.isCompleted) {
      _controllerReady.complete(controller);
    }
    final dataSource = BetterPlayerDataSource.network(
      source.url,
      headers: headers,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        maxCacheSize: 1024 * 1024 * 1024,
        maxCacheFileSize: 512 * 1024 * 1024,
        key: videoCacheKey(widget.video.id, source),
      ),
      bufferingConfiguration: videoBufferingConfiguration,
      notificationConfiguration: playbackNotificationConfiguration(
        showNotification: settings.backgroundPlayback,
      ),
    );
    try {
      _finishedNotified = false;
      await controller.setupDataSource(dataSource);
      if (!mounted || operation != _operation) {
        return false;
      }
      _bindVideoController();
      _hasPreparedSource = true;
      final video = _videoController;
      final duration = video?.value.duration;
      if (video == null || duration == null) {
        throw StateError('播放器初始化后未提供视频时长。');
      }
      final safeTarget = targetPosition < duration
          ? targetPosition
          : Duration(
              milliseconds: (duration.inMilliseconds - 1000).clamp(
                0,
                duration.inMilliseconds,
              ),
            );
      await controller.setLooping(_effectiveLooping);
      await controller.setSpeed(targetSpeed);
      var actualStart = Duration.zero;
      if (safeTarget > Duration.zero) {
        final result = await _seekVerified(safeTarget);
        actualStart = result.position;
        if (!result.matched) {
          unawaited(
            _logs.warning(
              'playback',
              '恢复播放位置未生效，已回退到播放器真实位置：video=${widget.video.id}，'
                  '目标=${safeTarget.inSeconds}s，实际=${actualStart.inSeconds}s。',
            ),
          );
        }
      }
      if (continuePlaying) {
        await controller.play();
      }
      _lastSavedSecond = actualStart.inSeconds;
      _lastKnownPlaying = continuePlaying;
      _playbackSpeed = targetSpeed;
      setState(() {
        _selectedSource = source;
        _initializing = false;
        _switchingVideo = false;
        _error = null;
      });
      if (!mounted) {
        return false;
      }
      return true;
    } catch (error) {
      if (!mounted || operation != _operation) {
        return false;
      }
      if (allowRefresh) {
        return _refreshSources(
          failedSource: source,
          resumeAt: targetPosition,
          shouldPlay: continuePlaying,
        );
      }
      setState(() {
        _initializing = false;
        _switchingVideo = false;
        _error = '无法播放此视频源：${redactSensitiveText(error)}';
      });
      return false;
    }
  }

  Future<void> _preCacheDetails(VideoDetails details, bool aggressive) async {
    final operation = ++_preCacheOperation;
    late final BetterPlayerController controller;
    try {
      controller = await _controllerReady.future.timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      if (mounted && operation == _preCacheOperation) {
        unawaited(_logs.warning('playback', '下一视频预缓存已取消：播放器控制器未及时就绪。'));
      }
      return;
    }
    if (!mounted ||
        operation != _preCacheOperation ||
        details.sources.isEmpty) {
      return;
    }
    final network = await _currentNetworkClass();
    if (!mounted ||
        operation != _preCacheOperation ||
        network == NetworkClass.offline) {
      return;
    }
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    final source = selectVideoSource(
      details.sources,
      _qualityForNetwork(settings, network),
    );
    final key = videoCacheKey(details.video.id, source);
    if (_preCacheKey == key) {
      return;
    }
    final previous = _preCacheDataSource;
    if (previous != null) {
      try {
        await controller.stopPreCache(previous);
      } on Object {
        // 停止过时预缓存失败不应影响新的预缓存任务。
      }
    }
    if (!mounted || operation != _preCacheOperation) {
      return;
    }
    final headers = <String, String>{..._mediaHeaders};
    final cookie = await widget.api.sessionCookieHeader();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    if (!mounted || operation != _preCacheOperation) {
      return;
    }
    final preCacheSize = aggressive
        ? playlistVideoPreCacheSizeForNetwork(network)
        : videoPreCacheSizeForNetwork(network);
    final dataSource = BetterPlayerDataSource.network(
      source.url,
      headers: headers,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: preCacheSize,
        maxCacheSize: 1024 * 1024 * 1024,
        maxCacheFileSize: 512 * 1024 * 1024,
        key: key,
      ),
    );
    _preCacheDataSource = dataSource;
    _preCacheKey = key;
    try {
      await controller.preCache(dataSource);
      if (mounted && operation == _preCacheOperation) {
        unawaited(
          _logs.info(
            'playback',
            '${aggressive ? '播放列表' : ''}下一视频预缓存完成：video=${details.video.id}，'
                '清晰度=${source.label}，大小=${preCacheSize ~/ (1024 * 1024)}MB。',
          ),
        );
      }
    } catch (error, stackTrace) {
      if (mounted && operation == _preCacheOperation) {
        unawaited(
          _logs.warning(
            'playback',
            '下一视频预缓存失败：video=${details.video.id}。',
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
  }

  Future<void> _stopPreCache() async {
    _preCacheOperation += 1;
    final dataSource = _preCacheDataSource;
    _preCacheDataSource = null;
    _preCacheKey = null;
    final controller = _controller;
    if (dataSource == null || controller == null) {
      return;
    }
    try {
      await controller.stopPreCache(dataSource);
    } on Object {
      // 预缓存只是体验优化，取消失败不能阻断播放。
    }
  }

  void _bindVideoController() {
    final next = _controller?.videoPlayerController;
    if (identical(next, _videoController)) {
      return;
    }
    _unbindVideoController();
    _videoController = next;
    _videoController?.addListener(_onVideoValueChanged);
  }

  void _unbindVideoController() {
    _videoController?.removeListener(_onVideoValueChanged);
    _videoController = null;
  }

  void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) {
      return;
    }
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.setupDataSource:
        _bindVideoController();
      case BetterPlayerEventType.initialized:
        _bindVideoController();
        if (!_startupLogged) {
          _startupLogged = true;
          _startupStopwatch.stop();
          unawaited(
            _logs.info(
              'playback',
              '播放器准备完成：video=${widget.video.id}，清晰度=${_selectedSource.label}，'
                  '耗时=${_startupStopwatch.elapsedMilliseconds}ms。',
            ),
          );
        }
      case BetterPlayerEventType.play:
        if (!_playbackStarted) {
          _playbackStarted = true;
          unawaited(
            _logs.info(
              'playback',
              '播放器进入播放状态：video=${widget.video.id}，'
                  '位置=${_videoController?.value.position.inSeconds ?? 0}s。',
            ),
          );
        }
      case BetterPlayerEventType.bufferingStart:
        _onBufferingStart();
      case BetterPlayerEventType.bufferingEnd:
        _onBufferingEnd();
      case BetterPlayerEventType.exception:
        final value = _videoController?.value;
        if (!_refreshingSource && value != null) {
          unawaited(
            _refreshSources(
              failedSource: _selectedSource,
              resumeAt: value.position,
              shouldPlay: _lastKnownPlaying,
            ),
          );
        }
      case BetterPlayerEventType.finished:
        if (!_finishedNotified) {
          _finishedNotified = true;
          widget.onFinished?.call();
        }
      case BetterPlayerEventType.openFullscreen:
        _scrollToTopController.setSuppressed(true);
      case BetterPlayerEventType.hideFullscreen:
        _scrollToTopController.setSuppressed(false);
      default:
        break;
    }
  }

  void _onBufferingStart() {
    if (_bufferingStartedAt != null) {
      return;
    }
    _bufferingStartedAt = DateTime.now();
    _bufferingCount += 1;
    final position = _videoController?.value.position ?? Duration.zero;
    unawaited(
      _logs.debug(
        'playback',
        '${_playbackStarted ? '播放中' : '首播'}开始缓冲：video=${widget.video.id}，'
            '位置=${position.inSeconds}s，次数=$_bufferingCount。',
      ),
    );
  }

  void _onBufferingEnd() {
    final startedAt = _bufferingStartedAt;
    if (startedAt == null) {
      return;
    }
    _bufferingStartedAt = null;
    final elapsed = DateTime.now().difference(startedAt);
    _bufferingTotal += elapsed;
    unawaited(
      _logs.info(
        'playback',
        '${_playbackStarted ? '播放中' : '首播'}缓冲结束：video=${widget.video.id}，'
            '本次=${elapsed.inMilliseconds}ms，累计=${_bufferingTotal.inMilliseconds}ms。',
      ),
    );
  }

  void _onVideoValueChanged() {
    final value = _videoController?.value;
    if (value == null || !mounted) {
      return;
    }
    _lastKnownPlaying = value.isPlaying;
    if (value.isPlaying && !_historyCacheInvalidated) {
      _historyCacheInvalidated = true;
      widget.api.invalidateHistoryCache();
    }
    final keepAwake =
        ref.read(appSettingsRepositoryProvider).settings.keepScreenAwake &&
        value.isPlaying;
    if (keepAwake != _wakeLockEnabled) {
      unawaited(_updateWakeLock(keepAwake));
    }
    final second = value.position.inSeconds;
    if (!_switchingVideo &&
        !_seeking &&
        value.initialized &&
        second >= 0 &&
        (second - _lastSavedSecond).abs() >= 5) {
      _lastSavedSecond = second;
      unawaited(_persist(value));
    }
    setState(() {});
  }

  Future<void> _updateWakeLock(bool enabled) async {
    _wakeLockEnabled = enabled;
    try {
      await _wakeLock.setEnabled(enabled);
    } catch (_) {
      if (enabled) {
        _wakeLockEnabled = false;
      }
    }
  }

  Future<bool> _refreshSources({
    required VideoSource failedSource,
    required Duration resumeAt,
    required bool shouldPlay,
    bool force = false,
  }) async {
    if (_refreshingSource ||
        (!force && _failedUrls.contains(failedSource.url))) {
      return false;
    }
    _failedUrls.add(failedSource.url);
    _refreshingSource = true;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final details = await widget.api.refreshVideoDetails(widget.video);
      if (!mounted) {
        return false;
      }
      if (details.sources.isEmpty) {
        setState(() {
          _initializing = false;
          _switchingVideo = false;
          _error = '刷新后仍未找到可播放的视频源。';
        });
        return false;
      }
      _sources = List.of(details.sources);
      final refreshedSource = _sources.cast<VideoSource?>().firstWhere(
        (source) => source?.label == failedSource.label,
        orElse: () => null,
      );
      final fallback = selectVideoSource(
        _sources,
        ref.read(appSettingsRepositoryProvider).settings.playbackQuality,
      );
      final nextSource = refreshedSource ?? fallback;
      if (!force && _failedUrls.contains(nextSource.url)) {
        setState(() {
          _initializing = false;
          _switchingVideo = false;
          _error = '视频地址刷新后仍不可用，请稍后重试。';
        });
        return false;
      }
      return _setSource(
        nextSource,
        resumeAt: resumeAt,
        shouldPlay: shouldPlay,
        allowRefresh: false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _switchingVideo = false;
          _error = '刷新视频地址失败：${redactSensitiveText(error)}';
        });
      }
      return false;
    } finally {
      _refreshingSource = false;
    }
  }

  Future<void> _manualRetry() async {
    _failedUrls.clear();
    final value = _videoController?.value;
    await _refreshSources(
      failedSource: _selectedSource,
      resumeAt: value?.position ?? Duration.zero,
      shouldPlay: _lastKnownPlaying,
      force: true,
    );
  }

  void _changeSource(VideoSource source) {
    if (!_initializing && source != _selectedSource) {
      unawaited(_setSource(source));
    }
  }

  Future<VerifiedSeekResult> _seekVerified(Duration target) async {
    final controller = _controller;
    final video = controller?.videoPlayerController;
    if (controller == null || video == null) {
      return const VerifiedSeekResult(position: Duration.zero, matched: false);
    }
    _seeking = true;
    try {
      final result = await verifyPlayerSeek(
        target: target,
        seek: controller.seekTo,
        readActualPosition: () => video.position,
      );
      return result;
    } finally {
      _seeking = false;
    }
  }

  Future<void> _persist(VideoPlayerValue value) {
    return _persistForVideo(widget.video, value);
  }

  Future<void> _persistForVideo(VideoItem video, VideoPlayerValue value) {
    final duration = value.duration;
    if (!value.initialized || duration == null) {
      return Future.value();
    }
    return _playback.savePosition(
      video: video,
      position: value.position,
      duration: duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _buildPlayer();
    if (widget.embedded) {
      return player;
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.video.title)),
      body: Center(child: player),
    );
  }

  Widget _buildPlayer() {
    return AspectRatio(
      key: const ValueKey('inline-video-player'),
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null)
              BetterPlayer(controller: _controller!)
            else
              const SizedBox.shrink(),
            if (!_hasPreparedSource && widget.video.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: widget.video.thumbnailUrl!,
                httpHeaders: _mediaHeaders,
                fit: BoxFit.cover,
                errorWidget: (context, _, _) => const SizedBox.shrink(),
              ),
            if (_initializing && !_switchingVideo)
              ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_refreshingSource) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '正在刷新视频地址…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_error != null)
              _PlayerError(message: _error!, onRetry: _manualRetry),
          ],
        ),
      ),
    );
  }
}

class _FluleVideoControls extends StatefulWidget {
  const _FluleVideoControls({
    required this.controller,
    required this.title,
    required this.sources,
    required this.selectedSource,
    required this.onSourceChanged,
    required this.onSeek,
    required this.onVisibilityChanged,
    required this.mediaVolume,
  });

  final BetterPlayerController controller;
  final String title;
  final List<VideoSource> sources;
  final VideoSource selectedSource;
  final ValueChanged<VideoSource> onSourceChanged;
  final Future<VerifiedSeekResult> Function(Duration target) onSeek;
  final ValueChanged<bool> onVisibilityChanged;
  final MediaVolumeService mediaVolume;

  @override
  State<_FluleVideoControls> createState() => _FluleVideoControlsState();
}

class _FluleVideoControlsState extends State<_FluleVideoControls> {
  static const _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
  ValueNotifier<VideoPlayerValue>? _videoController;
  Timer? _hideTimer;
  Timer? _lockTimer;
  Timer? _gestureFeedbackTimer;
  late bool _visible;
  late bool _useFullscreenLayout;
  var _animateOpacity = true;
  Duration? _dragPosition;
  List<({Duration start, Duration end})> _stableBuffered = const [];
  var _locked = false;
  var _lockVisible = false;
  Offset? _panStart;
  Duration? _panPosition;
  double _panVolume = 1;
  PlayerGestureAxis? _gestureAxis;
  Duration? _gestureTargetPosition;
  String? _gestureFeedback;

  @override
  void initState() {
    super.initState();
    _visible = initialVideoControlsVisible(widget.controller.isFullScreen);
    _useFullscreenLayout = widget.controller.isFullScreen;
    widget.controller.addEventsListener(_onPlayerEvent);
    _bindVideoController();
    unawaited(
      widget.mediaVolume.current().then((volume) {
        if (volume != null) {
          _panVolume = volume;
        }
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onVisibilityChanged(_visible);
      if (_visible) {
        _scheduleHide();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FluleVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeEventsListener(_onPlayerEvent);
      widget.controller.addEventsListener(_onPlayerEvent);
      _stableBuffered = const [];
      _useFullscreenLayout = widget.controller.isFullScreen;
      _bindVideoController();
    } else if (oldWidget.selectedSource.url != widget.selectedSource.url) {
      _stableBuffered = const [];
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _lockTimer?.cancel();
    _gestureFeedbackTimer?.cancel();
    widget.controller.removeEventsListener(_onPlayerEvent);
    _videoController?.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) {
      return;
    }
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
      case BetterPlayerEventType.changedResolution:
        _bindVideoController();
        setState(() {});
      case BetterPlayerEventType.openFullscreen:
        _hideTimer?.cancel();
        _bindVideoController();
        setState(() {
          _visible = videoControlsVisibleAfterFullscreenEvent(
            event.betterPlayerEventType,
            _visible,
          );
          _useFullscreenLayout = videoControlsUseFullscreenLayoutAfterEvent(
            event.betterPlayerEventType,
            _useFullscreenLayout,
          );
          _animateOpacity = videoControlsAnimateOpacityAfterEvent(
            event.betterPlayerEventType,
          );
        });
        widget.onVisibilityChanged(false);
      case BetterPlayerEventType.hideFullscreen:
        _bindVideoController();
        setState(() {
          _locked = false;
          _lockVisible = false;
          _visible = videoControlsVisibleAfterFullscreenEvent(
            event.betterPlayerEventType,
            _visible,
          );
          _useFullscreenLayout = videoControlsUseFullscreenLayoutAfterEvent(
            event.betterPlayerEventType,
            _useFullscreenLayout,
          );
          _animateOpacity = videoControlsAnimateOpacityAfterEvent(
            event.betterPlayerEventType,
          );
        });
        _lockTimer?.cancel();
        widget.onVisibilityChanged(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleHide();
          }
        });
      case BetterPlayerEventType.setupDataSource:
        _stableBuffered = const [];
        _bindVideoController();
        setState(() {});
      default:
        break;
    }
  }

  void _bindVideoController() {
    final next = widget.controller.videoPlayerController;
    if (identical(next, _videoController)) {
      return;
    }
    _videoController?.removeListener(_onValueChanged);
    _videoController = next;
    _videoController?.addListener(_onValueChanged);
  }

  void _onValueChanged() {
    if (!mounted) {
      return;
    }
    final buffered = _videoController?.value.buffered ?? const [];
    if (buffered.isNotEmpty) {
      _stableBuffered = mergeBufferedRanges(
        _stableBuffered,
        buffered
            .map((range) => (start: range.start, end: range.end))
            .toList(growable: false),
      );
    }
    setState(() {});
  }

  void _toggleControls() {
    _hideTimer?.cancel();
    setState(() => _visible = !_visible);
    widget.onVisibilityChanged(_visible);
    if (_visible) {
      _scheduleHide();
    }
  }

  void _showControls() {
    if (!_visible) {
      setState(() => _visible = true);
      widget.onVisibilityChanged(true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_locked || !_visible) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _visible && !_locked) {
        setState(() => _visible = false);
        widget.onVisibilityChanged(false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_videoController?.value.isPlaying == true) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    _showControls();
  }

  void _showGestureFeedback(String value) {
    _gestureFeedbackTimer?.cancel();
    setState(() => _gestureFeedback = value);
    _gestureFeedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _gestureFeedback = null);
      }
    });
  }

  Future<void> _togglePlaybackFromGesture() async {
    if (_videoController?.value.isPlaying == true) {
      await widget.controller.pause();
      _hideTimer?.cancel();
    } else {
      await widget.controller.play();
    }
    _hideTimer?.cancel();
    if (_visible) {
      setState(() => _visible = false);
      widget.onVisibilityChanged(false);
    }
    _showGestureFeedback(
      _videoController?.value.isPlaying == true ? '播放' : '暂停',
    );
  }

  void _showLockButton() {
    if (!_locked) {
      return;
    }
    _lockTimer?.cancel();
    setState(() => _lockVisible = true);
    _lockTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _locked) {
        setState(() => _lockVisible = false);
      }
    });
  }

  void _toggleLock() {
    _hideTimer?.cancel();
    _lockTimer?.cancel();
    if (_locked) {
      setState(() {
        _locked = false;
        _lockVisible = false;
      });
      _showControls();
      return;
    }
    setState(() {
      _locked = true;
      _lockVisible = true;
      _visible = false;
    });
    widget.onVisibilityChanged(false);
    _showLockButton();
  }

  void _onPanStart(DragStartDetails details) {
    if (_locked) {
      return;
    }
    final value = _videoController?.value;
    if (value?.duration == null) {
      return;
    }
    _hideTimer?.cancel();
    setState(() {
      _panStart = details.localPosition;
      _panPosition = value!.position;
      _gestureTargetPosition = null;
      _gestureAxis = null;
    });
    unawaited(
      widget.mediaVolume.current().then((volume) {
        if (mounted && _panStart != null && volume != null) {
          _panVolume = volume;
        }
      }),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _panStart;
    final value = _videoController?.value;
    final duration = value?.duration;
    if (start == null || value == null || duration == null || _locked) {
      return;
    }
    final delta = details.localPosition - start;
    final axis = _gestureAxis ?? playerGestureAxisForDelta(delta);
    if (axis == null) {
      return;
    }
    _gestureAxis = axis;
    final size = context.size ?? MediaQuery.sizeOf(context);
    if (axis == PlayerGestureAxis.horizontal) {
      final target = playerGestureTargetPosition(
        initial: _panPosition ?? value.position,
        duration: duration,
        deltaX: delta.dx,
        width: size.width,
      );
      setState(() {
        _gestureTargetPosition = target;
        _dragPosition = target;
        _gestureFeedback = '${_time(target)} / ${_time(duration)}';
        _visible = true;
      });
      widget.onVisibilityChanged(true);
      return;
    }
    final target = playerGestureTargetVolume(
      initial: _panVolume,
      deltaY: delta.dy,
      height: size.height,
    );
    setState(() => _gestureFeedback = '音量 ${(target * 100).round()}%');
    unawaited(widget.mediaVolume.setNormalized(target));
  }

  void _onPanEnd(DragEndDetails details) {
    final target = _gestureTargetPosition;
    final axis = _gestureAxis;
    setState(() {
      _panStart = null;
      _panPosition = null;
      _gestureTargetPosition = null;
      _gestureAxis = null;
      if (axis != PlayerGestureAxis.horizontal) {
        _dragPosition = null;
      }
    });
    if (axis == PlayerGestureAxis.horizontal && target != null) {
      unawaited(_commitPanSeek(target));
    }
    if (_gestureFeedback != null) {
      _showGestureFeedback(_gestureFeedback!);
    }
    if (!_locked) {
      _scheduleHide();
    }
  }

  Future<void> _commitPanSeek(Duration target) async {
    await widget.onSeek(target);
    if (mounted && _dragPosition == target) {
      setState(() => _dragPosition = null);
    }
  }

  Future<void> _seekFromProgressBar(Duration target) async {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _dragPosition = target;
        _visible = true;
      });
      widget.onVisibilityChanged(true);
    }
    try {
      await widget.onSeek(target);
    } finally {
      if (mounted && _dragPosition == target) {
        setState(() => _dragPosition = null);
        _scheduleHide();
      }
    }
  }

  void _onPanCancel() {
    if (!mounted) {
      return;
    }
    setState(() {
      _panStart = null;
      _panPosition = null;
      _gestureTargetPosition = null;
      _gestureAxis = null;
      _dragPosition = null;
      _gestureFeedback = null;
    });
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final value = _videoController?.value;
    return GestureDetector(
      key: const ValueKey('video-controls-pan-area'),
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: _locked ? null : _onPanStart,
      onPanUpdate: _locked ? null : _onPanUpdate,
      onPanEnd: _locked ? null : _onPanEnd,
      onPanCancel: _locked ? null : _onPanCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const ValueKey('video-controls-tap-area'),
            behavior: HitTestBehavior.opaque,
            onTap: _locked ? _showLockButton : _toggleControls,
            onDoubleTap: _locked
                ? _showLockButton
                : () => unawaited(_togglePlaybackFromGesture()),
          ),
          IgnorePointer(
            ignoring: !_visible || _locked,
            child: AnimatedOpacity(
              key: const ValueKey('video-controls-opacity'),
              opacity: _visible ? 1 : 0,
              duration: _animateOpacity
                  ? const Duration(milliseconds: 160)
                  : Duration.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_useFullscreenLayout)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _buildTopRow(context),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: value == null || !value.initialized
                        ? const SizedBox.shrink()
                        : _buildControlRow(context, value),
                  ),
                ],
              ),
            ),
          ),
          if (_useFullscreenLayout && (_visible || _lockVisible))
            Align(
              alignment: Alignment.centerLeft,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: _locked ? '解锁控件' : '锁定控件',
                  onPressed: _toggleLock,
                  icon: Icon(_locked ? Icons.lock : Icons.lock_open),
                ),
              ),
            ),
          if (_gestureFeedback != null)
            IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      _gestureFeedback!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return SafeArea(
      bottom: false,
      minimum: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              tooltip: '退出全屏',
              onPressed: () => unawaited(_exitFullScreen()),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(BuildContext context, VideoPlayerValue value) {
    final duration = value.duration ?? Duration.zero;
    final position = _dragPosition ?? value.position;
    final foreground = Colors.white;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: foreground,
      fontSize: 10,
      height: 1,
      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
    );
    final isFullScreen = _useFullscreenLayout;
    final horizontalInset = isFullScreen ? 18.0 : 6.0;
    return SafeArea(
      top: false,
      bottom: isFullScreen,
      minimum: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 1),
            child: Text(
              key: const ValueKey('player-time-label'),
              '${_time(position)} / ${_time(duration)}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.left,
              style: textStyle,
            ),
          ),
          SizedBox(
            key: const ValueKey('player-control-row'),
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CompactIconButton(
                  tooltip: value.isPlaying ? '暂停' : '播放',
                  onPressed: _togglePlayback,
                  icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _VideoProgressBar(
                    value: value,
                    dragPosition: _dragPosition,
                    buffered: _stableBuffered,
                    onSeek: (position) =>
                        unawaited(_seekFromProgressBar(position)),
                  ),
                ),
                const SizedBox(width: 2),
                _CompactPopup<VideoSource>(
                  tooltip: '清晰度',
                  label: widget.selectedSource.label,
                  values: widget.sources,
                  selected: widget.selectedSource,
                  labelFor: (source) => source.label,
                  onSelected: widget.onSourceChanged,
                  onInteraction: _showControls,
                ),
                _CompactPopup<double>(
                  tooltip: '播放速度',
                  label: '${value.speed}x',
                  values: _speeds,
                  selected: value.speed,
                  labelFor: (speed) => '${speed}x',
                  onSelected: (speed) =>
                      unawaited(widget.controller.setSpeed(speed)),
                  onInteraction: _showControls,
                ),
                if (!isFullScreen)
                  _CompactIconButton(
                    tooltip: '全屏',
                    onPressed: _enterFullScreen,
                    icon: Icons.fullscreen,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _enterFullScreen() {
    _hideTimer?.cancel();
    setState(() {
      _visible = false;
      _animateOpacity = false;
    });
    widget.onVisibilityChanged(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.isFullScreen) {
        widget.controller.enterFullScreen();
      }
    });
  }

  Future<void> _exitFullScreen() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final popped = await navigator.maybePop();
    if (!popped && widget.controller.isFullScreen) {
      widget.controller.exitFullScreen();
    }
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 36),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        icon,
        color: Colors.white,
        size: 24,
        shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
      ),
    );
  }
}

class _CompactPopup<T> extends StatelessWidget {
  const _CompactPopup({
    required this.tooltip,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    required this.onInteraction,
  });

  final String tooltip;
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: selected,
      onOpened: onInteraction,
      onCanceled: onInteraction,
      onSelected: (value) {
        onSelected(value);
        onInteraction();
      },
      color: colors.surfaceContainerHigh,
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 150),
      itemBuilder: (context) => values
          .map(
            (value) => PopupMenuItem<T>(
              value: value,
              height: 42,
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: value == selected
                        ? Icon(Icons.check, size: 17, color: colors.onSurface)
                        : null,
                  ),
                  Text(
                    labelFor(value),
                    style: TextStyle(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 42, minHeight: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  const _VideoProgressBar({
    required this.value,
    required this.dragPosition,
    required this.buffered,
    required this.onSeek,
  });

  final VideoPlayerValue value;
  final Duration? dragPosition;
  final List<({Duration start, Duration end})> buffered;
  final ValueChanged<Duration> onSeek;

  Duration _positionFor(double dx, double width) {
    final duration = value.duration ?? Duration.zero;
    if (width <= 0 || duration <= Duration.zero) {
      return Duration.zero;
    }
    return Duration(
      milliseconds: (duration.inMilliseconds * (dx / width).clamp(0.0, 1.0))
          .round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => onSeek(
          _positionFor(details.localPosition.dx, constraints.maxWidth),
        ),
        child: CustomPaint(
          painter: _ProgressPainter(
            duration: value.duration ?? Duration.zero,
            position: dragPosition ?? value.position,
            buffered: buffered,
            playedColor: Theme.of(context).colorScheme.primary,
            active: dragPosition != null,
          ),
          child: const SizedBox(height: 28),
        ),
      ),
    );
  }
}

List<({Duration start, Duration end})> mergeBufferedRanges(
  List<({Duration start, Duration end})> previous,
  List<({Duration start, Duration end})> current,
) {
  final ranges = [...previous, ...current]
    ..removeWhere((range) => range.end <= range.start)
    ..sort((left, right) => left.start.compareTo(right.start));
  if (ranges.isEmpty) {
    return const [];
  }
  final merged = <({Duration start, Duration end})>[];
  for (final range in ranges) {
    if (merged.isEmpty || range.start > merged.last.end) {
      merged.add(range);
      continue;
    }
    final last = merged.removeLast();
    merged.add((
      start: last.start,
      end: range.end > last.end ? range.end : last.end,
    ));
  }
  return List.unmodifiable(merged);
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.duration,
    required this.position,
    required this.buffered,
    required this.playedColor,
    required this.active,
  });

  final Duration duration;
  final Duration position;
  final List<({Duration start, Duration end})> buffered;
  final Color playedColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final strokeWidth = playerProgressStrokeWidth(active);
    final background = Paint()
      ..color = Colors.white30
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final cached = Paint()
      ..color = Colors.white60
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final played = Paint()
      ..color = playedColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      background,
    );
    if (duration > Duration.zero) {
      for (final range in buffered) {
        final start = range.start.inMilliseconds / duration.inMilliseconds;
        final end = range.end.inMilliseconds / duration.inMilliseconds;
        canvas.drawLine(
          Offset(size.width * start.clamp(0.0, 1.0), centerY),
          Offset(size.width * end.clamp(0.0, 1.0), centerY),
          cached,
        );
      }
      final fraction = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0);
      final x = size.width * fraction;
      canvas.drawLine(Offset(0, centerY), Offset(x, centerY), played);
      canvas.drawCircle(
        Offset(x, centerY),
        active ? 6.5 : 5,
        Paint()..color = playedColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.duration != duration ||
        oldDelegate.position != position ||
        oldDelegate.buffered != buffered ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.active != active;
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 40),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

String _time(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
