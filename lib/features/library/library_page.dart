import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/rule34video_api.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import '../downloads/presentation/downloads_list.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) {
        if (!api.sessionStore.isLoggedIn) {
          return _SignedOut(api: api);
        }
        return _SignedIn(
          key: ValueKey(api.sessionStore.currentUserId),
          api: api,
          downloads: ref.watch(downloadRepositoryProvider),
        );
      },
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined, size: 58),
            const SizedBox(height: 16),
            Text(
              '登录后使用媒体库',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              '收藏、稍后观看、播放列表、观看历史和下载均与网站账号绑定。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => showLoginSheet(context, api),
              icon: const Icon(Icons.login),
              label: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({super.key, required this.api, required this.downloads});

  final Rule34VideoApi api;
  final DownloadRepository downloads;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '媒体库',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '收藏'),
              Tab(text: '下载'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                VideoFeed(
                  loadPage: api.loadFavorites,
                  emptyMessage: '收藏夹里还没有视频。',
                ),
                DownloadsList(repository: downloads),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
