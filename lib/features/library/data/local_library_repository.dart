import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_log_service.dart';
import '../../../core/models/video_models.dart';

final class LocalLibraryException implements Exception {
  const LocalLibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class LocalLibrarySummary {
  const LocalLibrarySummary({required this.library, required this.videoCount});

  final LocalLibrary library;
  final int videoCount;
}

abstract interface class LocalLibraryRepository {
  Stream<List<LocalLibrary>> watchLibraries();

  Stream<List<LocalLibrarySummary>> watchLibrarySummaries();

  Stream<List<VideoItem>> watchVideos(int libraryId);

  Future<Set<int>> libraryIdsForVideo(String videoId);

  Future<int> createLibrary(String name);

  Future<void> renameLibrary(int id, String name);

  Future<void> deleteLibrary(int id);

  Future<void> addVideo({required int libraryId, required VideoItem video});

  Future<void> removeVideo({required int libraryId, required String videoId});
}

final class DriftLocalLibraryRepository implements LocalLibraryRepository {
  const DriftLocalLibraryRepository(this._database, {AppLogService? logService})
    : _logs = logService;

  final AppDatabase _database;
  final AppLogService? _logs;

  @override
  Stream<List<LocalLibrary>> watchLibraries() {
    return (_database.select(_database.localLibraries)..orderBy([
          (item) => OrderingTerm.desc(item.updatedAt),
          (item) => OrderingTerm.asc(item.name),
        ]))
        .watch();
  }

  @override
  Stream<List<LocalLibrarySummary>> watchLibrarySummaries() {
    final videoCount = _database.localLibraryVideos.videoId.count();
    final query = _database.select(_database.localLibraries).join([
      leftOuterJoin(
        _database.localLibraryVideos,
        _database.localLibraryVideos.libraryId.equalsExp(
          _database.localLibraries.id,
        ),
        useColumns: false,
      ),
    ]);
    query
      ..addColumns([videoCount])
      ..groupBy([_database.localLibraries.id])
      ..orderBy([
        OrderingTerm.desc(_database.localLibraries.updatedAt),
        OrderingTerm.asc(_database.localLibraries.name),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => LocalLibrarySummary(
              library: row.readTable(_database.localLibraries),
              videoCount: row.read(videoCount) ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<VideoItem>> watchVideos(int libraryId) {
    final query = _database.select(_database.localLibraryVideos)
      ..where((item) => item.libraryId.equals(libraryId))
      ..orderBy([(item) => OrderingTerm.desc(item.addedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => VideoItem(
              id: row.videoId,
              title: row.title,
              slug: row.slug,
              thumbnailUrl: row.thumbnailUrl,
              duration: row.durationLabel,
              publishedLabel: row.publishedLabel,
              views: row.views,
              rating: row.rating,
              ratingVotes: row.ratingVotes,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Set<int>> libraryIdsForVideo(String videoId) async {
    final rows = await (_database.select(
      _database.localLibraryVideos,
    )..where((item) => item.videoId.equals(videoId))).get();
    return rows.map((row) => row.libraryId).toSet();
  }

  @override
  Future<int> createLibrary(String name) async {
    final normalized = _normalizeName(name);
    final displayName = name.trim();
    if (normalized.isEmpty) {
      throw const LocalLibraryException('库名称不能为空。');
    }
    final existing =
        await (_database.select(_database.localLibraries)
              ..where((item) => item.normalizedName.equals(normalized)))
            .getSingleOrNull();
    if (existing != null) {
      throw const LocalLibraryException('已经存在同名的本地库。');
    }
    final id = await _database
        .into(_database.localLibraries)
        .insert(
          LocalLibrariesCompanion.insert(
            name: displayName,
            normalizedName: normalized,
          ),
        );
    unawaited(_logs?.info('local_library', '已创建本地库，libraryId=$id。'));
    return id;
  }

  @override
  Future<void> renameLibrary(int id, String name) async {
    final normalized = _normalizeName(name);
    final displayName = name.trim();
    if (normalized.isEmpty) {
      throw const LocalLibraryException('库名称不能为空。');
    }
    final duplicate =
        await (_database.select(_database.localLibraries)..where(
              (item) =>
                  item.normalizedName.equals(normalized) &
                  item.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      throw const LocalLibraryException('已经存在同名的本地库。');
    }
    await (_database.update(
      _database.localLibraries,
    )..where((item) => item.id.equals(id))).write(
      LocalLibrariesCompanion(
        name: Value(displayName),
        normalizedName: Value(normalized),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    unawaited(_logs?.info('local_library', '已重命名本地库，libraryId=$id。'));
  }

  @override
  Future<void> deleteLibrary(int id) async {
    await _database.transaction(() async {
      final library = await (_database.select(
        _database.localLibraries,
      )..where((item) => item.id.equals(id))).getSingleOrNull();
      if (library == null) {
        return;
      }
      final seedKey = library.seedKey;
      if (seedKey != null) {
        await (_database.update(_database.curatedLibrarySeeds)
              ..where((item) => item.seedKey.equals(seedKey)))
            .write(const CuratedLibrarySeedsCompanion(dismissed: Value(true)));
      }
      await (_database.delete(
        _database.localLibraries,
      )..where((item) => item.id.equals(id))).go();
    });
    unawaited(_logs?.info('local_library', '已删除本地库，libraryId=$id。'));
  }

  @override
  Future<void> addVideo({
    required int libraryId,
    required VideoItem video,
  }) async {
    await _database.transaction(() async {
      final library = await (_database.select(
        _database.localLibraries,
      )..where((item) => item.id.equals(libraryId))).getSingleOrNull();
      if (library == null) {
        throw const LocalLibraryException('所选本地库已经不存在。');
      }
      final now = DateTime.now().toUtc();
      await _database
          .into(_database.localLibraryVideos)
          .insertOnConflictUpdate(
            LocalLibraryVideosCompanion.insert(
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
          );
      await (_database.update(_database.localLibraries)
            ..where((item) => item.id.equals(libraryId)))
          .write(LocalLibrariesCompanion(updatedAt: Value(now)));
    });
    unawaited(
      _logs?.info(
        'local_library',
        '视频已加入本地库，libraryId=$libraryId，videoId=${video.id}。',
      ),
    );
  }

  @override
  Future<void> removeVideo({
    required int libraryId,
    required String videoId,
  }) async {
    await (_database.delete(_database.localLibraryVideos)..where(
          (item) =>
              item.libraryId.equals(libraryId) & item.videoId.equals(videoId),
        ))
        .go();
    unawaited(
      _logs?.info(
        'local_library',
        '视频已移出本地库，libraryId=$libraryId，videoId=$videoId。',
      ),
    );
  }

  String _normalizeName(String value) => value.trim().toLowerCase();
}
