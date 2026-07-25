import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/playback/data/playback_repository.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('播放进度按账号保存和恢复', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = PlaybackRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );

    await repository.savePosition(
      video: _video,
      position: const Duration(seconds: 30),
      duration: const Duration(minutes: 2),
    );
    expect(
      await repository.loadPosition('4505897'),
      const Duration(seconds: 30),
    );
    final continueWatching = await repository.watchContinueWatching().first;
    expect(continueWatching, hasLength(1));
    expect(continueWatching.single.title, _video.title);
    expect(continueWatching.single.slug, _video.slug);

    await harness.sessionStore.authenticate('2002');
    expect(await repository.loadPosition('4505897'), isNull);
    await harness.sessionStore.authenticate('1001');
    expect(
      await repository.loadPosition('4505897'),
      const Duration(seconds: 30),
    );
  });

  test('接近播放结尾时将恢复位置归零', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = PlaybackRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );

    await repository.savePosition(
      video: _video,
      position: const Duration(seconds: 110),
      duration: const Duration(minutes: 2),
    );

    expect(await repository.loadPosition('4505897'), isNull);
    final record = await harness.database.findPlaybackPosition(
      userId: '1001',
      videoId: '4505897',
    );
    expect(record?.positionMs, 0);
  });

  test('关闭进度记忆后不读取或写入进度', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = PlaybackRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );
    await repository.savePosition(
      video: _video,
      position: const Duration(seconds: 30),
      duration: const Duration(minutes: 2),
    );

    await settings.setRememberPlaybackProgress(false);
    expect(await repository.loadPosition('4505897'), isNull);
    await repository.savePosition(
      video: _video,
      position: const Duration(seconds: 50),
      duration: const Duration(minutes: 2),
    );
    final record = await harness.database.findPlaybackPosition(
      userId: '1001',
      videoId: '4505897',
    );
    expect(record?.positionMs, const Duration(seconds: 30).inMilliseconds);
  });

  test('播放会话绑定开始时账号，切换账号不会串写进度', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = PlaybackRepository(
      harness.database,
      harness.sessionStore,
      settings,
    );
    const boundUserId = '1001';

    await harness.sessionStore.authenticate('2002');
    await repository.savePositionForAccount(
      userId: boundUserId,
      video: _video,
      position: const Duration(seconds: 30),
      duration: const Duration(minutes: 2),
    );

    expect(
      await harness.database.findPlaybackPosition(
        userId: '1001',
        videoId: _video.id,
      ),
      isNotNull,
    );
    expect(
      await harness.database.findPlaybackPosition(
        userId: '2002',
        videoId: _video.id,
      ),
      isNull,
    );
  });
}

const _video = VideoItem(
  id: '4505897',
  title: '测试视频',
  slug: 'test-video',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  duration: '2:00',
);

Future<AppSettingsRepository> _createSettings() async {
  final repository = AppSettingsRepository(_MemorySettingsStore());
  await repository.load();
  return repository;
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
