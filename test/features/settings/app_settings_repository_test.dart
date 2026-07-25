import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';
import 'package:flule34/features/settings/domain/app_settings.dart';
import 'package:flule34/features/settings/domain/quality_selection.dart';

void main() {
  test('设置使用安全默认值并持久化变更', () async {
    final store = _MemorySettingsStore();
    final repository = AppSettingsRepository(store);
    addTearDown(repository.dispose);

    await repository.load();
    expect(repository.settings.theme, AppThemePreference.system);
    expect(repository.settings.askDownloadQuality, isTrue);

    await repository.setTheme(AppThemePreference.light);
    await repository.setAutoplay(true);
    await repository.setRememberPlaybackProgress(false);
    await repository.setWifiOnlyDownloads(true);
    await repository.setUpdateChannel(UpdateChannel.prerelease);

    final restored = AppSettingsRepository(store);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.settings.theme, AppThemePreference.light);
    expect(restored.settings.autoplay, isTrue);
    expect(restored.settings.rememberPlaybackProgress, isFalse);
    expect(restored.settings.wifiOnlyDownloads, isTrue);
    expect(restored.settings.updateChannel, UpdateChannel.prerelease);
  });

  test('旧纯黑主题迁移为中性深色主题', () async {
    final repository = AppSettingsRepository(
      _MemorySettingsStore({'flule34.settings.theme': 'amoled'}),
    );
    addTearDown(repository.dispose);

    await repository.load();

    expect(repository.settings.theme, AppThemePreference.dark);
  });

  test('损坏或过时的枚举值回退到默认设置', () async {
    final store = _MemorySettingsStore({
      'flule34.settings.theme': 'removed_theme',
      'flule34.settings.playback_quality': '8k',
      'flule34.settings.autoplay': 'yes',
    });
    final repository = AppSettingsRepository(store);
    addTearDown(repository.dispose);

    await repository.load();

    expect(repository.settings.theme, AppSettings.defaults.theme);
    expect(
      repository.settings.playbackQuality,
      AppSettings.defaults.playbackQuality,
    );
    expect(repository.settings.autoplay, AppSettings.defaults.autoplay);
  });

  test('清晰度规则支持最高、精确值和最近值', () {
    const sources = [
      VideoSource(
        label: '360p',
        url: 'https://example.com/360.mp4',
        isHd: false,
      ),
      VideoSource(
        label: '720p HD',
        url: 'https://example.com/720.mp4',
        isHd: true,
      ),
      VideoSource(
        label: '1080p',
        url: 'https://example.com/1080.mp4',
        isHd: true,
      ),
    ];

    expect(
      selectVideoSource(sources, VideoQualityPreference.highest).label,
      '1080p',
    );
    expect(
      selectVideoSource(sources, VideoQualityPreference.p720).label,
      '720p HD',
    );
    expect(
      selectVideoSource(sources, VideoQualityPreference.p480).label,
      '360p',
    );
  });
}

final class _MemorySettingsStore implements AppSettingsStore {
  _MemorySettingsStore([Map<String, Object>? values]) : _values = {...?values};

  final Map<String, Object> _values;

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
