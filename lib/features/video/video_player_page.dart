import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/models/video_models.dart';
import '../settings/domain/quality_selection.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.video,
    required this.sources,
    this.sessionCookie,
  });

  final VideoItem video;
  final List<VideoSource> sources;
  final String? sessionCookie;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  VideoPlayerController? _controller;
  late VideoSource _selectedSource;
  var _initializing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    _selectedSource = selectVideoSource(
      widget.sources,
      settings.playbackQuality,
    );
    _setSource(_selectedSource);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setSource(VideoSource source) async {
    setState(() {
      _selectedSource = source;
      _initializing = true;
      _error = null;
    });
    final previous = _controller;
    final previousPosition = previous?.value.position ?? Duration.zero;
    final shouldContinuePlaying = previous?.value.isPlaying ?? false;
    _controller = null;
    previous?.removeListener(_refresh);
    await previous?.dispose();

    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/0.1',
    };
    if (widget.sessionCookie != null) {
      headers['Cookie'] = widget.sessionCookie!;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
      httpHeaders: headers,
    );
    controller.addListener(_refresh);
    try {
      await controller.initialize();
      final settings = ref.read(appSettingsRepositoryProvider).settings;
      await controller.setLooping(settings.loopPlayback);
      if (previousPosition > Duration.zero &&
          previousPosition < controller.value.duration) {
        await controller.seekTo(previousPosition);
      }
      if (shouldContinuePlaying || (previous == null && settings.autoplay)) {
        await controller.play();
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() => _error = '无法播放此视频源：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
                  ? const CircularProgressIndicator()
                  : _error != null
                  ? _PlayerError(
                      message: _error!,
                      onRetry: () => _setSource(_selectedSource),
                    )
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
                    items: widget.sources
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
                              _setSource(source);
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

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) {
      return '${value.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
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
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
