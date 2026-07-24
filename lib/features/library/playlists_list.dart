import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart';

class PlaylistsList extends StatefulWidget {
  const PlaylistsList({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<PlaylistsList> createState() => _PlaylistsListState();
}

class _PlaylistsListState extends State<PlaylistsList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<PlaylistItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.loadMyPlaylists();
  }

  Future<void> _reload() async {
    final future = widget.api.loadMyPlaylists();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<PlaylistItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(message: snapshot.error.toString(), onRetry: _reload);
        }
        final playlists = snapshot.requireData;
        if (playlists.isEmpty) {
          return const Center(child: Text('还没有播放列表。'));
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: SizedBox(
                    width: 88,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: playlist.thumbnailUrl == null
                          ? const ColoredBox(
                              color: Color(0xff25252d),
                              child: Icon(Icons.playlist_play),
                            )
                          : CachedNetworkImage(
                              imageUrl: playlist.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: Color(0xff25252d),
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    playlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_metadata(playlist)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    AppRouteNames.playlist,
                    pathParameters: {'id': playlist.id},
                    extra: playlist,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _metadata(PlaylistItem playlist) {
    final values = <String>[];
    if (playlist.videoCount != null) {
      values.add('${playlist.videoCount} 个视频');
    }
    if (playlist.views != null) {
      values.add('${formatCount(playlist.views!)} 次观看');
    }
    return values.isEmpty ? '播放列表' : values.join(' · ');
  }

  @override
  bool get wantKeepAlive => true;
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
