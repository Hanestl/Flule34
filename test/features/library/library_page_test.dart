import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/core/services/predictive_prefetch_service.dart';
import 'package:flule34/features/library/library_page.dart';
import 'package:flule34/features/library/data/local_library_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('媒体库保留网站数据并新增本地分类库', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _LibraryApi(harness.sessionStore);
    final prefetch = PredictivePrefetchService(
      api: api,
      sessionStore: harness.sessionStore,
    );
    addTearDown(prefetch.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
        child: MaterialApp(
          home: LibraryPage(
            api: api,
            localLibraryRepository: _FakeLocalLibraryRepository(),
            prefetchService: prefetch,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('本地分类库'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('继续观看'), findsNothing);
    expect(find.text('稍后观看'), findsNothing);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('媒体库'), findsNothing);
    expect(api.favoriteLoads, 0);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(api.favoriteLoads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _FakeLocalLibraryRepository implements LocalLibraryRepository {
  @override
  Stream<List<LocalLibrary>> watchLibraries() => Stream.value(const []);

  @override
  Stream<List<LocalLibrarySummary>> watchLibrarySummaries() =>
      Stream.value(const []);

  @override
  Stream<List<VideoItem>> watchVideos(int libraryId) => Stream.value(const []);

  @override
  Future<Set<int>> libraryIdsForVideo(String videoId) async => const {};

  @override
  Future<int> createLibrary(String name) => throw UnimplementedError();

  @override
  Future<void> renameLibrary(int id, String name) => throw UnimplementedError();

  @override
  Future<void> deleteLibrary(int id) => throw UnimplementedError();

  @override
  Future<void> addVideo({required int libraryId, required VideoItem video}) =>
      throw UnimplementedError();

  @override
  Future<void> removeVideo({required int libraryId, required String videoId}) =>
      throw UnimplementedError();
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}

final class _LibraryApi extends Rule34VideoApi {
  _LibraryApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  var favoriteLoads = 0;

  @override
  Future<List<VideoItem>> loadFavorites(int page, {bool force = false}) async {
    favoriteLoads += 1;
    return const [];
  }

  @override
  Future<List<VideoItem>> loadHistory(int page, {bool force = false}) async =>
      const [];

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}
