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
  late Future<List<ContentCollectionItem>> _future;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.api.loadDiscoveryDirectory(widget.spec);
  }

  void _reload() {
    setState(() => _future = widget.api.loadDiscoveryDirectory(widget.spec));
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
              hintText: '在${widget.spec.title}中筛选',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ContentCollectionItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _DirectoryMessage(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }
                final normalized = _query.toLowerCase();
                final items = snapshot.requireData
                    .where(
                      (item) =>
                          normalized.isEmpty ||
                          item.title.toLowerCase().contains(normalized),
                    )
                    .toList(growable: false);
                if (items.isEmpty) {
                  return const Center(child: Text('没有匹配的内容。'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
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
                          pathParameters: {
                            'kind': item.kind.name,
                            'id': item.id,
                          },
                          extra: item,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
