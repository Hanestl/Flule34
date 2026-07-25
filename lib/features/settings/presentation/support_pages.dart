import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/config/app_build_config.dart';
import '../../../core/services/external_link_service.dart';
import '../data/app_diagnostics_service.dart';
import '../data/app_settings_repository.dart';
import '../data/app_update_service.dart';
import '../domain/app_settings.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('App 设置')),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final settings = repository.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.language_outlined),
                  title: Text('界面语言'),
                  subtitle: Text('简体中文（首个公开版本）'),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '更新通道',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<UpdateChannel>(
                        segments: UpdateChannel.values
                            .map(
                              (channel) => ButtonSegment<UpdateChannel>(
                                value: channel,
                                label: Text(channel.label),
                              ),
                            )
                            .toList(growable: false),
                        selected: {settings.updateChannel},
                        onSelectionChanged: (selection) {
                          unawaited(
                            _saveUpdateChannel(
                              context,
                              repository,
                              selection.single,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppBuildConfig.updateApiUri == null
                            ? '当前开发构建未配置更新源。'
                            : '更新源：${AppBuildConfig.updateApiUri}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('诊断信息'),
                  subtitle: const Text('查看并复制不含凭据的运行环境摘要'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(AppRouteNames.diagnostics),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HelpFeedbackPage extends StatelessWidget {
  const HelpFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            icon: Icons.account_circle_outlined,
            title: '账号与媒体库',
            text: '收藏、稍后观看、历史、播放列表和下载都以登录账号为边界。切换账号后不会混用本地数据。',
          ),
          const _InfoCard(
            icon: Icons.download_outlined,
            title: '下载与导出',
            text: '下载默认进入 App 私有目录；完成后可从下载管理复制到 Downloads/Flule34，并使用外部播放器打开。',
          ),
          const _InfoCard(
            icon: Icons.play_circle_outline,
            title: '播放问题',
            text: '播放源失效时 App 会重新请求视频详情。仍无法播放时，请复制诊断信息并在反馈中说明视频链接和清晰度。',
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('查看诊断信息'),
              subtitle: const Text('复制版本、设备和配置摘要，不包含 Cookie 或密码'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(AppRouteNames.diagnostics),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('打开网站反馈表单'),
              subtitle: const Text('网站要求填写验证码，因此由系统浏览器完成提交'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openExternal(
                context,
                Uri.parse('https://rule34video.com/feedback/'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  Future<DiagnosticReport>? _report;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = AppDiagnosticsService(
      ref.read(appDatabaseProvider),
      ref.read(sessionStoreProvider),
      ref.read(appSettingsRepositoryProvider).settings,
    );
    _report = service.collect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断信息'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DiagnosticReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              message: '无法生成诊断信息：${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final report = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoCard(
                icon: Icons.privacy_tip_outlined,
                title: '隐私说明',
                text: '报告不包含 Cookie、密码、邮箱、用户 ID 值或 Android 设备标识符。发送前仍建议自行检查。',
              ),
              Card(
                child: Column(
                  children: report.entries
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          subtitle: SelectableText(entry.value),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: report.toPlainText()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('诊断信息已复制。')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制诊断信息'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppUpdatePage extends ConsumerStatefulWidget {
  const AppUpdatePage({super.key});

  @override
  ConsumerState<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends ConsumerState<AppUpdatePage> {
  Future<AppUpdateResult>? _result;
  late final AppUpdateService _service;

  @override
  void initState() {
    super.initState();
    _service = AppUpdateService();
    _check();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  void _check() {
    final channel = ref
        .read(appSettingsRepositoryProvider)
        .settings
        .updateChannel;
    _result = _service.check(channel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: FutureBuilder<AppUpdateResult>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              message: '检查更新失败：${snapshot.error}',
              onRetry: () => setState(_check),
            );
          }
          final result = snapshot.requireData;
          final release = result.release;
          final icon = switch (result.status) {
            AppUpdateStatus.updateAvailable => Icons.system_update,
            AppUpdateStatus.upToDate => Icons.check_circle_outline,
            AppUpdateStatus.unconfigured => Icons.settings_suggest_outlined,
            AppUpdateStatus.failed => Icons.error_outline,
          };
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(icon, size: 72),
              const SizedBox(height: 16),
              Text(
                result.message ?? '更新检查已完成。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '当前版本：${result.currentVersion}',
                textAlign: TextAlign.center,
              ),
              if (release != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          release.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('版本：${release.version}'),
                        if (release.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(
                            release.notes!,
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openExternal(context, release.pageUri),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开 GitHub 发布页'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(_check),
                icon: const Icon(Icons.refresh),
                label: const Text('重新检查'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Flule34 不会静默下载或安装 APK。请只从配置的官方发布页获取更新，并在安装前核对签名和 SHA256。',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _saveUpdateChannel(
  BuildContext context,
  AppSettingsRepository repository,
  UpdateChannel channel,
) async {
  try {
    await repository.setUpdateChannel(channel);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存更新通道失败：$error')));
    }
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于 Flule34')),
      body: FutureBuilder<PackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          final package = snapshot.data;
          final version = package == null
              ? '正在读取版本…'
              : '版本 ${package.version}+${package.buildNumber}';
          return ListView(
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
              Text(version, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const _InfoCard(
                icon: Icons.code,
                title: '官方 Flutter 客户端',
                text: 'Flule34 是 Rule34Video 的 Android 客户端，面向侧载和可审计的开源发布流程。',
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('检查更新'),
                  subtitle: Text(
                    AppBuildConfig.updateApiUri == null
                        ? '当前开发构建未配置更新源'
                        : '通过配置的 GitHub Releases 源检查',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(AppRouteNames.update),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('开源许可'),
                  subtitle: const Text('查看 Flule34 与第三方 Flutter 依赖许可'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Flule34',
                    applicationVersion: package == null
                        ? null
                        : '${package.version}+${package.buildNumber}',
                    applicationLegalese: 'Copyright © 2026 Hanestl',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.source_outlined),
                  title: const Text('GitHub 源代码'),
                  subtitle: Text(
                    AppBuildConfig.repositoryUri == null
                        ? '当前构建未配置仓库地址'
                        : AppBuildConfig.repositoryUri.toString(),
                  ),
                  trailing: AppBuildConfig.repositoryUri == null
                      ? null
                      : const Icon(Icons.open_in_new),
                  enabled: AppBuildConfig.repositoryUri != null,
                  onTap: AppBuildConfig.repositoryUri == null
                      ? null
                      : () => _openExternal(
                          context,
                          AppBuildConfig.repositoryUri!,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
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
