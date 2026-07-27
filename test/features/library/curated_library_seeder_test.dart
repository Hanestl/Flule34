import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/features/library/data/curated_library_seeder.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('正式精选清单可完整导入', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _FileManifestLoader(
        AssetCuratedLibraryManifestLoader.assetPath,
      ),
    );

    await seeder.seedIfNeeded();

    final libraries = await harness.database.select(
      harness.database.localLibraries,
    ).get();
    final videos = await harness.database.select(
      harness.database.localLibraryVideos,
    ).get();
    expect(libraries, hasLength(5));
    expect(videos, hasLength(289));
    expect(
      libraries.map((item) => item.name).toSet(),
      {
        '作者：hydrafxx',
        '作者：nagoonimation',
        '作者：bamhor',
        '作者：JuicyNeko',
        '作者：Drills3D',
      },
    );
  });

  test('精选库只导入一次，同名用户库不会被覆盖', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final userLibraryId = await repository.createLibrary('作者：hydrafxx');
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifest),
    );

    await seeder.seedIfNeeded();
    await seeder.seedIfNeeded();

    final libraries = await harness.database
        .select(harness.database.localLibraries)
        .get();
    expect(libraries, hasLength(2));
    expect(
      libraries.singleWhere((item) => item.id == userLibraryId).seedKey,
      isNull,
    );
    final seeded = libraries.singleWhere((item) => item.seedKey != null);
    expect(seeded.name, '作者：hydrafxx（精选）');
    expect(seeded.seedKey, 'author_hydrafxx');

    final videos = await harness.database
        .select(harness.database.localLibraryVideos)
        .get();
    expect(videos, hasLength(2));
    expect(videos.map((item) => item.libraryId).toSet(), {seeded.id});
    expect(
      await harness.database.select(harness.database.curatedLibrarySeeds).get(),
      hasLength(1),
    );
  });

  test('用户删除精选库后再次初始化不会恢复', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    final repository = DriftLocalLibraryRepository(harness.database);
    final seeder = CuratedLibrarySeeder(
      harness.database,
      const _StringManifestLoader(_manifest),
    );
    await seeder.seedIfNeeded();
    final seeded =
        (await harness.database.select(harness.database.localLibraries).get())
            .single;

    await repository.deleteLibrary(seeded.id);
    await seeder.seedIfNeeded();

    expect(
      await harness.database.select(harness.database.localLibraries).get(),
      isEmpty,
    );
    final state =
        (await harness.database
                .select(harness.database.curatedLibrarySeeds)
                .get())
            .single;
    expect(state.dismissed, isTrue);
  });
}

final class _StringManifestLoader implements CuratedLibraryManifestLoader {
  const _StringManifestLoader(this.source);

  final String source;

  @override
  Future<String> load() async => source;
}

final class _FileManifestLoader implements CuratedLibraryManifestLoader {
  const _FileManifestLoader(this.path);

  final String path;

  @override
  Future<String> load() => File(path).readAsString();
}

const _manifest = '''
{
  "version": 1,
  "libraries": [
    {
      "key": "author_hydrafxx",
      "name": "作者：hydrafxx",
      "videos": [
        {
          "id": "3160398",
          "title": "Ingrid Hunnigan [HydraFXX][NO WM]",
          "slug": "4k-ingrid-hunnigan-hydrafxx-no-wm",
          "thumbnailUrl": "https://example.com/1.jpg",
          "duration": "0:47",
          "publishedLabel": "3 years ago",
          "views": 1000,
          "rating": 97,
          "ratingVotes": 798
        },
        {
          "id": "3116871",
          "title": "D.va Vibrator",
          "slug": "d-va-vibrator",
          "thumbnailUrl": null,
          "duration": "0:17",
          "publishedLabel": null,
          "views": null,
          "rating": 98,
          "ratingVotes": 165
        }
      ]
    }
  ]
}
''';
