import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/account_models.dart';
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
            const SizedBox(height: 4),
            Text(
              '管理账号、隐私和 Flule34 的使用方式',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _AccountCard(
              key: ValueKey(api.sessionStore.currentUserId),
              api: api,
              loggedIn: loggedIn,
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '偏好设置'),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: '外观设置',
              subtitle: '浅色、深色或跟随系统',
              onTap: () => context.pushNamed(AppRouteNames.appearanceSettings),
            ),
            _SettingsTile(
              icon: Icons.play_circle_outline,
              title: '播放设置',
              subtitle: '清晰度、网络策略、常亮与全屏方向',
              onTap: () => context.pushNamed(AppRouteNames.playbackSettings),
            ),
            _SettingsTile(
              icon: Icons.tune,
              title: '内容设置',
              subtitle: '内容取向、预览、封面与隐藏关键词',
              onTap: () => context.pushNamed(AppRouteNames.contentSettings),
            ),
            _SettingsTile(
              icon: Icons.download_outlined,
              title: '下载设置',
              subtitle: '清晰度、Wi-Fi、并发数与存储说明',
              onTap: () => context.pushNamed(AppRouteNames.downloadSettings),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: '隐私与支持'),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私与数据',
              subtitle: '账号隔离、本地数据和退出登录',
              onTap: () => context.pushNamed(AppRouteNames.privacySettings),
            ),
            _SettingsTile(
              icon: Icons.settings_applications_outlined,
              title: 'App 设置',
              subtitle: '语言、更新通道和诊断信息',
              onTap: () => context.pushNamed(AppRouteNames.appSettings),
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              title: '帮助与反馈',
              subtitle: '使用帮助、问题反馈和诊断信息',
              onTap: () => context.pushNamed(AppRouteNames.helpFeedback),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: '关于 Flule34',
              subtitle: '版本、开源计划、许可与更新状态',
              onTap: () => context.pushNamed(AppRouteNames.about),
            ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard({super.key, required this.api, required this.loggedIn});

  final Rule34VideoApi api;
  final bool loggedIn;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  Future<MemberProfile>? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      _profile = widget.api.loadCurrentUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemberProfile>(
      future: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final avatarUrl = profile?.avatarUrl;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.loggedIn
                ? () => context.pushNamed(AppRouteNames.account)
                : () => showLoginSheet(context, widget.api),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: avatarUrl == null
                        ? null
                        : CachedNetworkImageProvider(avatarUrl),
                    child: avatarUrl == null
                        ? Icon(
                            widget.loggedIn
                                ? Icons.person
                                : Icons.person_outline,
                            size: 32,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.loggedIn
                              ? profile?.displayName ?? 'Rule34Video 账号'
                              : '尚未登录',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.loggedIn
                              ? '用户 ID：${widget.api.sessionStore.currentUserId}'
                              : '登录后同步媒体库并使用下载功能。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (widget.loggedIn) ...[
                          const SizedBox(height: 4),
                          Text(
                            snapshot.hasError ? '资料暂不可用' : '账号数据已隔离',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  widget.loggedIn
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.login),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
