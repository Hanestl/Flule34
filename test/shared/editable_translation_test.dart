import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/editable_translation.dart';

void main() {
  testWidgets('长按翻译可修改并恢复内置结果', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ListenableBuilder(
              listenable: service,
              builder: (context, _) => EditableTranslationRegion(
                translationService: service,
                kind: DiscoveryKind.tag,
                english: 'footjob',
                child: Chip(
                  label: Text(
                    service.renderMetadata(DiscoveryKind.tag, 'footjob'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('footjob | 足交'));
    await tester.pumpAndSettle();
    expect(find.text('原文'), findsOneWidget);
    expect(find.text('footjob'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '足部服务');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('footjob | 足部服务'), findsOneWidget);

    await tester.longPress(find.text('footjob | 足部服务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复内置翻译'));
    await tester.pumpAndSettle();
    expect(find.text('footjob | 足交'), findsOneWidget);
  });

  testWidgets('没有内置译文时可长按原文新增用户翻译', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {},
    );
    addTearDown(service.dispose);
    await service.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ListenableBuilder(
              listenable: service,
              builder: (context, _) => EditableTranslationRegion(
                translationService: service,
                kind: DiscoveryKind.tag,
                english: 'unknown tag',
                child: Text(
                  service.renderMetadata(DiscoveryKind.tag, 'unknown tag'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('unknown tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '未知标签');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('unknown tag | 未知标签'), findsOneWidget);
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
