import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

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

@DriftDatabase(tables: [UserAccounts, PlaybackPositions, DownloadRecords])
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
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
  }) {
    return into(playbackPositions).insertOnConflictUpdate(
      PlaybackPositionsCompanion(
        userId: Value(userId),
        videoId: Value(videoId),
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
