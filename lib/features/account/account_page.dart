import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../features/auth/login_sheet.dart';
import '../../shared/video_feed.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.api});

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
          key: ValueKey(api.sessionStore.cookieHeader),
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
            const Icon(Icons.account_circle_outlined, size: 58),
            const SizedBox(height: 16),
            Text(
              '登录后同步你的收藏与稍后观看内容',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await showLoginSheet(context, api);
              },
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '我的收藏',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: '退出登录',
                onPressed: () async => api.logout(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ),
        Expanded(
          child: VideoFeed(
            api: api,
            loadPage: api.loadFavorites,
            emptyMessage: '收藏夹里还没有视频。',
          ),
        ),
      ],
    );
  }
}
