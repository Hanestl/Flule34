import 'package:flutter/material.dart';

import '../core/models/translation_models.dart';
import '../core/models/video_models.dart';
import '../core/services/translation_service.dart';

class TranslatedMetadataText extends StatelessWidget {
  const TranslatedMetadataText({
    super.key,
    required this.translationService,
    required this.kind,
    required this.original,
    this.style,
    this.textAlign,
    this.maxLines,
    this.prefix = '',
    this.suffix = '',
    this.constrainToScreen = false,
  });

  final TranslationService translationService;
  final DiscoveryKind kind;
  final String original;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final String prefix;
  final String suffix;
  final bool constrainToScreen;

  @override
  Widget build(BuildContext context) {
    return LocalizedTranslationText(
      value: translationService.resolveMetadata(kind, original),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      prefix: prefix,
      suffix: suffix,
      constrainToScreen: constrainToScreen,
    );
  }
}

class LocalizedTranslationText extends StatelessWidget {
  const LocalizedTranslationText({
    super.key,
    required this.value,
    this.style,
    this.textAlign,
    this.maxLines,
    this.prefix = '',
    this.suffix = '',
    this.constrainToScreen = false,
  });

  final LocalizedTranslation value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final String prefix;
  final String suffix;
  final bool constrainToScreen;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final chinese = value.translation?.trim();
    final bilingual =
        value.mode == TranslationDisplayMode.bilingual &&
        chinese != null &&
        chinese.isNotEmpty;
    final child = bilingual
        ? Semantics(
            label: '$prefix${value.original}；中文译文：$chinese$suffix',
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                style: effectiveStyle,
                children: [
                  TextSpan(text: '$prefix${value.original}'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 1,
                        height: (effectiveStyle.fontSize ?? 14) * 1.2,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  TextSpan(text: '$chinese$suffix'),
                ],
              ),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: maxLines == null
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              softWrap: true,
            ),
          )
        : Text(
            '$prefix${value.plainText}$suffix',
            style: effectiveStyle,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: maxLines == null
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            softWrap: true,
          );
    if (!constrainToScreen) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 72).clamp(120, 560),
      ),
      child: child,
    );
  }
}
