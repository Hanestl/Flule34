import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import '../settings/data/app_settings_repository.dart';
import '../settings/domain/quality_selection.dart';
import 'video_player_page.dart';

class VideoDetailPage extends ConsumerWidget {
  const VideoDetailPage({super.key, required this.api, required this.video});

  final Rule34VideoApi api;
  final VideoItem video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频详情')),
      body: FutureBuilder<VideoDetails>(
        future: api.loadVideoDetails(video),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _VideoDetailsBody(
            api: api,
            details: snapshot.requireData,
            downloads: ref.watch(downloadRepositoryProvider),
            settings: ref.watch(appSettingsRepositoryProvider),
          );
        },
      ),
    );
  }
}

class _VideoDetailsBody extends StatefulWidget {
  const _VideoDetailsBody({
    required this.api,
    required this.details,
    required this.downloads,
    required this.settings,
  });

  final Rule34VideoApi api;
  final VideoDetails details;
  final DownloadRepository downloads;
  final AppSettingsRepository settings;

  @override
  State<_VideoDetailsBody> createState() => _VideoDetailsBodyState();
}

class _VideoDetailsBodyState extends State<_VideoDetailsBody> {
  late bool _favorite;
  var _updatingFavorite = false;
  var _addingDownload = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.details.isFavorite;
  }

  Future<void> _toggleFavorite() async {
    if (_updatingFavorite) {
      return;
    }
    if (!widget.api.sessionStore.isLoggedIn) {
      final loggedIn = await showLoginSheet(context, widget.api);
      if (!loggedIn) {
        return;
      }
    }
    setState(() => _updatingFavorite = true);
    try {
      await widget.api.toggleFavorite(
        video: widget.details.video,
        add: !_favorite,
      );
      if (mounted) {
        setState(() => _favorite = !_favorite);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingFavorite = false);
      }
    }
  }

  Future<void> _openPlayer() async {
    final cookie = await widget.api.sessionCookieHeader();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerPage(
          video: widget.details.video,
          sources: widget.details.sources,
          sessionCookie: cookie,
        ),
      ),
    );
  }

  Future<void> _download() async {
    if (_addingDownload) {
      return;
    }
    if (!widget.api.sessionStore.isLoggedIn) {
      final loggedIn = await showLoginSheet(context, widget.api);
      if (!loggedIn || !mounted) {
        return;
      }
    }
    final preferences = widget.settings.settings;
    final source = preferences.askDownloadQuality
        ? await showModalBottomSheet<VideoSource>(
            context: context,
            useSafeArea: true,
            builder: (context) {
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      '选择下载清晰度',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  for (final item in widget.details.sources.reversed)
                    ListTile(
                      leading: Icon(item.isHd ? Icons.hd : Icons.sd),
                      title: Text(item.label),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                ],
              );
            },
          )
        : selectVideoSource(
            widget.details.sources,
            preferences.downloadQuality,
          );
    if (source == null || !mounted) {
      return;
    }

    setState(() => _addingDownload = true);
    try {
      await widget.downloads.enqueueVideo(
        details: widget.details,
        source: source,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${source.label} 已加入下载队列。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _addingDownload = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: details.video.thumbnailUrl == null
              ? const ColoredBox(
                  color: Color(0xff25252d),
                  child: Icon(Icons.movie_outlined, size: 52),
                )
              : CachedNetworkImage(
                  imageUrl: details.video.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 52),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.video.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (details.video.duration != null)
                    _StatChip(
                      icon: Icons.schedule,
                      label: details.video.duration!,
                    ),
                  if (details.video.views != null)
                    _StatChip(
                      icon: Icons.visibility_outlined,
                      label: '${details.video.views} 次观看',
                    ),
                  if (details.video.rating != null)
                    _StatChip(
                      icon: Icons.thumb_up_alt_outlined,
                      label: '${details.video.rating}%',
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: details.sources.isEmpty ? null : _openPlayer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: _favorite ? '取消收藏' : '收藏',
                    onPressed: _updatingFavorite ? null : _toggleFavorite,
                    icon: _updatingFavorite
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _favorite ? Icons.favorite : Icons.favorite_border,
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '下载',
                    onPressed: details.sources.isEmpty || _addingDownload
                        ? null
                        : _download,
                    icon: _addingDownload
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                  ),
                ],
              ),
              if (details.sources.isEmpty) ...[
                const SizedBox(height: 12),
                const Text('此视频未提供可直接播放的 MP4 源。'),
              ],
              if (details.description != null) ...[
                const SizedBox(height: 24),
                Text('简介', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(details.description!),
              ],
              _TagSection(title: '分类', values: details.categories),
              _TagSection(title: '标签', values: details.tags),
              _TagSection(title: '艺术家', values: details.models),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .take(40)
                .map((value) => Chip(label: Text(value)))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
