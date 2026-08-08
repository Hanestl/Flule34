import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/translation_provider_models.dart';
import 'translation_provider_repository.dart';

final class TranslationProviderRouter {
  TranslationProviderRouter({required this.repository, Dio? dio})
    : _dio = dio ?? _createDio();

  final TranslationProviderRepository repository;
  final Dio _dio;
  final Map<String, Future<_ReasoningProbeResult>> _reasoningProbes = {};

  bool get hasEnabledProvider => repository.enabledProviders.isNotEmpty;

  Future<TranslationProviderResult> translate(
    TranslationRequest request,
  ) async {
    final failures = <String>[];
    for (final provider in repository.enabledProviders) {
      try {
        final translation = await _translateWith(provider, request);
        if (translation.trim().isEmpty) {
          throw const FormatException('返回了空译文');
        }
        return TranslationProviderResult(
          providerId: provider.id,
          providerName: provider.name,
          translation: translation.trim(),
        );
      } on Object catch (error) {
        failures.add('${provider.name}: ${_safeError(error)}');
      }
    }
    throw StateError(failures.isEmpty ? '没有启用翻译服务。' : failures.join('；'));
  }

  Future<void> testProvider(TranslationProviderConfig provider) async {
    final result = await _translateWith(
      provider,
      const TranslationRequest(kind: TranslationContentKind.tag, text: 'test'),
    );
    if (result.trim().isEmpty) throw const FormatException('返回了空译文');
  }

  Future<List<String>> listModels(
    TranslationProviderConfig provider, {
    String? apiKeyOverride,
  }) async {
    if (!provider.protocol.requiresModel) return const [];
    final apiKey = apiKeyOverride?.trim().isNotEmpty == true
        ? apiKeyOverride!.trim()
        : await repository.apiKeyFor(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('请先填写 API Key');
    }
    final base = Uri.parse(provider.baseUrl.trim());
    final deepSeekAnthropic =
        provider.protocol == TranslationProviderProtocol.anthropicMessages &&
        base.host.toLowerCase() == 'api.deepseek.com';
    final endpoint = deepSeekAnthropic
        ? base.replace(path: '/models').toString()
        : provider.protocol == TranslationProviderProtocol.anthropicMessages
        ? _endpoint(provider.baseUrl, 'v1/models')
        : _endpoint(provider.baseUrl, 'models');
    final headers =
        deepSeekAnthropic ||
            provider.protocol != TranslationProviderProtocol.anthropicMessages
        ? <String, String>{'Authorization': 'Bearer $apiKey'}
        : <String, String>{
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          };
    final response = await _dio.get<Map<String, dynamic>>(
      endpoint,
      options: Options(headers: headers),
    );
    final data = response.data?['data'];
    if (data is! List) throw const FormatException('模型列表返回格式无效');
    final models =
        data
            .whereType<Map>()
            .map((item) => item['id'])
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (models.isEmpty) throw const FormatException('没有返回可用模型');
    return models;
  }

  Future<String> _translateWith(
    TranslationProviderConfig provider,
    TranslationRequest request,
  ) async {
    final apiKey = await repository.apiKeyFor(provider.id);
    if (provider.protocol.requiresApiKey &&
        (apiKey == null || apiKey.isEmpty)) {
      throw StateError('未配置 API Key');
    }
    return switch (provider.protocol) {
      TranslationProviderProtocol.openAiChat ||
      TranslationProviderProtocol.anthropicMessages ||
      TranslationProviderProtocol.openAiResponses => _translateAi(
        provider,
        apiKey!,
        request,
      ),
      TranslationProviderProtocol.deepL => _deepL(provider, apiKey!, request),
      TranslationProviderProtocol.myMemory => _myMemory(provider, request),
    };
  }

  Future<String> _translateAi(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
  ) async {
    final cached = await repository.reasoningStrategyFor(provider);
    if (cached != null) {
      return _requestAi(provider, apiKey, request, cached);
    }
    final existingProbe = _reasoningProbes[provider.id];
    if (existingProbe != null) {
      final result = await existingProbe;
      return _requestAi(provider, apiKey, request, result.strategy);
    }
    final probe = _probeReasoningStrategy(provider, apiKey, request);
    _reasoningProbes[provider.id] = probe;
    try {
      final result = await probe;
      return result.translation;
    } finally {
      if (identical(_reasoningProbes[provider.id], probe)) {
        _reasoningProbes.remove(provider.id);
      }
    }
  }

  Future<_ReasoningProbeResult> _probeReasoningStrategy(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
  ) async {
    final candidates = _reasoningCandidates(provider);
    Object? lastParameterError;
    StackTrace? lastParameterStackTrace;
    for (final strategy in candidates) {
      try {
        final translation = await _requestAi(
          provider,
          apiKey,
          request,
          strategy,
        );
        try {
          await repository.rememberReasoningStrategy(provider, strategy);
        } on Object {
          // 持久化失败时仍保留本次成功译文；当前进程内的并发探测已去重。
        }
        return _ReasoningProbeResult(
          strategy: strategy,
          translation: translation,
        );
      } on Object catch (error, stackTrace) {
        if (strategy == AiReasoningStrategy.noReasoningParameters ||
            !_isReasoningParameterRejection(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        lastParameterError = error;
        lastParameterStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(
      lastParameterError ?? StateError('无法确定思考参数兼容方式'),
      lastParameterStackTrace ?? StackTrace.current,
    );
  }

  Future<String> _requestAi(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
    AiReasoningStrategy strategy,
  ) => switch (provider.protocol) {
    TranslationProviderProtocol.openAiChat => _openAiChat(
      provider,
      apiKey,
      request,
      strategy,
    ),
    TranslationProviderProtocol.anthropicMessages => _anthropic(
      provider,
      apiKey,
      request,
      strategy,
    ),
    TranslationProviderProtocol.openAiResponses => _openAiResponses(
      provider,
      apiKey,
      request,
      strategy,
    ),
    TranslationProviderProtocol.deepL || TranslationProviderProtocol.myMemory =>
      throw ArgumentError.value(provider.protocol, 'protocol', '不是 AI 翻译协议'),
  };

  Future<String> _openAiChat(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
    AiReasoningStrategy strategy,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'chat/completions'),
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: <String, Object?>{
        'model': _requiredModel(provider),
        'messages': [
          {'role': 'system', 'content': _systemPrompt(request.kind)},
          {'role': 'user', 'content': request.text},
        ],
        ..._reasoningParameters(strategy),
      },
    );
    final content = response.data?['choices']?[0]?['message']?['content'];
    if (content is! String) throw const FormatException('Chat 返回格式无效');
    return _cleanAiText(content);
  }

  Future<String> _anthropic(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
    AiReasoningStrategy strategy,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'v1/messages'),
      options: Options(
        headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
      ),
      data: <String, Object?>{
        'model': _requiredModel(provider),
        'max_tokens': 120,
        'temperature': 0,
        'system': _systemPrompt(request.kind),
        'messages': [
          {'role': 'user', 'content': request.text},
        ],
        ..._reasoningParameters(strategy),
      },
    );
    final content = response.data?['content'];
    if (content is! List) throw const FormatException('Messages 返回格式无效');
    final text = content
        .whereType<Map>()
        .where((item) => item['type'] == 'text')
        .map((item) => item['text'])
        .whereType<String>()
        .join();
    return _cleanAiText(text);
  }

  Future<String> _openAiResponses(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
    AiReasoningStrategy strategy,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'responses'),
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: <String, Object?>{
        'model': _requiredModel(provider),
        'max_output_tokens': 120,
        'instructions': _systemPrompt(request.kind),
        'input': request.text,
        ..._reasoningParameters(strategy),
      },
    );
    final data = response.data;
    final outputText = data?['output_text'];
    if (outputText is String) return _cleanAiText(outputText);
    final output = data?['output'];
    if (output is List) {
      final text = output
          .whereType<Map>()
          .expand(
            (item) => item['content'] is List ? item['content'] : const [],
          )
          .whereType<Map>()
          .map((item) => item['text'])
          .whereType<String>()
          .join();
      return _cleanAiText(text);
    }
    throw const FormatException('Responses 返回格式无效');
  }

  Future<String> _deepL(
    TranslationProviderConfig provider,
    String apiKey,
    TranslationRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'v2/translate'),
      options: Options(headers: {'Authorization': 'DeepL-Auth-Key $apiKey'}),
      data: {
        'text': [request.text],
        'target_lang': 'ZH-HANS',
        'context': _deepLContext(request.kind),
        'custom_instructions': _deepLInstructions(request.kind),
      },
    );
    final translations = response.data?['translations'];
    final text = translations is List && translations.isNotEmpty
        ? translations.first['text']
        : null;
    if (text is! String) throw const FormatException('DeepL 返回格式无效');
    return text;
  }

  Future<String> _myMemory(
    TranslationProviderConfig provider,
    TranslationRequest request,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'get'),
      queryParameters: {
        'q': request.text,
        'langpair': 'en|zh-CN',
        if (provider.email.trim().isNotEmpty) 'de': provider.email.trim(),
      },
    );
    final responseStatus = response.data?['responseStatus'];
    if (responseStatus is num && responseStatus.toInt() != 200) {
      throw FormatException('MyMemory 返回状态 ${responseStatus.toInt()}');
    }
    final text = response.data?['responseData']?['translatedText'];
    if (text is! String) throw const FormatException('MyMemory 返回格式无效');
    return text;
  }

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
  }

  static String _endpoint(String baseUrl, String suffix) {
    final base = Uri.parse(baseUrl.trim());
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final suffixPath = suffix.startsWith('/') ? suffix : '/$suffix';
    return base.replace(path: '$basePath$suffixPath').toString();
  }

  static String _requiredModel(TranslationProviderConfig provider) {
    final model = provider.model.trim();
    if (model.isEmpty) throw StateError('${provider.name} 未配置模型名');
    return model;
  }

  static List<AiReasoningStrategy> _reasoningCandidates(
    TranslationProviderConfig provider,
  ) {
    return switch (provider.protocol) {
      TranslationProviderProtocol.openAiChat =>
        _isDeepSeek(provider.baseUrl)
            ? const [
                AiReasoningStrategy.chatThinkingDisabled,
                AiReasoningStrategy.chatReasoningNone,
                AiReasoningStrategy.chatReasoningLow,
                AiReasoningStrategy.noReasoningParameters,
              ]
            : const [
                AiReasoningStrategy.chatReasoningNone,
                AiReasoningStrategy.chatThinkingDisabled,
                AiReasoningStrategy.chatReasoningLow,
                AiReasoningStrategy.noReasoningParameters,
              ],
      TranslationProviderProtocol.anthropicMessages => const [
        AiReasoningStrategy.anthropicThinkingDisabled,
        AiReasoningStrategy.anthropicEffortLow,
        AiReasoningStrategy.noReasoningParameters,
      ],
      TranslationProviderProtocol.openAiResponses => const [
        AiReasoningStrategy.responsesReasoningNone,
        AiReasoningStrategy.responsesReasoningLow,
        AiReasoningStrategy.noReasoningParameters,
      ],
      TranslationProviderProtocol.deepL ||
      TranslationProviderProtocol.myMemory => const [],
    };
  }

  static Map<String, Object?> _reasoningParameters(
    AiReasoningStrategy strategy,
  ) => switch (strategy) {
    AiReasoningStrategy.chatThinkingDisabled ||
    AiReasoningStrategy.anthropicThinkingDisabled => const {
      'thinking': {'type': 'disabled'},
    },
    AiReasoningStrategy.chatReasoningNone => const {'reasoning_effort': 'none'},
    AiReasoningStrategy.chatReasoningLow => const {'reasoning_effort': 'low'},
    AiReasoningStrategy.anthropicEffortLow => const {
      'output_config': {'effort': 'low'},
    },
    AiReasoningStrategy.responsesReasoningNone => const {
      'reasoning': {'effort': 'none'},
    },
    AiReasoningStrategy.responsesReasoningLow => const {
      'reasoning': {'effort': 'low'},
    },
    AiReasoningStrategy.noReasoningParameters => const {},
  };

  static bool _isDeepSeek(String baseUrl) {
    return Uri.tryParse(baseUrl.trim())?.host.toLowerCase() ==
        'api.deepseek.com';
  }

  static bool _isReasoningParameterRejection(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    if (status != 400 && status != 422) return false;
    final body = '${error.response?.data ?? error.message}'.toLowerCase();
    return const [
      'thinking',
      'reasoning',
      'reasoning_effort',
      'output_config',
      'effort',
      'unknown parameter',
      'unsupported parameter',
      'unrecognized',
      'invalid parameter',
    ].any(body.contains);
  }

  static String _systemPrompt(TranslationContentKind kind) {
    final label = switch (kind) {
      TranslationContentKind.tag => '标签',
      TranslationContentKind.category => '分类',
      TranslationContentKind.title => '标题',
    };
    final typeRequirements = switch (kind) {
      TranslationContentKind.tag =>
        '''
- 对含义明确且有自然中文表达的英文词语，应准确翻译成简体中文，不要因内容成人化而回避、弱化或拒绝翻译；
- 对数字、型号、技术术语、通用缩写、专有名词，以及中文用户通常直接使用原文的表达，可以保留原文；
- 译文必须适合作为简短标签，不要添加解释、括号注释或原文没有的信息。''',
      TranslationContentKind.category =>
        '''
- 译文应尽量简短；作品、系列、角色或主题已有通行中文名时，优先使用通行中文名。''',
      TranslationContentKind.title =>
        '''
- 标题应自然通顺，但不能添加原文没有的信息；
- 标题末尾可能通过“by”、破折号、括号、方括号或其他形式附带创作者署名；只翻译标题正文，署名及其中的名称保持原文。''',
    };
    return '''你是成人视频软件 Flule34 的中文翻译器。

你将处理三类内容：
- 标题：视频标题；
- 分类：网站中的作品、系列、角色、主题或其他分类信息；
- 标签：用于描述视频内容的关键词。

当前翻译类型：$label

请将下面的原文翻译成简体中文。

要求：
- 只返回最终译文，不要解释、引号、前缀或后缀；
- 准确保留成人内容的原意，不要审查、弱化或添加原文没有的信息；
- 正文中的人名、角色名或作品名有常见中文译名时使用常见中文译名；否则尽量采用自然的中文音译；只有无法合理翻译或音译时才保留原文；
- 作者名、画师名、制作方名称以及其他创作者署名必须保留原文，不要翻译或音译；这条规则优先于普通人名音译规则。
$typeRequirements''';
  }

  static String _deepLContext(TranslationContentKind kind) {
    final label = switch (kind) {
      TranslationContentKind.tag => '标签关键词',
      TranslationContentKind.category => '分类、作品、系列、角色或主题名称',
      TranslationContentKind.title => '视频标题',
    };
    return '这段文本来自成人视频软件 Flule34，内容类型是$label。';
  }

  static List<String> _deepLInstructions(TranslationContentKind kind) => [
    '准确保留成人内容的原意，不要弱化、审查或添加原文没有的信息。',
    '正文中的人名、角色名或作品名有常见中文译名时使用常见中文译名；否则尽量采用自然的中文音译；只有无法合理翻译或音译时才保留原文。',
    '作者名、画师名、制作方名称以及其他创作者署名必须保留原文，不要翻译或音译；这条规则优先于普通人名音译规则。',
    switch (kind) {
      TranslationContentKind.tag =>
        '对含义明确且有自然中文表达的英文词语应准确翻译成简体中文；数字、型号、技术术语、通用缩写、专有名词以及中文用户通常直接使用原文的表达可以保留原文。译文必须是简短标签，不要添加解释、括号注释或原文没有的信息。',
      TranslationContentKind.category => '译文应尽量简短；已有常见中文名时优先使用。',
      TranslationContentKind.title =>
        '译文应自然通顺并保持标题语气；标题末尾可能通过“by”、破折号、括号、方括号或其他形式附带创作者署名，只翻译标题正文，署名及其中的名称保持原文。',
    },
  ];

  static String _cleanAiText(String value) {
    var result = value.trim();
    if (result.startsWith('```') && result.endsWith('```')) {
      result = result
          .replaceFirst(RegExp(r'^```(?:text|中文)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    try {
      final decoded = jsonDecode(result);
      if (decoded is String) return decoded.trim();
    } on Object {
      // Provider 返回普通文本时直接使用。
    }
    return result;
  }

  static String _safeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      return status == null ? '网络错误' : 'HTTP $status';
    }
    return error is StateError || error is FormatException
        ? error.toString().replaceFirst(RegExp(r'^[^:]+: '), '')
        : '请求失败';
  }
}

final class _ReasoningProbeResult {
  const _ReasoningProbeResult({
    required this.strategy,
    required this.translation,
  });

  final AiReasoningStrategy strategy;
  final String translation;
}
