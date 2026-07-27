import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/api/rule34video_api.dart';
import '../core/models/video_models.dart';
import '../features/auth/login_sheet.dart';
import '../features/library/local_library_picker.dart';
import '../features/settings/domain/quality_selection.dart';

class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final api = ref.read(rule34VideoApiProvider);
    var isFavorite = video.isFavorite == true;
    if (api.sessionStore.isLoggedIn && video.isFavorite == null) {
      try {
        isFavorite = await api.favoriteStatus(video);
      } catch (error) {
        if (context.mounted) {
          _message(context, error.toString());
        }
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    final action = await showModalBottomSheet<_VideoCardAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              title: Text(isFavorite ? '取消收藏' : '收藏'),
              onTap: () => Navigator.pop(context, _VideoCardAction.favorite),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载'),
              onTap: () => Navigator.pop(context, _VideoCardAction.download),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('入库'),
              onTap: () =>
                  Navigator.pop(context, _VideoCardAction.localLibrary),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('分享'),
              onTap: () => Navigator.pop(context, _VideoCardAction.share),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) {
      return;
    }
    try {
      switch (action) {
        case _VideoCardAction.share:
          await ref.read(shareServiceProvider).shareVideo(video);
        case _VideoCardAction.favorite:
          if (!await _ensureLogin(context, api) || !context.mounted) {
            return;
          }
          await api.toggleFavorite(video: video, add: !isFavorite);
          if (context.mounted) {
            _message(context, isFavorite ? '已取消收藏。' : '已加入收藏。');
          }
        case _VideoCardAction.download:
          final details = await api.loadVideoDetails(video);
          if (!context.mounted) {
            return;
          }
          if (details.sources.isEmpty) {
            _message(context, '此视频没有可下载的 MP4 源。');
            return;
          }
          final settings = ref.read(appSettingsRepositoryProvider).settings;
          final source = settings.askDownloadQuality
              ? await _chooseQuality(context, details.sources)
              : selectVideoSource(details.sources, settings.downloadQuality);
          if (source == null || !context.mounted) {
            return;
          }
          await ref
              .read(downloadRepositoryProvider)
              .enqueueVideo(details: details, source: source);
          if (context.mounted) {
            _message(context, '${source.label} 已加入下载队列。');
          }
        case _VideoCardAction.localLibrary:
          final name = await addVideoToLocalLibrary(
            context: context,
            repository: ref.read(localLibraryRepositoryProvider),
            video: video,
          );
          if (name != null && context.mounted) {
            _message(context, '已加入“$name”。');
          }
      }
    } catch (error) {
      if (context.mounted) {
        _message(context, error.toString());
      }
    }
  }

  Future<bool> _ensureLogin(BuildContext context, Rule34VideoApi api) async {
    if (api.sessionStore.isLoggedIn) {
      return true;
    }
    return showLoginSheet(context, api);
  }

  Future<VideoSource?> _chooseQuality(
    BuildContext context,
    List<VideoSource> sources,
  ) {
    return showModalBottomSheet<VideoSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final source in sources.reversed)
            ListTile(
              leading: Icon(source.isHd ? Icons.hd : Icons.sd),
              title: Text(source.label),
              onTap: () => Navigator.pop(context, source),
            ),
        ],
      ),
    );
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    return ListenableBuilder(
      listenable: settingsRepository,
      builder: (context, _) {
        final blurThumbnail = settingsRepository.settings.blurThumbnails;
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.thumbnailUrl != null)
                        blurThumbnail
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: _Thumbnail(
                                  url: video.highResolutionThumbnailUrl!,
                                  fallbackUrl: video.thumbnailUrl,
                                ),
                              )
                            : _Thumbnail(
                                url: video.highResolutionThumbnailUrl!,
                                fallbackUrl: video.thumbnailUrl,
                              )
                      else
                        const ColoredBox(
                          color: Color(0xff25252d),
                          child: Center(
                            child: Icon(Icons.movie_outlined, size: 42),
                          ),
                        ),
                      if (blurThumbnail)
                        const Positioned(
                          left: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton.filledTonal(
                          tooltip: '视频操作',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              unawaited(_showActions(context, ref)),
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                      if (video.duration != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                video.duration!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (progress != null)
                  LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _MetaText(
                              text: video.publishedLabel ?? '',
                              alignment: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            child: _MetaText(
                              text: video.rating == null
                                  ? ''
                                  : video.ratingVotes == null
                                  ? '${video.rating}%'
                                  : '${video.rating}% (${formatCount(video.ratingVotes!)})',
                              alignment: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: _MetaText(
                              text: video.views == null
                                  ? ''
                                  : formatCount(video.views!),
                              alignment: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _VideoCardAction { favorite, download, localLibrary, share }

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, this.fallbackUrl});

  final String url;
  final String? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(
        color: Color(0xff25252d),
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, _, _) {
        final fallback = fallbackUrl;
        if (fallback != null && fallback != url) {
          return CachedNetworkImage(
            imageUrl: fallback,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const _BrokenThumbnail(),
          );
        }
        return const _BrokenThumbnail();
      },
    );
  }
}

class _BrokenThumbnail extends StatelessWidget {
  const _BrokenThumbnail();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xff25252d),
      child: Center(child: Icon(Icons.broken_image_outlined, size: 42)),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, required this.alignment});

  final String text;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String formatCount(int value) {
  if (value >= 1000000) {
    return _compact(value / 1000000, 'M');
  }
  if (value >= 1000) {
    return _compact(value / 1000, 'K');
  }
  return value.toString();
}

String _compact(double value, String suffix) {
  final digits = value >= 10 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(digits)}$suffix';
}
