import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flule34/features/settings/data/app_update_service.dart';
import 'package:flule34/features/settings/domain/app_settings.dart';

void main() {
  test('语义版本比较忽略 v 前缀和构建号', () {
    expect(AppUpdateService.compareVersions('v1.2.0', '1.1.9+8'), 1);
    expect(AppUpdateService.compareVersions('1.0.0', '1.0.0+42'), 0);
    expect(AppUpdateService.compareVersions('0.9.9', '1.0.0'), -1);
  });

  test('稳定通道跳过预发布并返回可用 APK Release', () async {
    final dio = Dio()
      ..httpClientAdapter = _JsonAdapter([
        {
          'tag_name': 'v1.1.0-beta.1',
          'name': 'Beta',
          'html_url': 'https://github.com/example/releases/tag/v1.1.0-beta.1',
          'prerelease': true,
          'draft': false,
          'assets': const [],
        },
        {
          'tag_name': 'v1.0.1',
          'name': 'Stable',
          'html_url': 'https://github.com/example/releases/tag/v1.0.1',
          'prerelease': false,
          'draft': false,
          'assets': [
            {
              'name': 'flule34-arm64-v8a.apk',
              'browser_download_url':
                  'https://github.com/example/releases/download/v1.0.1/app.apk',
            },
          ],
        },
      ]);
    final service = AppUpdateService(
      client: dio,
      updateApiUri: Uri.parse('https://api.github.com/repos/example/releases'),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Flule34',
        packageName: 'com.hanestl.flule34',
        version: '1.0.0',
        buildNumber: '1',
      ),
    );

    final result = await service.check(UpdateChannel.stable);

    expect(result.status, AppUpdateStatus.updateAvailable);
    expect(result.release?.version, '1.0.1');
    expect(result.release?.apkUri, isNotNull);
  });
}

final class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.value);

  final Object value;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
