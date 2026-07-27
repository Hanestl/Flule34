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
      rating: 98,
      ratingVotes: 321,
    );

    await repository.addVideo(libraryId: firstId, video: video);
    await repository.addVideo(libraryId: secondId, video: video);

    expect(await repository.libraryIdsForVideo(video.id), {firstId, secondId});
    expect((await repository.watchVideos(firstId).first).single.rating, 98);
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
}
