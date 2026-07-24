import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';

class SubscriptionsList extends StatefulWidget {
  const SubscriptionsList({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<SubscriptionsList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<SubscriptionItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.loadSubscriptions();
  }

  Future<void> _reload() async {
    final future = widget.api.loadSubscriptions();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<SubscriptionItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            ),
          );
        }
        final subscriptions = snapshot.requireData;
        if (subscriptions.isEmpty) {
          return const Center(child: Text('还没有订阅内容。'));
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final item = subscriptions[index];
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
                  subtitle: Text(item.kind.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    AppRouteNames.subscription,
                    pathParameters: {'kind': item.kind.name},
                    queryParameters: {'path': item.path, 'title': item.title},
                    extra: item,
                  ),
                ),
              );
            },
          ),
        );
      },
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
