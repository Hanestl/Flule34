import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/translation_models.dart';

enum TranslationImportMode { safeMerge, importedLayersWin }

final class TranslationArchiveLayer {
  const TranslationArchiveLayer({
    required this.translation,
    this.providerId,
    this.providerName,
    this.createdAt,
    this.updatedAt,
    this.preferOverBuiltIn = false,
  });

  final String translation;
  final String? providerId;
  final String? providerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool preferOverBuiltIn;
}

final class TranslationArchiveEntry {
  const TranslationArchiveEntry({
    required this.kind,
    required this.canonicalName,
    required this.sourceText,
    this.videoSlug,
    this.builtInTranslation,
    this.learned,
    this.userOverride,
  });

  final TranslationCatalogKind kind;
  final String canonicalName;
  final String sourceText;
  final String? videoSlug;
  final String? builtInTranslation;
  final TranslationArchiveLayer? learned;
  final TranslationArchiveLayer? userOverride;
}

final class ParsedTranslationArchive {
  const ParsedTranslationArchive({
    required this.entries,
    required this.builtInLayerCount,
    required this.learnedLayerCount,
    required this.userLayerCount,
  });

  final List<TranslationArchiveEntry> entries;
  final int builtInLayerCount;
  final int learnedLayerCount;
  final int userLayerCount;
}

final class TranslationImportResult {
  const TranslationImportResult({
    required this.importedLearned,
    required this.importedUserOverrides,
    required this.skippedLearned,
    required this.skippedUserOverrides,
    required this.ignoredBuiltIn,
  });

  final int importedLearned;
  final int importedUserOverrides;
  final int skippedLearned;
  final int skippedUserOverrides;
  final int ignoredBuiltIn;

  int get importedTotal => importedLearned + importedUserOverrides;
}

final class TranslationCatalogArchiveService {
  const TranslationCatalogArchiveService();

  static const format = 'flule34-translation-catalog';
  static const schemaVersion = 1;
  static const maxImportBytes = 10 * 1024 * 1024;
  static const maxEntries = 100000;

  String encodeCatalog(
    List<TranslationCatalogItem> items, {
    required String appVersion,
    DateTime? exportedAt,
  }) {
    final document = <String, Object?>{
      'format': format,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'exportedAt': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'entries': [
        for (final item in items)
          <String, Object?>{
            'kind': item.kind.name,
            'canonicalName': item.canonicalName,
            'sourceText': item.sourceText,
            if (item.videoSlug?.isNotEmpty == true) 'videoSlug': item.videoSlug,
            if (item.hasBuiltIn)
              'builtIn': {'translation': item.builtInTranslation},
            if (item.hasLearned)
              'learned': <String, Object?>{
                'translation': item.learnedTranslation,
                if (item.learnedProviderName?.isNotEmpty == true)
                  'providerName': item.learnedProviderName,
                if (item.learnedCreatedAt != null)
                  'createdAt': item.learnedCreatedAt!.toUtc().toIso8601String(),
                if (item.learnedUpdatedAt != null)
                  'updatedAt': item.learnedUpdatedAt!.toUtc().toIso8601String(),
                'preferOverBuiltIn': item.protectLearnedFromBuiltIn,
              },
            if (item.hasUserOverride)
              'userOverride': <String, Object?>{
                'translation': item.userTranslation,
                if (item.userUpdatedAt != null)
                  'updatedAt': item.userUpdatedAt!.toUtc().toIso8601String(),
              },
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  ParsedTranslationArchive parseBytes(Uint8List bytes) {
    if (bytes.length > maxImportBytes) {
      throw const FormatException('翻译库文件不能超过 10 MB');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['format'] != format) {
      throw const FormatException('不是 Flule34 翻译库文件');
    }
    if (decoded['schemaVersion'] != schemaVersion) {
      throw FormatException('不支持的翻译库版本：${decoded['schemaVersion']}');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('翻译库缺少 entries');
    }
    if (rawEntries.length > maxEntries) {
      throw const FormatException('翻译库词条数量超过 100000 条');
    }
    final entries = <TranslationArchiveEntry>[];
    var builtInCount = 0;
    var learnedCount = 0;
    var userCount = 0;
    for (final raw in rawEntries) {
      if (raw is! Map) continue;
      final kindName = raw['kind']?.toString();
      final kind = TranslationCatalogKind.values
          .where((item) => item.name == kindName)
          .firstOrNull;
      final canonicalName = _limitedText(raw['canonicalName'], 1000);
      final sourceText = _limitedText(raw['sourceText'], 4000);
      if (kind == null || canonicalName.isEmpty || sourceText.isEmpty) continue;
      final builtIn = _layer(raw['builtIn'], allowMetadata: false);
      final learned = _layer(raw['learned'], allowMetadata: true);
      final user = _layer(raw['userOverride'], allowMetadata: false);
      if (builtIn != null) builtInCount += 1;
      if (learned != null) learnedCount += 1;
      if (user != null) userCount += 1;
      entries.add(
        TranslationArchiveEntry(
          kind: kind,
          canonicalName: canonicalName,
          sourceText: sourceText,
          videoSlug: _optionalLimitedText(raw['videoSlug'], 2000),
          builtInTranslation: builtIn?.translation,
          learned: learned,
          userOverride: user,
        ),
      );
    }
    return ParsedTranslationArchive(
      entries: List.unmodifiable(entries),
      builtInLayerCount: builtInCount,
      learnedLayerCount: learnedCount,
      userLayerCount: userCount,
    );
  }

  Future<File> createExportFile(String content) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}flule34_translation_exports',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    final now = DateTime.now();
    final name =
        'Flule34-translations-${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file;
  }

  static TranslationArchiveLayer? _layer(
    Object? raw, {
    required bool allowMetadata,
  }) {
    if (raw is! Map) return null;
    final translation = _limitedText(raw['translation'], 8000);
    if (translation.isEmpty) return null;
    return TranslationArchiveLayer(
      translation: translation,
      providerId: allowMetadata
          ? _optionalLimitedText(raw['providerId'], 500)
          : null,
      providerName: allowMetadata
          ? _optionalLimitedText(raw['providerName'], 500)
          : null,
      createdAt: allowMetadata ? _date(raw['createdAt']) : null,
      updatedAt: _date(raw['updatedAt']),
      preferOverBuiltIn: allowMetadata && raw['preferOverBuiltIn'] == true,
    );
  }

  static DateTime? _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toUtc();
  }

  static String _limitedText(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';
    if (text.length > maxLength) {
      throw const FormatException('翻译库包含长度异常的字段');
    }
    return text;
  }

  static String? _optionalLimitedText(Object? value, int maxLength) {
    final text = _limitedText(value, maxLength);
    return text.isEmpty ? null : text;
  }
}
