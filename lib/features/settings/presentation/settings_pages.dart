import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/rule34video_api.dart';
import '../../downloads/data/download_repository.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: AnimatedBuilder(
        animation: api.sessionStore,
        builder: (context, _) {
          final userId = api.sessionStore.currentUserId;
          if (userId == null) {
            return const _CenteredMessage(
              icon: Icons.person_off_outlined,
              title: '当前未登录',
              message: '请返回“我的”页面登录后查看账号信息。',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Rule34Video 账号',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      SelectableText('用户 ID：$userId'),
                    ],
                  ),
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
              const Card(
                child: ListTile(
                  leading: Icon(Icons.language_outlined),
                  title: Text('网站账号资料'),
                  subtitle: Text('编辑资料、修改邮箱和密码仍由网站管理；安全跳转将在后续版本接入。'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _confirmLogout(context, api),
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '外观设置',
      repository: repository,
      builder: (context, settings) => [
        Text('主题模式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<AppThemePreference>(
          segments: AppThemePreference.values
              .map(
                (value) => ButtonSegment<AppThemePreference>(
                  value: value,
                  label: Text(value.label),
                ),
              )
              .toList(growable: false),
          selected: {settings.theme},
          onSelectionChanged: (selection) {
            unawaited(_save(context, repository.setTheme(selection.single)));
          },
        ),
        const SizedBox(height: 16),
        const _InfoCard(
          icon: Icons.contrast,
          text: '纯黑主题会把主要背景改为黑色，适合 OLED 屏幕和低光环境。',
        ),
      ],
    );
  }
}

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '播放设置',
      repository: repository,
      builder: (context, settings) => [
        _QualityTile(
          title: '默认播放清晰度',
          value: settings.playbackQuality,
          onChanged: (value) =>
              _save(context, repository.setPlaybackQuality(value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('打开播放器后自动播放'),
          value: settings.autoplay,
          onChanged: (value) {
            unawaited(_save(context, repository.setAutoplay(value)));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('循环播放'),
          value: settings.loopPlayback,
          onChanged: (value) {
            unawaited(_save(context, repository.setLoopPlayback(value)));
          },
        ),
        const _InfoCard(
          icon: Icons.auto_awesome_outlined,
          text: '“自动”当前选择最高可解析的直链清晰度；后续接入网络质量评估后会动态选择。',
        ),
      ],
    );
  }
}

class ContentSettingsPage extends ConsumerWidget {
  const ContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '内容设置',
      repository: repository,
      builder: (context, settings) => [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('模糊视频封面'),
          subtitle: const Text('首页、搜索和媒体库的视频卡片会模糊显示封面。'),
          value: settings.blurThumbnails,
          onChanged: (value) {
            unawaited(_save(context, repository.setBlurThumbnails(value)));
          },
        ),
        const _InfoCard(
          icon: Icons.visibility_off_outlined,
          text: '隐藏标签和更细粒度的内容过滤需要先建立统一标签规则，后续将基于接口数据接入。',
        ),
      ],
    );
  }
}

class DownloadSettingsPage extends ConsumerWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return _SettingsScaffold(
      title: '下载设置',
      repository: repository,
      builder: (context, settings) => [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('每次下载前询问清晰度'),
          value: settings.askDownloadQuality,
          onChanged: (value) {
            unawaited(_save(context, repository.setAskDownloadQuality(value)));
          },
        ),
        if (!settings.askDownloadQuality)
          _QualityTile(
            title: '默认下载清晰度',
            value: settings.downloadQuality,
            onChanged: (value) =>
                _save(context, repository.setDownloadQuality(value)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('仅使用 Wi-Fi 下载'),
          subtitle: const Text('新建任务会等待符合条件的网络；已存在任务不被追溯修改。'),
          value: settings.wifiOnlyDownloads,
          onChanged: (value) {
            unawaited(_save(context, repository.setWifiOnlyDownloads(value)));
          },
        ),
        const _InfoCard(
          icon: Icons.folder_outlined,
          text: '下载文件默认保存在 App 私有目录，并按用户 ID 隔离。公共目录导出和存储清理将在下载管理下一阶段接入。',
        ),
      ],
    );
  }
}

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  var _clearing = false;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与数据')),
      body: AnimatedBuilder(
        animation: widget.api.sessionStore,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _InfoCard(
              icon: Icons.lock_outline,
              text: '收藏、观看进度、下载记录和文件均按登录后的稳定用户 ID 隔离；未登录状态不创建匿名媒体库。',
            ),
            Card(
              child: ListTile(
                leading: _clearing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
                title: const Text('清理当前账号本地数据'),
                subtitle: const Text('删除观看进度、下载任务、私有下载文件和对应记录；网站收藏不会受影响。'),
                enabled: widget.api.sessionStore.isLoggedIn && !_clearing,
                onTap: widget.api.sessionStore.isLoggedIn && !_clearing
                    ? () => _clearAccountData(downloads)
                    : null,
              ),
            ),
            if (widget.api.sessionStore.isLoggedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _clearing
                    ? null
                    : () => _confirmLogout(context, widget.api),
                icon: const Icon(Icons.logout),
                label: const Text('退出当前账号'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _clearAccountData(DownloadRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理本地数据？'),
        content: const Text(
          '这会取消当前账号的活动下载，并删除观看进度、下载文件和下载记录。网站上的收藏与账号资料不会改变。此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _clearing = true);
    try {
      final result = await repository.clearCurrentUserData();
      if (!mounted) {
        return;
      }
      final message = result.isComplete
          ? '本地数据已清理，共删除 ${result.deletedDownloads} 条下载。'
          : '已删除 ${result.deletedDownloads} 条下载，${result.failedDownloads} 条因文件系统错误而保留。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于 Flule34')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.play_circle_fill, size: 72),
          const SizedBox(height: 12),
          Text(
            'Flule34',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text('版本 1.0.0+1', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const _InfoCard(
            icon: Icons.code,
            text:
                'Flule34 是 Rule34Video 的 Flutter Android 客户端，计划在首个公开版本完成后开源到 GitHub。',
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.system_update_outlined),
              title: Text('更新检查'),
              subtitle: Text('GitHub Release 更新通道尚未配置。'),
              enabled: false,
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('开源许可'),
              subtitle: Text('将在发布流程和依赖许可清单完成后开放。'),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.repository,
    required this.builder,
  });

  final String title;
  final AppSettingsRepository repository;
  final List<Widget> Function(BuildContext context, AppSettings settings)
  builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: builder(context, repository.settings),
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final VideoQualityPreference value;
  final Future<void> Function(VideoQualityPreference value) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<VideoQualityPreference>(
        value: value,
        items: VideoQualityPreference.values
            .map(
              (quality) =>
                  DropdownMenuItem(value: quality, child: Text(quality.label)),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) {
            unawaited(onChanged(next));
          }
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
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

Future<void> _save(BuildContext context, Future<void> operation) async {
  try {
    await operation;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存设置失败：$error')));
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
  if (confirmed == true) {
    Object? logoutError;
    try {
      await api.logout();
    } catch (error) {
      logoutError = error;
    }
    final messenger = context.mounted
        ? ScaffoldMessenger.maybeOf(context)
        : null;
    if (logoutError != null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('网站退出请求失败，但本地登录状态已经清除。')),
      );
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
