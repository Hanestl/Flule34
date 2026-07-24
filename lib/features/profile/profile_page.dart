import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../auth/login_sheet.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) {
        final loggedIn = api.sessionStore.isLoggedIn;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text('我的', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _AccountCard(api: api, loggedIn: loggedIn),
            const SizedBox(height: 24),
            Text('设置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const _SettingsTile(
              icon: Icons.play_circle_outline,
              title: '播放设置',
              subtitle: '清晰度、自动播放、进度记忆与屏幕行为',
            ),
            const _SettingsTile(
              icon: Icons.tune,
              title: '内容设置',
              subtitle: '默认取向、隐藏标签、缩略图与预览策略',
            ),
            const _SettingsTile(
              icon: Icons.download_outlined,
              title: '下载设置',
              subtitle: '默认清晰度、网络约束、并发与存储空间',
            ),
            const _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私与数据',
              subtitle: '历史记录、缓存和账号本地数据',
            ),
            const SizedBox(height: 16),
            Text('支持', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const _SettingsTile(
              icon: Icons.help_outline,
              title: '帮助与反馈',
              subtitle: '使用帮助、问题反馈和诊断信息',
            ),
            const _SettingsTile(
              icon: Icons.info_outline,
              title: '关于 Flule34',
              subtitle: '版本、开源许可、GitHub 与更新检查',
            ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.api, required this.loggedIn});

  final Rule34VideoApi api;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(loggedIn ? Icons.person : Icons.person_outline),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loggedIn ? '已登录' : '尚未登录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loggedIn ? '网站会话有效，个人资料将在账号接口接入后显示。' : '登录后同步媒体库并使用下载功能。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            loggedIn
                ? IconButton(
                    tooltip: '退出登录',
                    onPressed: api.logout,
                    icon: const Icon(Icons.logout),
                  )
                : FilledButton(
                    onPressed: () => showLoginSheet(context, api),
                    child: const Text('登录'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Text('即将接入'),
        enabled: false,
      ),
    );
  }
}
