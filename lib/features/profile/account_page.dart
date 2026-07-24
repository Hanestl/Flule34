import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/account_models.dart';
import '../../core/services/external_link_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<MemberProfile>? _profile;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (widget.api.sessionStore.isLoggedIn) {
      _profile = widget.api.loadCurrentUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: AnimatedBuilder(
        animation: widget.api.sessionStore,
        builder: (context, _) {
          final userId = widget.api.sessionStore.currentUserId;
          if (userId == null) {
            return const _CenteredMessage(
              icon: Icons.person_off_outlined,
              title: '当前未登录',
              message: '请返回“我的”页面登录后查看账号信息。',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _profile;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<MemberProfile>(
                  future: _profile,
                  builder: (context, snapshot) => _ProfileCard(
                    userId: userId,
                    profile: snapshot.data,
                    loading:
                        snapshot.connectionState == ConnectionState.waiting,
                    error: snapshot.hasError,
                    onRetry: () => setState(_reload),
                  ),
                ),
                const SizedBox(height: 16),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('会话安全'),
                    subtitle: Text(
                      '登录 Cookie 和稳定用户 ID 保存在 Android 安全存储中，密码不会由 App 保存。',
                    ),
                  ),
                ),
                _WebsiteTile(
                  icon: Icons.person_outline,
                  title: '网站个人主页',
                  subtitle: '查看公开资料、上传内容和公开收藏',
                  uri: Uri.parse('https://rule34video.com/members/$userId/'),
                ),
                _WebsiteTile(
                  icon: Icons.edit_outlined,
                  title: '编辑资料',
                  subtitle: '在网站中修改头像、名称和公开资料',
                  uri: Uri.parse('https://rule34video.com/edit-profile/'),
                ),
                _WebsiteTile(
                  icon: Icons.alternate_email,
                  title: '修改邮箱',
                  subtitle: '由网站验证身份并处理邮箱变更',
                  uri: Uri.parse('https://rule34video.com/change-email/'),
                ),
                _WebsiteTile(
                  icon: Icons.password_outlined,
                  title: '修改密码',
                  subtitle: '由网站验证身份并更新账号密码',
                  uri: Uri.parse('https://rule34video.com/change-password/'),
                ),
                _WebsiteTile(
                  icon: Icons.video_library_outlined,
                  title: '我的上传',
                  subtitle: '在网站中管理已上传的视频',
                  uri: Uri.parse('https://rule34video.com/my/videos/'),
                ),
                _WebsiteTile(
                  icon: Icons.mail_outline,
                  title: '站内消息',
                  subtitle: '打开网站消息中心',
                  uri: Uri.parse('https://rule34video.com/my/messages/'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _confirmLogout(context, widget.api),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.userId,
    required this.profile,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final String userId;
  final MemberProfile? profile;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundImage: avatarUrl == null
                  ? null
                  : CachedNetworkImageProvider(avatarUrl),
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              profile?.displayName ?? 'Rule34Video 账号',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            SelectableText('用户 ID：$userId'),
            if (profile?.subscribersLabel case final subscribers?) ...[
              const SizedBox(height: 4),
              Text(subscribers, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (error) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('资料加载失败，重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebsiteTile extends StatelessWidget {
  const _WebsiteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uri,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openExternal(context, uri),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, Uri uri) async {
  try {
    await ExternalLinkService.open(uri);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<void> _confirmLogout(BuildContext context, Rule34VideoApi api) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('退出登录？'),
      content: const Text('活动下载会被取消；已完成文件和记录会保留，并在重新登录该账号后显示。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('退出'),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  Object? logoutError;
  try {
    await api.logout();
  } catch (error) {
    logoutError = error;
  }
  if (!context.mounted) {
    return;
  }
  if (logoutError != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('网站退出请求失败，但本地登录状态已经清除。')));
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}
