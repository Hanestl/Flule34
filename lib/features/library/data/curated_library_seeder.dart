import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';

abstract interface class CuratedLibraryManifestLoader {
  Future<String> load();
}

final class AssetCuratedLibraryManifestLoader
    implements CuratedLibraryManifestLoader {
  const AssetCuratedLibraryManifestLoader();

  static const assetPath = 'assets/curated_libraries/v1.json';

  @override
  Future<String> load() => rootBundle.loadString(assetPath);
}

final class CuratedLibrarySeeder {
  const CuratedLibrarySeeder(this._database, this._loader);

  final AppDatabase _database;
  final CuratedLibraryManifestLoader _loader;

  Future<void> seedIfNeeded() async {
    final manifest = _CuratedManifest.parse(await _loader.load());
    await _database.transaction(() async {
      for (final preset in manifest.libraries) {
        final existingState = await (_database.select(
          _database.curatedLibrarySeeds,
        )..where((item) => item.seedKey.equals(preset.key))).getSingleOrNull();
        if (existingState != null) {
          continue;
        }

        final resolvedName = await _availableLibraryName(preset.name);
        final now = DateTime.now().toUtc();
        final libraryId = await _database
            .into(_database.localLibraries)
            .insert(
              LocalLibrariesCompanion.insert(
                name: resolvedName,
                normalizedName: _normalizeName(resolvedName),
                seedKey: Value(preset.key),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _database.batch((batch) {
          batch.insertAll(
            _database.localLibraryVideos,
            preset.videos
                .map(
                  (video) => LocalLibraryVideosCompanion.insert(
                    libraryId: libraryId,
                    videoId: video.id,
                    title: video.title,
                    slug: video.slug,
                    thumbnailUrl: Value(video.thumbnailUrl),
                    durationLabel: Value(video.duration),
                    publishedLabel: Value(video.publishedLabel),
                    views: Value(video.views),
                    rating: Value(video.rating),
                    ratingVotes: Value(video.ratingVotes),
                    addedAt: Value(now),
                  ),
                )
                .toList(growable: false),
            mode: InsertMode.insertOrIgnore,
          );
        });
        await _database
            .into(_database.curatedLibrarySeeds)
            .insert(
              CuratedLibrarySeedsCompanion.insert(
                seedKey: preset.key,
                packVersion: manifest.version,
                appliedAt: Value(now),
              ),
            );
      }
    });
  }

  Future<String> _availableLibraryName(String preferredName) async {
    final preferred = preferredName.trim();
    if (!await _libraryNameExists(preferred)) {
      return preferred;
    }
    const suffix = '（精选）';
    final withSuffix = '$preferred$suffix';
    if (!await _libraryNameExists(withSuffix)) {
      return withSuffix;
    }
    var index = 2;
    while (await _libraryNameExists('$preferred（精选 $index）')) {
      index += 1;
    }
    return '$preferred（精选 $index）';
  }

  Future<bool> _libraryNameExists(String name) async {
    final existing =
        await (_database.select(_database.localLibraries)..where(
              (item) => item.normalizedName.equals(_normalizeName(name)),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  String _normalizeName(String value) => value.trim().toLowerCase();
}

final class _CuratedManifest {
  const _CuratedManifest({required this.version, required this.libraries});

  factory _CuratedManifest.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('精选库清单格式无效。');
    }
    final version = decoded['version'];
    final libraries = decoded['libraries'];
    if (version is! int || version < 1 || libraries is! List) {
      throw const FormatException('精选库清单缺少版本或库列表。');
    }
    final parsed = libraries.map(_CuratedLibrary.parse).toList(growable: false);
    final keys = parsed.map((item) => item.key).toSet();
    if (keys.length != parsed.length) {
      throw const FormatException('精选库清单包含重复标识。');
    }
    return _CuratedManifest(version: version, libraries: parsed);
  }

  final int version;
  final List<_CuratedLibrary> libraries;
}

final class _CuratedLibrary {
  const _CuratedLibrary({
    required this.key,
    required this.name,
    required this.videos,
  });

  factory _CuratedLibrary.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('精选库条目格式无效。');
    }
    final key = value['key'];
    final name = value['name'];
    final videos = value['videos'];
    if (key is! String ||
        key.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        videos is! List) {
      throw const FormatException('精选库条目缺少必要字段。');
    }
    final parsedVideos = videos
        .map(_CuratedVideo.parse)
        .toList(growable: false);
    final videoIds = parsedVideos.map((item) => item.id).toSet();
    if (videoIds.length != parsedVideos.length) {
      throw FormatException('精选库 $name 包含重复视频。');
    }
    return _CuratedLibrary(
      key: key.trim(),
      name: name.trim(),
      videos: parsedVideos,
    );
  }

  final String key;
  final String name;
  final List<_CuratedVideo> videos;
}

final class _CuratedVideo {
  const _CuratedVideo({
    required this.id,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    this.duration,
    this.publishedLabel,
    this.views,
    this.rating,
    this.ratingVotes,
  });

  factory _CuratedVideo.parse(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('精选视频条目格式无效。');
    }
    final id = value['id'];
    final title = value['title'];
    final slug = value['slug'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        slug is! String ||
        slug.trim().isEmpty) {
      throw const FormatException('精选视频条目缺少必要字段。');
    }
    return _CuratedVideo(
      id: id.trim(),
      title: title.trim(),
      slug: slug.trim(),
      thumbnailUrl: value['thumbnailUrl'] as String?,
      duration: value['duration'] as String?,
      publishedLabel: value['publishedLabel'] as String?,
      views: value['views'] as int?,
      rating: value['rating'] as int?,
      ratingVotes: value['ratingVotes'] as int?,
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final String? duration;
  final String? publishedLabel;
  final int? views;
  final int? rating;
  final int? ratingVotes;
}
