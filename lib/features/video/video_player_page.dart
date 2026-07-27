import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/logging/app_log_service.dart';
import '../../core/models/video_models.dart';
import '../../core/security/error_redaction.dart';
import '../../core/services/network_status_service.dart';
import '../../core/services/screen_wake_lock_service.dart';
import '../playback/data/playback_repository.dart';
import '../settings/domain/app_settings.dart';
import '../settings/domain/quality_selection.dart';

class VideoPlayerHandle {
  bool get isFullScreen => _isFullScreen?.call() ?? false;

  Future<void> pause() async {
    await _pause?.call();
  }

  Future<void> Function()? _pause;
  bool Function()? _isFullScreen;

  void _attach(Future<void> Function() pause, bool Function() isFullScreen) {
    _pause = pause;
    _isFullScreen = isFullScreen;
  }

  void _detach(Future<void> Function() pause) {
    if (_pause == pause) {
      _pause = null;
      _isFullScreen = null;
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
  });

  final Rule34VideoApi api;
  final VideoItem video;
  final List<VideoSource> sources;
  final bool embedded;
  final bool? autoplay;
  final VideoPlayerHandle? handle;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver {
  static const _mediaHeaders = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': 'Flule34 Android/1.1',
  };

  BetterPlayerController? _controller;
  ValueNotifier<VideoPlayerValue>? _videoController;
  late final PlaybackRepository _playback;
  late final String? _playbackUserId;
  late final ScreenWakeLockService _wakeLock;
  late final AppLogService _logs;
  late List<VideoSource> _sources;
  late VideoSource _selectedSource;
  final Set<String> _failedUrls = {};
  var _initializing = true;
  var _refreshingSource = false;
  var _operation = 0;
  var _lastSavedSecond = -1;
  var _lastKnownPlaying = false;
  var _wakeLockEnabled = false;
  var _resumeMessageShown = false;
  var _playbackSpeed = 1.0;
  var _hasPreparedSource = false;
  var _startupLogged = false;
  var _playbackStarted = false;
  var _bufferingCount = 0;
  var _bufferingTotal = Duration.zero;
  DateTime? _bufferingStartedAt;
  late final Stopwatch _startupStopwatch;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playback = ref.read(playbackRepositoryProvider);
    _playbackUserId = widget.api.sessionStore.currentUserId;
    _wakeLock = ref.read(screenWakeLockServiceProvider);
    _logs = ref.read(appLogServiceProvider);
    _startupStopwatch = Stopwatch()..start();
    _sources = List.of(widget.sources);
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    _selectedSource = selectVideoSource(_sources, settings.playbackQuality);
    widget.handle?._attach(
      _pauseForNavigation,
      () => _controller?.isFullScreen ?? false,
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
      );
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
    final quality = switch (settings.networkPlaybackPolicy) {
      NetworkPlaybackPolicy.automatic
          when network == NetworkClass.mobile &&
              settings.playbackQuality == VideoQualityPreference.automatic =>
        VideoQualityPreference.p480,
      NetworkPlaybackPolicy.dataSaver when network == NetworkClass.mobile =>
        VideoQualityPreference.p360,
      NetworkPlaybackPolicy.dataSaver => VideoQualityPreference.p720,
      _ => settings.playbackQuality,
    };
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

  Future<Duration> _resumePosition() async {
    try {
      return await _playback.loadPositionForAccount(
            videoId: widget.video.id,
            userId: _playbackUserId,
          ) ??
          Duration.zero;
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
    widget.handle?._detach(_pauseForNavigation);
    WidgetsBinding.instance.removeObserver(this);
    _operation += 1;
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
        looping: settings.loopPlayback,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        expandToFill: false,
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
              onVisibilityChanged: onVisibilityChanged,
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
    final dataSource = BetterPlayerDataSource.network(
      source.url,
      headers: headers,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        maxCacheSize: 1024 * 1024 * 1024,
        maxCacheFileSize: 512 * 1024 * 1024,
        key: _cacheKey(source),
      ),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 30000,
        maxBufferMs: 120000,
        bufferForPlaybackMs: 1500,
        bufferForPlaybackAfterRebufferMs: 3000,
      ),
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: settings.backgroundPlayback,
        title: widget.video.title,
        author: 'Flule34',
        imageUrl: widget.video.thumbnailUrl,
        notificationChannelName: 'Flule34 后台播放',
        activityName: 'MainActivity',
      ),
    );
    try {
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
      await controller.setLooping(settings.loopPlayback);
      await controller.setSpeed(targetSpeed);
      if (safeTarget > Duration.zero) {
        await controller.seekTo(safeTarget);
      }
      if (continuePlaying) {
        await controller.play();
      }
      _lastSavedSecond = safeTarget.inSeconds;
      _lastKnownPlaying = continuePlaying;
      _playbackSpeed = targetSpeed;
      setState(() {
        _selectedSource = source;
        _initializing = false;
        _error = null;
      });
      if (!mounted) {
        return false;
      }
      if (!_resumeMessageShown &&
          targetPosition >= const Duration(seconds: 5)) {
        _resumeMessageShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已从 ${_time(safeTarget)} 继续播放。')),
        );
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
        _error = '无法播放此视频源：${redactSensitiveText(error)}';
      });
      return false;
    }
  }

  String _cacheKey(VideoSource source) {
    final quality = source.label.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
    return 'flule34_${widget.video.id}_$quality';
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
    final keepAwake =
        ref.read(appSettingsRepositoryProvider).settings.keepScreenAwake &&
        value.isPlaying;
    if (keepAwake != _wakeLockEnabled) {
      unawaited(_updateWakeLock(keepAwake));
    }
    final second = value.position.inSeconds;
    if (value.initialized &&
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

  Future<void> _persist(VideoPlayerValue value) {
    final duration = value.duration;
    if (!value.initialized || duration == null) {
      return Future.value();
    }
    return _playback.savePositionForAccount(
      userId: _playbackUserId,
      video: widget.video,
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
            if (_initializing)
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
    required this.onVisibilityChanged,
  });

  final BetterPlayerController controller;
  final String title;
  final List<VideoSource> sources;
  final VideoSource selectedSource;
  final ValueChanged<VideoSource> onSourceChanged;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  State<_FluleVideoControls> createState() => _FluleVideoControlsState();
}

class _FluleVideoControlsState extends State<_FluleVideoControls> {
  static const _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
  ValueNotifier<VideoPlayerValue>? _videoController;
  Timer? _hideTimer;
  var _visible = true;
  Duration? _dragPosition;
  List<({Duration start, Duration end})> _stableBuffered = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addEventsListener(_onPlayerEvent);
    _bindVideoController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleHide());
  }

  @override
  void didUpdateWidget(covariant _FluleVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeEventsListener(_onPlayerEvent);
      widget.controller.addEventsListener(_onPlayerEvent);
      _stableBuffered = const [];
      _bindVideoController();
    } else if (oldWidget.selectedSource.url != widget.selectedSource.url) {
      _stableBuffered = const [];
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
      case BetterPlayerEventType.openFullscreen:
      case BetterPlayerEventType.hideFullscreen:
        _bindVideoController();
        setState(() {});
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
    if (_videoController?.value.isPlaying == true && _visible) {
      _scheduleHide();
    }
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
    if (_videoController?.value.isPlaying != true) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController?.value.isPlaying == true) {
        setState(() => _visible = false);
        widget.onVisibilityChanged(false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_videoController?.value.isPlaying == true) {
      await widget.controller.pause();
      _hideTimer?.cancel();
      _showControls();
    } else {
      await widget.controller.play();
      _scheduleHide();
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final value = _videoController?.value;
    final duration = value?.duration;
    if (value == null || duration == null) {
      return;
    }
    final target = Duration(
      milliseconds: (value.position + delta).inMilliseconds.clamp(
        0,
        duration.inMilliseconds,
      ),
    );
    await widget.controller.seekTo(target);
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final value = _videoController?.value;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final width = MediaQuery.sizeOf(context).width;
            unawaited(
              _seekRelative(
                details.localPosition.dx < width / 2
                    ? const Duration(seconds: -10)
                    : const Duration(seconds: 10),
              ),
            );
          },
          child: const SizedBox.expand(),
        ),
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.controller.isFullScreen)
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
      ],
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
              onPressed: widget.controller.exitFullScreen,
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
    final isFullScreen = widget.controller.isFullScreen;
    return SafeArea(
      top: false,
      bottom: isFullScreen,
      minimum: const EdgeInsets.fromLTRB(6, 0, 6, 3),
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
                    onDragStart: (position) {
                      _hideTimer?.cancel();
                      setState(() => _dragPosition = position);
                    },
                    onDragUpdate: (position) {
                      setState(() => _dragPosition = position);
                    },
                    onDragEnd: (position) async {
                      setState(() => _dragPosition = null);
                      await widget.controller.seekTo(position);
                      _showControls();
                    },
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
                ),
                _CompactPopup<double>(
                  tooltip: '播放速度',
                  label: '${value.speed}x',
                  values: _speeds,
                  selected: value.speed,
                  labelFor: (speed) => '${speed}x',
                  onSelected: (speed) =>
                      unawaited(widget.controller.setSpeed(speed)),
                ),
                _CompactIconButton(
                  tooltip: widget.controller.isFullScreen ? '退出全屏' : '全屏',
                  onPressed: widget.controller.isFullScreen
                      ? widget.controller.exitFullScreen
                      : widget.controller.enterFullScreen,
                  icon: widget.controller.isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                ),
                if (isFullScreen) const SizedBox(width: 20),
              ],
            ),
          ),
        ],
      ),
    );
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
  });

  final String tooltip;
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: selected,
      onSelected: onSelected,
      color: const Color(0xff242529),
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
                        ? const Icon(Icons.check, size: 17)
                        : null,
                  ),
                  Text(labelFor(value)),
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
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final VideoPlayerValue value;
  final Duration? dragPosition;
  final List<({Duration start, Duration end})> buffered;
  final ValueChanged<Duration> onDragStart;
  final ValueChanged<Duration> onDragUpdate;
  final ValueChanged<Duration> onDragEnd;

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
        onTapDown: (details) => onDragEnd(
          _positionFor(details.localPosition.dx, constraints.maxWidth),
        ),
        onHorizontalDragStart: (details) => onDragStart(
          _positionFor(details.localPosition.dx, constraints.maxWidth),
        ),
        onHorizontalDragUpdate: (details) => onDragUpdate(
          _positionFor(details.localPosition.dx, constraints.maxWidth),
        ),
        onHorizontalDragEnd: (_) => onDragEnd(dragPosition ?? value.position),
        child: CustomPaint(
          painter: _ProgressPainter(
            duration: value.duration ?? Duration.zero,
            position: dragPosition ?? value.position,
            buffered: buffered,
            playedColor: Theme.of(context).colorScheme.primary,
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
  });

  final Duration duration;
  final Duration position;
  final List<({Duration start, Duration end})> buffered;
  final Color playedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final background = Paint()
      ..color = Colors.white30
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final cached = Paint()
      ..color = Colors.white60
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final played = Paint()
      ..color = playedColor
      ..strokeWidth = 3
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
      canvas.drawCircle(Offset(x, centerY), 5, Paint()..color = playedColor);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.duration != duration ||
        oldDelegate.position != position ||
        oldDelegate.buffered != buffered ||
        oldDelegate.playedColor != playedColor;
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
