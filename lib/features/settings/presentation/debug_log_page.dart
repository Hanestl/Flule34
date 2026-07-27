import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/logging/app_log_service.dart';
import '../data/app_diagnostics_service.dart';
import '../data/app_settings_repository.dart';

class DebugLogPage extends ConsumerStatefulWidget {
  const DebugLogPage({super.key});

  @override
  ConsumerState<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends ConsumerState<DebugLogPage> {
  Future<DebugLogSnapshot>? _snapshot;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _snapshot = ref.read(appLogServiceProvider).snapshot();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(appSettingsRepositoryProvider);
    final logs = ref.watch(appLogServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试日志'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _working ? null : () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final settings = repository.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用调试日志'),
                      subtitle: const Text('记录运行异常、公共目录写入、下载任务和本地分类库操作。'),
                      value: settings.debugLoggingEnabled,
                      onChanged: _working
                          ? null
                          : (value) => _setEnabled(
                              repository,
                              logs,
                              value,
                              settings.debugLogRetentionDays,
                            ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('日志保留时间'),
                      subtitle: const Text('到期日志会在启动或修改设置时自动清理。'),
                      trailing: DropdownButton<int>(
                        value: settings.debugLogRetentionDays,
                        items: List.generate(
                          AppLogService.maxRetentionDays,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1} 天'),
                          ),
                        ),
                        onChanged: _working
                            ? null
                            : (value) {
                                if (value != null) {
                                  _setRetention(
                                    repository,
                                    logs,
                                    settings.debugLoggingEnabled,
                                    value,
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: FutureBuilder<DebugLogSnapshot>(
                  future: _snapshot,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final data = snapshot.requireData;
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text('${data.fileCount} 个日志文件'),
                          subtitle: Text('共 ${_formatBytes(data.totalBytes)}'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.visibility_outlined),
                          title: const Text('查看最近日志'),
                          enabled: data.content.isNotEmpty,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: data.content.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => _LogViewerPage(
                                      content: data.content,
                                      truncated: data.truncated,
                                    ),
                                  ),
                                ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.share_outlined),
                          title: const Text('分享诊断信息与日志'),
                          subtitle: const Text('生成一个 UTF-8 文本文件，由系统分享面板发送。'),
                          enabled: !_working,
                          onTap: _working ? null : () => _share(data),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('清除全部日志'),
                          enabled: !_working && data.fileCount > 0,
                          onTap: !_working && data.fileCount > 0
                              ? _clear
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setEnabled(
    AppSettingsRepository repository,
    AppLogService logs,
    bool enabled,
    int retentionDays,
  ) async {
    await _run(() async {
      await repository.setDebugLoggingEnabled(enabled);
      await logs.configure(enabled: enabled, retentionDays: retentionDays);
      if (!enabled) {
        _message('已停止记录新日志；现有日志会保留到到期或手动清除。');
      }
    });
  }

  Future<void> _setRetention(
    AppSettingsRepository repository,
    AppLogService logs,
    bool enabled,
    int retentionDays,
  ) async {
    await _run(() async {
      await repository.setDebugLogRetentionDays(retentionDays);
      await logs.configure(enabled: enabled, retentionDays: retentionDays);
    });
  }

  Future<void> _share(DebugLogSnapshot snapshot) async {
    await _run(() async {
      final settings = ref.read(appSettingsRepositoryProvider).settings;
      final report = await AppDiagnosticsService(
        ref.read(appDatabaseProvider),
        ref.read(sessionStoreProvider),
        settings,
      ).collect();
      final now = DateTime.now();
      final text = StringBuffer()
        ..writeln('Flule34 调试包')
        ..writeln('生成时间：${now.toIso8601String()}')
        ..writeln()
        ..writeln('===== 诊断信息 =====')
        ..writeln(report.toPlainText())
        ..writeln()
        ..writeln('===== 调试日志 =====')
        ..writeln(snapshot.content.isEmpty ? '没有日志。' : snapshot.content);
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Flule34 调试日志',
          text: 'Flule34 调试信息，仅在你主动选择后发送。',
          files: [
            XFile.fromData(
              utf8.encode(text.toString()),
              mimeType: 'text/plain',
            ),
          ],
          fileNameOverrides: ['flule34-debug-${_datePart(now)}.txt'],
        ),
      );
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除全部调试日志？'),
        content: const Text('该操作不会影响下载、账号、本地分类库或其他设置。'),
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
    if (confirmed != true) {
      return;
    }
    await _run(() async {
      await ref.read(appLogServiceProvider).clear();
      _message('调试日志已清除。');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      _message('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _reload();
        });
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _datePart(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}';
  }
}

class _LogViewerPage extends StatelessWidget {
  const _LogViewerPage({required this.content, required this.truncated});

  final String content;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最近调试日志')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (truncated)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('日志过长'),
                subtitle: Text('页面仅显示最近一部分；分享文件同样采用安全长度上限。'),
              ),
            ),
          SelectableText(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
