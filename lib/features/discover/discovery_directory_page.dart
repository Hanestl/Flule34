import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';

class DiscoveryDirectoryPage extends StatefulWidget {
  const DiscoveryDirectoryPage({
    super.key,
    required this.api,
    required this.spec,
  });

  final Rule34VideoApi api;
  final DiscoveryDirectorySpec spec;

  @override
  State<DiscoveryDirectoryPage> createState() => _DiscoveryDirectoryPageState();
}

class _DiscoveryDirectoryPageState extends State<DiscoveryDirectoryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ContentCollectionItem> _items = [];
  var _query = '';
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_load(reset: false));
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
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.api.loadDiscoveryDirectory(
        widget.spec,
        page: _page,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final newItems = page
            .where(
              (item) => !_items.any(
                (saved) =>
                    saved.kind == item.kind &&
                    (saved.id == item.id || saved.path == item.path),
              ),
            )
            .toList(growable: false);
        _items.addAll(newItems);
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.spec.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: '筛选已加载的${widget.spec.title}',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(child: _buildDirectory()),
        ],
      ),
    );
  }

  Widget _buildDirectory() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _DirectoryMessage(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    final normalized = _query.toLowerCase();
    final visibleItems = _items
        .where(
          (item) =>
              normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
    if (visibleItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('没有匹配的已加载内容。')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: visibleItems.length + 1,
        itemBuilder: (context, index) {
          if (index == visibleItems.length) {
            return _buildFooter();
          }
          final item = visibleItems[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: item.thumbnailUrl == null
                    ? null
                    : CachedNetworkImageProvider(item.thumbnailUrl!),
                child: item.thumbnailUrl == null
                    ? Icon(_kindIcon(item.kind))
                    : null,
              ),
              title: Text(item.title),
              subtitle: item.total == null
                  ? Text(item.kind.label)
                  : Text('${item.total} 个视频'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(
                AppRouteNames.collection,
                pathParameters: {'kind': item.kind.name, 'id': item.id},
                extra: item,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
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

  IconData _kindIcon(DiscoveryKind kind) => switch (kind) {
    DiscoveryKind.tag => Icons.tag,
    DiscoveryKind.category => Icons.category_outlined,
    DiscoveryKind.model => Icons.brush_outlined,
    DiscoveryKind.channel => Icons.live_tv_outlined,
  };
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({required this.message, required this.onRetry});

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
