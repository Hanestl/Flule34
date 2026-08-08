import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/translation_provider_models.dart';
import '../session/secret_store.dart';
import '../../features/settings/data/app_settings_store.dart';

final class TranslationProviderRepository extends ChangeNotifier {
  TranslationProviderRepository({required this.store, required this.secrets});

  static const _settingsKey = 'flule34.translation.providers.v1';
  static const _reasoningProfilesKey =
      'flule34.translation.reasoning_profiles.v1';
  static const _secretPrefix = 'flule34.translation.provider.';

  final AppSettingsStore store;
  final SecretStore secrets;
  List<TranslationProviderConfig> _providers = const [];
  final Map<String, _ReasoningProfile> _reasoningProfiles = {};
  bool _loaded = false;

  List<TranslationProviderConfig> get providers => _providers;
  List<TranslationProviderConfig> get enabledProviders =>
      _providers.where((item) => item.enabled).toList(growable: false);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await store.readString(_settingsKey);
    final decoded = raw == null ? null : _tryDecode(raw);
    if (decoded is List) {
      _providers = decoded
          .map(TranslationProviderConfig.fromJson)
          .whereType<TranslationProviderConfig>()
          .toList(growable: false);
    }
    final rawProfiles = await store.readString(_reasoningProfilesKey);
    final decodedProfiles = rawProfiles == null
        ? null
        : _tryDecode(rawProfiles);
    if (decodedProfiles is Map) {
      for (final entry in decodedProfiles.entries) {
        final profile = _ReasoningProfile.fromJson(entry.value);
        if (entry.key is String && profile != null) {
          _reasoningProfiles[entry.key as String] = profile;
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> upsert(
    TranslationProviderConfig provider, {
    String? apiKey,
  }) async {
    final normalized = provider.copyWith(
      name: provider.name.trim(),
      baseUrl: _normalizeBaseUrl(provider.baseUrl),
      model: provider.model.trim(),
      email: provider.email.trim(),
    );
    final next = [..._providers];
    final index = next.indexWhere((item) => item.id == normalized.id);
    final previous = index < 0 ? null : next[index];
    final invalidatesReasoningProfile =
        previous != null &&
        _reasoningFingerprint(previous) != _reasoningFingerprint(normalized);
    if (index < 0) {
      next.add(normalized);
    } else {
      next[index] = normalized;
    }
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await secrets.write(_secretKey(normalized.id), apiKey.trim());
    } else if (!normalized.protocol.requiresApiKey ||
        (previous != null && !_sharesCredentialScope(previous, normalized))) {
      await secrets.delete(_secretKey(normalized.id));
    }
    await _replace(next);
    if (invalidatesReasoningProfile) {
      await clearReasoningStrategy(normalized.id);
    }
  }

  Future<void> remove(String id) async {
    await secrets.delete(_secretKey(id));
    _reasoningProfiles.remove(id);
    await _persistReasoningProfiles();
    await _replace(_providers.where((item) => item.id != id).toList());
  }

  Future<void> duplicateAfter(String id) async {
    final index = _providers.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final original = _providers[index];
    final duplicateId =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}copy';
    final duplicate = TranslationProviderConfig(
      id: duplicateId,
      name: original.name,
      protocol: original.protocol,
      baseUrl: original.baseUrl,
      model: original.model,
      email: original.email,
      enabled: original.enabled,
    );
    final apiKey = await apiKeyFor(original.id);
    if (apiKey?.isNotEmpty == true) {
      await secrets.write(_secretKey(duplicateId), apiKey!);
    }
    final next = [..._providers]..insert(index + 1, duplicate);
    try {
      await _replace(next);
    } on Object {
      await secrets.delete(_secretKey(duplicateId));
      rethrow;
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _replace([
      for (final item in _providers)
        item.id == id ? item.copyWith(enabled: enabled) : item,
    ]);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final next = [..._providers];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    await _replace(next);
  }

  Future<String?> apiKeyFor(String id) => secrets.read(_secretKey(id));

  Future<bool> hasApiKey(String id) async {
    final value = await apiKeyFor(id);
    return value != null && value.isNotEmpty;
  }

  Future<AiReasoningStrategy?> reasoningStrategyFor(
    TranslationProviderConfig provider,
  ) async {
    final profile = _reasoningProfiles[provider.id];
    if (profile == null) return null;
    if (profile.fingerprint == _reasoningFingerprint(provider)) {
      return profile.strategy;
    }
    await clearReasoningStrategy(provider.id);
    return null;
  }

  Future<void> rememberReasoningStrategy(
    TranslationProviderConfig provider,
    AiReasoningStrategy strategy,
  ) async {
    _reasoningProfiles[provider.id] = _ReasoningProfile(
      fingerprint: _reasoningFingerprint(provider),
      strategy: strategy,
    );
    await _persistReasoningProfiles();
  }

  Future<void> clearReasoningStrategy(String providerId) async {
    if (_reasoningProfiles.remove(providerId) == null) return;
    await _persistReasoningProfiles();
  }

  Future<void> _replace(List<TranslationProviderConfig> providers) async {
    _providers = List.unmodifiable(providers);
    await store.writeString(
      _settingsKey,
      jsonEncode(_providers.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistReasoningProfiles() {
    return store.writeString(
      _reasoningProfilesKey,
      jsonEncode({
        for (final entry in _reasoningProfiles.entries)
          entry.key: entry.value.toJson(),
      }),
    );
  }

  static Object? _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static bool _sharesCredentialScope(
    TranslationProviderConfig previous,
    TranslationProviderConfig next,
  ) {
    if (previous.protocol != next.protocol) return false;
    final previousUri = Uri.tryParse(previous.baseUrl.trim());
    final nextUri = Uri.tryParse(next.baseUrl.trim());
    if (previousUri == null || nextUri == null) return false;
    return previousUri.scheme.toLowerCase() == nextUri.scheme.toLowerCase() &&
        previousUri.host.toLowerCase() == nextUri.host.toLowerCase() &&
        previousUri.port == nextUri.port;
  }

  static String _reasoningFingerprint(TranslationProviderConfig provider) {
    final normalizedBaseUrl = _normalizeBaseUrl(provider.baseUrl).toLowerCase();
    return '${provider.protocol.name}|$normalizedBaseUrl|${provider.model.trim()}';
  }

  static String _secretKey(String id) => '$_secretPrefix$id.api_key';
}

final class _ReasoningProfile {
  const _ReasoningProfile({required this.fingerprint, required this.strategy});

  final String fingerprint;
  final AiReasoningStrategy strategy;

  Map<String, Object?> toJson() => {
    'fingerprint': fingerprint,
    'strategy': strategy.name,
  };

  static _ReasoningProfile? fromJson(Object? value) {
    if (value is! Map) return null;
    final fingerprint = value['fingerprint']?.toString() ?? '';
    final strategyName = value['strategy']?.toString();
    final strategy = AiReasoningStrategy.values
        .where((item) => item.name == strategyName)
        .firstOrNull;
    if (fingerprint.isEmpty || strategy == null) return null;
    return _ReasoningProfile(fingerprint: fingerprint, strategy: strategy);
  }
}
