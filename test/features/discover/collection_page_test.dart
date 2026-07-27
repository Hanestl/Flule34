import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/discover/collection_page.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/shared/site_avatar.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('艺术家集合使用数值筛选 ID 并显示头像', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = _CollectionApi(harness.sessionStore);
    addTearDown(api.close);
    final settings = AppSettingsRepository(_MemorySettingsStore());
    await settings.load();
    addTearDown(settings.dispose);
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CollectionPage(
            api: api,
            collection: const ContentCollectionItem(
              id: 'hydrafxx',
              filterId: '87',
              title: 'HydraFXX',
              path: '/models/hydrafxx/',
              kind: DiscoveryKind.model,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.lastFilters.models.single.id, '87');
    expect(find.byType(SiteAvatar), findsOneWidget);
    expect(find.text('HydraFXX'), findsWidgets);
  });
}

final class _CollectionApi extends Rule34VideoApi {
  _CollectionApi(SessionStore sessionStore) : super(sessionStore: sessionStore);

  SearchFilters lastFilters = const SearchFilters();

  @override
  Future<ContentCollectionItem> resolveCollection(
    ContentCollectionItem collection,
  ) async {
    return collection.copyWith(
      thumbnailUrl: 'https://rule34video.com/contents/models/87/s1_hydra.png',
    );
  }

  @override
  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    lastFilters = filters;
    return const [];
  }

  @override
  void close() {}
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
