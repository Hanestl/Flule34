import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/models/video_models.dart';

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RankingTile(
            icon: Icons.local_fire_department_outlined,
            title: '热门视频',
            subtitle: '按观看量浏览热门内容',
            onTap: () => _openVideos(
              context,
              const ContentCollectionItem(
                id: 'popular',
                title: '热门视频',
                path: '/most-popular/',
                kind: DiscoveryKind.tag,
              ),
              VideoSort.mostViewed,
            ),
          ),
          _RankingTile(
            icon: Icons.star_outline,
            title: '高评分视频',
            subtitle: '浏览站点评分最高的视频',
            onTap: () => _openVideos(
              context,
              const ContentCollectionItem(
                id: 'top-rated',
                title: '高评分视频',
                path: '/top-rated/',
                kind: DiscoveryKind.tag,
              ),
              VideoSort.topRated,
            ),
          ),
          _RankingTile(
            icon: Icons.brush_outlined,
            title: '艺术家排行榜',
            subtitle: '历史累计最高评分艺术家',
            onTap: () => context.pushNamed(
              AppRouteNames.discoveryDirectory,
              pathParameters: {'kind': DiscoveryKind.model.name},
              extra: const DiscoveryDirectorySpec(
                title: '艺术家排行榜',
                path: '/top-model/',
                kind: DiscoveryKind.model,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openVideos(
    BuildContext context,
    ContentCollectionItem item,
    VideoSort sort,
  ) {
    context.pushNamed(
      AppRouteNames.collection,
      pathParameters: {'kind': item.kind.name, 'id': item.id},
      queryParameters: {'sort': sort.name},
      extra: item,
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
