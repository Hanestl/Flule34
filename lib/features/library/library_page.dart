import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';
import 'subscriptions_list.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) {
        if (!api.sessionStore.isLoggedIn) {
          return _SignedOut(api: api);
        }
        return _SignedIn(
          key: ValueKey(api.sessionStore.currentUserId),
          api: api,
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
            const Text('收藏、观看历史和订阅均与网站账号绑定。', textAlign: TextAlign.center),
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
  const _SignedIn({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '收藏'),
              Tab(text: '历史'),
              Tab(text: '订阅'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                VideoFeed(
                  loadPage: api.loadFavorites,
                  emptyMessage: '收藏夹里还没有视频。',
                ),
                VideoFeed(
                  loadPage: api.loadHistory,
                  emptyMessage: '网站观看历史还是空的。',
                ),
                SubscriptionsList(api: api),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
