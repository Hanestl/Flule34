import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/translation_models.dart';
import 'package:flule34/core/models/translation_provider_models.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/services/translation_provider_repository.dart';
import 'package:flule34/core/services/translation_provider_router.dart';
import 'package:flule34/core/services/translation_service.dart';
import 'package:flule34/core/session/secret_store.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

void main() {
  test('多翻译服务顺序和密钥分别持久化', () async {
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
        name: '首选',
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
        name: '备用',
        protocol: TranslationProviderProtocol.myMemory,
        baseUrl: 'https://second.test',
        enabled: true,
      ),
    );
    await repository.reorder(1, 0);

    final restored = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.providers.map((item) => item.id), ['second', 'first']);
    expect(await restored.apiKeyFor('first'), 'secret-a');
    expect(store.values.values.join(), isNot(contains('secret-a')));

    await restored.remove('first');
    expect(await restored.apiKeyFor('first'), isNull);
  });

  test('复制翻译服务会复制配置和密钥并插入原服务下一项', () async {
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
        id: 'original',
        name: 'DeepSeek',
        protocol: TranslationProviderProtocol.openAiChat,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
        enabled: true,
      ),
      apiKey: 'secret',
    );

    await repository.duplicateAfter('original');

    expect(repository.providers, hasLength(2));
    final duplicate = repository.providers[1];
    expect(duplicate.name, 'DeepSeek');
    expect(duplicate.protocol, TranslationProviderProtocol.openAiChat);
    expect(duplicate.model, 'deepseek-v4-flash');
    expect(await repository.apiKeyFor(duplicate.id), 'secret');
  });

  test('DeepSeek 默认端点和模型列表拉取使用当前密钥', () async {
    expect(
      TranslationProviderProtocol.openAiChat.defaultBaseUrl,
      'https://api.deepseek.com',
    );
    expect(
      TranslationProviderProtocol.openAiResponses.defaultBaseUrl,
      'https://api.deepseek.com',
    );
    expect(
      TranslationProviderProtocol.anthropicMessages.defaultBaseUrl,
      'https://api.deepseek.com/anthropic',
    );
    final repository = TranslationProviderRepository(
      store: _MemorySettingsStore(),
      secrets: _MemorySecretStore(),
    );
    addTearDown(repository.dispose);
    await repository.load();
    final adapter = _SingleResponseAdapter(
      '{"data":[{"id":"deepseek-v4-pro"},{"id":"deepseek-v4-flash"}]}',
    );
    final router = TranslationProviderRouter(
      repository: repository,
      dio: Dio()..httpClientAdapter = adapter,
    );

    final models = await router.listModels(
      const TranslationProviderConfig(
        id: 'unsaved',
        name: 'DeepSeek',
        protocol: TranslationProviderProtocol.openAiChat,
        baseUrl: 'https://api.deepseek.com',
        enabled: true,
      ),
      apiKeyOverride: 'temporary-key',
    );

    expect(models, ['deepseek-v4-flash', 'deepseek-v4-pro']);
    expect(adapter.request?.uri.path, '/models');
    expect(adapter.request?.headers['Authorization'], 'Bearer temporary-key');
  });

  test('首选服务失败后使用下一项且只发送当前文本', () async {
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
        name: '首选',
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
        name: '备用',
        protocol: TranslationProviderProtocol.myMemory,
        baseUrl: 'https://second.test',
        enabled: true,
      ),
    );
    final adapter = _RoutingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final router = TranslationProviderRouter(repository: repository, dio: dio);

    final result = await router.translate(
      const TranslationRequest(
        kind: TranslationContentKind.tag,
        text: 'footjob',
      ),
    );

    expect(result.providerId, 'second');
    expect(result.translation, '足交');
    expect(adapter.requests, hasLength(2));
    final firstBody = jsonEncode(adapter.requests.first.data);
    expect(firstBody, contains('footjob'));
    expect(firstBody, contains('成人视频软件 Flule34'));
    expect(firstBody, contains('当前翻译类型：标签'));
    expect(firstBody, contains('含义明确且有自然中文表达'));
    expect(firstBody, contains('作者名、画师名、制作方名称'));
    expect(firstBody, isNot(contains('下面的英文')));
    expect(firstBody, isNot(contains('artist')));
    expect(firstBody, isNot(contains('uploader')));
  });

  test('协议或服务器变化时不会把旧密钥带到新的凭据范围', () async {
    final store = _MemorySettingsStore();
    final secrets = _MemorySecretStore();
    final repository = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(repository.dispose);
    await repository.load();

    const original = TranslationProviderConfig(
      id: 'provider',
      name: '服务',
      protocol: TranslationProviderProtocol.openAiChat,
      baseUrl: 'https://first.test/v1',
      model: 'model-a',
      enabled: true,
    );
    await repository.upsert(original, apiKey: 'secret-a');

    await repository.upsert(
      original.copyWith(baseUrl: 'https://second.test/v1'),
    );
    expect(await repository.apiKeyFor('provider'), isNull);

    await repository.upsert(
      original.copyWith(baseUrl: 'https://second.test/v1'),
      apiKey: 'secret-b',
    );
    await repository.upsert(
      original.copyWith(baseUrl: 'https://second.test/compatible/v1'),
    );
    expect(await repository.apiKeyFor('provider'), 'secret-b');

    await repository.upsert(
      original.copyWith(
        protocol: TranslationProviderProtocol.myMemory,
        baseUrl: TranslationProviderProtocol.myMemory.defaultBaseUrl,
        model: '',
      ),
    );
    expect(await repository.apiKeyFor('provider'), isNull);
  });

  test('各协议使用预期端点并解析单项译文', () async {
    final cases =
        <
          ({
            TranslationProviderProtocol protocol,
            String baseUrl,
            String model,
            String path,
            String response,
            String translation,
          })
        >[
          (
            protocol: TranslationProviderProtocol.openAiChat,
            baseUrl: 'https://provider.test/v1',
            model: 'chat-model',
            path: '/v1/chat/completions',
            response: '{"choices":[{"message":{"content":"聊天译文"}}]}',
            translation: '聊天译文',
          ),
          (
            protocol: TranslationProviderProtocol.anthropicMessages,
            baseUrl: 'https://provider.test',
            model: 'claude-model',
            path: '/v1/messages',
            response: '{"content":[{"type":"text","text":"消息译文"}]}',
            translation: '消息译文',
          ),
          (
            protocol: TranslationProviderProtocol.openAiResponses,
            baseUrl: 'https://provider.test/v1',
            model: 'response-model',
            path: '/v1/responses',
            response:
                '{"output":[{"content":[{"type":"output_text","text":"响应译文"}]}]}',
            translation: '响应译文',
          ),
          (
            protocol: TranslationProviderProtocol.deepL,
            baseUrl: 'https://provider.test',
            model: '',
            path: '/v2/translate',
            response: '{"translations":[{"text":"专用译文"}]}',
            translation: '专用译文',
          ),
        ];

    for (final testCase in cases) {
      final repository = TranslationProviderRepository(
        store: _MemorySettingsStore(),
        secrets: _MemorySecretStore(),
      );
      await repository.load();
      await repository.upsert(
        TranslationProviderConfig(
          id: testCase.protocol.name,
          name: testCase.protocol.label,
          protocol: testCase.protocol,
          baseUrl: testCase.baseUrl,
          model: testCase.model,
          enabled: true,
        ),
        apiKey: 'secret',
      );
      final adapter = _SingleResponseAdapter(testCase.response);
      final dio = Dio()..httpClientAdapter = adapter;
      final router = TranslationProviderRouter(
        repository: repository,
        dio: dio,
      );

      final result = await router.translate(
        const TranslationRequest(
          kind: TranslationContentKind.category,
          text: 'original text',
        ),
      );

      expect(result.translation, testCase.translation);
      expect(adapter.request?.uri.path, testCase.path);
      final body = jsonEncode(adapter.request?.data);
      expect(body, contains('original text'));
      if (testCase.protocol == TranslationProviderProtocol.deepL) {
        expect(body, contains('ZH-HANS'));
        final data = adapter.request?.data;
        expect(data, isA<Map>());
        final instructions = (data! as Map)['custom_instructions'];
        expect(instructions, isA<List>());
        expect(instructions, everyElement(isA<String>()));
        expect(instructions, isNot(everyElement(isA<Map>())));
      }
      repository.dispose();
    }
  });

  test('AI 提示词会按标题、分类和标签应用不同翻译规则', () async {
    final cases = <(TranslationContentKind, String)>[
      (TranslationContentKind.title, '标题末尾可能通过“by”'),
      (TranslationContentKind.category, '已有通行中文名时，优先使用通行中文名'),
      (TranslationContentKind.tag, '数字、型号、技术术语、通用缩写'),
    ];

    for (final (kind, expectedRule) in cases) {
      final repository = TranslationProviderRepository(
        store: _MemorySettingsStore(),
        secrets: _MemorySecretStore(),
      );
      await repository.load();
      await repository.upsert(
        const TranslationProviderConfig(
          id: 'ai',
          name: 'AI',
          protocol: TranslationProviderProtocol.openAiChat,
          baseUrl: 'https://provider.test/v1',
          model: 'model-a',
          enabled: true,
        ),
        apiKey: 'secret',
      );
      final adapter = _SingleResponseAdapter(
        '{"choices":[{"message":{"content":"译文"}}]}',
      );
      final router = TranslationProviderRouter(
        repository: repository,
        dio: Dio()..httpClientAdapter = adapter,
      );

      await router.translate(TranslationRequest(kind: kind, text: 'source'));

      final body = jsonEncode(adapter.request?.data);
      expect(body, contains(expectedRule));
      expect(body, contains('作者名、画师名、制作方名称'));
      expect(body, contains('优先于普通人名音译规则'));
      repository.dispose();
    }
  });

  test('DeepL 定制指令使用受支持的字符串数组并覆盖三类规则', () async {
    final cases = <(TranslationContentKind, String)>[
      (TranslationContentKind.title, '标题末尾可能通过“by”'),
      (TranslationContentKind.category, '已有常见中文名时优先使用'),
      (TranslationContentKind.tag, '通用缩写'),
    ];

    for (final (kind, expectedRule) in cases) {
      final repository = TranslationProviderRepository(
        store: _MemorySettingsStore(),
        secrets: _MemorySecretStore(),
      );
      await repository.load();
      await repository.upsert(
        const TranslationProviderConfig(
          id: 'deepl',
          name: 'DeepL',
          protocol: TranslationProviderProtocol.deepL,
          baseUrl: 'https://provider.test',
          enabled: true,
        ),
        apiKey: 'secret',
      );
      final adapter = _SingleResponseAdapter(
        '{"translations":[{"text":"译文"}]}',
      );
      final router = TranslationProviderRouter(
        repository: repository,
        dio: Dio()..httpClientAdapter = adapter,
      );

      await router.translate(TranslationRequest(kind: kind, text: 'source'));

      final data = adapter.request?.data as Map;
      final instructions = data['custom_instructions'] as List;
      expect(instructions, isNotEmpty);
      expect(instructions, hasLength(lessThanOrEqualTo(10)));
      expect(instructions, everyElement(isA<String>()));
      expect(
        instructions.cast<String>(),
        everyElement(hasLength(lessThanOrEqualTo(300))),
      );
      expect(instructions.join('\n'), contains(expectedRule));
      expect(instructions.join('\n'), contains('作者名、画师名、制作方名称'));
      repository.dispose();
    }
  });

  test('自动翻译会并发去重并作为已学习译文跨启动恢复', () async {
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
        id: 'auto',
        name: '自动服务',
        protocol: TranslationProviderProtocol.openAiChat,
        baseUrl: 'https://provider.test/v1',
        model: 'model-a',
        enabled: true,
      ),
      apiKey: 'secret',
    );
    final adapter = _SingleResponseAdapter(
      '{"choices":[{"message":{"content":"自动译文"}}]}',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final router = TranslationProviderRouter(repository: repository, dio: dio);
    final settings = AppSettingsRepository(store);
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setAutomaticTranslationTargets(const {
      AutomaticTranslationTarget.title,
      AutomaticTranslationTarget.category,
      AutomaticTranslationTarget.tag,
    });
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      providerRouter: router,
      dictionary: const {},
    );
    addTearDown(service.dispose);
    await service.initialize();

    await Future.wait([
      service.requestAutomaticTitle(
        videoId: 'video-1',
        raw: 'MOM BREAKER',
        videoSlug: 'mom-breaker',
      ),
      service.requestAutomaticTitle(
        videoId: 'video-1',
        raw: 'MOM BREAKER',
        videoSlug: 'mom-breaker',
      ),
    ]);
    await service.requestAutomaticMetadataTranslation(
      DiscoveryKind.tag,
      'new tag',
    );

    expect(adapter.requestCount, 2);
    expect(service.learnedEntryCount, 2);
    expect(service.renderTitle('video-1', 'MOM BREAKER'), contains('自动译文'));
    expect(service.lookupChinese('new tag'), '自动译文');

    final restored = TranslationService.fromDictionary(
      settingsRepository: settings,
      database: database,
      dictionary: const {},
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.learnedEntryCount, 2);
    expect(restored.lookupTitleChinese('video-1', raw: 'MOM BREAKER'), '自动译文');
  });

  test('AI 思考能力只在首次调用探测并跨启动固定策略', () async {
    final store = _MemorySettingsStore();
    final secrets = _MemorySecretStore();
    final repository = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(repository.dispose);
    await repository.load();
    const provider = TranslationProviderConfig(
      id: 'ai',
      name: '兼容服务',
      protocol: TranslationProviderProtocol.openAiChat,
      baseUrl: 'https://provider.test/v1',
      model: 'model-a',
      enabled: true,
    );
    await repository.upsert(provider, apiKey: 'secret');
    final firstAdapter = _ReasoningFallbackAdapter();
    final firstRouter = TranslationProviderRouter(
      repository: repository,
      dio: Dio()..httpClientAdapter = firstAdapter,
    );

    await firstRouter.translate(
      const TranslationRequest(kind: TranslationContentKind.tag, text: 'one'),
    );
    expect(firstAdapter.requestCount, 3);
    expect(firstAdapter.bodies.last, contains('reasoning_effort'));
    expect(firstAdapter.bodies.last, contains('"low"'));

    await firstRouter.translate(
      const TranslationRequest(
        kind: TranslationContentKind.category,
        text: 'two',
      ),
    );
    expect(firstAdapter.requestCount, 4);

    final restored = TranslationProviderRepository(
      store: store,
      secrets: secrets,
    );
    addTearDown(restored.dispose);
    await restored.load();
    final secondAdapter = _ReasoningFallbackAdapter();
    final secondRouter = TranslationProviderRouter(
      repository: restored,
      dio: Dio()..httpClientAdapter = secondAdapter,
    );
    await secondRouter.translate(
      const TranslationRequest(
        kind: TranslationContentKind.title,
        text: 'three',
      ),
    );
    expect(secondAdapter.requestCount, 1);
    expect(secondAdapter.bodies.single, contains('"low"'));

    await restored.upsert(provider.copyWith(model: 'model-b'));
    final thirdAdapter = _ReasoningFallbackAdapter();
    final thirdRouter = TranslationProviderRouter(
      repository: restored,
      dio: Dio()..httpClientAdapter = thirdAdapter,
    );
    await thirdRouter.translate(
      const TranslationRequest(kind: TranslationContentKind.tag, text: 'four'),
    );
    expect(thirdAdapter.requestCount, 3);
  });

  test('AI 思考参数全部不兼容时最终固定为不带参数', () async {
    final repository = TranslationProviderRepository(
      store: _MemorySettingsStore(),
      secrets: _MemorySecretStore(),
    );
    addTearDown(repository.dispose);
    await repository.load();
    await repository.upsert(
      const TranslationProviderConfig(
        id: 'ai',
        name: '兼容服务',
        protocol: TranslationProviderProtocol.openAiChat,
        baseUrl: 'https://provider.test/v1',
        model: 'model-a',
        enabled: true,
      ),
      apiKey: 'secret',
    );
    final adapter = _RejectAllReasoningAdapter();
    final router = TranslationProviderRouter(
      repository: repository,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await router.translate(
      const TranslationRequest(kind: TranslationContentKind.tag, text: 'one'),
    );
    expect(adapter.requestCount, 4);
    expect(adapter.bodies.last, isNot(contains('reasoning_effort')));
    expect(adapter.bodies.last, isNot(contains('thinking')));
    await router.translate(
      const TranslationRequest(kind: TranslationContentKind.tag, text: 'two'),
    );
    expect(adapter.requestCount, 5);
  });
}

final class _RoutingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.host == 'first.test') {
      return ResponseBody.fromString(
        '{"error":"offline"}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"responseData":{"translatedText":"足交"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _SingleResponseAdapter implements HttpClientAdapter {
  _SingleResponseAdapter(this.response);

  final String response;
  RequestOptions? request;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    requestCount += 1;
    return ResponseBody.fromString(
      response,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _ReasoningFallbackAdapter implements HttpClientAdapter {
  final List<String> bodies = [];
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = jsonEncode(options.data);
    bodies.add(body);
    requestCount += 1;
    if (body.contains('"reasoning_effort":"none"') ||
        body.contains('"thinking"')) {
      return ResponseBody.fromString(
        '{"error":"unsupported reasoning parameter"}',
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"choices":[{"message":{"content":"译文"}}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _RejectAllReasoningAdapter implements HttpClientAdapter {
  final List<String> bodies = [];
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = jsonEncode(options.data);
    bodies.add(body);
    requestCount += 1;
    if (body.contains('reasoning_effort') || body.contains('thinking')) {
      return ResponseBody.fromString(
        '{"error":"unknown parameter"}',
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"choices":[{"message":{"content":"默认译文"}}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
