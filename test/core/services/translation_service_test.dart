import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/translation_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内置词表资产可以加载', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService(settingsRepository: settings);

    await service.initialize();

    expect(service.isInitialized, isTrue);
    expect(service.builtinEntryCount, 8090);
    expect(service.builtinCategoryEntryCount, 1898);
    expect(service.lookupChinese('footjob'), '足交');
    expect(
      service.lookupChinese(
        '13 sentinels aegis rim',
        kind: DiscoveryKind.category,
      ),
      '十三机兵防卫圈',
    );
    expect(
      service.lookupChinese('Hi-Fi Rush', kind: DiscoveryKind.category),
      '完美音浪',
    );
  });

  test('本地词表支持归一化和模特原文回退', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交', 'some_tag': '示例标签'},
    );

    expect(
      service.renderMetadata(DiscoveryKind.tag, 'footjob'),
      'footjob | 足交',
    );
    expect(
      service.renderMetadata(DiscoveryKind.tag, 'some tag'),
      'some tag | 示例标签',
    );
    expect(service.renderMetadata(DiscoveryKind.model, 'footjob'), 'footjob');
    expect(service.suggestEnglish('足交'), contains('footjob'));
  });

  test('显示模式生效且原文模式仍保留翻译能力', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );

    await settings.setTranslationDisplayMode(
      TranslationDisplayMode.chineseOnly,
    );
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), '足交');
    await settings.setTranslationDisplayMode(
      TranslationDisplayMode.originalOnly,
    );
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), 'footjob');
  });

  test('分类和标签使用各自的语言显示模式', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'anime': '动画'},
    );

    await settings.setTranslationDisplayModeFor(
      TranslationDisplayTarget.category,
      TranslationDisplayMode.chineseOnly,
    );
    await settings.setTranslationDisplayModeFor(
      TranslationDisplayTarget.tag,
      TranslationDisplayMode.originalOnly,
    );

    expect(service.renderMetadata(DiscoveryKind.category, 'anime'), '动画');
    expect(service.renderMetadata(DiscoveryKind.tag, 'footjob'), 'footjob');
  });

  test('用户覆盖优先于内置词表并可跨服务实例恢复', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'footjob': '分类译文'},
    );
    await service.initialize();

    await service.setOverride(DiscoveryKind.tag, 'footjob', '足部服务');

    expect(
      service.renderMetadata(DiscoveryKind.tag, 'footjob'),
      'footjob | 足部服务',
    );
    expect(
      service.renderMetadata(DiscoveryKind.category, 'footjob'),
      'footjob | 分类译文',
    );

    final restored = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
      categoryDictionary: const {'footjob': '分类译文'},
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.lookupChinese('footjob'), '足部服务');

    await restored.removeOverride(DiscoveryKind.tag, 'footjob');
    expect(restored.lookupChinese('footjob'), '足交');
    expect(await database.loadTranslationOverrides(), isEmpty);
  });

  test('反查同时支持内置译名和用户译名', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      dictionary: const {'footjob': '足交'},
    );

    await service.setOverride(DiscoveryKind.tag, 'footjob', '足部服务');

    final builtInMatch = service.searchTagAliases('足交').single;
    expect(builtInMatch.english, 'footjob');
    expect(builtInMatch.displayChinese, '足部服务');
    expect(builtInMatch.aliasSource, TranslationAliasSource.builtIn);

    final overrideMatch = service.searchTagAliases('足部服务').single;
    expect(overrideMatch.aliasSource, TranslationAliasSource.userOverride);
    expect(overrideMatch.matchKind, TranslationMatchKind.exact);
  });

  test('已学习译文仅次于用户和内置译文并支持中文标题反查', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'footjob',
      sourceText: 'footjob',
      translation: '接口足交',
    );
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'new tag',
      sourceText: 'new tag',
      translation: '新标签',
    );
    await database.upsertLearnedTranslation(
      kind: 'title',
      canonicalName: 'video-1',
      sourceText: 'MOM BREAKER',
      translation: '母亲终结者',
      videoSlug: 'mom-breaker',
    );
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'footjob': '足交'},
    );
    addTearDown(service.dispose);
    await service.initialize();

    expect(service.lookupChinese('footjob'), '足交');
    expect(service.lookupChinese('new tag'), '新标签');
    expect(
      service.searchTagAliases('新标签').single.aliasSource,
      TranslationAliasSource.learned,
    );
    expect(service.searchTitleTranslations('母亲').single.videoId, 'video-1');

    await service.setOverride(DiscoveryKind.tag, 'new tag', '用户新标签');
    expect(service.lookupChinese('new tag'), '用户新标签');
    await service.removeOverride(DiscoveryKind.tag, 'new tag');
    expect(service.lookupChinese('new tag'), '新标签');

    await service.setTitleOverride(
      'video-1',
      '用户标题',
      sourceText: 'MOM BREAKER',
      videoSlug: 'mom-breaker',
    );
    final userTitle = service.searchTitleTranslations('用户标题').single;
    expect(userTitle.aliasSource, TranslationAliasSource.userOverride);
  });

  test('新加入内置词表不会覆盖此前已经学到的 API 译文', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();

    final first = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'old tag': '旧内置'},
      builtInPackVersion: 1,
    );
    await first.initialize();
    first.dispose();
    await database.upsertLearnedTranslation(
      kind: 'tag',
      canonicalName: 'new tag',
      sourceText: 'new tag',
      translation: 'API 译文',
    );

    final second = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'old tag': '新版内置', 'new tag': '新增内置'},
      builtInPackVersion: 2,
    );
    addTearDown(second.dispose);
    await second.initialize();

    expect(second.lookupChinese('old tag'), '新版内置');
    expect(second.lookupChinese('new tag'), 'API 译文');
  });

  test('批量删除 API 译文只通知一次且不会删除用户译文', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    for (var index = 0; index < 120; index++) {
      await database.upsertLearnedTranslation(
        kind: index.isEven ? 'tag' : 'category',
        canonicalName: 'learned-$index',
        sourceText: 'learned-$index',
        translation: 'API-$index',
      );
    }
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'keep': '内置'},
    );
    addTearDown(service.dispose);
    await service.initialize();
    await service.setOverride(DiscoveryKind.tag, 'keep', '用户译文');

    var notifications = 0;
    service.addListener(() => notifications++);
    final selected = service
        .catalogItems()
        .where((item) => item.canonicalName.startsWith('learned-'))
        .toList(growable: false);

    await service.deleteLearnedTranslations(selected);

    expect(notifications, 1);
    expect(service.learnedEntryCount, 0);
    expect(service.lookupChinese('keep'), '用户译文');
    expect(await database.loadLearnedTranslations(), isEmpty);
    expect(await database.loadTranslationOverrides(), hasLength(1));
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
