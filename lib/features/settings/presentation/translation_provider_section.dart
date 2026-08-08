import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/translation_provider_models.dart';
import '../../../core/security/error_redaction.dart';
import '../../../core/services/external_link_service.dart';

class TranslationProviderSection extends ConsumerWidget {
  const TranslationProviderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(translationProviderRepositoryProvider);
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final providers = repository.providers;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '翻译服务',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editProvider(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('新建'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '自动或手动翻译时，每次只发送当前标题、标签或分类。服务按当前顺序依次尝试，失败后自动使用下一项。建议优先使用 AI 翻译，结果通常更自然、准确。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (providers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('尚未配置翻译服务。内置词表和用户手动译文仍可正常使用。'),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                // 卡片自身已经显式固定了背景和圆角。直接复用原卡片，
                // 避免拖拽代理额外包裹装饰后产生错位高亮框。
                proxyDecorator: (child, _, _) => child,
                itemCount: providers.length,
                onReorderItem: repository.reorder,
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(provider.id),
                    index: index,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                      ),
                      child: Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        surfaceTintColor: Colors.transparent,
                        child: ListTile(
                          tileColor: Colors.transparent,
                          leading: Switch(
                            value: provider.enabled,
                            onChanged: (value) =>
                                repository.setEnabled(provider.id, value),
                          ),
                          title: Text(provider.name),
                          subtitle: Text(provider.protocol.label),
                          onTap: () =>
                              _editProvider(context, ref, provider: provider),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) =>
                                _handleAction(context, ref, provider, value),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'test', child: Text('测试连接')),
                              PopupMenuItem(value: 'edit', child: Text('编辑')),
                              PopupMenuItem(value: 'copy', child: Text('复制')),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    TranslationProviderConfig provider,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _editProvider(context, ref, provider: provider);
      case 'test':
        try {
          await ref
              .read(translationProviderRouterProvider)
              .testProvider(provider);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${provider.name} 连接成功')));
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('连接失败：${redactSensitiveText(error)}')),
            );
          }
        }
      case 'copy':
        try {
          await ref
              .read(translationProviderRepositoryProvider)
              .duplicateAfter(provider.id);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('复制翻译服务失败：${redactSensitiveText(error)}')),
            );
          }
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除翻译服务？'),
            content: Text('将删除“${provider.name}”及其本机密钥。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await ref
                .read(translationProviderRepositoryProvider)
                .remove(provider.id);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('删除翻译服务失败：${redactSensitiveText(error)}'),
                ),
              );
            }
          }
        }
    }
  }

  Future<void> _editProvider(
    BuildContext context,
    WidgetRef ref, {
    TranslationProviderConfig? provider,
  }) async {
    final repository = ref.read(translationProviderRepositoryProvider);
    final result = await showDialog<_ProviderEditResult>(
      context: context,
      builder: (context) => _ProviderEditDialog(provider: provider),
    );
    if (result == null) return;
    try {
      await repository.upsert(result.provider, apiKey: result.apiKey);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存翻译服务失败：${redactSensitiveText(error)}')),
        );
      }
    }
  }
}

final class _ProviderEditResult {
  const _ProviderEditResult(this.provider, this.apiKey);

  final TranslationProviderConfig provider;
  final String? apiKey;
}

class _ProviderEditDialog extends ConsumerStatefulWidget {
  const _ProviderEditDialog({this.provider});

  final TranslationProviderConfig? provider;

  @override
  ConsumerState<_ProviderEditDialog> createState() =>
      _ProviderEditDialogState();
}

class _ProviderEditDialogState extends ConsumerState<_ProviderEditDialog> {
  late TranslationProviderProtocol _protocol;
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late final TextEditingController _email;
  String? _error;
  bool _loadingModels = false;
  late String _deepLPlan;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _protocol = provider?.protocol ?? TranslationProviderProtocol.openAiChat;
    _name = TextEditingController(
      text: provider?.name ?? _protocol.defaultName,
    );
    _baseUrl = TextEditingController(
      text: provider?.baseUrl ?? _protocol.defaultBaseUrl,
    );
    _model = TextEditingController(text: provider?.model ?? '');
    _apiKey = TextEditingController();
    _email = TextEditingController(text: provider?.email ?? '');
    _deepLPlan = switch (provider?.baseUrl) {
      'https://api.deepl.com' => 'pro',
      'https://api-free.deepl.com' || null => 'free',
      _ => 'legacy',
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(520.0, MediaQuery.sizeOf(context).width - 48);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(widget.provider == null ? '新建翻译服务' : '编辑翻译服务'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TranslationProviderProtocol>(
                initialValue: _protocol,
                decoration: const InputDecoration(labelText: '接口类型'),
                items: TranslationProviderProtocol.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    final oldDefault = _protocol.defaultBaseUrl;
                    _protocol = value;
                    if (_baseUrl.text.isEmpty || _baseUrl.text == oldDefault) {
                      _baseUrl.text = value.defaultBaseUrl;
                    }
                    if (widget.provider == null) _name.text = value.defaultName;
                    if (value == TranslationProviderProtocol.deepL) {
                      _deepLPlan = 'free';
                      _baseUrl.text = value.defaultBaseUrl;
                    } else if (value.hasFixedBaseUrl) {
                      _baseUrl.text = value.defaultBaseUrl;
                    }
                  });
                },
              ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '服务名称'),
              ),
              if (_protocol == TranslationProviderProtocol.deepL)
                DropdownButtonFormField<String>(
                  initialValue: _deepLPlan,
                  decoration: const InputDecoration(labelText: 'DeepL 套餐与端点'),
                  items: [
                    const DropdownMenuItem(
                      value: 'free',
                      child: Text('API Developer / API Free'),
                    ),
                    const DropdownMenuItem(
                      value: 'pro',
                      child: Text('API Growth / API Pro'),
                    ),
                    if (_deepLPlan == 'legacy')
                      const DropdownMenuItem(
                        value: 'legacy',
                        child: Text('旧版自定义端点'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _deepLPlan = value;
                      if (value == 'free') {
                        _baseUrl.text = 'https://api-free.deepl.com';
                      } else if (value == 'pro') {
                        _baseUrl.text = 'https://api.deepl.com';
                      }
                    });
                  },
                ),
              TextField(
                controller: _baseUrl,
                readOnly: _protocol.hasFixedBaseUrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: '基址',
                  suffixIcon: _protocol.helpUri == null
                      ? null
                      : IconButton(
                          tooltip: '打开官方网站',
                          onPressed: _openProviderHelp,
                          icon: const Icon(Icons.open_in_new),
                        ),
                ),
              ),
              if (_protocol.requiresApiKey)
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    helperText: widget.provider == null
                        ? null
                        : _requiresFreshApiKey
                        ? '接口类型或服务器已改变，请重新填写密钥'
                        : '留空表示保留原密钥',
                  ),
                ),
              if (_protocol.requiresModel)
                TextField(
                  controller: _model,
                  decoration: InputDecoration(
                    labelText: '模型名',
                    suffixIcon: IconButton(
                      tooltip: '拉取模型列表',
                      onPressed: _loadingModels ? null : _loadModels,
                      icon: _loadingModels
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                    ),
                  ),
                ),
              if (_protocol == TranslationProviderProtocol.myMemory)
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱（可选）',
                    helperText: 'MyMemory 可用邮箱标识提高免费额度。',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (name.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        (_protocol.requiresModel && _model.text.trim().isEmpty) ||
        (_protocol.requiresApiKey &&
            (widget.provider == null || _requiresFreshApiKey) &&
            _apiKey.text.trim().isEmpty)) {
      setState(() => _error = '请完整填写名称、基址、模型和密钥。');
      return;
    }
    final id =
        widget.provider?.id ??
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(9999)}';
    Navigator.pop(
      context,
      _ProviderEditResult(
        TranslationProviderConfig(
          id: id,
          name: name,
          protocol: _protocol,
          baseUrl: baseUrl,
          model: _model.text.trim(),
          email: _email.text.trim(),
          enabled: widget.provider?.enabled ?? true,
        ),
        _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
      ),
    );
  }

  Future<void> _loadModels() async {
    final baseUrl = _baseUrl.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() => _error = '请先填写有效基址。');
      return;
    }
    setState(() {
      _loadingModels = true;
      _error = null;
    });
    try {
      final provider = TranslationProviderConfig(
        id: widget.provider?.id ?? 'unsaved-provider',
        name: _name.text.trim().isEmpty
            ? _protocol.defaultName
            : _name.text.trim(),
        protocol: _protocol,
        baseUrl: baseUrl,
        model: _model.text.trim(),
        email: _email.text.trim(),
        enabled: true,
      );
      final models = await ref
          .read(translationProviderRouterProvider)
          .listModels(provider, apiKeyOverride: _apiKey.text);
      if (!mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择模型'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(models[index]),
                onTap: () => Navigator.pop(context, models[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('继续手动填写'),
            ),
          ],
        ),
      );
      if (selected != null && mounted) {
        setState(() => _model.text = selected);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '模型列表拉取失败：$error');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _openProviderHelp() async {
    final uri = _protocol.helpUri;
    if (uri == null) return;
    try {
      await ExternalLinkService.open(uri);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  bool get _requiresFreshApiKey {
    final previous = widget.provider;
    if (previous == null || !_protocol.requiresApiKey) return false;
    if (previous.protocol != _protocol) return true;
    final previousUri = Uri.tryParse(previous.baseUrl.trim());
    final nextUri = Uri.tryParse(_baseUrl.text.trim());
    if (previousUri == null || nextUri == null) return true;
    return previousUri.scheme.toLowerCase() != nextUri.scheme.toLowerCase() ||
        previousUri.host.toLowerCase() != nextUri.host.toLowerCase() ||
        previousUri.port != nextUri.port;
  }
}
