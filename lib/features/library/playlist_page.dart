import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart';
import '../../shared/video_list_filters.dart';
import 'playlist_playback_page.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.api, required this.playlist});

  final Rule34VideoApi api;
  final PlaylistItem playlist;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<VideoItem> _videos = [];
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  String? _error;
  final Set<String> _removingIds = {};
  var _query = '';
  var _filters = const VideoListFilters();
  var _loadingAllForFilter = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 700) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || (!reset && !_hasMore)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _videos.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.api.loadPlaylistVideos(widget.playlist, _page);
      if (!mounted) {
        return;
      }
      final newItems = page
          .where((item) => !_videos.any((saved) => saved.id == item.id))
          .toList(growable: false);
      setState(() {
        _videos.addAll(newItems);
        _page += 1;
        _hasMore = page.isNotEmpty && newItems.isNotEmpty;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_hasActiveFiltering) {
          unawaited(_loadAllForFilter());
        }
      }
    }
  }

  bool get _hasActiveFiltering => _query.isNotEmpty || _filters.activeCount > 0;

  Future<void> _loadAllForFilter() async {
    if (!_hasActiveFiltering || _loading || _loadingAllForFilter || !_hasMore) {
      return;
    }
    setState(() => _loadingAllForFilter = true);
    try {
      while (_hasMore && mounted && _hasActiveFiltering) {
        await _load(reset: false);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAllForFilter = false);
      }
    }
  }

  void _applyQuery(String value) {
    setState(() => _query = value.trim());
    unawaited(_loadAllForFilter());
  }

  Future<void> _showFilters() async {
    final selected = await showVideoListFilters(
      context,
      initialValue: _filters,
      title: '筛选播放列表',
      defaultSortLabel: '列表顺序',
    );
    if (selected != null && mounted) {
      setState(() => _filters = selected);
      unawaited(_loadAllForFilter());
    }
  }

  void _playFrom(List<VideoItem> videos, int index) {
    context.pushNamed(
      AppRouteNames.playlistPlayback,
      pathParameters: {'id': widget.playlist.id},
      extra: PlaylistPlaybackRequest(
        playlist: widget.playlist,
        videos: List.of(videos),
        initialIndex: index,
        nextPage: _page,
        hasMore: _hasActiveFiltering ? false : _hasMore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.title),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
          ),
          IconButton(
            tooltip: '从头连续播放',
            onPressed: _filteredVideos.isEmpty || _loadingAllForFilter
                ? null
                : () => _playFrom(_filteredVideos, 0),
            icon: const Icon(Icons.play_circle_outline),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_videos.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videos.isEmpty && _error != null) {
      return _PlaylistMessage(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('这个播放列表里还没有视频。'));
    }
    final videos = _filteredVideos;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search),
            hintText: '搜索播放列表中的视频',
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _searchController.clear();
                    _applyQuery('');
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
            onChanged: _applyQuery,
          ),
        ),
        if (_loadingAllForFilter)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: videos.isEmpty && _hasActiveFiltering && !_loadingAllForFilter
              ? const Center(child: Text('没有符合搜索和筛选条件的视频。'))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: videos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == videos.length) {
                        if (_loading) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: Text(
                              _loadingAllForFilter
                                  ? '正在读取全部视频…'
                                  : (_hasMore ? '继续向下滚动' : '已经到底了'),
                            ),
                          ),
                        );
                      }
                      final video = videos[index];
                      return VideoCard(
                        video: video,
                        contextActionLabel: '移出此播放列表',
                        onContextAction: _removingIds.contains(video.id)
                            ? null
                            : () => _removeVideo(video),
                        onTap: () => _playFrom(videos, index),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  List<VideoItem> get _filteredVideos =>
      filterAndSortVideos(_videos, query: _query, filters: _filters);

  Future<void> _removeVideo(VideoItem video) async {
    setState(() => _removingIds.add(video.id));
    try {
      await widget.api.removeVideoFromPlaylist(
        video: video,
        playlistId: widget.playlist.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _videos.removeWhere((item) => item.id == video.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已从播放列表移出。')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _removingIds.remove(video.id));
      }
    }
  }
}

class _PlaylistMessage extends StatelessWidget {
  const _PlaylistMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
