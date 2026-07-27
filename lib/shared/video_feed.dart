import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/router/route_names.dart';
import '../core/models/video_models.dart';
import 'video_card.dart';

class VideoFeed extends ConsumerStatefulWidget {
  const VideoFeed({
    super.key,
    required this.loadPage,
    this.emptyMessage = '没有找到视频。',
    this.itemFilter,
  });

  final Future<List<VideoItem>> Function(int page) loadPage;
  final String emptyMessage;
  final bool Function(VideoItem video)? itemFilter;

  @override
  ConsumerState<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends ConsumerState<VideoFeed>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<VideoItem> _videos = [];
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  String? _error;

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
      } while (_hasMore &&
          attempts < 3 &&
          _videos.where(_isVisible).length < 8);
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
    ref.watch(appSettingsRepositoryProvider);
    final visibleVideos = _videos.where(_isVisible).toList(growable: false);
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
        message: _hasMore ? '当前加载的视频都被隐藏标题关键词过滤了。' : '所有已加载视频都被隐藏标题关键词过滤了。',
        actionLabel: _hasMore ? '继续查找未隐藏内容' : null,
        onAction: _hasMore ? () => _load(reset: false) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visibleVideos.length + 1,
        itemBuilder: (context, index) {
          if (index < visibleVideos.length) {
            final video = visibleVideos[index];
            return VideoCard(
              video: video,
              onTap: () => context.pushNamed(
                AppRouteNames.video,
                pathParameters: {'id': video.id, 'slug': video.slug},
                extra: video,
              ),
            );
          }
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  bool _isVisible(VideoItem video) {
    if (widget.itemFilter case final filter? when !filter(video)) {
      return false;
    }
    final hiddenKeywords = ref
        .read(appSettingsRepositoryProvider)
        .settings
        .hiddenKeywords
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty);
    final title = video.title.toLowerCase();
    return !hiddenKeywords.any(title.contains);
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
