enum AppThemePreference {
  system('跟随系统'),
  dark('深色'),
  amoled('纯黑');

  const AppThemePreference(this.label);

  final String label;
}

enum VideoQualityPreference {
  automatic('自动'),
  highest('最高可用'),
  p1080('1080p'),
  p720('720p'),
  p480('480p'),
  p360('360p');

  const VideoQualityPreference(this.label);

  final String label;

  int? get targetHeight => switch (this) {
    VideoQualityPreference.p1080 => 1080,
    VideoQualityPreference.p720 => 720,
    VideoQualityPreference.p480 => 480,
    VideoQualityPreference.p360 => 360,
    _ => null,
  };
}

final class AppSettings {
  const AppSettings({
    required this.theme,
    required this.playbackQuality,
    required this.autoplay,
    required this.loopPlayback,
    required this.blurThumbnails,
    required this.askDownloadQuality,
    required this.downloadQuality,
    required this.wifiOnlyDownloads,
  });

  static const defaults = AppSettings(
    theme: AppThemePreference.dark,
    playbackQuality: VideoQualityPreference.automatic,
    autoplay: false,
    loopPlayback: false,
    blurThumbnails: false,
    askDownloadQuality: true,
    downloadQuality: VideoQualityPreference.highest,
    wifiOnlyDownloads: false,
  );

  final AppThemePreference theme;
  final VideoQualityPreference playbackQuality;
  final bool autoplay;
  final bool loopPlayback;
  final bool blurThumbnails;
  final bool askDownloadQuality;
  final VideoQualityPreference downloadQuality;
  final bool wifiOnlyDownloads;

  AppSettings copyWith({
    AppThemePreference? theme,
    VideoQualityPreference? playbackQuality,
    bool? autoplay,
    bool? loopPlayback,
    bool? blurThumbnails,
    bool? askDownloadQuality,
    VideoQualityPreference? downloadQuality,
    bool? wifiOnlyDownloads,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      playbackQuality: playbackQuality ?? this.playbackQuality,
      autoplay: autoplay ?? this.autoplay,
      loopPlayback: loopPlayback ?? this.loopPlayback,
      blurThumbnails: blurThumbnails ?? this.blurThumbnails,
      askDownloadQuality: askDownloadQuality ?? this.askDownloadQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
    );
  }
}
