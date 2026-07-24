import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('登录会逐跳保存 Cookie 并以页面 userId 建立身份', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();

    final adapter = _TestAdapter((options) {
      if (options.method == 'POST' && options.uri.path == '/login/') {
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            HttpHeaders.locationHeader: ['/'],
            HttpHeaders.setCookieHeader: [
              'PHPSESSID=session-value; Path=/; Secure; HttpOnly',
            ],
          },
        );
      }
      if (options.method == 'GET' && options.uri.path == '/') {
        expect(
          _header(options, HttpHeaders.cookieHeader),
          contains('PHPSESSID'),
        );
        return _htmlResponse(
          "<script>pageContext = { userId: '2421071' };</script>",
        );
      }
      return ResponseBody.fromString('not found', 404);
    });
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: adapter,
    );
    addTearDown(api.close);

    await api.login(email: 'user@example.com', password: 'password');

    expect(harness.sessionStore.currentUserId, '2421071');
    expect(
      await harness.sessionStore.cookieHeaderFor(
        Uri.parse('https://rule34video.com/'),
      ),
      contains('PHPSESSID=session-value'),
    );
  });

  test('服务器明确返回未登录页面时清除恢复中的会话', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.cookieJar.saveFromResponse(
      Uri.parse('https://rule34video.com/'),
      [Cookie('PHPSESSID', 'expired')..path = '/'],
    );
    await harness.sessionStore.authenticate('2421071');

    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter(
        (_) => _htmlResponse('<html>Login</html>'),
      ),
    );
    addTearDown(api.close);

    await api.restoreSession();

    expect(harness.sessionStore.isLoggedIn, isFalse);
    expect(
      await harness.sessionStore.cookieHeaderFor(
        Uri.parse('https://rule34video.com/'),
      ),
      isNull,
    );
  });

  test('账号媒体库接口使用正确的分页路径', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final paths = <String>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        paths.add(options.uri.path);
        if (options.uri.path == '/my/playlists/') {
          return _htmlResponse('''
            <div class="item">
              <a href="/my/playlists/77/" title="测试列表">测试列表</a>
            </div>
          ''');
        }
        if (options.uri.path == '/my/subscriptions/') {
          return _htmlResponse('''
            <div class="item">
              <a href="/models/example-artist/" title="Example Artist">
                Example Artist
              </a>
            </div>
          ''');
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    await api.loadWatchLater(2);
    await api.loadHistory(3);
    final playlist = (await api.loadMyPlaylists()).single;
    await api.loadPlaylistVideos(playlist, 2);
    final subscription = (await api.loadSubscriptions()).single;
    await api.loadSubscriptionVideos(subscription, 2);

    expect(paths, [
      '/my/favourites/videos-watch-later/2/',
      '/my/history/3/',
      '/my/playlists/',
      '/my/playlists/77/2/',
      '/my/subscriptions/',
      '/models/example-artist/2/',
    ]);
  });

  test('发现目录和集合视频使用正确的路径与排序参数', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final requests = <Uri>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options.uri);
        if (options.uri.path == '/models/') {
          return _htmlResponse('''
            <div class="item">
              <a href="/models/example-artist/" title="Example Artist">
                Example Artist
              </a>
            </div>
          ''');
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);
    const spec = DiscoveryDirectorySpec(
      title: '艺术家',
      path: '/models/',
      kind: DiscoveryKind.model,
    );

    final item = (await api.loadDiscoveryDirectory(spec)).single;
    await api.loadCollectionVideos(item, 2, sort: VideoSort.mostViewed);

    expect(requests.first.path, '/models/');
    expect(requests.last.path, '/models/example-artist/2/');
    expect(requests.last.queryParameters['sort_by'], 'video_viewed');
  });

  test('视频搜索会发送排序、时间、时长、取向和实体筛选', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    Uri? request;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        request = options.uri;
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    await api.searchVideos(
      'example query',
      2,
      filters: const SearchFilters(
        sort: VideoSort.topRated,
        orientation: ContentOrientation.straight,
        uploadPeriod: UploadPeriod.pastWeek,
        duration: VideoDurationPreset.medium,
        verifiedOnly: true,
        tags: [
          SearchSuggestion(
            id: '23',
            title: 'sound',
            total: 1,
            kind: SearchSuggestionKind.tag,
          ),
        ],
        categories: [
          SearchSuggestion(
            id: '199',
            title: '3D',
            total: 1,
            kind: SearchSuggestionKind.category,
          ),
        ],
        models: [
          SearchSuggestion(
            id: '639',
            title: 'Example Artist',
            total: 1,
            kind: SearchSuggestionKind.model,
          ),
        ],
      ),
    );

    expect(request?.path, '/search/example%20query/2/');
    expect(request?.queryParameters['sort_by'], 'rating');
    expect(request?.queryParameters['flag1'], '2109');
    expect(request?.queryParameters['duration_from'], '300');
    expect(request?.queryParameters['duration_to'], '1200');
    expect(request?.queryParameters['flag2'], '1');
    expect(request?.queryParameters['tag_ids'], '23');
    expect(request?.queryParameters['category_ids'], '199');
    expect(request?.queryParameters['model_ids'], '639');
    expect(
      request?.queryParameters['post_date_from'],
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
  });

  test('标签、分类和艺术家自动补全使用各自的参数协议', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final requests = <Uri>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options.uri);
        return _htmlResponse(
          '{"items":[{"id":"1","title":"Example","total":"42"}]}',
        );
      }),
    );
    addTearDown(api.close);

    for (final kind in SearchSuggestionKind.values) {
      final suggestions = await api.searchSuggestions('ex', kind);
      expect(suggestions.single.kind, kind);
    }

    expect(requests[0].path, '/tags_json.php');
    expect(requests[0].queryParameters['id'], 'true');
    expect(requests[0].queryParameters['term'], 'ex');
    expect(requests[1].path, '/categories_json.php');
    expect(requests[1].queryParameters['term'], 'ex');
    expect(requests[2].path, '/models_json.php');
    expect(requests[2].queryParameters['q'], 'ex');
    expect(requests[2].queryParameters.containsKey('term'), isFalse);
  });
}

ResponseBody _htmlResponse(String body) {
  return ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    },
  );
}

String? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

final class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
