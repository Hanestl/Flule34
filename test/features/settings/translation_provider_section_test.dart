import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/models/translation_provider_models.dart';
import 'package:flule34/core/services/translation_provider_repository.dart';
import 'package:flule34/core/session/secret_store.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/presentation/translation_provider_section.dart';

void main() {
  testWidgets('服务列表会实时反映优先级重排', (tester) async {
    final store = _MemorySettingsStore();
    final secrets = _MemorySecretStore();
    final repository = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(repository.dispose);
    await repository.load();
    await repository.upsert(
      const TranslationProviderConfig(
        id: 'first',
        name: '首选服务',
        protocol: TranslationProviderProtocol.openAiChat,
        baseUrl: 'https://first.test/v1',
        model: 'model-a',
        enabled: true,
      ),
      apiKey: 'secret-a',
    );
    await repository.upsert(
      const TranslationProviderConfig(
        id: 'second',
        name: '备用服务',
        protocol: TranslationProviderProtocol.myMemory,
        baseUrl: 'https://second.test',
        enabled: true,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        translationProviderRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TranslationProviderSection()),
        ),
      ),
    );
    expect(find.text('首选服务'), findsOneWidget);
    expect(find.text('备用服务'), findsOneWidget);
    expect(find.text('OpenAI Chat Completions'), findsOneWidget);

    await repository.reorder(1, 0);
    await tester.pump();

    expect(find.text('MyMemory'), findsOneWidget);
    expect(find.text('OpenAI Chat Completions'), findsOneWidget);
  });

  testWidgets('DeepL 编辑器会明确显示新旧套餐对应的端点分组', (tester) async {
    final store = _MemorySettingsStore();
    final secrets = _MemorySecretStore();
    final repository = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(repository.dispose);
    await repository.load();
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        translationProviderRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TranslationProviderSection()),
        ),
      ),
    );
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI Chat Completions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepL').last);
    await tester.pumpAndSettle();

    expect(find.text('DeepL 套餐与端点'), findsOneWidget);
    expect(find.text('API Developer / API Free'), findsOneWidget);

    await tester.tap(find.text('API Developer / API Free'));
    await tester.pumpAndSettle();
    expect(find.text('API Growth / API Pro'), findsOneWidget);
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

final class _MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
