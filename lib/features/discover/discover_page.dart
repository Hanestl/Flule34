import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text('发现', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SearchBar(
          readOnly: true,
          leading: const Icon(Icons.search),
          hintText: '搜索视频、标签、分类或艺术家',
          onTap: () => context.pushNamed(AppRouteNames.search),
        ),
        const SizedBox(height: 24),
        Text('探索内容', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const _DiscoveryEntry(
          icon: Icons.tag,
          title: '标签',
          description: '按热门标签和内容主题探索',
        ),
        const _DiscoveryEntry(
          icon: Icons.category_outlined,
          title: '分类',
          description: '浏览站点的完整内容分类',
        ),
        const _DiscoveryEntry(
          icon: Icons.brush_outlined,
          title: '艺术家与模型',
          description: '查找艺术家、作者和模型页面',
        ),
        const _DiscoveryEntry(
          icon: Icons.live_tv_outlined,
          title: '频道',
          description: '浏览站点频道与专题内容',
        ),
        const _DiscoveryEntry(
          icon: Icons.leaderboard_outlined,
          title: '排行榜',
          description: '查看热门视频与艺术家排行',
        ),
        const _DiscoveryEntry(
          icon: Icons.casino_outlined,
          title: '随机探索',
          description: '从站点内容中随机发现视频',
        ),
      ],
    );
  }
}

class _DiscoveryEntry extends StatelessWidget {
  const _DiscoveryEntry({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Text('即将接入'),
        enabled: false,
      ),
    );
  }
}
