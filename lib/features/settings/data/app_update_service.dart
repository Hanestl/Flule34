import 'dart:async';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_build_config.dart';
import '../../../core/logging/app_log_service.dart';
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
    Uri? releaseFeedUri,
    AppLogService? logService,
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
       _updateApiUri = updateApiUri ?? AppBuildConfig.updateApiUri,
       _releaseFeedUri = releaseFeedUri ?? _defaultReleaseFeedUri(),
       _logs = logService;

  final Dio _client;
  final bool _ownsClient;
  final PackageInfoLoader _packageInfoLoader;
  final AbiLoader _abiLoader;
  final Uri? _updateApiUri;
  final Uri? _releaseFeedUri;
  final AppLogService? _logs;

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
    } catch (error, stackTrace) {
      final feed = _releaseFeedUri;
      if (feed != null) {
        try {
          final release = await _checkReleaseFeed(feed, channel);
          if (release != null) {
            final available =
                compareVersions(release.version, currentVersion) > 0;
            unawaited(
              _logs?.warning(
                'update',
                'GitHub API 检查失败，已通过 Releases Feed 完成检查。',
                error: error,
                stackTrace: stackTrace,
              ),
            );
            return AppUpdateResult(
              status: available
                  ? AppUpdateStatus.updateAvailable
                  : AppUpdateStatus.upToDate,
              currentVersion: currentVersion,
              release: release,
              message: available ? '发现新版本 ${release.version}。' : '当前已是最新版本。',
            );
          }
        } catch (feedError, feedStackTrace) {
          unawaited(
            _logs?.warning(
              'update',
              'GitHub API 与 Releases Feed 均检查失败。',
              error: feedError,
              stackTrace: feedStackTrace,
            ),
          );
        }
      }
      return AppUpdateResult(
        status: AppUpdateStatus.failed,
        currentVersion: currentVersion,
        message: _failureMessage(error),
      );
    }
  }

  Future<AppRelease?> _checkReleaseFeed(
    Uri source,
    UpdateChannel channel,
  ) async {
    final response = await _client.getUri<String>(
      source,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'Accept': 'application/atom+xml,application/xml'},
      ),
    );
    final body = response.data ?? '';
    for (final match in RegExp(
      r'<entry\b[^>]*>(.*?)</entry>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(body)) {
      final entry = match.group(1) ?? '';
      final pageValue = RegExp(
        r'''<link\b[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(entry)?.group(1);
      final pageUri = _httpsUri(pageValue);
      if (pageUri == null) {
        continue;
      }
      final rawVersion = pageUri.pathSegments.isEmpty
          ? null
          : pageUri.pathSegments.last;
      if (rawVersion == null || rawVersion.isEmpty) {
        continue;
      }
      final version = rawVersion.replaceFirst(RegExp(r'^[vV]'), '');
      final title = _xmlText(entry, 'title') ?? rawVersion;
      final prerelease =
          version.contains('-') ||
          RegExp(
            r'\b(?:alpha|beta|preview|rc|pre-release)\b',
            caseSensitive: false,
          ).hasMatch(title);
      if (channel == UpdateChannel.stable && prerelease) {
        continue;
      }
      return AppRelease(
        version: version,
        title: title,
        pageUri: pageUri,
        prerelease: prerelease,
        publishedAt: DateTime.tryParse(_xmlText(entry, 'updated') ?? ''),
      );
    }
    return null;
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

  static Uri? _defaultReleaseFeedUri() {
    final repository = AppBuildConfig.repositoryUri;
    if (repository == null) {
      return null;
    }
    final path = repository.path.endsWith('/')
        ? '${repository.path}releases.atom'
        : '${repository.path}/releases.atom';
    return repository.replace(path: path, query: null, fragment: null);
  }

  static String _failureMessage(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 429) {
        return 'GitHub 暂时拒绝了更新请求，请稍后重试或更换网络。';
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '检查更新超时，请稍后重试。',
        DioExceptionType.connectionError => '无法连接 GitHub，请检查网络后重试。',
        _ => '暂时无法检查更新，请稍后重试。',
      };
    }
    return '暂时无法检查更新，请稍后重试。';
  }

  static String? _xmlText(String source, String tag) {
    final value = RegExp(
      '<${RegExp.escape(tag)}\\b[^>]*>(.*?)</${RegExp.escape(tag)}>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source)?.group(1);
    if (value == null) {
      return null;
    }
    final cleaned = value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
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
