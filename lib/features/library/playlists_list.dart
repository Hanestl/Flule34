import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import 'playlist_form_dialog.dart';

enum PlaylistOverviewSort {
  source('最新创建'),
  name('按名字'),
  videoCount('视频数量');

  const PlaylistOverviewSort(this.label);

  final String label;
}

class PlaylistsList extends StatefulWidget {
  const PlaylistsList({super.key, required this.api, this.active = true});

  final Rule34VideoApi api;
  final bool active;

  @override
  State<PlaylistsList> createState() => _PlaylistsListState();
}

class _PlaylistsListState extends State<PlaylistsList>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  Future<List<PlaylistItem>>? _future;
  var _mutating = false;
  var _query = '';
  var _sort = PlaylistOverviewSort.source;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _future = widget.api.loadMyPlaylists();
    }
  }

  @override
  void didUpdateWidget(covariant PlaylistsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && _future == null) {
      setState(() => _future = widget.api.loadMyPlaylists());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = widget.api.loadMyPlaylists(force: true);
    setState(() => _future = future);
    await future;
  }

  List<PlaylistItem> _visiblePlaylists(List<PlaylistItem> source) {
    final normalized = _query.trim().toLowerCase();
    final sourceIndex = <String, int>{
      for (var index = 0; index < source.length; index += 1)
        source[index].id: index,
    };
    final result = source
        .where(
          (item) =>
              normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized),
        )
        .toList(growable: true);
    switch (_sort) {
      case PlaylistOverviewSort.source:
        break;
      case PlaylistOverviewSort.name:
        result.sort((left, right) {
          final compared = left.title.toLowerCase().compareTo(
            right.title.toLowerCase(),
          );
          return compared == 0
              ? (sourceIndex[left.id] ?? 0).compareTo(
                  sourceIndex[right.id] ?? 0,
                )
              : compared;
        });
      case PlaylistOverviewSort.videoCount:
        result.sort((left, right) {
          final compared = (right.videoCount ?? -1).compareTo(
            left.videoCount ?? -1,
          );
          return compared == 0
              ? (sourceIndex[left.id] ?? 0).compareTo(
                  sourceIndex[right.id] ?? 0,
                )
              : compared;
        });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _mutating ? null : () => _editPlaylist(),
              icon: const Icon(Icons.playlist_add),
              label: const Text('新建播放列表'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PlaylistItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (_future == null) {
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _PlaylistState(
                  message: snapshot.error.toString(),
                  onRetry: _reload,
                );
              }
              final playlists = snapshot.requireData;
              if (playlists.isEmpty) {
                return const Center(child: Text('账号中还没有播放列表。'));
              }
              final visible = _visiblePlaylists(playlists);
              return Material(
                type: MaterialType.transparency,
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                    itemCount: visible.isEmpty ? 2 : visible.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _toolbar(context);
                      }
                      if (visible.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 44),
                          child: Center(child: Text('没有符合条件的播放列表。')),
                        );
                      }
                      final playlist = visible[index - 1];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.playlist_play),
                          ),
                          title: Text(playlist.title),
                          subtitle: playlist.videoCount == null
                              ? null
                              : Text('${playlist.videoCount} 个视频'),
                          trailing: PopupMenuButton<_PlaylistAction>(
                            enabled: !_mutating,
                            onSelected: (action) {
                              switch (action) {
                                case _PlaylistAction.edit:
                                  _editPlaylist(playlist);
                                case _PlaylistAction.delete:
                                  _deletePlaylist(playlist);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _PlaylistAction.edit,
                                child: Text('编辑'),
                              ),
                              PopupMenuItem(
                                value: _PlaylistAction.delete,
                                child: Text('删除'),
                              ),
                            ],
                          ),
                          onTap: () => context.pushNamed(
                            AppRouteNames.playlist,
                            pathParameters: {'id': playlist.id},
                            extra: playlist,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: _searchController,
              leading: const Icon(Icons.search),
              hintText: '搜索播放列表',
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: '清除',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<PlaylistOverviewSort>(
            tooltip: '排序',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => PlaylistOverviewSort.values
                .map(
                  (item) => PopupMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.sort),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlaylist([PlaylistItem? playlist]) async {
    setState(() => _mutating = true);
    try {
      final initial = playlist == null
          ? const PlaylistFormData(title: '')
          : await widget.api.loadPlaylistForm(playlist.id);
      if (!mounted) {
        return;
      }
      final form = await showPlaylistEditor(
        context,
        title: playlist == null ? '新建播放列表' : '编辑播放列表',
        initial: initial,
      );
      if (form == null || !mounted) {
        return;
      }
      if (playlist == null) {
        await widget.api.createPlaylist(form);
      } else {
        await widget.api.updatePlaylist(playlistId: playlist.id, form: form);
      }
      await _reload();
      if (mounted) {
        _message(playlist == null ? '播放列表已创建。' : '播放列表已更新。');
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _deletePlaylist(PlaylistItem playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${playlist.title}”？'),
        content: const Text('播放列表会从网站账号中删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    try {
      await widget.api.deletePlaylist(playlist.id);
      await _reload();
      if (mounted) {
        _message('播放列表已删除。');
      }
    } catch (error) {
      if (mounted) {
        _message(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  bool get wantKeepAlive => true;
}

enum _PlaylistAction { edit, delete }

class _PlaylistState extends StatelessWidget {
  const _PlaylistState({required this.message, required this.onRetry});

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
