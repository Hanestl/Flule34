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

enum UpdateChannel {
  stable('稳定版'),
  prerelease('预发布版');

  const UpdateChannel(this.label);

  final String label;
}

final class AppSettings {
  const AppSettings({
    required this.theme,
    required this.playbackQuality,
    required this.autoplay,
    required this.loopPlayback,
    required this.rememberPlaybackProgress,
    required this.blurThumbnails,
    required this.askDownloadQuality,
    required this.downloadQuality,
    required this.wifiOnlyDownloads,
    required this.updateChannel,
  });

  static const defaults = AppSettings(
    theme: AppThemePreference.dark,
    playbackQuality: VideoQualityPreference.automatic,
    autoplay: false,
    loopPlayback: false,
    rememberPlaybackProgress: true,
    blurThumbnails: false,
    askDownloadQuality: true,
    downloadQuality: VideoQualityPreference.highest,
    wifiOnlyDownloads: false,
    updateChannel: UpdateChannel.stable,
  );

  final AppThemePreference theme;
  final VideoQualityPreference playbackQuality;
  final bool autoplay;
  final bool loopPlayback;
  final bool rememberPlaybackProgress;
  final bool blurThumbnails;
  final bool askDownloadQuality;
  final VideoQualityPreference downloadQuality;
  final bool wifiOnlyDownloads;
  final UpdateChannel updateChannel;

  AppSettings copyWith({
    AppThemePreference? theme,
    VideoQualityPreference? playbackQuality,
    bool? autoplay,
    bool? loopPlayback,
    bool? rememberPlaybackProgress,
    bool? blurThumbnails,
    bool? askDownloadQuality,
    VideoQualityPreference? downloadQuality,
    bool? wifiOnlyDownloads,
    UpdateChannel? updateChannel,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      playbackQuality: playbackQuality ?? this.playbackQuality,
      autoplay: autoplay ?? this.autoplay,
      loopPlayback: loopPlayback ?? this.loopPlayback,
      rememberPlaybackProgress:
          rememberPlaybackProgress ?? this.rememberPlaybackProgress,
      blurThumbnails: blurThumbnails ?? this.blurThumbnails,
      askDownloadQuality: askDownloadQuality ?? this.askDownloadQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      updateChannel: updateChannel ?? this.updateChannel,
    );
  }
}
