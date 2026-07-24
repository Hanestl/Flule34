import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('不同账号的播放进度相互隔离', () async {
    await database.recordAuthenticatedAccount('1001');
    await database.recordAuthenticatedAccount('2002');

    await database.savePlaybackPosition(
      userId: '1001',
      videoId: '4505897',
      positionMs: 12000,
      durationMs: 60000,
    );
    await database.savePlaybackPosition(
      userId: '2002',
      videoId: '4505897',
      positionMs: 34000,
      durationMs: 60000,
    );

    final first = await database.findPlaybackPosition(
      userId: '1001',
      videoId: '4505897',
    );
    final second = await database.findPlaybackPosition(
      userId: '2002',
      videoId: '4505897',
    );

    expect(first?.positionMs, 12000);
    expect(second?.positionMs, 34000);
  });

  test('删除账号会级联清除该账号的进度与下载记录', () async {
    await database.recordAuthenticatedAccount('1001');
    await database.savePlaybackPosition(
      userId: '1001',
      videoId: '4505897',
      positionMs: 12000,
    );
    await database.saveDownloadRecord(
      DownloadRecordsCompanion(
        id: const Value('download-1'),
        userId: const Value('1001'),
        videoId: const Value('4505897'),
        title: const Value('测试视频'),
        quality: const Value('720p'),
        state: const Value('queued'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    await database.deleteAccountData('1001');

    expect(await database.findAccount('1001'), isNull);
    expect(
      await database.findPlaybackPosition(userId: '1001', videoId: '4505897'),
      isNull,
    );
    expect(await database.select(database.downloadRecords).get(), isEmpty);
  });

  test('搜索历史按账号隔离并对大小写去重', () async {
    await database.recordAuthenticatedAccount('1001');
    await database.recordAuthenticatedAccount('2002');

    await database.recordSearchQuery(userId: '1001', query: 'Example');
    await database.recordSearchQuery(userId: '1001', query: 'example');
    await database.recordSearchQuery(userId: '2002', query: 'Another');

    final first = await database.watchSearchHistory('1001').first;
    final second = await database.watchSearchHistory('2002').first;

    expect(first, hasLength(1));
    expect(first.single.normalizedQuery, 'example');
    expect(first.single.displayQuery, 'example');
    expect(second.single.displayQuery, 'Another');
  });

  test('搜索历史只保留当前账号最近 20 条并随账号级联删除', () async {
    await database.recordAuthenticatedAccount('1001');
    for (var index = 0; index < 22; index += 1) {
      await database.recordSearchQuery(userId: '1001', query: 'query-$index');
    }

    final history = await database.watchSearchHistory('1001').first;
    expect(history, hasLength(20));
    expect(history.first.displayQuery, 'query-21');
    expect(history.any((item) => item.displayQuery == 'query-0'), isFalse);

    await database.deleteAccountData('1001');
    expect(await database.select(database.searchHistories).get(), isEmpty);
  });
}
