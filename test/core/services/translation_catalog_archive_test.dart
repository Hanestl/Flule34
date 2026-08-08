import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/translation_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_catalog_archive.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

void main() {
  test('翻译库导出保留三层译文，导入明确忽略内置层', () async {
    const archiveService = TranslationCatalogArchiveService();
    final content = archiveService.encodeCatalog([
      const TranslationCatalogItem(
        kind: TranslationCatalogKind.tag,
        canonicalName: 'example',
        sourceText: 'example',
        videoSlug: null,
        builtInTranslation: '内置译文',
        learnedTranslation: 'API译文',
        userTranslation: '用户译文',
        learnedProviderName: 'DeepSeek',
        learnedCreatedAt: null,
        learnedUpdatedAt: null,
        userUpdatedAt: null,
        protectLearnedFromBuiltIn: true,
      ),
    ], appVersion: '1.5.0+27');
    final parsed = archiveService.parseBytes(
      Uint8List.fromList(utf8.encode(content)),
    );
    expect(parsed.entries, hasLength(1));
    expect(parsed.builtInLayerCount, 1);
    expect(parsed.learnedLayerCount, 1);
    expect(parsed.userLayerCount, 1);
    expect(parsed.entries.single.builtInTranslation, '内置译文');
    expect(parsed.entries.single.learned?.translation, 'API译文');
    expect(parsed.entries.single.userOverride?.translation, '用户译文');
  });

  test('翻译库安全合并不会覆盖本机用户译文', () async {
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {'example': '内置译文'},
    );
    addTearDown(service.dispose);
    await service.initialize();
    await service.setOverride(DiscoveryKind.tag, 'example', '本机用户译文');

    const archiveService = TranslationCatalogArchiveService();
    final archiveJson = archiveService.encodeCatalog([
      const TranslationCatalogItem(
        kind: TranslationCatalogKind.tag,
        canonicalName: 'example',
        sourceText: 'example',
        videoSlug: null,
        builtInTranslation: '其他内置译文',
        learnedTranslation: '导入 API 译文',
        userTranslation: '导入用户译文',
        learnedProviderName: '其他服务',
        learnedCreatedAt: null,
        learnedUpdatedAt: null,
        userUpdatedAt: null,
        protectLearnedFromBuiltIn: false,
      ),
    ], appVersion: '1.5.0+27');
    final archive = archiveService.parseBytes(
      Uint8List.fromList(utf8.encode(archiveJson)),
    );
    final result = await service.importCatalogArchive(
      archive,
      mode: TranslationImportMode.safeMerge,
    );
    expect(result.importedTotal, 1);
    expect(result.importedLearned, 1);
    expect(result.skippedLearned, 0);
    expect(result.skippedUserOverrides, 1);
    expect(service.lookupChinese('example', kind: DiscoveryKind.tag), '本机用户译文');
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> values = {};

  @override
  Future<bool?> readBool(String key) async => values[key] as bool?;

  @override
  Future<String?> readString(String key) async => values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
