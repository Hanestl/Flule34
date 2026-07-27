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
    expect(repository.settings.playbackQuality, VideoQualityPreference.p1080);

    await repository.setTheme(AppThemePreference.light);
    await repository.setNetworkPlaybackPolicy(NetworkPlaybackPolicy.dataSaver);
    await repository.setKeepScreenAwake(false);
    await repository.setFullscreenOrientation(
      FullscreenOrientationPreference.device,
    );
    await repository.setDefaultOrientation(ContentOrientation.futa);
    await repository.setDownloadConcurrentTasks(3);
    await repository.setSaveSearchHistory(false);
    await repository.setAutoplay(true);
    await repository.setRememberPlaybackProgress(false);
    await repository.setWifiOnlyDownloads(true);
    await repository.setUpdateChannel(UpdateChannel.prerelease);
    await repository.setHomeVideoLayout(HomeVideoLayout.doubleColumn);

    final restored = AppSettingsRepository(store);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.settings.theme, AppThemePreference.light);
    expect(
      restored.settings.networkPlaybackPolicy,
      NetworkPlaybackPolicy.dataSaver,
    );
    expect(restored.settings.keepScreenAwake, isFalse);
    expect(
      restored.settings.fullscreenOrientation,
      FullscreenOrientationPreference.device,
    );
    expect(restored.settings.defaultOrientation, ContentOrientation.futa);
    expect(restored.settings.downloadConcurrentTasks, 3);
    expect(restored.settings.saveSearchHistory, isFalse);
    expect(restored.settings.autoplay, isTrue);
    expect(restored.settings.rememberPlaybackProgress, isFalse);
    expect(restored.settings.wifiOnlyDownloads, isTrue);
    expect(restored.settings.updateChannel, UpdateChannel.prerelease);
    expect(restored.settings.homeVideoLayout, HomeVideoLayout.doubleColumn);
  });

  test('旧纯黑主题迁移为中性深色主题', () async {
    final repository = AppSettingsRepository(
      _MemorySettingsStore({'flule34.settings.theme': 'amoled'}),
    );
    addTearDown(repository.dispose);

    await repository.load();

    expect(repository.settings.theme, AppThemePreference.dark);
  });

  test('旧自动清晰度无感迁移为 1080p', () async {
    final repository = AppSettingsRepository(
      _MemorySettingsStore({'flule34.settings.playback_quality': 'automatic'}),
    );
    addTearDown(repository.dispose);

    await repository.load();

    expect(repository.settings.playbackQuality, VideoQualityPreference.p1080);
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

  test('清晰度规则优先目标档位并只向下回退', () {
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
      VideoSource(
        label: '2160p (4K)',
        url: 'https://example.com/2160.mp4',
        isHd: true,
      ),
    ];

    expect(
      selectVideoSource(sources, VideoQualityPreference.highest).label,
      '2160p (4K)',
    );
    expect(
      selectVideoSource(sources, VideoQualityPreference.p720).label,
      '720p HD',
    );
    expect(
      selectVideoSource(sources, VideoQualityPreference.p480).label,
      '360p',
    );
    const missing1080 = [
      VideoSource(
        label: '720p',
        url: 'https://example.com/720.mp4',
        isHd: true,
      ),
      VideoSource(
        label: '2160p',
        url: 'https://example.com/2160.mp4',
        isHd: true,
      ),
    ];
    expect(
      selectVideoSource(missing1080, VideoQualityPreference.p1080).label,
      '720p',
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
