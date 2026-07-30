// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;

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

  test('migration from v2 to v3 preserves account media data', () async {
    const createdAt = 1700000000;
    const updatedAt = 1700000060;
    const oldUser = v2.UserAccountsData(
      userId: '1001',
      displayName: '测试账号',
      createdAt: createdAt,
      lastAuthenticatedAt: updatedAt,
    );
    const newUser = v3.UserAccountsData(
      userId: '1001',
      displayName: '测试账号',
      createdAt: createdAt,
      lastAuthenticatedAt: updatedAt,
    );
    const oldPlayback = v2.PlaybackPositionsData(
      userId: '1001',
      videoId: '4505897',
      title: '测试视频',
      slug: 'test-video',
      positionMs: 30000,
      durationMs: 120000,
      updatedAt: updatedAt,
    );
    const newPlayback = v3.PlaybackPositionsData(
      userId: '1001',
      videoId: '4505897',
      title: '测试视频',
      slug: 'test-video',
      positionMs: 30000,
      durationMs: 120000,
      updatedAt: updatedAt,
    );
    const oldDownload = v2.DownloadRecordsData(
      id: 'download-1',
      userId: '1001',
      videoId: '4505897',
      title: '测试视频',
      quality: '720p',
      state: 'complete',
      bytesDownloaded: 1024,
      totalBytes: 1024,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: updatedAt,
    );
    const newDownload = v3.DownloadRecordsData(
      id: 'download-1',
      userId: '1001',
      videoId: '4505897',
      title: '测试视频',
      quality: '720p',
      state: 'complete',
      bytesDownloaded: 1024,
      totalBytes: 1024,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: updatedAt,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.userAccounts, oldUser);
        batch.insert(oldDb.playbackPositions, oldPlayback);
        batch.insert(oldDb.downloadRecords, oldDownload);
      },
      validateItems: (newDb) async {
        expect([newUser], await newDb.select(newDb.userAccounts).get());
        expect([
          newPlayback,
        ], await newDb.select(newDb.playbackPositions).get());
        expect([newDownload], await newDb.select(newDb.downloadRecords).get());
        expect(await newDb.select(newDb.searchHistories).get(), isEmpty);
      },
    );
  });

  test('migration from v5 to v6 preserves local libraries', () async {
    const timestamp = 1700000000;
    const oldLibrary = v5.LocalLibrariesData(
      id: 1,
      name: '自建库',
      normalizedName: '自建库',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    const newLibrary = v6.LocalLibrariesData(
      id: 1,
      name: '自建库',
      normalizedName: '自建库',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    const oldVideo = v5.LocalLibraryVideosData(
      libraryId: 1,
      videoId: '4505897',
      title: '测试视频',
      slug: 'test-video',
      durationLabel: '1:00',
      rating: 98,
      ratingVotes: 321,
      addedAt: timestamp,
    );
    const newVideo = v6.LocalLibraryVideosData(
      libraryId: 1,
      videoId: '4505897',
      title: '测试视频',
      slug: 'test-video',
      durationLabel: '1:00',
      rating: 98,
      ratingVotes: 321,
      addedAt: timestamp,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 5,
      newVersion: 6,
      createOld: v5.DatabaseAtV5.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.localLibraries, oldLibrary);
        batch.insert(oldDb.localLibraryVideos, oldVideo);
      },
      validateItems: (newDb) async {
        expect([newLibrary], await newDb.select(newDb.localLibraries).get());
        expect([newVideo], await newDb.select(newDb.localLibraryVideos).get());
        expect(await newDb.select(newDb.curatedLibrarySeeds).get(), isEmpty);
      },
    );
  });

  test('migration from v6 to v7 preserves local videos', () async {
    const timestamp = 1700000000;
    const oldLibrary = v6.LocalLibrariesData(
      id: 1,
      name: '旧本地库',
      normalizedName: '旧本地库',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    const newLibrary = v7.LocalLibrariesData(
      id: 1,
      name: '旧本地库',
      normalizedName: '旧本地库',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    const oldVideo = v6.LocalLibraryVideosData(
      libraryId: 1,
      videoId: '4514001',
      title: '旧视频',
      slug: 'old-video',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      durationLabel: '2:00',
      rating: 99,
      ratingVotes: 100,
      addedAt: timestamp,
    );
    const newVideo = v7.LocalLibraryVideosData(
      libraryId: 1,
      videoId: '4514001',
      title: '旧视频',
      slug: 'old-video',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      durationLabel: '2:00',
      rating: 99,
      ratingVotes: 100,
      addedAt: timestamp,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 6,
      newVersion: 7,
      createOld: v6.DatabaseAtV6.new,
      createNew: v7.DatabaseAtV7.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.localLibraries, oldLibrary);
        batch.insert(oldDb.localLibraryVideos, oldVideo);
      },
      validateItems: (newDb) async {
        expect([newLibrary], await newDb.select(newDb.localLibraries).get());
        expect([newVideo], await newDb.select(newDb.localLibraryVideos).get());
        expect(
          (await newDb.select(newDb.localLibraryVideos).get())
              .single
              .previewUrl,
          null,
        );
      },
    );
  });

  test(
    'migration from v7 to v8 merges account progress by latest update',
    () async {
      const older = 1700000000;
      const newer = 1700000060;
      const newest = 1700000120;
      const users = [
        v7.UserAccountsData(
          userId: '1001',
          createdAt: older,
          lastAuthenticatedAt: older,
        ),
        v7.UserAccountsData(
          userId: '2002',
          createdAt: older,
          lastAuthenticatedAt: newer,
        ),
      ];
      const oldPositions = [
        v7.PlaybackPositionsData(
          userId: '1001',
          videoId: 'same-video',
          title: '旧标题',
          slug: 'old-title',
          positionMs: 30000,
          durationMs: 120000,
          updatedAt: older,
        ),
        v7.PlaybackPositionsData(
          userId: '2002',
          videoId: 'same-video',
          title: '新标题',
          slug: 'new-title',
          positionMs: 70000,
          durationMs: 120000,
          updatedAt: newest,
        ),
        v7.PlaybackPositionsData(
          userId: '1001',
          videoId: 'other-video',
          title: '另一条',
          slug: 'other-video',
          positionMs: 15000,
          durationMs: 60000,
          updatedAt: newer,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 7,
        newVersion: 8,
        createOld: v7.DatabaseAtV7.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.userAccounts, users);
          batch.insertAll(oldDb.playbackPositions, oldPositions);
        },
        validateItems: (newDb) async {
          final positions = await newDb.select(newDb.playbackPositions).get()
            ..sort((left, right) => left.videoId.compareTo(right.videoId));
          expect(positions, [
            const v8.PlaybackPositionsData(
              videoId: 'other-video',
              title: '另一条',
              slug: 'other-video',
              positionMs: 15000,
              durationMs: 60000,
              updatedAt: newer,
            ),
            const v8.PlaybackPositionsData(
              videoId: 'same-video',
              title: '新标题',
              slug: 'new-title',
              positionMs: 70000,
              durationMs: 120000,
              updatedAt: newest,
            ),
          ]);
          expect(await newDb.select(newDb.userAccounts).get(), hasLength(2));
        },
      );
    },
  );
}
