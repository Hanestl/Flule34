import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../playback/data/playback_repository.dart';
import '../settings/domain/quality_selection.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.api,
    required this.video,
    required this.sources,
  });

  final Rule34VideoApi api;
  final VideoItem video;
  final List<VideoSource> sources;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  VideoPlayerController? _controller;
  late List<VideoSource> _sources;
  late VideoSource _selectedSource;
  final Set<String> _failedUrls = {};
  var _initializing = true;
  var _refreshingSource = false;
  var _operation = 0;
  var _lastSavedSecond = -1;
  var _lastKnownPlaying = false;
  var _resumeMessageShown = false;
  String? _error;

  PlaybackRepository get _playback => ref.read(playbackRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _sources = List.of(widget.sources);
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    _selectedSource = selectVideoSource(_sources, settings.playbackQuality);
    unawaited(_start());
  }

  Future<void> _start() async {
    final resumePosition = await _playback.loadPosition(widget.video.id);
    if (!mounted) {
      return;
    }
    await _setSource(
      _selectedSource,
      resumeAt: resumePosition,
      shouldPlay: ref.read(appSettingsRepositoryProvider).settings.autoplay,
    );
  }

  @override
  void dispose() {
    _operation += 1;
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      unawaited(_persist(controller.value));
      unawaited(controller.dispose());
    }
    super.dispose();
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
    }

    final previous = _controller;
    final previousValue = previous?.value;
    final targetPosition = resumeAt ?? previousValue?.position ?? Duration.zero;
    final continuePlaying = shouldPlay ?? previousValue?.isPlaying ?? false;
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
      if (targetPosition > Duration.zero) {
        await controller.seekTo(targetPosition);
      }
      _controller = controller;
      controller.addListener(_onControllerChanged);
      _lastSavedSecond = targetPosition.inSeconds;
      setState(() {
        _selectedSource = source;
        _initializing = false;
        _error = null;
      });
      if (continuePlaying) {
        await controller.play();
      }
      _lastKnownPlaying = continuePlaying;
      if (!_resumeMessageShown &&
          targetPosition >= const Duration(seconds: 5)) {
        _resumeMessageShown = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已从 ${_time(targetPosition)} 继续播放。')),
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
    final second = value.position.inSeconds;
    if (value.isInitialized &&
        second >= 0 &&
        (second - _lastSavedSecond).abs() >= 5) {
      _lastSavedSecond = second;
      unawaited(_persist(value));
    }
    setState(() {});
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
      final details = await widget.api.loadVideoDetails(widget.video);
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

  Future<void> _persist(VideoPlayerValue value) {
    if (!value.isInitialized) {
      return Future.value();
    }
    return _playback.savePosition(
      videoId: widget.video.id,
      position: value.position,
      duration: value.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _initializing
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (_refreshingSource) ...[
                          const SizedBox(height: 12),
                          const Text('正在刷新视频地址…'),
                        ],
                      ],
                    )
                  : _error != null
                  ? _PlayerError(message: _error!, onRetry: _manualRetry)
                  : controller == null
                  ? const SizedBox.shrink()
                  : _PlayerSurface(controller: controller),
            ),
          ),
          if (controller != null && controller.value.isInitialized)
            _Controls(controller: controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                const Text('清晰度'),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<VideoSource>(
                    value: _selectedSource,
                    isExpanded: true,
                    items: _sources
                        .map(
                          (source) => DropdownMenuItem(
                            value: source,
                            child: Text(source.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _initializing
                        ? null
                        : (source) {
                            if (source != null && source != _selectedSource) {
                              unawaited(_setSource(source));
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          controller.value.isPlaying ? controller.pause() : controller.play(),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            if (!controller.value.isPlaying)
              const Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 64,
              ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Column(
      children: [
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              Text('${_time(value.position)} / ${_time(value.duration)}'),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    controller.setVolume(value.volume == 0 ? 1 : 0),
                icon: Icon(
                  value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
          const Icon(Icons.error_outline, size: 52),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('刷新并重试')),
        ],
      ),
    );
  }
}
