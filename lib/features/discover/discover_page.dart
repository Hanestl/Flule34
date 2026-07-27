import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/models/video_models.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        SearchBar(
          readOnly: true,
          leading: const Icon(Icons.search),
          hintText: '搜索视频、标签、分类或艺术家',
          onTap: () => context.pushNamed(AppRouteNames.search),
        ),
        const SizedBox(height: 24),
        Text('探索内容', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _DiscoveryEntry(
          icon: Icons.tag,
          title: '标签',
          description: '按标签和内容主题探索',
          onTap: () => _openDirectory(context, DiscoveryKind.tag),
        ),
        _DiscoveryEntry(
          icon: Icons.category_outlined,
          title: '分类',
          description: '浏览站点内容分类',
          onTap: () => _openDirectory(context, DiscoveryKind.category),
        ),
        _DiscoveryEntry(
          icon: Icons.brush_outlined,
          title: '艺术家',
          description: '查找艺术家页面',
          onTap: () => _openDirectory(context, DiscoveryKind.model),
        ),
        _DiscoveryEntry(
          icon: Icons.leaderboard_outlined,
          title: '排行榜',
          description: '热门视频、高评分视频和艺术家排行',
          onTap: () => context.pushNamed(AppRouteNames.rankings),
        ),
        _DiscoveryEntry(
          icon: Icons.casino_outlined,
          title: '随机探索',
          description: '每次加载一批随机视频',
          onTap: () => context.pushNamed(
            AppRouteNames.collection,
            pathParameters: {'kind': DiscoveryKind.tag.name, 'id': 'random'},
            extra: const ContentCollectionItem(
              id: 'random',
              title: '随机探索',
              path: '/latest-updates/',
              kind: DiscoveryKind.tag,
            ),
            queryParameters: const {'sort': 'random'},
          ),
        ),
      ],
    );
  }

  void _openDirectory(BuildContext context, DiscoveryKind kind) {
    final spec = DiscoveryDirectorySpec(
      title: kind.label,
      path: '/${kind.pathSegment}/',
      kind: kind,
    );
    context.pushNamed(
      AppRouteNames.discoveryDirectory,
      pathParameters: {'kind': kind.name},
      extra: spec,
    );
  }
}

class _DiscoveryEntry extends StatelessWidget {
  const _DiscoveryEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
