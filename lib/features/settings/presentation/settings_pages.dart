import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/rule34video_api.dart';
import '../../../core/models/video_models.dart';
import '../../playback/data/playback_repository.dart';
import '../../search/data/search_history_repository.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

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
        Text('首页视频布局', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<HomeVideoLayout>(
          segments: HomeVideoLayout.values
              .map(
                (value) => ButtonSegment<HomeVideoLayout>(
                  value: value,
                  label: Text(value.label),
                ),
              )
              .toList(growable: false),
          selected: {settings.homeVideoLayout},
          onSelectionChanged: (selection) {
            unawaited(
              _save(context, repository.setHomeVideoLayout(selection.single)),
            );
          },
        ),
        const SizedBox(height: 16),
        const _InfoCard(
          icon: Icons.contrast,
          text: '浅色使用白色与浅灰背景；深色使用中性灰背景；跟随系统会随手机的夜间模式自动切换。',
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('网络播放策略'),
          subtitle: Text(settings.networkPlaybackPolicy.description),
          trailing: DropdownButton<NetworkPlaybackPolicy>(
            value: settings.networkPlaybackPolicy,
            items: NetworkPlaybackPolicy.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  _save(context, repository.setNetworkPlaybackPolicy(value)),
                );
              }
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('循环播放'),
          value: settings.loopPlayback,
          onChanged: (value) {
            unawaited(_save(context, repository.setLoopPlayback(value)));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('播放时保持屏幕常亮'),
          subtitle: const Text('仅在视频正在播放时生效，暂停或离开页面后自动恢复。'),
          value: settings.keepScreenAwake,
          onChanged: (value) {
            unawaited(_save(context, repository.setKeepScreenAwake(value)));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('后台播放'),
          subtitle: const Text('开启后，切换应用或关闭屏幕时继续播放声音。'),
          value: settings.backgroundPlayback,
          onChanged: (value) {
            unawaited(_save(context, repository.setBackgroundPlayback(value)));
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('全屏方向'),
          trailing: DropdownButton<FullscreenOrientationPreference>(
            value: settings.fullscreenOrientation,
            items: FullscreenOrientationPreference.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  _save(context, repository.setFullscreenOrientation(value)),
                );
              }
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('记忆播放进度'),
          subtitle: const Text('仅登录后按账号保存；关闭后不读取或写入已有进度。'),
          value: settings.rememberPlaybackProgress,
          onChanged: (value) {
            unawaited(
              _save(context, repository.setRememberPlaybackProgress(value)),
            );
          },
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('首页默认内容取向'),
          trailing: DropdownButton<ContentOrientation>(
            value: settings.defaultOrientation,
            items: ContentOrientation.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  _save(context, repository.setDefaultOrientation(value)),
                );
              }
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('模糊视频封面'),
          subtitle: const Text('首页、搜索和媒体库的视频卡片会模糊显示封面。'),
          value: settings.blurThumbnails,
          onChanged: (value) {
            unawaited(_save(context, repository.setBlurThumbnails(value)));
          },
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('同时下载任务数'),
          trailing: DropdownButton<int>(
            value: settings.downloadConcurrentTasks,
            items: [1, 2, 3, 4]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value')),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  _save(context, repository.setDownloadConcurrentTasks(value)),
                );
              }
            },
          ),
        ),
        const _InfoCard(
          icon: Icons.folder_outlined,
          text: '视频保存路径：Download/Flule34',
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
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    final searchHistory = ref.watch(searchHistoryRepositoryProvider);
    final playback = ref.watch(playbackRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与数据')),
      body: ListenableBuilder(
        listenable: settingsRepository,
        builder: (context, _) => AnimatedBuilder(
          animation: widget.api.sessionStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保存搜索历史'),
                subtitle: const Text('仅登录后按账号保存；关闭后不再记录新搜索。'),
                value: settingsRepository.settings.saveSearchHistory,
                onChanged: (value) => unawaited(
                  _save(
                    context,
                    settingsRepository.setSaveSearchHistory(value),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: const Text('清除当前账号搜索历史'),
                  enabled: widget.api.sessionStore.isLoggedIn && !_clearing,
                  onTap: widget.api.sessionStore.isLoggedIn && !_clearing
                      ? () => _clearSearchHistory(searchHistory)
                      : null,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('清除图片缓存'),
                  subtitle: const Text('不会删除下载的视频或账号数据。'),
                  onTap: _clearing ? null : _clearImageCache,
                ),
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
                  subtitle: const Text(
                    '删除当前账号的搜索历史与观看进度；公共目录中的下载文件和下载任务不会受影响。',
                  ),
                  enabled: widget.api.sessionStore.isLoggedIn && !_clearing,
                  onTap: widget.api.sessionStore.isLoggedIn && !_clearing
                      ? () => _clearAccountData(playback, searchHistory)
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
      ),
    );
  }

  Future<void> _clearImageCache() async {
    setState(() => _clearing = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await DefaultCacheManager().emptyCache();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片缓存已清除。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清除图片缓存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _clearSearchHistory(
    SearchHistoryRepository searchHistory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除搜索历史？'),
        content: const Text('只会删除当前账号在这台设备上的搜索记录。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await searchHistory.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索历史已清除。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清除搜索历史失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _clearAccountData(
    PlaybackRepository playback,
    SearchHistoryRepository searchHistory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理本地数据？'),
        content: const Text(
          '这会删除当前账号在本机保存的观看进度和搜索历史。下载文件、下载任务、网站收藏与账号资料不会改变。此操作无法撤销。',
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
      await playback.clearCurrentAccount();
      await searchHistory.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前账号的本地数据已清理。')));
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
      content: const Text('下载属于本机功能，退出登录不会取消下载或删除公共目录中的文件。'),
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
