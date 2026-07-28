import '../../../core/models/video_models.dart';

enum AppThemePreference {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppThemePreference(this.label);

  final String label;
}

enum ContentLayout {
  singleColumn('一列'),
  doubleColumn('两列');

  const ContentLayout(this.label);

  final String label;
}

enum VideoQualityPreference {
  highest('最高可用'),
  p2160('2160p / 4K'),
  p1080('1080p'),
  p720('720p'),
  p480('480p'),
  p360('360p');

  const VideoQualityPreference(this.label);

  final String label;

  int? get targetHeight => switch (this) {
    VideoQualityPreference.p2160 => 2160,
    VideoQualityPreference.p1080 => 1080,
    VideoQualityPreference.p720 => 720,
    VideoQualityPreference.p480 => 480,
    VideoQualityPreference.p360 => 360,
    _ => null,
  };
}

enum NetworkPlaybackPolicy {
  automatic('自动', 'Wi-Fi 使用默认清晰度，移动网络最高 480p'),
  alwaysDefault('始终使用默认清晰度', '所有网络都使用上方选择的清晰度'),
  dataSaver('节省流量', 'Wi-Fi 最高 720p，移动网络最高 360p');

  const NetworkPlaybackPolicy(this.label, this.description);

  final String label;
  final String description;
}

enum FullscreenOrientationPreference {
  landscape('进入全屏时横屏'),
  device('保持设备当前方向');

  const FullscreenOrientationPreference(this.label);

  final String label;
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
    required this.networkPlaybackPolicy,
    required this.autoplay,
    required this.loopPlayback,
    required this.rememberPlaybackProgress,
    required this.keepScreenAwake,
    required this.backgroundPlayback,
    required this.fullscreenOrientation,
    required this.defaultOrientation,
    required this.blurThumbnails,
    required this.askDownloadQuality,
    required this.downloadQuality,
    required this.wifiOnlyDownloads,
    required this.downloadConcurrentTasks,
    required this.saveSearchHistory,
    required this.updateChannel,
    required this.videoLayout,
    required this.subscriptionLayout,
  });

  static const defaults = AppSettings(
    theme: AppThemePreference.system,
    playbackQuality: VideoQualityPreference.p1080,
    networkPlaybackPolicy: NetworkPlaybackPolicy.automatic,
    autoplay: false,
    loopPlayback: false,
    rememberPlaybackProgress: true,
    keepScreenAwake: true,
    backgroundPlayback: false,
    fullscreenOrientation: FullscreenOrientationPreference.landscape,
    defaultOrientation: ContentOrientation.all,
    blurThumbnails: false,
    askDownloadQuality: true,
    downloadQuality: VideoQualityPreference.highest,
    wifiOnlyDownloads: false,
    downloadConcurrentTasks: 2,
    saveSearchHistory: true,
    updateChannel: UpdateChannel.stable,
    videoLayout: ContentLayout.singleColumn,
    subscriptionLayout: ContentLayout.doubleColumn,
  );

  final AppThemePreference theme;
  final VideoQualityPreference playbackQuality;
  final NetworkPlaybackPolicy networkPlaybackPolicy;
  final bool autoplay;
  final bool loopPlayback;
  final bool rememberPlaybackProgress;
  final bool keepScreenAwake;
  final bool backgroundPlayback;
  final FullscreenOrientationPreference fullscreenOrientation;
  final ContentOrientation defaultOrientation;
  final bool blurThumbnails;
  final bool askDownloadQuality;
  final VideoQualityPreference downloadQuality;
  final bool wifiOnlyDownloads;
  final int downloadConcurrentTasks;
  final bool saveSearchHistory;
  final UpdateChannel updateChannel;
  final ContentLayout videoLayout;
  final ContentLayout subscriptionLayout;

  AppSettings copyWith({
    AppThemePreference? theme,
    VideoQualityPreference? playbackQuality,
    NetworkPlaybackPolicy? networkPlaybackPolicy,
    bool? autoplay,
    bool? loopPlayback,
    bool? rememberPlaybackProgress,
    bool? keepScreenAwake,
    bool? backgroundPlayback,
    FullscreenOrientationPreference? fullscreenOrientation,
    ContentOrientation? defaultOrientation,
    bool? blurThumbnails,
    bool? askDownloadQuality,
    VideoQualityPreference? downloadQuality,
    bool? wifiOnlyDownloads,
    int? downloadConcurrentTasks,
    bool? saveSearchHistory,
    UpdateChannel? updateChannel,
    ContentLayout? videoLayout,
    ContentLayout? subscriptionLayout,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      playbackQuality: playbackQuality ?? this.playbackQuality,
      networkPlaybackPolicy:
          networkPlaybackPolicy ?? this.networkPlaybackPolicy,
      autoplay: autoplay ?? this.autoplay,
      loopPlayback: loopPlayback ?? this.loopPlayback,
      rememberPlaybackProgress:
          rememberPlaybackProgress ?? this.rememberPlaybackProgress,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      fullscreenOrientation:
          fullscreenOrientation ?? this.fullscreenOrientation,
      defaultOrientation: defaultOrientation ?? this.defaultOrientation,
      blurThumbnails: blurThumbnails ?? this.blurThumbnails,
      askDownloadQuality: askDownloadQuality ?? this.askDownloadQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      downloadConcurrentTasks:
          downloadConcurrentTasks ?? this.downloadConcurrentTasks,
      saveSearchHistory: saveSearchHistory ?? this.saveSearchHistory,
      updateChannel: updateChannel ?? this.updateChannel,
      videoLayout: videoLayout ?? this.videoLayout,
      subscriptionLayout: subscriptionLayout ?? this.subscriptionLayout,
    );
  }
}
