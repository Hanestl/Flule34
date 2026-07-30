import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/providers.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/features/playback/data/playback_repository.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/presentation/settings_pages.dart';

void main() {
  testWidgets('关闭记忆播放进度需确认并清空全部本地记录', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final settings = AppSettingsRepository(_MemorySettingsStore());
    await settings.load();
    final playback = PlaybackRepository(database, settings);
    addTearDown(database.close);
    addTearDown(settings.dispose);

    await database.savePlaybackPosition(
      videoId: 'video-1',
      positionMs: 30000,
      durationMs: 120000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appSettingsRepositoryProvider.overrideWithValue(settings),
          playbackRepositoryProvider.overrideWithValue(playback),
        ],
        child: const MaterialApp(home: PlaybackSettingsPage()),
      ),
    );

    final progressSwitch = find.widgetWithText(SwitchListTile, '记忆播放进度');
    await tester.ensureVisible(progressSwitch);
    await tester.tap(progressSwitch);
    await tester.pumpAndSettle();

    expect(find.text('关闭后将清除全部本地播放进度。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(settings.settings.rememberPlaybackProgress, isTrue);
    expect(
      await database.select(database.playbackPositions).get(),
      hasLength(1),
    );

    await tester.tap(progressSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭并清除'));
    await tester.pumpAndSettle();

    expect(settings.settings.rememberPlaybackProgress, isFalse);
    expect(await database.select(database.playbackPositions).get(), isEmpty);
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
