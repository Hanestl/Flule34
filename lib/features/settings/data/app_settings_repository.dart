import 'package:flutter/foundation.dart';

import '../../../core/models/video_models.dart';
import '../domain/app_settings.dart';
import 'app_settings_store.dart';

final class AppSettingsRepository extends ChangeNotifier {
  AppSettingsRepository(this._store);

  static const _themeKey = 'flule34.settings.theme';
  static const _playbackQualityKey = 'flule34.settings.playback_quality';
  static const _networkPlaybackPolicyKey =
      'flule34.settings.network_playback_policy';
  static const _autoplayKey = 'flule34.settings.autoplay';
  static const _loopPlaybackKey = 'flule34.settings.loop_playback';
  static const _rememberPlaybackProgressKey =
      'flule34.settings.remember_playback_progress';
  static const _keepScreenAwakeKey = 'flule34.settings.keep_screen_awake';
  static const _backgroundPlaybackKey = 'flule34.settings.background_playback';
  static const _fullscreenOrientationKey =
      'flule34.settings.fullscreen_orientation';
  static const _defaultOrientationKey =
      'flule34.settings.default_content_orientation';
  static const _blurThumbnailsKey = 'flule34.settings.blur_thumbnails';
  static const _askDownloadQualityKey = 'flule34.settings.ask_download_quality';
  static const _downloadQualityKey = 'flule34.settings.download_quality';
  static const _wifiOnlyDownloadsKey = 'flule34.settings.wifi_only_downloads';
  static const _downloadConcurrentTasksKey =
      'flule34.settings.download_concurrent_tasks';
  static const _saveSearchHistoryKey = 'flule34.settings.save_search_history';
  static const _updateChannelKey = 'flule34.settings.update_channel';
  static const _homeVideoLayoutKey = 'flule34.settings.home_video_layout';

  final AppSettingsStore _store;
  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final values = await Future.wait<Object?>([
      _readString(_themeKey),
      _readString(_playbackQualityKey),
      _readString(_networkPlaybackPolicyKey),
      _readBool(_autoplayKey),
      _readBool(_loopPlaybackKey),
      _readBool(_rememberPlaybackProgressKey),
      _readBool(_keepScreenAwakeKey),
      _readBool(_backgroundPlaybackKey),
      _readString(_fullscreenOrientationKey),
      _readString(_defaultOrientationKey),
      _readBool(_blurThumbnailsKey),
      _readBool(_askDownloadQualityKey),
      _readString(_downloadQualityKey),
      _readBool(_wifiOnlyDownloadsKey),
      _readString(_downloadConcurrentTasksKey),
      _readBool(_saveSearchHistoryKey),
      _readString(_updateChannelKey),
      _readString(_homeVideoLayoutKey),
    ]);
    _settings = AppSettings(
      theme: _themeValue(values[0] as String?),
      playbackQuality: _qualityValue(
        values[1] as String?,
        AppSettings.defaults.playbackQuality,
      ),
      networkPlaybackPolicy: _enumValue(
        NetworkPlaybackPolicy.values,
        values[2] as String?,
        AppSettings.defaults.networkPlaybackPolicy,
      ),
      autoplay: values[3] as bool? ?? AppSettings.defaults.autoplay,
      loopPlayback: values[4] as bool? ?? AppSettings.defaults.loopPlayback,
      rememberPlaybackProgress:
          values[5] as bool? ?? AppSettings.defaults.rememberPlaybackProgress,
      keepScreenAwake:
          values[6] as bool? ?? AppSettings.defaults.keepScreenAwake,
      backgroundPlayback:
          values[7] as bool? ?? AppSettings.defaults.backgroundPlayback,
      fullscreenOrientation: _enumValue(
        FullscreenOrientationPreference.values,
        values[8] as String?,
        AppSettings.defaults.fullscreenOrientation,
      ),
      defaultOrientation: _enumValue(
        ContentOrientation.values,
        values[9] as String?,
        AppSettings.defaults.defaultOrientation,
      ),
      blurThumbnails:
          values[10] as bool? ?? AppSettings.defaults.blurThumbnails,
      askDownloadQuality:
          values[11] as bool? ?? AppSettings.defaults.askDownloadQuality,
      downloadQuality: _qualityValue(
        values[12] as String?,
        AppSettings.defaults.downloadQuality,
      ),
      wifiOnlyDownloads:
          values[13] as bool? ?? AppSettings.defaults.wifiOnlyDownloads,
      downloadConcurrentTasks:
          (int.tryParse(values[14] as String? ?? '') ??
                  AppSettings.defaults.downloadConcurrentTasks)
              .clamp(1, 4),
      saveSearchHistory:
          values[15] as bool? ?? AppSettings.defaults.saveSearchHistory,
      updateChannel: _enumValue(
        UpdateChannel.values,
        values[16] as String?,
        AppSettings.defaults.updateChannel,
      ),
      homeVideoLayout: _enumValue(
        HomeVideoLayout.values,
        values[17] as String?,
        AppSettings.defaults.homeVideoLayout,
      ),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemePreference value) async {
    await _store.writeString(_themeKey, value.name);
    _update(_settings.copyWith(theme: value));
  }

  Future<void> setPlaybackQuality(VideoQualityPreference value) async {
    await _store.writeString(_playbackQualityKey, value.name);
    _update(_settings.copyWith(playbackQuality: value));
  }

  Future<void> setNetworkPlaybackPolicy(NetworkPlaybackPolicy value) async {
    await _store.writeString(_networkPlaybackPolicyKey, value.name);
    _update(_settings.copyWith(networkPlaybackPolicy: value));
  }

  Future<void> setAutoplay(bool value) async {
    await _store.writeBool(_autoplayKey, value);
    _update(_settings.copyWith(autoplay: value));
  }

  Future<void> setLoopPlayback(bool value) async {
    await _store.writeBool(_loopPlaybackKey, value);
    _update(_settings.copyWith(loopPlayback: value));
  }

  Future<void> setRememberPlaybackProgress(bool value) async {
    await _store.writeBool(_rememberPlaybackProgressKey, value);
    _update(_settings.copyWith(rememberPlaybackProgress: value));
  }

  Future<void> setKeepScreenAwake(bool value) async {
    await _store.writeBool(_keepScreenAwakeKey, value);
    _update(_settings.copyWith(keepScreenAwake: value));
  }

  Future<void> setBackgroundPlayback(bool value) async {
    await _store.writeBool(_backgroundPlaybackKey, value);
    _update(_settings.copyWith(backgroundPlayback: value));
  }

  Future<void> setFullscreenOrientation(
    FullscreenOrientationPreference value,
  ) async {
    await _store.writeString(_fullscreenOrientationKey, value.name);
    _update(_settings.copyWith(fullscreenOrientation: value));
  }

  Future<void> setDefaultOrientation(ContentOrientation value) async {
    await _store.writeString(_defaultOrientationKey, value.name);
    _update(_settings.copyWith(defaultOrientation: value));
  }

  Future<void> setBlurThumbnails(bool value) async {
    await _store.writeBool(_blurThumbnailsKey, value);
    _update(_settings.copyWith(blurThumbnails: value));
  }

  Future<void> setAskDownloadQuality(bool value) async {
    await _store.writeBool(_askDownloadQualityKey, value);
    _update(_settings.copyWith(askDownloadQuality: value));
  }

  Future<void> setDownloadQuality(VideoQualityPreference value) async {
    await _store.writeString(_downloadQualityKey, value.name);
    _update(_settings.copyWith(downloadQuality: value));
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    await _store.writeBool(_wifiOnlyDownloadsKey, value);
    _update(_settings.copyWith(wifiOnlyDownloads: value));
  }

  Future<void> setDownloadConcurrentTasks(int value) async {
    final normalized = value.clamp(1, 4);
    await _store.writeString(
      _downloadConcurrentTasksKey,
      normalized.toString(),
    );
    _update(_settings.copyWith(downloadConcurrentTasks: normalized));
  }

  Future<void> setSaveSearchHistory(bool value) async {
    await _store.writeBool(_saveSearchHistoryKey, value);
    _update(_settings.copyWith(saveSearchHistory: value));
  }

  Future<void> setUpdateChannel(UpdateChannel value) async {
    await _store.writeString(_updateChannelKey, value.name);
    _update(_settings.copyWith(updateChannel: value));
  }

  Future<void> setHomeVideoLayout(HomeVideoLayout value) async {
    await _store.writeString(_homeVideoLayoutKey, value.name);
    _update(_settings.copyWith(homeVideoLayout: value));
  }

  void _update(AppSettings value) {
    if (identical(value, _settings)) {
      return;
    }
    _settings = value;
    notifyListeners();
  }

  Future<String?> _readString(String key) async {
    try {
      return await _store.readString(key);
    } on TypeError {
      return null;
    }
  }

  Future<bool?> _readBool(String key) async {
    try {
      return await _store.readBool(key);
    } on TypeError {
      return null;
    }
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  VideoQualityPreference _qualityValue(
    String? name,
    VideoQualityPreference fallback,
  ) {
    // 1.2.0 以前的“自动”实际等同于 1080p，保留无感迁移。
    if (name == 'automatic') {
      return VideoQualityPreference.p1080;
    }
    return _enumValue(VideoQualityPreference.values, name, fallback);
  }

  AppThemePreference _themeValue(String? name) {
    if (name == 'amoled') {
      return AppThemePreference.dark;
    }
    return _enumValue(
      AppThemePreference.values,
      name,
      AppSettings.defaults.theme,
    );
  }
}
