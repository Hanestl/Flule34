import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/models/translation_models.dart';
import 'package:flule34/features/settings/presentation/translation_catalog_page.dart';

void main() {
  test('最近更新排序把 API 和用户时间排在纯内置词条之前', () {
    final items =
        [
          _item(name: 'built-in', builtIn: '内置'),
          _item(
            name: 'older-api',
            learned: '较早 API',
            learnedUpdatedAt: DateTime.utc(2026, 8, 6),
          ),
          _item(
            name: 'newer-api',
            learned: '最新 API',
            learnedUpdatedAt: DateTime.utc(2026, 8, 7),
          ),
        ]..sort(
          (left, right) => compareTranslationCatalogItems(
            left,
            right,
            TranslationCatalogSort.updatedDesc,
          ),
        );

    expect(items.map((item) => item.canonicalName), [
      'newer-api',
      'older-api',
      'built-in',
    ]);
  });

  test('翻译库排序标签明确说明排序方式', () {
    expect(TranslationCatalogSort.updatedDesc.label, '按最近更新排序');
    expect(TranslationCatalogSort.originalAsc.label, '按原文排序');
    expect(TranslationCatalogSort.translationAsc.label, '按中文排序');
    expect(TranslationCatalogSort.source.label, '按来源排序');
  });
}

TranslationCatalogItem _item({
  required String name,
  String? builtIn,
  String? learned,
  DateTime? learnedUpdatedAt,
}) {
  return TranslationCatalogItem(
    kind: TranslationCatalogKind.tag,
    canonicalName: name,
    sourceText: name,
    videoSlug: null,
    builtInTranslation: builtIn,
    learnedTranslation: learned,
    userTranslation: null,
    learnedProviderName: learned == null ? null : '测试服务',
    learnedCreatedAt: learnedUpdatedAt,
    learnedUpdatedAt: learnedUpdatedAt,
    userUpdatedAt: null,
    protectLearnedFromBuiltIn: false,
  );
}
