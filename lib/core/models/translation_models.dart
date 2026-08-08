import 'package:flutter/foundation.dart';

enum TranslationDisplayMode {
  originalOnly('原文'),
  chineseOnly('中文'),
  bilingual('双语');

  const TranslationDisplayMode(this.label);

  final String label;
}

enum TranslationDisplayTarget {
  title('标题'),
  category('分类'),
  tag('标签');

  const TranslationDisplayTarget(this.label);

  final String label;
}

enum AutomaticTranslationTarget {
  title('标题'),
  category('分类'),
  tag('标签');

  const AutomaticTranslationTarget(this.label);

  final String label;
}

@immutable
final class LocalizedTranslation {
  const LocalizedTranslation({
    required this.original,
    required this.translation,
    required this.mode,
  });

  final String original;
  final String? translation;
  final TranslationDisplayMode mode;

  bool get hasTranslation => translation?.trim().isNotEmpty ?? false;

  String get plainText {
    final chinese = translation?.trim();
    if (mode == TranslationDisplayMode.originalOnly ||
        chinese == null ||
        chinese.isEmpty) {
      return original;
    }
    if (mode == TranslationDisplayMode.chineseOnly) return chinese;
    return '$original | $chinese';
  }
}

@immutable
final class TranslationEntry {
  const TranslationEntry({required this.english, required this.chinese});

  final String english;
  final String chinese;
}

enum TranslationAliasSource { userOverride, builtIn, learned }

enum TranslationCatalogSource {
  userOverride('用户'),
  learned('API'),
  builtIn('内置');

  const TranslationCatalogSource(this.label);

  final String label;
}

enum TranslationCatalogKind {
  title('标题'),
  category('分类'),
  tag('标签');

  const TranslationCatalogKind(this.label);

  final String label;
}

enum TranslationCatalogSort {
  updatedDesc('按最近更新排序'),
  originalAsc('按原文排序'),
  translationAsc('按中文排序'),
  source('按来源排序');

  const TranslationCatalogSort(this.label);

  final String label;
}

@immutable
final class TranslationCatalogItem {
  const TranslationCatalogItem({
    required this.kind,
    required this.canonicalName,
    required this.sourceText,
    required this.videoSlug,
    required this.builtInTranslation,
    required this.learnedTranslation,
    required this.userTranslation,
    required this.learnedProviderName,
    required this.learnedCreatedAt,
    required this.learnedUpdatedAt,
    required this.userUpdatedAt,
    required this.protectLearnedFromBuiltIn,
  });

  final TranslationCatalogKind kind;
  final String canonicalName;
  final String sourceText;
  final String? videoSlug;
  final String? builtInTranslation;
  final String? learnedTranslation;
  final String? userTranslation;
  final String? learnedProviderName;
  final DateTime? learnedCreatedAt;
  final DateTime? learnedUpdatedAt;
  final DateTime? userUpdatedAt;
  final bool protectLearnedFromBuiltIn;

  bool get hasBuiltIn => builtInTranslation?.isNotEmpty ?? false;
  bool get hasLearned => learnedTranslation?.isNotEmpty ?? false;
  bool get hasUserOverride => userTranslation?.isNotEmpty ?? false;

  String get effectiveTranslation =>
      userTranslation ??
      (protectLearnedFromBuiltIn ? learnedTranslation : null) ??
      builtInTranslation ??
      learnedTranslation ??
      '';

  TranslationCatalogSource get effectiveSource {
    if (hasUserOverride) return TranslationCatalogSource.userOverride;
    if (protectLearnedFromBuiltIn && hasLearned) {
      return TranslationCatalogSource.learned;
    }
    if (hasBuiltIn) return TranslationCatalogSource.builtIn;
    return TranslationCatalogSource.learned;
  }

  Set<TranslationCatalogSource> get sources => {
    if (hasUserOverride) TranslationCatalogSource.userOverride,
    if (hasLearned) TranslationCatalogSource.learned,
    if (hasBuiltIn) TranslationCatalogSource.builtIn,
  };

  DateTime? get updatedAt {
    final dates = [
      userUpdatedAt,
      learnedUpdatedAt,
    ].whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort((left, right) => right.compareTo(left));
    return dates.first;
  }
}

enum TranslationMatchKind { exact, prefix, contains }

@immutable
final class TranslatedTagSuggestion {
  const TranslatedTagSuggestion({
    required this.english,
    required this.displayChinese,
    required this.matchedAlias,
    required this.aliasSource,
    required this.matchKind,
  });

  final String english;
  final String displayChinese;
  final String matchedAlias;
  final TranslationAliasSource aliasSource;
  final TranslationMatchKind matchKind;

  bool get matchedAlternateAlias => matchedAlias != displayChinese;
}

@immutable
final class TranslatedTitleSuggestion {
  const TranslatedTitleSuggestion({
    required this.videoId,
    required this.slug,
    required this.english,
    required this.displayChinese,
    required this.aliasSource,
    required this.matchKind,
  });

  final String videoId;
  final String slug;
  final String english;
  final String displayChinese;
  final TranslationAliasSource aliasSource;
  final TranslationMatchKind matchKind;
}
