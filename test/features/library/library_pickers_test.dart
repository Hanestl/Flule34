import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flule34/features/library/local_library_picker.dart';
import 'package:flule34/features/library/playlist_picker.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('本地库选择器点击已勾选项目会移出视频', (tester) async {
    final repository = _PickerLocalLibraryRepository();
    String? message;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                message = await manageVideoLocalLibraries(
                  context: context,
                  repository: repository,
                  video: _video,
                );
              },
              child: const Text('本地分类库'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('本地分类库'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('新建本地库'), findsOneWidget);

    await tester.tap(find.text('测试本地库'));
    await tester.pumpAndSettle();

    expect(repository.removed, isTrue);
    expect(repository.added, isFalse);
    expect(message, '已从“测试本地库”移出。');
  });

  testWidgets('播放列表选择器显示勾选和新建入口并可移除视频', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final api = _PickerRule34VideoApi(harness.sessionStore);
    addTearDown(api.close);
    String? message;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                message = await manageVideoAccountPlaylists(
                  context: context,
                  api: api,
                  video: _video,
                );
              },
              child: const Text('播放列表'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('播放列表'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('新建播放列表'), findsOneWidget);

    await tester.tap(find.text('测试播放列表'));
    await tester.pumpAndSettle();

    expect(api.removedPlaylistId, '42');
    expect(api.addedPlaylistId, isNull);
    expect(message, '已从播放列表“测试播放列表”移出。');
  });
}

const _video = VideoItem(id: '123', title: '测试视频', slug: 'test-video');

final class _PickerLocalLibraryRepository implements LocalLibraryRepository {
  bool added = false;
  bool removed = false;

  final LocalLibrary library = LocalLibrary(
    id: 1,
    name: '测试本地库',
    normalizedName: '测试本地库',
    createdAt: DateTime.utc(2026, 7, 27),
    updatedAt: DateTime.utc(2026, 7, 27),
  );

  @override
  Stream<List<LocalLibrary>> watchLibraries() async* {
    yield [library];
  }

  @override
  Future<Set<int>> libraryIdsForVideo(String videoId) async => {library.id};

  @override
  Future<void> addVideo({
    required int libraryId,
    required VideoItem video,
  }) async {
    added = true;
  }

  @override
  Future<void> removeVideo({
    required int libraryId,
    required String videoId,
  }) async {
    removed = true;
  }

  @override
  Future<int> createLibrary(String name) async => library.id;

  @override
  Future<void> deleteLibrary(int id) async {}

  @override
  Future<void> renameLibrary(int id, String name) async {}

  @override
  Stream<List<LocalLibrarySummary>> watchLibrarySummaries() =>
      const Stream.empty();

  @override
  Stream<List<VideoItem>> watchVideos(int libraryId) => const Stream.empty();
}

final class _PickerRule34VideoApi extends Rule34VideoApi {
  _PickerRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  String? addedPlaylistId;
  String? removedPlaylistId;

  @override
  Future<List<PlaylistItem>> loadMyPlaylists({bool force = false}) async =>
      const [
        PlaylistItem(
          id: '42',
          title: '测试播放列表',
          path: '/playlists/42/test/',
          videoCount: 3,
        ),
      ];

  @override
  Future<Set<String>> playlistIdsForVideo(VideoItem video) async => {'42'};

  @override
  Future<void> addVideoToPlaylist({
    required VideoItem video,
    required String playlistId,
  }) async {
    addedPlaylistId = playlistId;
  }

  @override
  Future<void> removeVideoFromPlaylist({
    required VideoItem video,
    required String playlistId,
  }) async {
    removedPlaylistId = playlistId;
  }

  @override
  void close() {}
}
