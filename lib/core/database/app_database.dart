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

class PlaybackPositions extends Table {
  TextColumn get userId =>
      text().references(UserAccounts, #userId, onDelete: KeyAction.cascade)();
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get durationLabel => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {userId, videoId};
}

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
  TextColumn get durationLabel => text().nullable()();
  TextColumn get publishedLabel => text().nullable()();
  IntColumn get views => integer().nullable()();
  IntColumn get rating => integer().nullable()();
  IntColumn get ratingVotes => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {libraryId, videoId};
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
  int get schemaVersion => 6;

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
    ),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
    required String userId,
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
        userId: Value(userId),
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

  Future<PlaybackPosition?> findPlaybackPosition({
    required String userId,
    required String videoId,
  }) {
    return (select(playbackPositions)..where(
          (position) =>
              position.userId.equals(userId) & position.videoId.equals(videoId),
        ))
        .getSingleOrNull();
  }

  Stream<List<PlaybackPosition>> watchContinueWatching(String userId) {
    return (select(playbackPositions)
          ..where(
            (position) =>
                position.userId.equals(userId) &
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
          ..orderBy([(record) => OrderingTerm.desc(record.updatedAt)]))
        .watch();
  }

  Future<List<DownloadRecord>> downloadsForUser(String userId) {
    return (select(downloadRecords)
          ..where((record) => record.userId.equals(userId))
          ..orderBy([(record) => OrderingTerm.desc(record.updatedAt)]))
        .get();
  }

  Future<List<DownloadRecord>> allDownloads() {
    return (select(
      downloadRecords,
    )..orderBy([(record) => OrderingTerm.desc(record.updatedAt)])).get();
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

  Future<void> deletePlaybackPositionsForUser(String userId) {
    return (delete(
      playbackPositions,
    )..where((position) => position.userId.equals(userId))).go();
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
      for (final item in all.skip(20)) {
        await (delete(searchHistories)..where(
              (row) =>
                  row.userId.equals(item.userId) &
                  row.normalizedQuery.equals(item.normalizedQuery),
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
