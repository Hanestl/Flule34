import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router/route_names.dart';
import '../core/models/video_models.dart';
import 'video_card.dart';

class VideoFeed extends StatefulWidget {
  const VideoFeed({
    super.key,
    required this.loadPage,
    this.emptyMessage = '没有找到视频。',
  });

  final Future<List<VideoItem>> Function(int page) loadPage;
  final String emptyMessage;

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed>
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
      final page = await widget.loadPage(_page);
      if (!mounted) {
        return;
      }
      setState(() {
        _videos.addAll(
          page.where((item) => !_videos.any((saved) => saved.id == item.id)),
        );
        _page += 1;
        _hasMore = page.length >= 30;
      });
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

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _videos.length + 1,
        itemBuilder: (context, index) {
          if (index < _videos.length) {
            final video = _videos[index];
            return VideoCard(
              video: video,
              onTap: () => context.pushNamed(
                AppRouteNames.video,
                pathParameters: {'id': video.id, 'slug': video.slug},
                extra: video,
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : _hasMore
                  ? const Text('继续向下滚动以加载更多')
                  : const Text('已经到底了'),
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
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
