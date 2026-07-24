import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_build_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/session_store.dart';
import '../domain/app_settings.dart';

typedef DiagnosticPackageInfoLoader = Future<PackageInfo> Function();

final class DiagnosticReport {
  const DiagnosticReport(this.entries);

  final List<MapEntry<String, String>> entries;

  String toPlainText() {
    return entries.map((entry) => '${entry.key}：${entry.value}').join('\n');
  }
}

final class AppDiagnosticsService {
  AppDiagnosticsService(
    this._database,
    this._sessionStore,
    this._settings, {
    DeviceInfoPlugin? deviceInfo,
    DiagnosticPackageInfoLoader? packageInfoLoader,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  final AppDatabase _database;
  final SessionStore _sessionStore;
  final AppSettings _settings;
  final DeviceInfoPlugin _deviceInfo;
  final DiagnosticPackageInfoLoader _packageInfoLoader;

  Future<DiagnosticReport> collect() async {
    final packageInfo = await _packageInfoLoader();
    final userId = _sessionStore.currentUserId;
    final downloads = userId == null
        ? const <DownloadRecord>[]
        : await _database.watchDownloads(userId).first;
    final entries = <MapEntry<String, String>>[
      MapEntry(
        'App',
        '${packageInfo.appName} ${packageInfo.version}+${packageInfo.buildNumber}',
      ),
      MapEntry('包名', packageInfo.packageName),
      MapEntry('构建模式', _buildMode),
      const MapEntry('Flutter', AppBuildConfig.flutterVersion),
      MapEntry('Dart', Platform.version.split(' ').first),
      const MapEntry('Git 提交', AppBuildConfig.gitCommit),
      const MapEntry('构建时间', AppBuildConfig.buildTime),
      MapEntry('数据库结构', 'v${_database.schemaVersion}'),
      MapEntry('当前账号 ID', userId == null ? '不存在' : '存在'),
      MapEntry('当前账号下载记录', downloads.length.toString()),
      MapEntry('主题', _settings.theme.label),
      MapEntry('播放清晰度', _settings.playbackQuality.label),
      MapEntry('下载清晰度', _settings.downloadQuality.label),
      MapEntry('仅 Wi-Fi 下载', _settings.wifiOnlyDownloads ? '是' : '否'),
      MapEntry('更新通道', _settings.updateChannel.label),
      MapEntry('更新源', AppBuildConfig.updateApiUri?.toString() ?? '未配置'),
    ];
    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      entries.addAll([
        MapEntry('设备', '${android.manufacturer} ${android.model}'),
        MapEntry(
          'Android',
          '${android.version.release} (SDK ${android.version.sdkInt})',
        ),
        MapEntry('CPU ABI', android.supportedAbis.join(', ')),
      ]);
    } else {
      entries.add(MapEntry('平台', Platform.operatingSystemVersion));
    }
    return DiagnosticReport(List.unmodifiable(entries));
  }

  String get _buildMode {
    if (kReleaseMode) {
      return 'release';
    }
    if (kProfileMode) {
      return 'profile';
    }
    return 'debug';
  }
}
