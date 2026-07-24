import 'package:flutter/foundation.dart';

import '../domain/app_settings.dart';
import 'app_settings_store.dart';

final class AppSettingsRepository extends ChangeNotifier {
  AppSettingsRepository(this._store);

  static const _themeKey = 'flule34.settings.theme';
  static const _playbackQualityKey = 'flule34.settings.playback_quality';
  static const _autoplayKey = 'flule34.settings.autoplay';
  static const _loopPlaybackKey = 'flule34.settings.loop_playback';
  static const _rememberPlaybackProgressKey =
      'flule34.settings.remember_playback_progress';
  static const _blurThumbnailsKey = 'flule34.settings.blur_thumbnails';
  static const _askDownloadQualityKey = 'flule34.settings.ask_download_quality';
  static const _downloadQualityKey = 'flule34.settings.download_quality';
  static const _wifiOnlyDownloadsKey = 'flule34.settings.wifi_only_downloads';

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
      _readBool(_autoplayKey),
      _readBool(_loopPlaybackKey),
      _readBool(_rememberPlaybackProgressKey),
      _readBool(_blurThumbnailsKey),
      _readBool(_askDownloadQualityKey),
      _readString(_downloadQualityKey),
      _readBool(_wifiOnlyDownloadsKey),
    ]);
    _settings = AppSettings(
      theme: _enumValue(
        AppThemePreference.values,
        values[0] as String?,
        AppSettings.defaults.theme,
      ),
      playbackQuality: _enumValue(
        VideoQualityPreference.values,
        values[1] as String?,
        AppSettings.defaults.playbackQuality,
      ),
      autoplay: values[2] as bool? ?? AppSettings.defaults.autoplay,
      loopPlayback: values[3] as bool? ?? AppSettings.defaults.loopPlayback,
      rememberPlaybackProgress:
          values[4] as bool? ?? AppSettings.defaults.rememberPlaybackProgress,
      blurThumbnails: values[5] as bool? ?? AppSettings.defaults.blurThumbnails,
      askDownloadQuality:
          values[6] as bool? ?? AppSettings.defaults.askDownloadQuality,
      downloadQuality: _enumValue(
        VideoQualityPreference.values,
        values[7] as String?,
        AppSettings.defaults.downloadQuality,
      ),
      wifiOnlyDownloads:
          values[8] as bool? ?? AppSettings.defaults.wifiOnlyDownloads,
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
}
