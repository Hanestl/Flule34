import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import 'app_database.steps.dart' as migrations;

part 'app_database.g.dart';

class UserAccounts extends Table {
  TextColumn get userId => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAuthenticatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

@TableIndex(name: 'idx_playback_positions_updated_at', columns: {#updatedAt})
class PlaybackPositions extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get durationLabel => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}

@TableIndex(name: 'idx_download_records_task_id', columns: {#taskId})
@TableIndex(name: 'idx_download_records_user_state', columns: {#userId, #state})
class DownloadRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId =>
      text().references(UserAccounts, #userId, onDelete: KeyAction.cascade)();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get quality => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get state => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get filePath => text().nullable()();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, videoId, quality},
  ];
}

@TableIndex(
  name: 'idx_search_histories_user_last_searched',
  columns: {#userId, #lastSearchedAt},
)
class SearchHistories extends Table {
  TextColumn get userId =>
      text().references(UserAccounts, #userId, onDelete: KeyAction.cascade)();
  TextColumn get normalizedQuery => text()();
  TextColumn get displayQuery => text()();
  DateTimeColumn get lastSearchedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, normalizedQuery};
}

class LocalLibraries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  TextColumn get seedKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {normalizedName},
  ];
}

class CuratedLibrarySeeds extends Table {
  TextColumn get seedKey => text()();
  IntColumn get packVersion => integer()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {seedKey};
}

class LocalLibraryVideos extends Table {
  IntColumn get libraryId =>
      integer().references(LocalLibraries, #id, onDelete: KeyAction.cascade)();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get slug => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get previewUrl => text().nullable()();
  TextColumn get durationLabel => text().nullable()();
  TextColumn get publishedLabel => text().nullable()();
  IntColumn get views => integer().nullable()();
  IntColumn get rating => integer().nullable()();
  IntColumn get ratingVotes => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {libraryId, videoId};
}

class TranslationOverrides extends Table {
  TextColumn get kind => text()();
  TextColumn get canonicalName => text()();
  TextColumn get sourceText => text().nullable()();
  TextColumn get videoSlug => text().nullable()();
  TextColumn get translation => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {kind, canonicalName};
}

class LearnedTranslations extends Table {
  TextColumn get kind => text()();
  TextColumn get canonicalName => text()();
  TextColumn get sourceText => text()();
  TextColumn get translation => text()();
  TextColumn get providerId => text().nullable()();
  TextColumn get providerName => text().nullable()();
  TextColumn get videoSlug => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {kind, canonicalName};
}

class BuiltInTranslationStates extends Table {
  TextColumn get kind => text()();
  TextColumn get canonicalName => text()();
  IntColumn get introducedPackVersion => integer()();
  BoolColumn get protectExistingLearned =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {kind, canonicalName};
}

class TranslationCatalogPacks extends Table {
  TextColumn get packKey => text()();
  IntColumn get packVersion => integer()();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {packKey};
}

@DriftDatabase(
  tables: [
    UserAccounts,
    PlaybackPositions,
    DownloadRecords,
    SearchHistories,
    LocalLibraries,
    CuratedLibrarySeeds,
    LocalLibraryVideos,
    TranslationOverrides,
    LearnedTranslations,
    BuiltInTranslationStates,
    TranslationCatalogPacks,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'flule34',
          native: DriftNativeOptions(
            shareAcrossIsolates: true,
            setup: _setupNativeDatabase,
          ),
        ),
      );

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: migrations.stepByStep(
      from1To2: (migrator, schema) async {
        await migrator.addColumn(
          schema.playbackPositions,
          schema.playbackPositions.title,
        );
        await migrator.addColumn(
          schema.playbackPositions,
          schema.playbackPositions.slug,
        );
        await migrator.addColumn(
          schema.playbackPositions,
          schema.playbackPositions.thumbnailUrl,
        );
        await migrator.addColumn(
          schema.playbackPositions,
          schema.playbackPositions.durationLabel,
        );
      },
      from2To3: (migrator, schema) async {
        await migrator.createTable(schema.searchHistories);
      },
      from3To4: (migrator, schema) async {
        await migrator.createTable(schema.localLibraries);
        await migrator.createTable(schema.localLibraryVideos);
      },
      from4To5: (migrator, schema) async {
        await migrator.addColumn(
          schema.downloadRecords,
          schema.downloadRecords.thumbnailUrl,
        );
        await migrator.addColumn(
          schema.downloadRecords,
          schema.downloadRecords.fileName,
        );
      },
      from5To6: (migrator, schema) async {
        await migrator.addColumn(
          schema.localLibraries,
          schema.localLibraries.seedKey,
        );
        await migrator.createTable(schema.curatedLibrarySeeds);
      },
      from6To7: (migrator, schema) async {
        await migrator.addColumn(
          schema.localLibraryVideos,
          schema.localLibraryVideos.previewUrl,
        );
      },
      from7To8: (migrator, schema) async {
        await customStatement(
          'ALTER TABLE playback_positions '
          'RENAME TO playback_positions_v7',
        );
        await migrator.createTable(schema.playbackPositions);
        await customStatement('''
          INSERT INTO playback_positions (
            video_id,
            title,
            slug,
            thumbnail_url,
            duration_label,
            position_ms,
            duration_ms,
            updated_at
          )
          SELECT
            legacy.video_id,
            legacy.title,
            legacy.slug,
            legacy.thumbnail_url,
            legacy.duration_label,
            legacy.position_ms,
            legacy.duration_ms,
            legacy.updated_at
          FROM playback_positions_v7 AS legacy
          WHERE legacy.rowid = (
            SELECT candidate.rowid
            FROM playback_positions_v7 AS candidate
            WHERE candidate.video_id = legacy.video_id
            ORDER BY candidate.updated_at DESC, candidate.rowid DESC
            LIMIT 1
          )
        ''');
        await customStatement('DROP TABLE playback_positions_v7');
      },
      from8To9: (migrator, schema) async {
        await migrator.createTable(schema.translationOverrides);
      },
      from9To10: (migrator, schema) async {
        await migrator.addColumn(
          schema.translationOverrides,
          schema.translationOverrides.sourceText,
        );
        await migrator.addColumn(
          schema.translationOverrides,
          schema.translationOverrides.videoSlug,
        );
        await migrator.createTable(schema.learnedTranslations);
      },
      from10To11: (migrator, schema) async {
        await migrator.createTable(schema.builtInTranslationStates);
        await migrator.createTable(schema.translationCatalogPacks);
      },
      from11To12: (migrator, schema) async {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_playback_positions_updated_at '
          'ON playback_positions (updated_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_download_records_task_id '
          'ON download_records (task_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_download_records_user_state '
          'ON download_records (user_id, state)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_search_histories_user_last_searched '
          'ON search_histories (user_id, last_searched_at)',
        );
      },
    ),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> updateLocalLibraryVideoPreviewUrl({
    required String videoId,
    required String? previewUrl,
  }) {
    return (update(localLibraryVideos)
          ..where((item) => item.videoId.equals(videoId)))
        .write(LocalLibraryVideosCompanion(previewUrl: Value(previewUrl)));
  }

  Future<List<TranslationOverride>> loadTranslationOverrides() {
    return (select(translationOverrides)..orderBy([
          (row) => OrderingTerm.asc(row.kind),
          (row) => OrderingTerm.asc(row.canonicalName),
        ]))
        .get();
  }

  Future<void> upsertTranslationOverride({
    required String kind,
    required String canonicalName,
    String? sourceText,
    String? videoSlug,
    required String translation,
    DateTime? updatedAt,
  }) {
    return into(translationOverrides).insertOnConflictUpdate(
      TranslationOverridesCompanion.insert(
        kind: kind,
        canonicalName: canonicalName,
        sourceText: Value(sourceText),
        videoSlug: Value(videoSlug),
        translation: translation,
        updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
      ),
    );
  }

  Future<List<LearnedTranslation>> loadLearnedTranslations() {
    return (select(learnedTranslations)..orderBy([
          (row) => OrderingTerm.asc(row.kind),
          (row) => OrderingTerm.asc(row.canonicalName),
        ]))
        .get();
  }

  Future<void> upsertLearnedTranslation({
    required String kind,
    required String canonicalName,
    required String sourceText,
    required String translation,
    String? providerId,
    String? providerName,
    String? videoSlug,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().toUtc();
    final existing =
        await (select(learnedTranslations)..where(
              (row) =>
                  row.kind.equals(kind) &
                  row.canonicalName.equals(canonicalName),
            ))
            .getSingleOrNull();
    await into(learnedTranslations).insertOnConflictUpdate(
      LearnedTranslationsCompanion.insert(
        kind: kind,
        canonicalName: canonicalName,
        sourceText: sourceText,
        translation: translation,
        providerId: Value(providerId),
        providerName: Value(providerName),
        videoSlug: Value(videoSlug),
        createdAt: Value(existing?.createdAt ?? createdAt ?? now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteLearnedTranslation({
    required String kind,
    required String canonicalName,
  }) {
    return (delete(learnedTranslations)..where(
          (row) =>
              row.kind.equals(kind) & row.canonicalName.equals(canonicalName),
        ))
        .go();
  }

  Future<void> deleteLearnedTranslations(
    Iterable<({String kind, String canonicalName})> entries,
  ) async {
    final grouped = <String, Set<String>>{};
    for (final entry in entries) {
      final kind = entry.kind.trim();
      final canonicalName = entry.canonicalName.trim();
      if (kind.isEmpty || canonicalName.isEmpty) continue;
      grouped.putIfAbsent(kind, () => <String>{}).add(canonicalName);
    }
    if (grouped.isEmpty) return;

    await transaction(() async {
      for (final entry in grouped.entries) {
        await (delete(learnedTranslations)..where(
              (row) =>
                  row.kind.equals(entry.key) &
                  row.canonicalName.isIn(entry.value.toList(growable: false)),
            ))
            .go();
      }
    });
  }

  Future<void> clearLearnedTranslations() {
    return delete(learnedTranslations).go();
  }

  Future<void> setBuiltInLearnedProtection({
    required String kind,
    required String canonicalName,
    required bool protect,
  }) {
    return (update(builtInTranslationStates)..where(
          (row) =>
              row.kind.equals(kind) & row.canonicalName.equals(canonicalName),
        ))
        .write(
          BuiltInTranslationStatesCompanion(
            protectExistingLearned: Value(protect),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<TranslationCatalogPack?> loadTranslationCatalogPack(String packKey) {
    return (select(
      translationCatalogPacks,
    )..where((row) => row.packKey.equals(packKey))).getSingleOrNull();
  }

  Future<List<BuiltInTranslationState>> loadBuiltInTranslationStates() {
    return select(builtInTranslationStates).get();
  }

  Future<void> applyBuiltInTranslationPack({
    required String packKey,
    required int packVersion,
    required Iterable<({String kind, String canonicalName})> entries,
  }) async {
    await transaction(() async {
      final previous = await loadTranslationCatalogPack(packKey);
      if (previous != null && previous.packVersion >= packVersion) return;
      final baseline = previous == null;
      final now = DateTime.now().toUtc();
      final existingStates = await loadBuiltInTranslationStates();
      final existingKeys = {
        for (final state in existingStates)
          '${state.kind}:${state.canonicalName}',
      };
      final learnedRows = baseline
          ? const <LearnedTranslation>[]
          : await loadLearnedTranslations();
      final learnedKeys = {
        for (final learned in learnedRows)
          '${learned.kind}:${learned.canonicalName}',
      };
      final additions = <BuiltInTranslationStatesCompanion>[];
      for (final entry in entries) {
        final key = '${entry.kind}:${entry.canonicalName}';
        if (!existingKeys.add(key)) continue;
        additions.add(
          BuiltInTranslationStatesCompanion.insert(
            kind: entry.kind,
            canonicalName: entry.canonicalName,
            introducedPackVersion: packVersion,
            protectExistingLearned: Value(
              !baseline && learnedKeys.contains(key),
            ),
            updatedAt: Value(now),
          ),
        );
      }
      if (additions.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            builtInTranslationStates,
            additions,
            mode: InsertMode.insertOrIgnore,
          );
        });
      }
      await into(translationCatalogPacks).insertOnConflictUpdate(
        TranslationCatalogPacksCompanion.insert(
          packKey: packKey,
          packVersion: packVersion,
          appliedAt: Value(now),
        ),
      );
    });
  }

  Future<void> deleteTranslationOverride({
    required String kind,
    required String canonicalName,
  }) {
    return (delete(translationOverrides)..where(
          (row) =>
              row.kind.equals(kind) & row.canonicalName.equals(canonicalName),
        ))
        .go();
  }

  Future<void> recordAuthenticatedAccount(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await findAccount(userId);
    if (existing == null) {
      await into(userAccounts).insert(
        UserAccountsCompanion.insert(
          userId: userId,
          displayName: Value(displayName),
          avatarUrl: Value(avatarUrl),
          createdAt: Value(now),
          lastAuthenticatedAt: Value(now),
        ),
      );
      return;
    }

    await (update(
      userAccounts,
    )..where((account) => account.userId.equals(userId))).write(
      UserAccountsCompanion(
        displayName: displayName == null
            ? const Value.absent()
            : Value(displayName),
        avatarUrl: avatarUrl == null ? const Value.absent() : Value(avatarUrl),
        lastAuthenticatedAt: Value(now),
      ),
    );
  }

  Future<UserAccount?> findAccount(String userId) {
    return (select(
      userAccounts,
    )..where((account) => account.userId.equals(userId))).getSingleOrNull();
  }

  Future<void> savePlaybackPosition({
    required String videoId,
    required int positionMs,
    int? durationMs,
    String? title,
    String? slug,
    String? thumbnailUrl,
    String? durationLabel,
  }) {
    return into(playbackPositions).insertOnConflictUpdate(
      PlaybackPositionsCompanion(
        videoId: Value(videoId),
        title: title == null ? const Value.absent() : Value(title),
        slug: slug == null ? const Value.absent() : Value(slug),
        thumbnailUrl: thumbnailUrl == null
            ? const Value.absent()
            : Value(thumbnailUrl),
        durationLabel: durationLabel == null
            ? const Value.absent()
            : Value(durationLabel),
        positionMs: Value(positionMs),
        durationMs: Value(durationMs),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<PlaybackPosition?> findPlaybackPosition({required String videoId}) {
    return (select(
      playbackPositions,
    )..where((position) => position.videoId.equals(videoId))).getSingleOrNull();
  }

  Stream<List<PlaybackPosition>> watchContinueWatching() {
    return (select(playbackPositions)
          ..where(
            (position) =>
                position.positionMs.isBiggerThanValue(0) &
                position.title.isNotNull() &
                position.slug.isNotNull(),
          )
          ..orderBy([(position) => OrderingTerm.desc(position.updatedAt)]))
        .watch();
  }

  Future<void> saveDownloadRecord(DownloadRecordsCompanion record) {
    return into(downloadRecords).insertOnConflictUpdate(record);
  }

  Future<DownloadRecord?> findDownloadRecord(String id) {
    return (select(
      downloadRecords,
    )..where((record) => record.id.equals(id))).getSingleOrNull();
  }

  Future<DownloadRecord?> findDownloadRecordByTaskId(String taskId) {
    return (select(
      downloadRecords,
    )..where((record) => record.taskId.equals(taskId))).getSingleOrNull();
  }

  Future<DownloadRecord?> findVideoDownload({
    required String userId,
    required String videoId,
    required String quality,
  }) {
    return (select(downloadRecords)..where(
          (record) =>
              record.userId.equals(userId) &
              record.videoId.equals(videoId) &
              record.quality.equals(quality),
        ))
        .getSingleOrNull();
  }

  Future<void> updateDownloadStatus({
    required String id,
    required String state,
    String? filePath,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return (update(
      downloadRecords,
    )..where((record) => record.id.equals(id))).write(
      DownloadRecordsCompanion(
        state: Value(state),
        filePath: filePath == null ? const Value.absent() : Value(filePath),
        errorMessage: errorMessage == null
            ? const Value.absent()
            : Value(errorMessage),
        completedAt: completedAt == null
            ? const Value.absent()
            : Value(completedAt),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateDownloadProgress({
    required String id,
    required int bytesDownloaded,
    int? totalBytes,
  }) {
    return (update(
      downloadRecords,
    )..where((record) => record.id.equals(id))).write(
      DownloadRecordsCompanion(
        bytesDownloaded: Value(bytesDownloaded),
        totalBytes: totalBytes == null
            ? const Value.absent()
            : Value(totalBytes),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Stream<List<DownloadRecord>> watchDownloads(String userId) {
    return (select(downloadRecords)
          ..where((record) => record.userId.equals(userId))
          ..orderBy([
            (record) => OrderingTerm.desc(record.createdAt),
            (record) => OrderingTerm.desc(record.id),
          ]))
        .watch();
  }

  Future<List<DownloadRecord>> downloadsForUser(String userId) {
    return (select(downloadRecords)
          ..where((record) => record.userId.equals(userId))
          ..orderBy([
            (record) => OrderingTerm.desc(record.createdAt),
            (record) => OrderingTerm.desc(record.id),
          ]))
        .get();
  }

  Future<List<DownloadRecord>> allDownloads() {
    return (select(downloadRecords)..orderBy([
          (record) => OrderingTerm.desc(record.createdAt),
          (record) => OrderingTerm.desc(record.id),
        ]))
        .get();
  }

  Future<List<DownloadRecord>> activeDownloads(String userId) {
    return (select(downloadRecords)..where(
          (record) =>
              record.userId.equals(userId) &
              record.state.isIn(const [
                'queued',
                'running',
                'waiting_to_retry',
                'paused',
              ]),
        ))
        .get();
  }

  Future<void> deleteDownloadRecord(String id) {
    return (delete(
      downloadRecords,
    )..where((record) => record.id.equals(id))).go();
  }

  Future<void> deleteAllPlaybackPositions() {
    return delete(playbackPositions).go();
  }

  Future<void> recordSearchQuery({
    required String userId,
    required String query,
  }) async {
    final displayQuery = query.trim();
    final normalizedQuery = displayQuery.toLowerCase();
    if (normalizedQuery.isEmpty) {
      return;
    }

    await transaction(() async {
      final latest =
          await (select(searchHistories)
                ..where((item) => item.userId.equals(userId))
                ..orderBy([(item) => OrderingTerm.desc(item.lastSearchedAt)])
                ..limit(1))
              .getSingleOrNull();
      final now = DateTime.now().toUtc();
      var searchedAt = DateTime.fromMillisecondsSinceEpoch(
        (now.millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );
      if (latest != null && !searchedAt.isAfter(latest.lastSearchedAt)) {
        searchedAt = latest.lastSearchedAt.add(const Duration(seconds: 1));
      }
      await into(searchHistories).insertOnConflictUpdate(
        SearchHistoriesCompanion.insert(
          userId: userId,
          normalizedQuery: normalizedQuery,
          displayQuery: displayQuery,
          lastSearchedAt: Value(searchedAt),
        ),
      );
      final all =
          await (select(searchHistories)
                ..where((item) => item.userId.equals(userId))
                ..orderBy([(item) => OrderingTerm.desc(item.lastSearchedAt)]))
              .get();
      if (all.length > 20) {
        final keep = all.take(20).map((item) => item.normalizedQuery).toSet();
        await (delete(searchHistories)..where(
              (row) =>
                  row.userId.equals(userId) & row.normalizedQuery.isNotIn(keep),
            ))
            .go();
      }
    });
  }

  Stream<List<SearchHistory>> watchSearchHistory(String userId) {
    final query = select(searchHistories)
      ..where((item) => item.userId.equals(userId))
      ..orderBy([(item) => OrderingTerm.desc(item.lastSearchedAt)])
      ..limit(20);
    return query.watch();
  }

  Future<void> deleteSearchHistory({
    required String userId,
    required String normalizedQuery,
  }) {
    return (delete(searchHistories)..where(
          (item) =>
              item.userId.equals(userId) &
              item.normalizedQuery.equals(normalizedQuery),
        ))
        .go();
  }

  Future<void> clearSearchHistory(String userId) {
    return (delete(
      searchHistories,
    )..where((item) => item.userId.equals(userId))).go();
  }

  Future<void> deleteAccountData(String userId) {
    return (delete(
      userAccounts,
    )..where((account) => account.userId.equals(userId))).go();
  }

  static void _setupNativeDatabase(CommonDatabase database) {
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA synchronous = NORMAL');
    database.execute('PRAGMA busy_timeout = 5000');
  }
}
