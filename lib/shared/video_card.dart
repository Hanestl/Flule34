import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../app/providers.dart';
import '../core/api/rule34video_api.dart';
import '../core/models/video_models.dart';
import '../core/services/network_status_service.dart';
import '../features/auth/login_sheet.dart';
import '../features/settings/domain/app_settings.dart';
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

  Future<void> _showPreview(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(appSettingsRepositoryProvider).settings;
    if (settings.videoPreviewPolicy == VideoPreviewPolicy.disabled) {
      _message(context, '视频预览已关闭，可在“我的 → 内容设置”中开启。');
      return;
    }
    final previewUrl = video.previewUrl;
    if (previewUrl == null) {
      _message(context, '这个视频没有提供短预览。');
      return;
    }
    if (settings.videoPreviewPolicy == VideoPreviewPolicy.wifiOnly) {
      try {
        final network = await ref.read(networkStatusServiceProvider).current();
        if (network != NetworkClass.wifi) {
          if (context.mounted) {
            _message(context, '当前不是 Wi-Fi，已按设置阻止视频预览。');
          }
          return;
        }
      } catch (_) {
        if (context.mounted) {
          _message(context, '无法确认网络类型，未启动仅 Wi-Fi 预览。');
        }
        return;
      }
    }
    final api = ref.read(rule34VideoApiProvider);
    final headers = <String, String>{
      'Referer': 'https://rule34video.com/',
      'User-Agent': 'Flule34 Android/0.1',
    };
    final cookie = await api.sessionCookieHeader();
    if (cookie != null) {
      headers['Cookie'] = cookie;
    }
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (_) => _VideoPreviewSheet(
        title: video.title,
        url: previewUrl,
        headers: headers,
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_VideoCardAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () => Navigator.pop(context, _VideoCardAction.favorite),
            ),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.watch_later_outlined),
              title: Text('稍后观看'),
              subtitle: Text('网站写入参数尚未验证，暂不冒险修改账号数据'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('加入播放列表'),
              onTap: () => Navigator.pop(context, _VideoCardAction.playlist),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('下载'),
              onTap: () => Navigator.pop(context, _VideoCardAction.download),
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
    final api = ref.read(rule34VideoApiProvider);
    try {
      switch (action) {
        case _VideoCardAction.share:
          await ref.read(shareServiceProvider).shareVideo(video);
        case _VideoCardAction.favorite:
          if (!await _ensureLogin(context, api) || !context.mounted) {
            return;
          }
          await api.toggleFavorite(video: video, add: true);
          if (context.mounted) {
            _message(context, '已加入收藏。');
          }
        case _VideoCardAction.playlist:
          if (!await _ensureLogin(context, api) || !context.mounted) {
            return;
          }
          final playlists = await api.loadMyPlaylists();
          if (!context.mounted) {
            return;
          }
          if (playlists.isEmpty) {
            _message(context, '账号中还没有播放列表。');
            return;
          }
          final playlist = await showModalBottomSheet<PlaylistItem>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in playlists)
                    ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(item.title),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
          );
          if (playlist == null) {
            return;
          }
          await api.addVideoToPlaylist(video: video, playlistId: playlist.id);
          if (context.mounted) {
            _message(context, '已加入“${playlist.title}”。');
          }
        case _VideoCardAction.download:
          if (!await _ensureLogin(context, api) || !context.mounted) {
            return;
          }
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
            onLongPress: () => unawaited(_showPreview(context, ref)),
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
                                child: _Thumbnail(url: video.thumbnailUrl!),
                              )
                            : _Thumbnail(url: video.thumbnailUrl!)
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

enum _VideoCardAction { favorite, playlist, download, share }

class _VideoPreviewSheet extends StatefulWidget {
  const _VideoPreviewSheet({
    required this.title,
    required this.url,
    required this.headers,
  });

  final String title;
  final String url;
  final Map<String, String> headers;

  @override
  State<_VideoPreviewSheet> createState() => _VideoPreviewSheetState();
}

class _VideoPreviewSheetState extends State<_VideoPreviewSheet> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    );
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    await _controller.setVolume(0);
    await _controller.setLooping(true);
    await _controller.play();
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '无法播放预览：${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Stack(
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(
        color: Color(0xff25252d),
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xff25252d),
        child: Center(child: Icon(Icons.broken_image_outlined, size: 42)),
      ),
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
