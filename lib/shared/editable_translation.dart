import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/translation_provider_models.dart';
import '../core/models/video_models.dart';
import '../core/services/translation_service.dart';

class EditableTranslationRegion extends StatelessWidget {
  const EditableTranslationRegion({
    super.key,
    required this.translationService,
    required this.kind,
    required this.english,
    required this.child,
  });

  final TranslationService translationService;
  final DiscoveryKind kind;
  final String english;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (translationService.shouldAutoTranslateMetadata(kind, english)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          translationService.requestAutomaticMetadataTranslation(kind, english),
        );
      });
    }
    final editable = translationService.canEditDisplayedTranslation(
      kind,
      english,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: editable
          ? () => showTranslationEditDialog(
              context,
              translationService: translationService,
              kind: kind,
              english: english,
            )
          : null,
      child: child,
    );
  }
}

Future<void> showTranslationEditDialog(
  BuildContext context, {
  required TranslationService translationService,
  required DiscoveryKind kind,
  required String english,
}) async {
  final current = translationService.lookupChinese(english, kind: kind);
  final builtIn = translationService.lookupBuiltInChinese(english, kind: kind);
  final result = await showDialog<_TranslationEditResult>(
    context: context,
    builder: (context) => _TranslationEditDialog(
      english: english,
      currentTranslation: current ?? '',
      hasOverride: translationService.hasOverride(kind, english),
      hasBuiltIn: builtIn != null,
      hasLearned: translationService.hasLearnedTranslation(kind, english),
      translate: translationService.hasEnabledProvider
          ? () => translationService.translateWithProvider(kind, english)
          : null,
    ),
  );
  if (result == null || !context.mounted) {
    return;
  }

  try {
    if (result.restoreBuiltIn) {
      await translationService.removeOverride(kind, english);
    } else {
      await translationService.setOverride(kind, english, result.translation!);
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存翻译失败：$error')));
    }
  }
}

final class _TranslationEditResult {
  const _TranslationEditResult.save(this.translation) : restoreBuiltIn = false;

  const _TranslationEditResult.restore()
    : translation = null,
      restoreBuiltIn = true;

  final String? translation;
  final bool restoreBuiltIn;
}

class _TranslationEditDialog extends StatefulWidget {
  const _TranslationEditDialog({
    required this.english,
    required this.currentTranslation,
    required this.hasOverride,
    required this.hasBuiltIn,
    required this.hasLearned,
    required this.translate,
  });

  final String english;
  final String currentTranslation;
  final bool hasOverride;
  final bool hasBuiltIn;
  final bool hasLearned;
  final Future<TranslationProviderResult> Function()? translate;

  @override
  State<_TranslationEditDialog> createState() => _TranslationEditDialogState();
}

class _TranslationEditDialogState extends State<_TranslationEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTranslation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑中文翻译'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('原文', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(widget.english),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '中文翻译',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (widget.hasOverride)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _TranslationEditResult.restore()),
            child: Text(
              widget.hasBuiltIn
                  ? '恢复内置翻译'
                  : widget.hasLearned
                  ? '恢复已学习翻译'
                  : '删除自定义翻译',
            ),
          ),
        if (widget.translate != null)
          TextButton(
            onPressed: _translating ? null : _translate,
            child: _translating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('使用翻译服务'),
          ),
        FilledButton(
          onPressed: _translating ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '中文翻译不能为空');
      return;
    }
    Navigator.of(context).pop(_TranslationEditResult.save(value));
  }

  Future<void> _translate() async {
    setState(() {
      _translating = true;
      _errorText = null;
    });
    try {
      final result = await widget.translate!();
      _controller.text = result.translation;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } catch (error) {
      if (mounted) setState(() => _errorText = '翻译失败：$error');
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }
}

Future<void> showTitleTranslationEditDialog(
  BuildContext context, {
  required TranslationService translationService,
  required String videoId,
  required String english,
  String? videoSlug,
}) async {
  final current =
      translationService.lookupTitleChinese(videoId, raw: english) ?? '';
  final result = await showDialog<_TranslationEditResult>(
    context: context,
    builder: (context) => _TranslationEditDialog(
      english: english,
      currentTranslation: current,
      hasOverride: translationService.hasTitleOverride(videoId, raw: english),
      hasBuiltIn: false,
      hasLearned: translationService.hasLearnedTitle(videoId, raw: english),
      translate: translationService.hasEnabledProvider
          ? () => translationService.translateTitleWithProvider(
              english,
              videoId: videoId,
              videoSlug: videoSlug,
            )
          : null,
    ),
  );
  if (result == null || !context.mounted) return;
  try {
    if (result.restoreBuiltIn) {
      await translationService.removeTitleOverride(videoId);
    } else {
      await translationService.setTitleOverride(
        videoId,
        result.translation!,
        sourceText: english,
        videoSlug: videoSlug,
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存翻译失败：$error')));
    }
  }
}
