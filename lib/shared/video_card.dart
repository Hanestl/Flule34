import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/api/rule34video_api.dart';
import '../core/models/video_models.dart';
import '../features/auth/login_sheet.dart';
import '../features/library/local_library_picker.dart';
import '../features/library/playlist_picker.dart';
import '../features/settings/domain/quality_selection.dart';
import 'editable_translation.dart';
import 'localized_translation_text.dart';

class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.compact = false,
    this.contextActionLabel,
    this.onContextAction,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;
  final bool compact;
  final String? contextActionLabel;
  final Future<void> Function()? onContextAction;

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final api = ref.read(rule34VideoApiProvider);
    final loggedIn = api.sessionStore.isLoggedIn;
    final initialFavorite =
        video.isFavorite ??
        (loggedIn ? api.cachedFavoriteStatus(video.id) : null);
    final Future<bool>? favoriteFuture = loggedIn
        ? initialFavorite == null
              ? api.favoriteStatus(video)
              : Future.value(initialFavorite)
        : null;
    final detailsFuture = api.loadVideoDetails(video);
    unawaited(
      detailsFuture.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    final action = await showModalBottomSheet<_VideoCardAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (!loggedIn)
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('收藏'),
                onTap: () => Navigator.pop(context, _VideoCardAction.favorite),
              )
            else
              FutureBuilder<bool>(
                future: favoriteFuture,
                initialData: initialFavorite,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  final loading = value == null && !snapshot.hasError;
                  return ListTile(
                    leading: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            value == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                    title: Text(
                      loading
                          ? '正在读取收藏状态'
                          : snapshot.hasError
                          ? '收藏状态读取失败，点击重试'
                          : value == true
                          ? '取消收藏'
                          : '收藏',
                    ),
                    onTap: loading
                        ? null
                        : () =>
                              Navigator.pop(context, _VideoCardAction.favorite),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载'),
              onTap: () => Navigator.pop(context, _VideoCardAction.download),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('本地分类库'),
              onTap: () =>
                  Navigator.pop(context, _VideoCardAction.localLibrary),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('播放列表'),
              onTap: () => Navigator.pop(context, _VideoCardAction.playlist),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('分享'),
              onTap: () => Navigator.pop(context, _VideoCardAction.share),
            ),
            if (contextActionLabel != null && onContextAction != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(contextActionLabel!),
                onTap: () =>
                    Navigator.pop(context, _VideoCardAction.contextAction),
              ),
            ],
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
          final isFavorite = favoriteFuture == null
              ? await api.favoriteStatus(video)
              : await favoriteFuture;
          await api.toggleFavorite(video: video, add: !isFavorite);
          if (context.mounted) {
            _message(context, isFavorite ? '已取消收藏。' : '已加入收藏。');
          }
        case _VideoCardAction.download:
          final details = await _loadDetailsWithProgress(
            context,
            detailsFuture,
          );
          if (details == null) {
            return;
          }
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
          final message = await manageVideoLocalLibraries(
            context: context,
            repository: ref.read(localLibraryRepositoryProvider),
            video: video,
          );
          if (message != null && context.mounted) {
            _message(context, message);
          }
        case _VideoCardAction.playlist:
          if (!await _ensureLogin(context, api) || !context.mounted) {
            return;
          }
          final message = await manageVideoAccountPlaylists(
            context: context,
            api: api,
            video: video,
          );
          if (message != null && context.mounted) {
            _message(context, message);
          }
        case _VideoCardAction.contextAction:
          await onContextAction?.call();
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

  Future<VideoDetails?> _loadDetailsWithProgress(
    BuildContext context,
    Future<VideoDetails> future,
  ) async {
    final shouldShowProgress = await Future.any<bool>([
      future.then((_) => false, onError: (Object _, StackTrace _) => false),
      Future<bool>.delayed(const Duration(milliseconds: 120), () => true),
    ]);
    if (!shouldShowProgress) {
      return future;
    }
    if (!context.mounted) {
      return null;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final progressRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 18),
            Expanded(child: Text('正在读取可用清晰度…')),
          ],
        ),
      ),
    );
    unawaited(navigator.push(progressRoute));
    try {
      return await future;
    } finally {
      final routeNavigator = progressRoute.navigator;
      if (routeNavigator != null) {
        routeNavigator.removeRoute(progressRoute);
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    final translationService = ref.watch(translationServiceProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([settingsRepository, translationService]),
      builder: (context, _) {
        final settings = settingsRepository.settings;
        final blurThumbnail = settings.blurThumbnails;
        if (translationService.shouldAutoTranslateTitle(
          video.id,
          video.title,
        )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              translationService.requestAutomaticTitle(
                videoId: video.id,
                raw: video.title,
                videoSlug: video.slug,
              ),
            );
          });
        }
        final card = Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: compact
              ? const EdgeInsets.all(2)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: InkWell(
            onTap: () {
              ref.read(videoPreviewControllerProvider).hide();
              onTap();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewRegion(
                  enabled: settings.videoPreviewEnabled,
                  onLongPress: () {
                    ref
                        .read(videoPreviewControllerProvider)
                        .show(video, onOpen: onTap);
                  },
                  child: AspectRatio(
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
                                    url:
                                        video.highResolutionThumbnailUrl ??
                                        video.thumbnailUrl!,
                                    fallbackUrl: video.thumbnailUrl,
                                  ),
                                )
                              : _Thumbnail(
                                  url:
                                      video.highResolutionThumbnailUrl ??
                                      video.thumbnailUrl!,
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
                          child: GestureDetector(
                            onLongPress: () {},
                            child: IconButton.filledTonal(
                              tooltip: '视频操作',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  unawaited(_showActions(context, ref)),
                              icon: const Icon(Icons.more_vert),
                            ),
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
                ),
                GestureDetector(
                  key: const ValueKey('video-card-title-translation-region'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => showTitleTranslationEditDialog(
                    context,
                    translationService: translationService,
                    videoId: video.id,
                    english: video.title,
                    videoSlug: video.slug,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (progress != null)
                        LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                        ),
                      Padding(
                        padding: compact
                            ? const EdgeInsets.fromLTRB(7, 6, 7, 7)
                            : const EdgeInsets.fromLTRB(9, 7, 9, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedTranslationText(
                              value: translationService.resolveTitle(
                                video.id,
                                video.title,
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            if (compact) ...[
                              _MetaText(
                                text: video.publishedLabel ?? '',
                                alignment: TextAlign.left,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetaText(
                                      icon: Icons.thumb_up_alt_outlined,
                                      text: video.rating == null
                                          ? ''
                                          : video.ratingVotes == null
                                          ? '${video.rating}%'
                                          : '${video.rating}% (${formatCount(video.ratingVotes!)})',
                                      alignment: TextAlign.left,
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetaText(
                                      icon: Icons.visibility_outlined,
                                      text: video.views == null
                                          ? ''
                                          : formatCount(video.views!),
                                      alignment: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ] else
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
                                      icon: Icons.thumb_up_alt_outlined,
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
                                      icon: Icons.visibility_outlined,
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
              ],
            ),
          ),
        );
        return card;
      },
    );
  }
}

class _PreviewRegion extends StatelessWidget {
  const _PreviewRegion({
    required this.enabled,
    required this.onLongPress,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(seconds: 1),
              ),
              (recognizer) {
                recognizer.onLongPress = () {
                  HapticFeedback.selectionClick();
                  onLongPress();
                };
              },
            ),
      },
      child: child,
    );
  }
}

enum _VideoCardAction {
  favorite,
  download,
  localLibrary,
  playlist,
  share,
  contextAction,
}

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
  const _MetaText({required this.text, required this.alignment, this.icon});

  final String text;
  final TextAlign alignment;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: switch (alignment) {
        TextAlign.center => MainAxisAlignment.center,
        TextAlign.right || TextAlign.end => MainAxisAlignment.end,
        _ => MainAxisAlignment.start,
      },
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignment,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
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
