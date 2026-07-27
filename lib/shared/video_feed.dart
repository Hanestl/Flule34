import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router/route_names.dart';
import '../core/models/video_models.dart';
import 'video_card.dart';
import 'video_list_filters.dart';

class VideoFeed extends ConsumerStatefulWidget {
  const VideoFeed({
    super.key,
    required this.loadPage,
    this.emptyMessage = '没有找到视频。',
    this.itemFilter,
    this.columns = 1,
    this.showSearchAndFilters = false,
    this.searchHint = '搜索已加载的视频',
    this.sortNewest = false,
  });

  final Future<List<VideoItem>> Function(int page) loadPage;
  final String emptyMessage;
  final bool Function(VideoItem video)? itemFilter;
  final int columns;
  final bool showSearchAndFilters;
  final String searchHint;
  final bool sortNewest;

  @override
  ConsumerState<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends ConsumerState<VideoFeed>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<VideoItem> _videos = [];
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  String? _error;
  String _query = '';
  VideoListFilters _filters = const VideoListFilters();

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
    if (_scrollController.position.extentAfter < 800) {
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
      var attempts = 0;
      do {
        final page = await widget.loadPage(_page);
        if (!mounted) {
          return;
        }
        final newItems = page
            .where((item) => !_videos.any((saved) => saved.id == item.id))
            .toList(growable: false);
        setState(() {
          _videos.addAll(newItems);
          _page += 1;
          // 网站不同列表的分页数量并不完全一致。只要本页仍返回了新内容，
          // 就允许再探测一页；最后一页之后的空响应会可靠地结束分页。
          _hasMore = page.isNotEmpty && newItems.isNotEmpty;
        });
        attempts += 1;
      } while (_hasMore && attempts < 3 && _visibleVideos().length < 8);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visibleVideos = _visibleVideos();
    final body = _buildBody(context, visibleVideos);
    if (!widget.showSearchAndFilters) {
      return body;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search),
            hintText: widget.searchHint,
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: '清除搜索',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close),
                ),
              IconButton(
                tooltip: '筛选',
                onPressed: _showFilters,
                icon: Badge(
                  isLabelVisible: _filters.activeCount > 0,
                  label: Text('${_filters.activeCount}'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _query = value.trim()),
            onSubmitted: (_) => unawaited(_load(reset: false)),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<VideoItem> visibleVideos) {
    if (_videos.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videos.isEmpty && _error != null) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: '重试',
        onAction: () => _load(reset: true),
      );
    }
    if (_videos.isEmpty) {
      return _StateMessage(
        icon: Icons.video_library_outlined,
        message: widget.emptyMessage,
      );
    }
    if (visibleVideos.isEmpty && !_loading) {
      return _StateMessage(
        icon: Icons.visibility_off_outlined,
        message: _hasMore ? '当前已加载内容没有匹配项。' : '没有符合搜索和筛选条件的视频。',
        actionLabel: _hasMore ? '继续加载并查找' : null,
        onAction: _hasMore ? () => _load(reset: false) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: widget.columns > 1
                ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
                : EdgeInsets.zero,
            sliver: widget.columns > 1
                ? SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.88,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _videoCard(visibleVideos[index], compact: true),
                      childCount: visibleVideos.length,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _videoCard(visibleVideos[index]),
                      childCount: visibleVideos.length,
                    ),
                  ),
          ),
          SliverToBoxAdapter(child: _footer(context)),
        ],
      ),
    );
  }

  Widget _videoCard(VideoItem video, {bool compact = false}) {
    return VideoCard(
      video: video,
      compact: compact,
      onTap: () => context.pushNamed(
        AppRouteNames.video,
        pathParameters: {'id': video.id, 'slug': video.slug},
        extra: video,
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _load(reset: false),
              icon: const Icon(Icons.refresh),
              label: const Text('重试加载下一页'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(child: Text(_hasMore ? '继续向下滚动以加载更多' : '已经到底了')),
    );
  }

  @override
  bool get wantKeepAlive => true;

  bool _isVisible(VideoItem video) {
    return widget.itemFilter?.call(video) ?? true;
  }

  List<VideoItem> _visibleVideos() {
    final source = _videos.where(_isVisible).toList(growable: false);
    if (widget.sortNewest && !widget.showSearchAndFilters) {
      return filterAndSortVideos(
        source,
        filters: const VideoListFilters(sort: VideoListSort.newest),
      );
    }
    if (!widget.showSearchAndFilters) {
      return source;
    }
    return filterAndSortVideos(source, query: _query, filters: _filters);
  }

  Future<void> _showFilters() async {
    final selected = await showVideoListFilters(
      context,
      initialValue: _filters,
      title: '筛选视频',
      defaultSortLabel: '网站顺序',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _filters = selected);
    if (_visibleVideos().length < 8) {
      unawaited(_load(reset: false));
    }
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
