import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/library/library_page.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  testWidgets('媒体库只保留收藏、历史和订阅三个页签', (tester) async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final api = _LibraryApi(harness.sessionStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
        child: MaterialApp(home: LibraryPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('继续观看'), findsNothing);
    expect(find.text('稍后观看'), findsNothing);
    expect(find.text('播放列表'), findsNothing);
  });
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

  @override
  Future<List<VideoItem>> loadFavorites(int page) async => const [];

  @override
  Future<List<VideoItem>> loadHistory(int page) async => const [];

  @override
  Future<List<SubscriptionItem>> loadSubscriptions({
    bool force = false,
  }) async => const [];

  @override
  void close() {}
}
