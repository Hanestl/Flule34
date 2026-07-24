// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 does not corrupt data', () async {
    const createdAt = 1700000000;
    const updatedAt = 1700000060;
    const oldUserAccountsData = [
      v1.UserAccountsData(
        userId: '1001',
        displayName: '测试账号',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: createdAt,
        lastAuthenticatedAt: updatedAt,
      ),
    ];
    const expectedNewUserAccountsData = [
      v2.UserAccountsData(
        userId: '1001',
        displayName: '测试账号',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: createdAt,
        lastAuthenticatedAt: updatedAt,
      ),
    ];

    const oldPlaybackPositionsData = [
      v1.PlaybackPositionsData(
        userId: '1001',
        videoId: '4505897',
        positionMs: 30000,
        durationMs: 120000,
        updatedAt: updatedAt,
      ),
    ];
    const expectedNewPlaybackPositionsData = [
      v2.PlaybackPositionsData(
        userId: '1001',
        videoId: '4505897',
        positionMs: 30000,
        durationMs: 120000,
        updatedAt: updatedAt,
      ),
    ];

    const oldDownloadRecordsData = [
      v1.DownloadRecordsData(
        id: 'download-1',
        userId: '1001',
        videoId: '4505897',
        title: '测试视频',
        quality: '720p',
        state: 'complete',
        taskId: 'download-1',
        filePath: 'downloads/1001/video.mp4',
        bytesDownloaded: 1024,
        totalBytes: 1024,
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: updatedAt,
      ),
    ];
    const expectedNewDownloadRecordsData = [
      v2.DownloadRecordsData(
        id: 'download-1',
        userId: '1001',
        videoId: '4505897',
        title: '测试视频',
        quality: '720p',
        state: 'complete',
        taskId: 'download-1',
        filePath: 'downloads/1001/video.mp4',
        bytesDownloaded: 1024,
        totalBytes: 1024,
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: updatedAt,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.userAccounts, oldUserAccountsData);
        batch.insertAll(oldDb.playbackPositions, oldPlaybackPositionsData);
        batch.insertAll(oldDb.downloadRecords, oldDownloadRecordsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewUserAccountsData,
          await newDb.select(newDb.userAccounts).get(),
        );
        expect(
          expectedNewPlaybackPositionsData,
          await newDb.select(newDb.playbackPositions).get(),
        );
        expect(
          expectedNewDownloadRecordsData,
          await newDb.select(newDb.downloadRecords).get(),
        );
      },
    );
  });
}
