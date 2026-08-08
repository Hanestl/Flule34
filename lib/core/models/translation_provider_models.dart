import 'package:flutter/foundation.dart';

enum TranslationProviderProtocol {
  openAiChat('OpenAI Chat Completions'),
  anthropicMessages('Anthropic Messages'),
  openAiResponses('OpenAI Responses'),
  deepL('DeepL'),
  myMemory('MyMemory');

  const TranslationProviderProtocol(this.label);

  final String label;

  String get defaultName => switch (this) {
    TranslationProviderProtocol.openAiChat ||
    TranslationProviderProtocol.anthropicMessages ||
    TranslationProviderProtocol.openAiResponses => 'DeepSeek',
    TranslationProviderProtocol.deepL => 'DeepL',
    TranslationProviderProtocol.myMemory => 'MyMemory',
  };

  bool get requiresModel => switch (this) {
    TranslationProviderProtocol.openAiChat ||
    TranslationProviderProtocol.anthropicMessages ||
    TranslationProviderProtocol.openAiResponses => true,
    TranslationProviderProtocol.deepL ||
    TranslationProviderProtocol.myMemory => false,
  };

  bool get requiresApiKey => this != TranslationProviderProtocol.myMemory;

  String get defaultBaseUrl => switch (this) {
    TranslationProviderProtocol.openAiChat => 'https://api.deepseek.com',
    TranslationProviderProtocol.anthropicMessages =>
      'https://api.deepseek.com/anthropic',
    TranslationProviderProtocol.openAiResponses => 'https://api.deepseek.com',
    TranslationProviderProtocol.deepL => 'https://api-free.deepl.com',
    TranslationProviderProtocol.myMemory =>
      'https://api.mymemory.translated.net',
  };

  bool get hasFixedBaseUrl =>
      this == TranslationProviderProtocol.deepL ||
      this == TranslationProviderProtocol.myMemory;

  Uri? get helpUri => switch (this) {
    TranslationProviderProtocol.deepL => Uri.parse(
      'https://www.deepl.com/pro-api',
    ),
    TranslationProviderProtocol.myMemory => Uri.parse(
      'https://mymemory.translated.net/doc/spec.php',
    ),
    _ => null,
  };
}

enum TranslationContentKind { tag, category, title }

enum AiReasoningStrategy {
  chatThinkingDisabled,
  chatReasoningNone,
  chatReasoningLow,
  anthropicThinkingDisabled,
  anthropicEffortLow,
  responsesReasoningNone,
  responsesReasoningLow,
  noReasoningParameters,
}

@immutable
final class TranslationProviderConfig {
  const TranslationProviderConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.enabled,
    this.model = '',
    this.email = '',
  });

  final String id;
  final String name;
  final TranslationProviderProtocol protocol;
  final String baseUrl;
  final String model;
  final String email;
  final bool enabled;

  TranslationProviderConfig copyWith({
    String? name,
    TranslationProviderProtocol? protocol,
    String? baseUrl,
    String? model,
    String? email,
    bool? enabled,
  }) {
    return TranslationProviderConfig(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      email: email ?? this.email,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'baseUrl': baseUrl,
    'model': model,
    'email': email,
    'enabled': enabled,
  };

  static TranslationProviderConfig? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim() ?? '';
    final name = value['name']?.toString().trim() ?? '';
    final protocolName = value['protocol']?.toString();
    final protocol = TranslationProviderProtocol.values
        .where((item) => item.name == protocolName)
        .firstOrNull;
    if (id.isEmpty || name.isEmpty || protocol == null) return null;
    final baseUrl = value['baseUrl']?.toString().trim() ?? '';
    return TranslationProviderConfig(
      id: id,
      name: name,
      protocol: protocol,
      baseUrl: baseUrl.isEmpty ? protocol.defaultBaseUrl : baseUrl,
      model: value['model']?.toString().trim() ?? '',
      email: value['email']?.toString().trim() ?? '',
      enabled: value['enabled'] is bool ? value['enabled'] as bool : true,
    );
  }
}

@immutable
final class TranslationRequest {
  const TranslationRequest({required this.kind, required this.text});

  final TranslationContentKind kind;
  final String text;
}

@immutable
final class TranslationProviderResult {
  const TranslationProviderResult({
    required this.providerId,
    required this.providerName,
    required this.translation,
  });

  final String providerId;
  final String providerName;
  final String translation;
}
