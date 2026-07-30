import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../app/providers.dart';
import '../core/models/video_models.dart';
import '../core/services/video_preview_service.dart';

class VideoPreviewOverlay extends ConsumerStatefulWidget {
  const VideoPreviewOverlay({
    super.key,
    required this.child,
    required this.navigationListenable,
    required this.bottomInsetBuilder,
  });

  final Widget child;
  final Listenable navigationListenable;
  final double Function(BuildContext context) bottomInsetBuilder;

  @override
  ConsumerState<VideoPreviewOverlay> createState() =>
      _VideoPreviewOverlayState();
}

class _VideoPreviewOverlayState extends ConsumerState<VideoPreviewOverlay>
    with WidgetsBindingObserver {
  VideoPreviewController get _previewController =>
      ref.read(videoPreviewControllerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.navigationListenable.addListener(_closePreview);
  }

  @override
  void didUpdateWidget(covariant VideoPreviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationListenable != widget.navigationListenable) {
      oldWidget.navigationListenable.removeListener(_closePreview);
      widget.navigationListenable.addListener(_closePreview);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _closePreview();
    }
  }

  @override
  void dispose() {
    widget.navigationListenable.removeListener(_closePreview);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _closePreview() {
    _previewController.hide();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(videoPreviewControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final request = controller.request;
        final bottomInset = widget.bottomInsetBuilder(context);
        return PopScope(
          canPop: request == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              controller.hide();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (request != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.hide,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.scrim.withAlpha(82),
                    ),
                  ),
                ),
                SafeArea(
                  key: const Key('video-preview-safe-area'),
                  minimum: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: controller.open,
                      child: _VideoPreviewPanel(
                        key: ValueKey('${request.video.id}:${request.serial}'),
                        video: request.video,
                        resolver: ref.watch(videoPreviewResolverProvider),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VideoPreviewPanel extends StatefulWidget {
  const _VideoPreviewPanel({
    super.key,
    required this.video,
    required this.resolver,
  });

  final VideoItem video;
  final VideoPreviewResolver resolver;

  @override
  State<_VideoPreviewPanel> createState() => _VideoPreviewPanelState();
}

class _VideoPreviewPanelState extends State<_VideoPreviewPanel> {
  static const _headers = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': 'Flule34 Android/1.4.4',
  };

  VideoPlayerController? _player;
  bool _loading = true;
  String? _error;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadSerial += 1;
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    await _replacePlayer(null);
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      var previewUrl = await widget.resolver.resolve(widget.video);
      if (previewUrl == null) {
        throw const _PreviewUnavailableException();
      }
      try {
        await _initialize(previewUrl, serial);
      } catch (_) {
        await widget.resolver.invalidate(widget.video.id);
        previewUrl = await widget.resolver.resolve(
          widget.video.copyWith(previewUrl: null),
          forceRefresh: true,
        );
        if (previewUrl == null) {
          throw const _PreviewUnavailableException();
        }
        await _initialize(previewUrl, serial);
      }
    } catch (_) {
      if (!mounted || serial != _loadSerial) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '暂时无法预览';
      });
    }
  }

  Future<void> _initialize(String url, int serial) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: _headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(false);
      await controller.play();
      if (!mounted || serial != _loadSerial) {
        await controller.dispose();
        return;
      }
      await _replacePlayer(controller);
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _replacePlayer(VideoPlayerController? next) async {
    final previous = _player;
    _player = next;
    if (previous != null && previous != next) {
      await previous.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        key: const Key('video-preview-panel'),
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 10,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.video.thumbnailUrl case final thumbnail?)
                  CachedNetworkImage(
                    imageUrl:
                        widget.video.highResolutionThumbnailUrl ?? thumbnail,
                    fit: BoxFit.contain,
                    httpHeaders: _headers,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                if (_player case final player?)
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: player,
                    builder: (context, value, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: value.size.width,
                            height: value.size.height,
                            child: VideoPlayer(player),
                          ),
                        ),
                        if (value.isBuffering)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error case final error?)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_disabled_outlined,
                          color: Colors.white70,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => unawaited(_load()),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _PreviewUnavailableException implements Exception {
  const _PreviewUnavailableException();
}
