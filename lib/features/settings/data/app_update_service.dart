import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_build_config.dart';
import '../domain/app_settings.dart';

enum AppUpdateStatus { unconfigured, upToDate, updateAvailable, failed }

final class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.pageUri,
    required this.prerelease,
    this.publishedAt,
    this.apkUri,
    this.notes,
  });

  final String version;
  final String title;
  final Uri pageUri;
  final bool prerelease;
  final DateTime? publishedAt;
  final Uri? apkUri;
  final String? notes;
}

final class AppUpdateResult {
  const AppUpdateResult({
    required this.status,
    required this.currentVersion,
    this.release,
    this.message,
  });

  final AppUpdateStatus status;
  final String currentVersion;
  final AppRelease? release;
  final String? message;
}

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef AbiLoader = Future<List<String>> Function();

final class AppUpdateService {
  AppUpdateService({
    Dio? client,
    PackageInfoLoader? packageInfoLoader,
    AbiLoader? abiLoader,
    Uri? updateApiUri,
  }) : _client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: const {
                 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'Flule34 Android update checker',
               },
             ),
           ),
       _ownsClient = client == null,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _abiLoader = abiLoader ?? _loadSupportedAbis,
       _updateApiUri = updateApiUri ?? AppBuildConfig.updateApiUri;

  final Dio _client;
  final bool _ownsClient;
  final PackageInfoLoader _packageInfoLoader;
  final AbiLoader _abiLoader;
  final Uri? _updateApiUri;

  Uri? get configuredSource => _updateApiUri;

  void close() {
    if (_ownsClient) {
      _client.close(force: true);
    }
  }

  Future<AppUpdateResult> check(UpdateChannel channel) async {
    final packageInfo = await _packageInfoLoader();
    final currentVersion = packageInfo.version;
    final source = _updateApiUri;
    if (source == null) {
      return AppUpdateResult(
        status: AppUpdateStatus.unconfigured,
        currentVersion: currentVersion,
        message: '此构建未配置 GitHub Releases 更新源。',
      );
    }

    try {
      final response = await _client.getUri<Object?>(
        source,
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      );
      List<String> supportedAbis;
      try {
        supportedAbis = await _abiLoader();
      } catch (_) {
        supportedAbis = const [];
      }
      final release = _selectRelease(response.data, channel, supportedAbis);
      if (release == null) {
        return AppUpdateResult(
          status: AppUpdateStatus.failed,
          currentVersion: currentVersion,
          message: '更新源没有可用的 Android Release。',
        );
      }
      final available = compareVersions(release.version, currentVersion) > 0;
      return AppUpdateResult(
        status: available
            ? AppUpdateStatus.updateAvailable
            : AppUpdateStatus.upToDate,
        currentVersion: currentVersion,
        release: release,
        message: available ? '发现新版本 ${release.version}。' : '当前已是最新版本。',
      );
    } catch (error) {
      return AppUpdateResult(
        status: AppUpdateStatus.failed,
        currentVersion: currentVersion,
        message: '检查更新失败：$error',
      );
    }
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index++) {
      final difference = leftParts[index] - rightParts[index];
      if (difference != 0) {
        return difference.sign;
      }
    }
    return 0;
  }

  AppRelease? _selectRelease(
    Object? data,
    UpdateChannel channel,
    List<String> supportedAbis,
  ) {
    final candidates = switch (data) {
      List<Object?> values => values,
      Map<Object?, Object?> value => <Object?>[value],
      _ => const <Object?>[],
    };
    for (final candidate in candidates) {
      if (candidate is! Map) {
        continue;
      }
      final release = _parseRelease(candidate, supportedAbis);
      if (release == null || candidate['draft'] == true) {
        continue;
      }
      if (channel == UpdateChannel.stable && release.prerelease) {
        continue;
      }
      return release;
    }
    return null;
  }

  AppRelease? _parseRelease(
    Map<Object?, Object?> data,
    List<String> supportedAbis,
  ) {
    final rawVersion = data['tag_name']?.toString().trim();
    final pageUri = _httpsUri(data['html_url']);
    if (rawVersion == null || rawVersion.isEmpty || pageUri == null) {
      return null;
    }
    final apkAssets = <({String name, Uri uri})>[];
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map>()) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final candidate = _httpsUri(asset['browser_download_url']);
        if (name.endsWith('.apk') && candidate != null) {
          apkAssets.add((name: name, uri: candidate));
        }
      }
    }
    final apkUri = _selectApk(apkAssets, supportedAbis);
    return AppRelease(
      version: rawVersion.replaceFirst(RegExp(r'^[vV]'), ''),
      title: data['name']?.toString().trim().isNotEmpty == true
          ? data['name'].toString().trim()
          : rawVersion,
      pageUri: pageUri,
      prerelease: data['prerelease'] == true,
      publishedAt: DateTime.tryParse(data['published_at']?.toString() ?? ''),
      apkUri: apkUri,
      notes: data['body']?.toString().trim(),
    );
  }

  Uri? _selectApk(
    List<({String name, Uri uri})> assets,
    List<String> supportedAbis,
  ) {
    for (final abi in supportedAbis) {
      final normalized = abi.toLowerCase();
      for (final asset in assets) {
        if (asset.name.contains(normalized)) {
          return asset.uri;
        }
      }
    }
    for (final asset in assets) {
      if (asset.name.contains('universal')) {
        return asset.uri;
      }
    }
    return assets.firstOrNull?.uri;
  }

  static Future<List<String>> _loadSupportedAbis() async {
    return (await DeviceInfoPlugin().androidInfo).supportedAbis;
  }

  static List<int> _versionParts(String version) {
    final core = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[-+]'))
        .first;
    final values = core.split('.').take(3).map((part) {
      return int.tryParse(RegExp(r'^\d+').firstMatch(part)?.group(0) ?? '') ??
          0;
    }).toList();
    return List<int>.generate(
      3,
      (index) => index < values.length ? values[index] : 0,
    );
  }

  Uri? _httpsUri(Object? value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }
}
