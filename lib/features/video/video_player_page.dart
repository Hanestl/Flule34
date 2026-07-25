import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/network_status_service.dart';
import '../../core/services/screen_wake_lock_service.dart';
import '../playback/data/playback_repository.dart';
import '../settings/domain/app_settings.dart';
import '../settings/domain/quality_selection.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.api,
    required this.video,
    required this.sources,
    this.embedded = false,
    this.autoplay,
  });

  final Rule34VideoApi api;
  final VideoItem video;
  final List<VideoSource> sources;
  final bool embedded;
  final bool? autoplay;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late final PlaybackRepository _playback;
  late final ScreenWakeLockService _wakeLock;
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
  var _fullscreen = false;
  var _controlsVisible = true;
  var _playbackSpeed = 1.0;
  Timer? _controlsTimer;
  final ValueNotifier<int> _fullscreenRevision = ValueNotifier<int>(0);
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playback = ref.read(playbackRepositoryProvider);
    _wakeLock = ref.read(screenWakeLockServiceProvider);
    _sources = List.of(widget.sources);
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    _selectedSource = selectVideoSource(_sources, settings.playbackQuality);
    unawaited(_start());
  }

  Future<void> _start() async {
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    NetworkClass network;
    try {
      network = await ref.read(networkStatusServiceProvider).current();
    } catch (_) {
      network = NetworkClass.other;
    }
    final quality = switch (settings.networkPlaybackPolicy) {
      NetworkPlaybackPolicy.automatic when network == NetworkClass.mobile =>
        VideoQualityPreference.p480,
      NetworkPlaybackPolicy.dataSaver when network == NetworkClass.mobile =>
        VideoQualityPreference.p360,
      NetworkPlaybackPolicy.dataSaver => VideoQualityPreference.p720,
      _ => settings.playbackQuality,
    };
    _selectedSource = selectVideoSource(_sources, quality);
    final resumePosition = await _playback.loadPosition(widget.video.id);
    if (!mounted) {
      return;
    }
    await _setSource(
      _selectedSource,
      resumeAt: resumePosition,
      shouldPlay:
          widget.autoplay ??
          ref.read(appSettingsRepositoryProvider).settings.autoplay,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _operation += 1;
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      unawaited(_persist(controller.value));
      unawaited(controller.dispose());
    }
    unawaited(_updateWakeLock(false));
    unawaited(_restoreSystemUi());
    _fullscreenRevision.dispose();
    super.dispose();
  }

  void _bumpFullscreenRevision() {
    if (mounted) {
      _fullscreenRevision.value += 1;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.pause());
        unawaited(_persist(controller.value));
      }
    }
  }

  Future<bool> _setSource(
    VideoSource source, {
    Duration? resumeAt,
    bool? shouldPlay,
    bool allowRefresh = true,
  }) async {
    final operation = ++_operation;
    if (mounted) {
      setState(() {
        _selectedSource = source;
        _initializing = true;
        _error = null;
      });
      _bumpFullscreenRevision();
    }

    final previous = _controller;
    final previousValue = previous?.value;
    final targetPosition = resumeAt ?? previousValue?.position ?? Duration.zero;
    final continuePlaying = shouldPlay ?? previousValue?.isPlaying ?? false;
    final targetVolume = previousValue?.volume ?? 1.0;
    final targetSpeed = previousValue?.playbackSpeed ?? _playbackSpeed;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_onControllerChanged);
      await _persist(previous.value);
      await previous.dispose();
    }

    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/0.1',
    };
    final cookie = await widget.api.sessionCookieHeader();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
      httpHeaders: headers,
    );
    try {
      await controller.initialize();
      if (!mounted || operation != _operation) {
        await controller.dispose();
        return false;
      }
      final settings = ref.read(appSettingsRepositoryProvider).settings;
      await controller.setLooping(settings.loopPlayback);
      await controller.setVolume(targetVolume);
      await controller.setPlaybackSpeed(targetSpeed);
      final safeTarget = targetPosition < controller.value.duration
          ? targetPosition
          : Duration(
              milliseconds: (controller.value.duration.inMilliseconds - 1000)
                  .clamp(0, controller.value.duration.inMilliseconds),
            );
      if (safeTarget > Duration.zero) {
        await controller.seekTo(safeTarget);
      }
      _controller = controller;
      controller.addListener(_onControllerChanged);
      _lastSavedSecond = safeTarget.inSeconds;
      _playbackSpeed = targetSpeed;
      setState(() {
        _selectedSource = source;
        _initializing = false;
        _error = null;
      });
      _bumpFullscreenRevision();
      if (continuePlaying) {
        await controller.play();
        _scheduleControlsHide();
      }
      _lastKnownPlaying = continuePlaying;
      if (!_resumeMessageShown &&
          targetPosition >= const Duration(seconds: 5)) {
        _resumeMessageShown = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已从 ${_time(safeTarget)} 继续播放。')),
          );
        }
      }
      return true;
    } catch (error) {
      await controller.dispose();
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
        _error = '无法播放此视频源：$error';
      });
      _bumpFullscreenRevision();
      return false;
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final value = controller.value;
    if (value.hasError && !_refreshingSource) {
      unawaited(
        _refreshSources(
          failedSource: _selectedSource,
          resumeAt: value.position,
          shouldPlay: _lastKnownPlaying,
        ),
      );
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
    if (value.isInitialized &&
        second >= 0 &&
        (second - _lastSavedSecond).abs() >= 5) {
      _lastSavedSecond = second;
      unawaited(_persist(value));
    }
    setState(() {});
    _bumpFullscreenRevision();
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
      _bumpFullscreenRevision();
    }
    try {
      final details = await widget.api.loadVideoDetails(widget.video);
      if (!mounted) {
        return false;
      }
      if (details.sources.isEmpty) {
        setState(() {
          _initializing = false;
          _error = '刷新后仍未找到可播放的视频源。';
        });
        _bumpFullscreenRevision();
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
        _bumpFullscreenRevision();
        return false;
      }
      return await _setSource(
        nextSource,
        resumeAt: resumeAt,
        shouldPlay: shouldPlay,
        allowRefresh: false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = '刷新视频地址失败：$error';
        });
        _bumpFullscreenRevision();
      }
      return false;
    } finally {
      _refreshingSource = false;
    }
  }

  Future<void> _manualRetry() async {
    _failedUrls.clear();
    final controller = _controller;
    await _refreshSources(
      failedSource: _selectedSource,
      resumeAt: controller?.value.position ?? Duration.zero,
      shouldPlay: _lastKnownPlaying,
      force: true,
    );
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      _controlsTimer?.cancel();
      if (mounted) {
        setState(() => _controlsVisible = true);
      }
    } else {
      await controller.play();
      _scheduleControlsHide();
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    final targetMs = (value.position + delta).inMilliseconds.clamp(
      0,
      value.duration.inMilliseconds,
    );
    await controller.seekTo(Duration(milliseconds: targetMs));
    _showControls();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setPlaybackSpeed(speed);
      if (mounted) {
        setState(() => _playbackSpeed = speed);
        _bumpFullscreenRevision();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法切换播放速度：$error')));
      }
    }
  }

  void _showControls() {
    _controlsTimer?.cancel();
    if (mounted && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _toggleControls() {
    _controlsTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) {
      return;
    }
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _setFullscreen(bool value) async {
    if (!value) {
      if (_fullscreen && mounted) {
        await Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }
    if (_fullscreen) {
      return;
    }
    try {
      final orientation = ref
          .read(appSettingsRepositoryProvider)
          .settings
          .fullscreenOrientation;
      await SystemChrome.setPreferredOrientations(
        orientation == FullscreenOrientationPreference.landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!mounted) {
        return;
      }
      setState(() => _fullscreen = true);
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullscreenPlayerHost(owner: this),
        ),
      );
    } finally {
      await _restoreSystemUi();
      if (mounted) {
        setState(() {
          _fullscreen = false;
          _controlsVisible = true;
        });
        _scheduleControlsHide();
      }
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _changeSource(VideoSource source) {
    if (!_initializing && source != _selectedSource) {
      unawaited(_setSource(source));
    }
  }

  Future<void> _persist(VideoPlayerValue value) {
    if (!value.isInitialized) {
      return Future.value();
    }
    return _playback.savePosition(
      video: widget.video,
      position: value.position,
      duration: value.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final player = _buildInline(controller);
    if (widget.embedded) {
      return player;
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(child: player),
    );
  }

  Widget _buildInline(VideoPlayerController? controller) {
    return AspectRatio(
      key: const ValueKey('inline-video-player'),
      aspectRatio: 16 / 9,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTapDown: (details) {
                final width = MediaQuery.sizeOf(context).width;
                final delta = details.localPosition.dx < width / 2
                    ? const Duration(seconds: -10)
                    : const Duration(seconds: 10);
                unawaited(_seekRelative(delta));
              },
              child: Center(child: _buildPlayerState(controller)),
            ),
            if (controller != null && controller.value.isInitialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: _Controls(
                      controller: controller,
                      fullscreen: false,
                      sources: _sources,
                      selectedSource: _selectedSource,
                      playbackSpeed: _playbackSpeed,
                      onTogglePlayback: _togglePlayback,
                      onSeekBack: () =>
                          _seekRelative(const Duration(seconds: -10)),
                      onSeekForward: () =>
                          _seekRelative(const Duration(seconds: 10)),
                      onSpeedChanged: _setPlaybackSpeed,
                      onSourceChanged: _changeSource,
                      onFullscreenChanged: () => _setFullscreen(true),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerState(VideoPlayerController? controller) {
    if (_initializing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (_refreshingSource) ...[
            const SizedBox(height: 12),
            const Text('正在刷新视频地址…', style: TextStyle(color: Colors.white)),
          ],
        ],
      );
    }
    if (_error != null) {
      return _PlayerError(message: _error!, onRetry: _manualRetry);
    }
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return _PlayerSurface(
      controller: controller,
      onTogglePlayback: _togglePlayback,
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({
    required this.controller,
    required this.onTogglePlayback,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: const ValueKey('video-content-aspect-ratio'),
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          VideoPlayer(controller),
          if (controller.value.isBuffering)
            const Center(child: CircularProgressIndicator()),
          if (!controller.value.isPlaying && !controller.value.isBuffering)
            Center(
              child: IconButton(
                tooltip: '播放视频',
                onPressed: onTogglePlayback,
                iconSize: 64,
                color: Colors.white70,
                icon: const Icon(Icons.play_circle_fill),
              ),
            ),
        ],
      ),
    );
  }
}

class _FullscreenPlayerHost extends StatefulWidget {
  const _FullscreenPlayerHost({required this.owner});

  final _VideoPlayerPageState owner;

  @override
  State<_FullscreenPlayerHost> createState() => _FullscreenPlayerHostState();
}

class _FullscreenPlayerHostState extends State<_FullscreenPlayerHost> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleHide());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    }
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!mounted || widget.owner._controller?.value.isPlaying != true) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.owner._controller?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _exit() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<int>(
        valueListenable: widget.owner._fullscreenRevision,
        builder: (context, _, _) {
          final controller = widget.owner._controller;
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: (details) {
                  final width = MediaQuery.sizeOf(context).width;
                  final delta = details.localPosition.dx < width / 2
                      ? const Duration(seconds: -10)
                      : const Duration(seconds: 10);
                  unawaited(widget.owner._seekRelative(delta));
                  _showControls();
                },
                child: Center(
                  child: widget.owner._buildPlayerState(controller),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IconButton.filledTonal(
                        tooltip: '退出全屏',
                        onPressed: _exit,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                ),
              ),
              if (controller != null && controller.value.isInitialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: _Controls(
                          controller: controller,
                          fullscreen: true,
                          sources: widget.owner._sources,
                          selectedSource: widget.owner._selectedSource,
                          playbackSpeed: widget.owner._playbackSpeed,
                          onTogglePlayback: () {
                            unawaited(
                              widget.owner._togglePlayback().whenComplete(
                                _scheduleHide,
                              ),
                            );
                          },
                          onSeekBack: () {
                            unawaited(
                              widget.owner._seekRelative(
                                const Duration(seconds: -10),
                              ),
                            );
                            _showControls();
                          },
                          onSeekForward: () {
                            unawaited(
                              widget.owner._seekRelative(
                                const Duration(seconds: 10),
                              ),
                            );
                            _showControls();
                          },
                          onSpeedChanged: widget.owner._setPlaybackSpeed,
                          onSourceChanged: widget.owner._changeSource,
                          onFullscreenChanged: _exit,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.fullscreen,
    required this.sources,
    required this.selectedSource,
    required this.playbackSpeed,
    required this.onTogglePlayback,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSpeedChanged,
    required this.onSourceChanged,
    required this.onFullscreenChanged,
  });

  final VideoPlayerController controller;
  final bool fullscreen;
  final List<VideoSource> sources;
  final VideoSource selectedSource;
  final double playbackSpeed;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<VideoSource> onSourceChanged;
  final VoidCallback onFullscreenChanged;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final foreground = fullscreen ? Colors.white : null;
    return Material(
      color: fullscreen
          ? Colors.black87
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, fullscreen ? 4 : 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Colors.white38,
                backgroundColor: fullscreen
                    ? Colors.white24
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final showSeekButtons =
                    fullscreen || constraints.maxWidth >= 340;
                final showVolume = fullscreen || constraints.maxWidth >= 440;
                return Row(
                  children: [
                    IconButton(
                      tooltip: value.isPlaying ? '暂停' : '播放',
                      color: foreground,
                      onPressed: onTogglePlayback,
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    if (showSeekButtons) ...[
                      IconButton(
                        tooltip: '后退 10 秒',
                        color: foreground,
                        onPressed: onSeekBack,
                        icon: const Icon(Icons.replay_10),
                      ),
                      IconButton(
                        tooltip: '前进 10 秒',
                        color: foreground,
                        onPressed: onSeekForward,
                        icon: const Icon(Icons.forward_10),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        '${_time(value.position)} / ${_time(value.duration)}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground),
                      ),
                    ),
                    const Spacer(),
                    if (showVolume)
                      IconButton(
                        tooltip: value.volume == 0 ? '恢复声音' : '静音',
                        color: foreground,
                        onPressed: () =>
                            controller.setVolume(value.volume == 0 ? 1 : 0),
                        icon: Icon(
                          value.volume == 0
                              ? Icons.volume_off
                              : Icons.volume_up,
                        ),
                      ),
                    PopupMenuButton<_PlayerMenuOption>(
                      tooltip: '播放选项',
                      color: fullscreen
                          ? const Color(0xff242529)
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      onSelected: (option) {
                        switch (option) {
                          case _SpeedMenuOption(:final speed):
                            onSpeedChanged(speed);
                          case _SourceMenuOption(:final source):
                            onSourceChanged(source);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<_PlayerMenuOption>(
                          enabled: false,
                          height: 32,
                          child: Text('播放速度'),
                        ),
                        for (final speed in const [0.5, 1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem<_PlayerMenuOption>(
                            value: _SpeedMenuOption(speed),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: speed == playbackSpeed
                                      ? const Icon(Icons.check, size: 18)
                                      : null,
                                ),
                                Text('${speed}x'),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<_PlayerMenuOption>(
                          enabled: false,
                          height: 32,
                          child: Text('清晰度'),
                        ),
                        for (final source in sources)
                          PopupMenuItem<_PlayerMenuOption>(
                            value: _SourceMenuOption(source),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: source == selectedSource
                                      ? const Icon(Icons.check, size: 18)
                                      : null,
                                ),
                                Text(source.label),
                              ],
                            ),
                          ),
                      ],
                      icon: Icon(Icons.more_vert, color: foreground),
                    ),
                    IconButton(
                      tooltip: fullscreen ? '退出全屏' : '全屏',
                      color: foreground,
                      onPressed: onFullscreenChanged,
                      icon: Icon(
                        fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _PlayerMenuOption {
  const _PlayerMenuOption();
}

final class _SpeedMenuOption extends _PlayerMenuOption {
  const _SpeedMenuOption(this.speed);

  final double speed;
}

final class _SourceMenuOption extends _PlayerMenuOption {
  const _SourceMenuOption(this.source);

  final VideoSource source;
}

String _time(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (value.inHours > 0) {
    return '${value.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            onPressed: onRetry,
            child: const Text('刷新并重试'),
          ),
        ],
      ),
    );
  }
}
