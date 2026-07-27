import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/site_avatar.dart';

class SubscriptionsList extends StatefulWidget {
  const SubscriptionsList({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<SubscriptionsList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<SubscriptionItem> _subscriptions = [];
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
    if (_scrollController.position.extentAfter < 500) {
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
        _subscriptions.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.api.loadSubscriptionsPage(_page, force: reset);
      if (!mounted) {
        return;
      }
      final newItems = page
          .where(
            (item) => !_subscriptions.any((saved) => saved.path == item.path),
          )
          .toList(growable: false);
      setState(() {
        _subscriptions.addAll(newItems);
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
    super.build(context);
    if (_subscriptions.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subscriptions.isEmpty && _error != null) {
      return _StateMessage(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_subscriptions.isEmpty) {
      return const Center(child: Text('还没有订阅内容。'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _subscriptions.length + 1,
        itemBuilder: (context, index) {
          if (index == _subscriptions.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null) {
              return _StateMessage(
                message: _error!,
                onRetry: () => _load(reset: false),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text(_hasMore ? '继续向下滚动' : '已经到底了')),
            );
          }
          final item = _subscriptions[index];
          return FutureBuilder<SubscriptionItem>(
            future: widget.api.resolveSubscription(item),
            initialData: item,
            builder: (context, resolvedSnapshot) {
              final resolved = resolvedSnapshot.data ?? item;
              return Card(
                child: ListTile(
                  leading: SiteAvatar(
                    imageUrl: resolved.thumbnailUrl,
                    radius: 20,
                    fallbackIcon: _kindIcon(resolved.kind),
                  ),
                  title: Text(resolved.title),
                  subtitle: Text(resolved.kind.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    AppRouteNames.subscription,
                    pathParameters: {'kind': resolved.kind.name},
                    queryParameters: {
                      'path': resolved.path,
                      'title': resolved.title,
                    },
                    extra: resolved,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _kindIcon(SubscriptionKind kind) => switch (kind) {
    SubscriptionKind.category => Icons.category_outlined,
    SubscriptionKind.model => Icons.brush_outlined,
    SubscriptionKind.member => Icons.person_outline,
    SubscriptionKind.playlist => Icons.playlist_play,
    SubscriptionKind.channel => Icons.live_tv_outlined,
  };

  @override
  bool get wantKeepAlive => true;
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, required this.onRetry});

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
