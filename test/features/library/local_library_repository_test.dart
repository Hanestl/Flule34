import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('本地库与账号无关，同一视频可加入多个库并随库删除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final firstId = await repository.createLibrary('动画');
    final secondId = await repository.createLibrary('待整理');
    const video = VideoItem(
      id: '4505897',
      title: '测试视频',
      slug: 'test-video',
      thumbnailUrl: 'https://example.com/336x189/1.jpg',
      previewUrl: 'https://example.com/preview.mp4',
      rating: 98,
      ratingVotes: 321,
    );

    await repository.addVideo(libraryId: firstId, video: video);
    await repository.addVideo(libraryId: secondId, video: video);

    expect(await repository.libraryIdsForVideo(video.id), {firstId, secondId});
    final storedVideo = (await repository.watchVideos(firstId).first).single;
    expect(storedVideo.rating, 98);
    expect(storedVideo.previewUrl, 'https://example.com/preview.mp4');
    final summaries = await repository.watchLibrarySummaries().first;
    expect(
      summaries.where((item) => item.library.id == firstId).single.videoCount,
      1,
    );

    await repository.deleteLibrary(firstId);
    expect(await repository.libraryIdsForVideo(video.id), {secondId});
  });

  test('本地库名称忽略大小写和首尾空格去重', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    await repository.createLibrary('Favorites');

    await expectLater(
      repository.createLibrary(' favorites '),
      throwsA(isA<LocalLibraryException>()),
    );
  });

  test('旧本地视频补全预览地址后会持久化到所有所在库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final firstId = await repository.createLibrary('库一');
    final secondId = await repository.createLibrary('库二');
    const video = VideoItem(id: '4514001', title: '旧视频', slug: 'old-video');
    await repository.addVideo(libraryId: firstId, video: video);
    await repository.addVideo(libraryId: secondId, video: video);

    await harness.database.updateLocalLibraryVideoPreviewUrl(
      videoId: video.id,
      previewUrl: 'https://example.com/resolved.mp4',
    );

    final firstVideo = (await repository.watchVideos(firstId).first).single;
    final secondVideo = (await repository.watchVideos(secondId).first).single;
    expect(firstVideo.previewUrl, 'https://example.com/resolved.mp4');
    expect(secondVideo.previewUrl, 'https://example.com/resolved.mp4');
  });
}
