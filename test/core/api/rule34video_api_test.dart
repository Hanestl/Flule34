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
    final credentials = await harness.sessionStore.loadCredentials();
    expect(credentials?.email, 'user@example.com');
    expect(credentials?.password, 'password');
  });

  test('没有可用 Cookie 时会使用安全存储中的账号密码自动登录', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.saveCredentials(
      email: 'user@example.com',
      password: 'password',
    );
    var loginRequests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.method == 'POST' && options.uri.path == '/login/') {
          loginRequests += 1;
          return _htmlResponse(
            "<script>pageContext = { userId: '2421071' };</script>",
          );
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    await api.restoreSession();

    expect(loginRequests, 1);
    expect(harness.sessionStore.currentUserId, '2421071');
  });

  test('启动校验遇到无法识别的页面时保留本地身份并清理失效 Cookie', () async {
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

    expect(harness.sessionStore.currentUserId, '2421071');
    expect(
      await harness.sessionStore.cookieHeaderFor(
        Uri.parse('https://rule34video.com/'),
      ),
      isNull,
    );
  });

  test('视频详情遇到过期登录重定向时仍使用公开请求继续播放', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.cookieJar.saveFromResponse(
      Uri.parse('https://rule34video.com/'),
      [Cookie('PHPSESSID', 'expired')..path = '/'],
    );
    await harness.sessionStore.authenticate('2421071');
    var authenticatedRequests = 0;
    var publicRequests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        final cookie = _header(options, HttpHeaders.cookieHeader);
        if (cookie != null) {
          authenticatedRequests += 1;
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              HttpHeaders.locationHeader: ['/?login'],
            },
          );
        }
        publicRequests += 1;
        return _htmlResponse('''
          <link rel="canonical" href="/video/4505897/example/">
          <script>
            flashvars = {
              video_url: 'https://cdn.example.com/video_720p.mp4',
              video_url_text: '720p'
            };
          </script>
        ''');
      }),
    );
    addTearDown(api.close);

    final details = await api.loadVideoDetails(
      const VideoItem(id: '4505897', title: 'Example', slug: 'example'),
    );

    expect(details.sources.single.label, '720p');
    expect(authenticatedRequests, 1);
    expect(publicRequests, 1);
    expect(harness.sessionStore.isLoggedIn, isFalse);
  });

  test('视频详情短时缓存复用结果且强制刷新会重新请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    var requests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((_) {
        requests += 1;
        return _htmlResponse('''
          <link rel="canonical" href="/video/4505897/example/">
          <script>
            flashvars = {
              video_url: 'https://cdn.example.com/video-$requests.mp4',
              video_url_text: '720p'
            };
          </script>
        ''');
      }),
    );
    addTearDown(api.close);
    const video = VideoItem(id: '4505897', title: 'Example', slug: 'example');

    final first = await api.loadVideoDetails(video);
    final cached = await api.loadVideoDetails(video);
    final refreshed = await api.refreshVideoDetails(video);

    expect(requests, 2);
    expect(first.sources.single.url, endsWith('video-1.mp4'));
    expect(cached.sources.single.url, endsWith('video-1.mp4'));
    expect(refreshed.sources.single.url, endsWith('video-2.mp4'));
  });

  test('视频详情缓存超过上限后淘汰最早条目', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    var requests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests += 1;
        final id = options.uri.pathSegments.length > 1
            ? options.uri.pathSegments[1]
            : '0';
        return _htmlResponse('''
          <link rel="canonical" href="/video/$id/video-$id/">
          <script>
            flashvars = {
              video_url: 'https://cdn.example.com/video-$id.mp4',
              video_url_text: '720p'
            };
          </script>
        ''');
      }),
    );
    addTearDown(api.close);

    for (var index = 0; index <= 100; index += 1) {
      await api.loadVideoDetails(
        VideoItem(id: '$index', title: 'Video $index', slug: 'video-$index'),
      );
    }
    await api.loadVideoDetails(
      const VideoItem(id: '0', title: 'Video 0', slug: 'video-0'),
    );

    expect(requests, 102);
  });

  test('当前账号资料优先读取数据库缓存且网络刷新在进程内去重', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    await harness.database.recordAuthenticatedAccount(
      '2421071',
      displayName: '缓存名称',
      avatarUrl: 'https://example.com/cached.jpg',
    );
    var requests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((_) {
        requests += 1;
        return _htmlResponse('''
          <div class="channel_logo">
            <div class="avatar"><img src="/fresh.jpg"></div>
            <h2 class="title">刷新名称</h2>
          </div>
        ''');
      }),
    );
    addTearDown(api.close);

    final cached = await api.loadCachedCurrentUserProfile();
    final firstFresh = await api.loadCurrentUserProfile();
    final secondFresh = await api.loadCurrentUserProfile();

    expect(cached?.displayName, '缓存名称');
    expect(firstFresh.displayName, '刷新名称');
    expect(secondFresh.displayName, '刷新名称');
    expect(requests, 1);
  });

  test('受保护页面重定向到登录页时清除过期会话', () async {
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
        (_) => ResponseBody.fromString(
          '',
          302,
          headers: {
            HttpHeaders.locationHeader: ['/?login'],
          },
        ),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.loadFavorites(1),
      throwsA(
        isA<SessionExpiredException>().having(
          (error) => error.message,
          'message',
          '登录状态已过期，请重新登录。',
        ),
      ),
    );

    expect(harness.sessionStore.isLoggedIn, isFalse);
    expect(
      await harness.sessionStore.cookieHeaderFor(
        Uri.parse('https://rule34video.com/'),
      ),
      isNull,
    );
  });

  test('分页列表第二页以后 404 视为正常结束，第一页仍保留错误', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter(
        (_) => ResponseBody.fromString('Not Found', 404),
      ),
    );
    addTearDown(api.close);

    expect(await api.loadFavorites(2), isEmpty);
    await expectLater(
      api.loadFavorites(1),
      throwsA(
        isA<HttpStatusException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });

  test('收藏第一页会复用在途请求和短时缓存，强制刷新才重新请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    var requests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((_) async {
        requests += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _htmlResponse(
          _videoListItem(
            id: '1',
            slug: 'cached-favorite',
            title: '缓存收藏',
            published: 'today',
          ),
        );
      }),
    );
    addTearDown(api.close);

    final token = CancelToken();
    final values = await Future.wait([
      api.loadFavorites(1),
      api
          .prefetchFavorites(cancelToken: token)
          .then((_) => api.loadFavorites(1)),
    ]);
    await api.loadFavorites(1);

    expect(values.expand((items) => items).map((item) => item.id), ['1', '1']);
    expect(requests, 1);

    await api.loadFavorites(1, force: true);
    expect(requests, 2);
  });

  test('普通 403 保留登录状态并按 HTTP 错误上报', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter(
        (_) => ResponseBody.fromString('Forbidden', 403),
      ),
    );
    addTearDown(api.close);
    const video = VideoItem(id: '4505897', title: 'Example', slug: 'example');

    await expectLater(
      api.toggleFavorite(video: video, add: true),
      throwsA(
        isA<HttpStatusException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );

    expect(harness.sessionStore.isLoggedIn, isTrue);
  });

  test('网络异常文本不会暴露临时媒体凭据', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        throw DioException(
          requestOptions: options,
          message:
              'failed https://rule34video.com/get_file/video.mp4?v-acctoken=secret-token Cookie: PHPSESSID=secret-cookie',
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.loadFeed(FeedKind.newest, 1),
      throwsA(
        isA<ApiException>()
            .having((error) => error.message, 'message', contains('<redacted>'))
            .having(
              (error) => error.message,
              'message',
              isNot(contains('secret-token')),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('secret-cookie')),
            ),
      ),
    );
  });

  test('账号历史和订阅接口使用网站异步区块分页参数', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.uri.path == '/my/subscriptions/' &&
            !options.uri.queryParameters.containsKey('from_my_subscriptions')) {
          return _htmlResponse('''
            <div class="item">
              <a href="/models/example-artist/" title="Example Artist">
                Example Artist
              </a>
            </div>
          ''');
        }
        if (options.uri.path == '/my/subscriptions/' &&
            options.uri.queryParameters['from_my_subscriptions'] == '2') {
          return _htmlResponse('<html></html>');
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    await api.loadHistory(3);
    final subscription = (await api.loadSubscriptions()).single;
    await api.loadSubscriptionVideos(subscription, 2);

    expect(requests.map((request) => request.uri.path), [
      '/my/history/3/',
      '/my/subscriptions/',
      '/my/subscriptions/',
      '/models/example-artist/2/',
    ]);
    final nextSubscriptionsRequest = requests[2].uri.queryParameters;
    expect(nextSubscriptionsRequest, {
      'mode': 'async',
      'function': 'get_block',
      'block_id': 'list_members_subscriptions_my_subscriptions',
      'sort_by': 'added_date',
      'from_my_subscriptions': '2',
    });
  });

  test('订阅分页即使中间页只有重复项也会继续读取后续页', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        final page =
            int.tryParse(
              options.uri.queryParameters['from_my_subscriptions'] ?? '1',
            ) ??
            1;
        return switch (page) {
          1 || 2 => _htmlResponse('''
              <div class="item"><a href="/models/first/">First</a></div>
            '''),
          3 => _htmlResponse('''
              <div class="item"><a href="/models/third/">Third</a></div>
            '''),
          _ => _htmlResponse('<html></html>'),
        };
      }),
    );
    addTearDown(api.close);

    final subscriptions = await api.loadSubscriptions();

    expect(subscriptions.map((item) => item.title), ['First', 'Third']);
  });

  test('订阅强制刷新偶发空响应时会自动复核而不丢失列表', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    var firstPageRequests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path == '/my/subscriptions/' &&
            !options.uri.queryParameters.containsKey('from_my_subscriptions')) {
          firstPageRequests += 1;
          if (firstPageRequests == 2) {
            return _htmlResponse('<html></html>');
          }
          return _htmlResponse(
            '<div class="item"><a href="/models/artist/">Artist</a></div>',
          );
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    final initial = await api.loadSubscriptions();
    final refreshed = await api.loadSubscriptions(force: true);

    expect(initial.single.title, 'Artist');
    expect(refreshed.single.title, 'Artist');
    expect(firstPageRequests, 3);
  });

  test('关注视频按发布时间从新到旧返回', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        return switch (options.uri.path) {
          '/my/subscriptions/' => _htmlResponse('''
              <div class="item"><a href="/models/older/">较旧来源</a></div>
              <div class="item"><a href="/models/newer/">较新来源</a></div>
            '''),
          '/my/subscriptions/2/' => _htmlResponse('<html></html>'),
          '/models/older/' => _htmlResponse(
            _videoListItem(
              id: '1',
              slug: 'older-video',
              title: '较旧视频',
              published: '3 days ago',
            ),
          ),
          '/models/newer/' => _htmlResponse(
            _videoListItem(
              id: '2',
              slug: 'newer-video',
              title: '较新视频',
              published: '2 hours ago',
            ),
          ),
          _ => _htmlResponse('<html></html>'),
        };
      }),
    );
    addTearDown(api.close);

    final videos = await api.loadFollowingFeed(1);

    expect(videos.map((item) => item.id), ['2', '1']);
  });

  test('订阅缓存按账号隔离，切换账号后必须重新请求', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    var requests = 0;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        if (options.uri.path == '/my/subscriptions/' &&
            options.uri.queryParameters.containsKey('from_my_subscriptions')) {
          return _htmlResponse('<html></html>');
        }
        requests += 1;
        final userId = harness.sessionStore.currentUserId!;
        return _htmlResponse('''
          <div class="item">
            <a href="/models/artist-$userId/" title="Artist $userId">
              Artist $userId
            </a>
          </div>
        ''');
      }),
    );
    addTearDown(api.close);

    await harness.sessionStore.authenticate('1001');
    expect((await api.loadSubscriptions()).single.title, 'Artist 1001');
    expect((await api.loadSubscriptions()).single.title, 'Artist 1001');
    expect(requests, 1);

    await harness.sessionStore.authenticate('2002');
    expect((await api.loadSubscriptions()).single.title, 'Artist 2002');
    expect(requests, 2);
  });

  test('订阅中的艺术家和上传者头像会按路径补全并去重', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final requests = <String, int>{};
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.update(
          options.uri.path,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        if (options.uri.path == '/models/hydrafxx/') {
          return _htmlResponse('''
            <div class="brand_image">
              <div class="brand_image_wrapper">
                <img src="/contents/models/87/s1_hydra.png" alt="HydraFXX">
              </div>
            </div>
          ''');
        }
        if (options.uri.path == '/members/98965/') {
          return _htmlResponse('''
            <div class="channel_logo">
              <div class="avatar">
                <img src="/contents/avatars/98000/98965.png" alt="">
              </div>
              <h2 class="title">Oppai3Dporn</h2>
            </div>
          ''');
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);
    const artist = SubscriptionItem(
      title: 'HydraFXX',
      path: '/models/hydrafxx/',
      kind: SubscriptionKind.model,
    );
    const uploader = SubscriptionItem(
      title: 'Oppai3Dporn',
      path: '/members/98965/',
      kind: SubscriptionKind.member,
    );

    final resolvedArtist = await api.resolveSubscription(artist);
    final resolvedUploader = await api.resolveSubscription(uploader);
    await api.resolveSubscription(artist);
    await api.resolveSubscription(uploader);

    expect(
      resolvedArtist.thumbnailUrl,
      'https://rule34video.com/contents/models/87/s1_hydra.png',
    );
    expect(
      resolvedUploader.thumbnailUrl,
      'https://rule34video.com/contents/avatars/98000/98965.png',
    );
    expect(requests['/models/hydrafxx/'], 1);
    expect(requests['/members/98965/'], 1);
  });

  test('账号播放列表可分页读取并使用已验证参数加入和移除视频', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.uri.path == '/my/playlists/') {
          return _htmlResponse('''
            <div class="item">
              <a href="/my/playlists/42/example/" title="Example playlist">
                Example playlist
              </a>
            </div>
          ''');
        }
        if (options.uri.path == '/my/playlists/2/') {
          return _htmlResponse('<html></html>');
        }
        return _htmlResponse('<success/>');
      }),
    );
    addTearDown(api.close);

    final playlist = (await api.loadMyPlaylists()).single;
    await api.addVideoToPlaylist(
      video: const VideoItem(id: '123', title: 'Example', slug: 'example'),
      playlistId: playlist.id,
    );
    await api.removeVideoFromPlaylist(
      video: const VideoItem(id: '123', title: 'Example', slug: 'example'),
      playlistId: playlist.id,
    );

    expect(requests.map((item) => item.uri.path), [
      '/my/playlists/',
      '/my/playlists/2/',
      '/video/123/example/',
      '/video/123/example/',
    ]);
    expect(requests.last.method, 'POST');
    expect(requests.last.data, containsPair('fav_type', '10'));
    expect(requests.last.data, containsPair('playlist_id', '42'));
    expect(
      requests.last.data,
      containsPair('action', 'delete_from_favourites'),
    );
  });

  test('账号播放列表使用网站表单协议创建、编辑和删除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.method == 'GET' &&
            options.uri.path == '/edit-playlist/42/') {
          return _htmlResponse('''
            <input name="title" value="原名称">
            <textarea name="description">原描述</textarea>
            <input type="radio" name="is_private" value="1" checked>
          ''');
        }
        if (options.method == 'GET' && options.uri.path == '/my/playlists/') {
          return _htmlResponse('{"status":"success"}');
        }
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);

    final current = await api.loadPlaylistForm('42');
    await api.createPlaylist(
      const PlaylistFormData(
        title: '新列表',
        description: '新描述',
        isPrivate: false,
      ),
    );
    await api.updatePlaylist(
      playlistId: '42',
      form: const PlaylistFormData(
        title: '新名称',
        description: '更新描述',
        isPrivate: true,
      ),
    );
    await api.deletePlaylist('42');

    expect(current.title, '原名称');
    expect(current.description, '原描述');
    expect(current.isPrivate, isTrue);
    expect(requests.map((item) => item.uri.path), [
      '/edit-playlist/42/',
      '/create-playlist/',
      '/edit-playlist/42/',
      '/my/playlists/',
    ]);
    expect(_requestFields(requests[1].data), {
      'title': '新列表',
      'description': '新描述',
      'is_private': '0',
      'action': 'add_new_complete',
    });
    expect(_requestFields(requests[2].data), {
      'title': '新名称',
      'description': '更新描述',
      'is_private': '1',
      'action': 'change_complete',
    });
    expect(requests[3].uri.queryParameters, containsPair('mode', 'async'));
    expect(requests[3].uri.queryParameters, containsPair('format', 'json'));
    expect(
      requests[3].uri.queryParameters,
      containsPair('action', 'delete_playlists'),
    );
    expect(requests[3].uri.queryParametersAll['delete[]'], ['42']);
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
    await api.loadDiscoveryDirectory(spec, page: 2);
    await api.loadCollectionVideos(item, 2, sort: VideoSort.mostViewed);

    expect(requests.first.path, '/models/');
    expect(requests[1].path, '/models/2/');
    expect(requests.last.path, '/models/example-artist/2/');
    expect(requests.last.queryParameters['sort_by'], 'video_viewed');
  });

  test('艺术家集合可补全数值筛选 ID、真实路径和头像', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    Uri? request;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        request = options.uri;
        return _htmlResponse('''
          <div class="item">
            <a href="/models/hydrafxx/" title="HydraFXX">
              <img src="/contents/models/87/s1_hydra.png" alt="HydraFXX">
            </a>
            <span>201 videos</span>
          </div>
        ''');
      }),
    );
    addTearDown(api.close);
    const collection = ContentCollectionItem(
      id: '87',
      filterId: '87',
      title: 'HydraFXX',
      path: '/models/87/',
      kind: DiscoveryKind.model,
      total: 1449,
    );

    final resolved = await api.resolveCollection(collection);

    expect(request?.path, '/models/');
    expect(request?.queryParameters['q'], 'HydraFXX');
    expect(resolved.id, '87');
    expect(resolved.filterId, '87');
    expect(resolved.path, '/models/hydrafxx/');
    expect(
      resolved.thumbnailUrl,
      'https://rule34video.com/contents/models/87/s1_hydra.png',
    );
  });

  test('标签目录第二页使用 AJAX Block 而不是标签 ID 页面', () async {
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

    await api.loadDiscoveryDirectory(
      const DiscoveryDirectorySpec(
        title: '标签',
        path: '/tags/',
        kind: DiscoveryKind.tag,
      ),
      page: 2,
    );

    expect(request?.path, '/tags/');
    expect(request?.queryParameters['mode'], 'async');
    expect(request?.queryParameters['function'], 'get_block');
    expect(request?.queryParameters['block_id'], 'list_tags_tags_list');
    expect(request?.queryParameters['from'], '2');
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
      1,
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
          SearchSuggestion(
            id: '24',
            title: 'voice',
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
        excludedTags: [
          SearchSuggestion(
            id: '66',
            title: 'watermark',
            total: 1,
            kind: SearchSuggestionKind.tag,
          ),
        ],
        excludedCategories: [
          SearchSuggestion(
            id: '88',
            title: 'Compilation',
            total: 1,
            kind: SearchSuggestionKind.category,
          ),
        ],
        excludedModels: [
          SearchSuggestion(
            id: '99',
            title: 'Excluded Artist',
            total: 1,
            kind: SearchSuggestionKind.model,
          ),
        ],
      ),
    );

    expect(request?.path, '/search/example%20query/');
    expect(request?.queryParameters['sort_by'], 'rating');
    expect(request?.queryParameters['flag1'], '2109');
    expect(request?.queryParameters['duration_from'], '300');
    expect(request?.queryParameters['duration_to'], '1200');
    expect(request?.queryParameters['flag2'], '1');
    expect(request?.queryParameters['tag_ids'], 'all,23,24');
    expect(request?.queryParameters['category_ids'], 'all,199');
    expect(request?.queryParameters['model_ids'], 'all,639');
    expect(
      request?.queryParameters['temp_skip_items'],
      'tag:66,cat:88,model:99',
    );
    expect(
      request?.queryParameters['post_date_from'],
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
  });

  test('预览补全使用网站搜索表单并解析专用预览地址', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    Uri? request;
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        request = options.uri;
        return _htmlResponse('''
          <div class="item thumb">
            <a class="th" href="/video/4514001/target-video/">
              <div class="img wrap_image" data-preview="/preview.mp4">
                <img class="thumb" data-original="/thumb.jpg">
              </div>
            </a>
            <div class="thumb_title">目标视频</div>
          </div>
        ''');
      }),
    );
    addTearDown(api.close);

    final videos = await api.searchVideosForPreview('目标视频');

    expect(request?.path, '/search/');
    expect(request?.queryParameters, {'q': '目标视频'});
    expect(videos.single.id, '4514001');
    expect(videos.single.previewUrl, 'https://rule34video.com/preview.mp4');
  });

  test('空关键词也可仅依靠筛选条件搜索', () async {
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
      '',
      1,
      filters: const SearchFilters(
        tags: [
          SearchSuggestion(
            id: '23',
            title: 'sound',
            total: 1,
            kind: SearchSuggestionKind.tag,
          ),
        ],
      ),
    );

    expect(request?.path, '/search/');
    expect(request?.queryParameters['tag_ids'], 'all,23');
  });

  test('搜索第二页使用网站 AJAX Block 分页协议', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final requests = <Uri>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options.uri);
        return _htmlResponse('<html></html>');
      }),
    );
    addTearDown(api.close);
    const filters = SearchFilters(
      sort: VideoSort.newest,
      duration: VideoDurationPreset.short,
      models: [
        SearchSuggestion(
          id: '87',
          title: 'HydraFXX',
          total: 1449,
          kind: SearchSuggestionKind.model,
        ),
      ],
    );

    await api.searchVideos('', 2, filters: filters);
    await api.searchVideos('tifa', 3, filters: filters);

    for (final request in requests) {
      expect(request.path, '/search/');
      expect(request.queryParameters['mode'], 'async');
      expect(request.queryParameters['function'], 'get_block');
      expect(
        request.queryParameters['block_id'],
        'custom_list_videos_videos_list_search',
      );
      expect(request.queryParameters['sort_by'], 'post_date');
      expect(request.queryParameters['duration_from'], '0');
      expect(request.queryParameters['duration_to'], '300');
      expect(request.queryParameters['model_ids'], 'all,87');
    }
    expect(requests[0].queryParameters['q'], '');
    expect(requests[0].queryParameters['from_videos'], '2');
    expect(requests[0].queryParameters['from_albums'], '2');
    expect(requests[1].queryParameters['q'], 'tifa');
    expect(requests[1].queryParameters['from_videos'], '3');
    expect(requests[1].queryParameters['from_albums'], '3');
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
    expect(requests[0].queryParameters['q'], 'ex');
    expect(requests[0].queryParameters.containsKey('term'), isFalse);
    expect(requests[1].path, '/categories_json.php');
    expect(requests[1].queryParameters['id'], 'true');
    expect(requests[1].queryParameters['q'], 'ex');
    expect(requests[1].queryParameters.containsKey('term'), isFalse);
    expect(requests[2].path, '/models_json.php');
    expect(requests[2].queryParameters['q'], 'ex');
    expect(requests[2].queryParameters.containsKey('term'), isFalse);
  });

  test('订阅与取消订阅使用已验证协议', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final bodies = <Map<String, String>>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        bodies.add(_requestFields(options.data));
        return _htmlResponse('<success/>');
      }),
    );
    addTearDown(api.close);
    const video = VideoItem(id: '4505897', title: 'Example', slug: 'example');
    const category = VideoMetadataItem(
      id: '199',
      title: '3D',
      path: '/categories/3d/',
      kind: DiscoveryKind.category,
    );

    await api.toggleSubscription(video: video, item: category, subscribe: true);
    await api.toggleSubscription(
      video: video,
      item: category,
      subscribe: false,
    );
    expect(requests.map((request) => request.uri.path).toSet(), {
      '/video/4505897/example/',
    });
    expect(
      requests.every(
        (request) => request.uri.queryParameters['mode'] == 'async',
      ),
      isTrue,
    );
    expect(bodies[0], {'action': 'subscribe', 'subscribe_category_id': '199'});
    expect(bodies[1], {
      'action': 'unsubscribe',
      'unsubscribe_category_id': '199',
    });
  });

  test('上传者订阅使用用户订阅参数', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final bodies = <Map<String, String>>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        bodies.add(_requestFields(options.data));
        return _htmlResponse('<success/>');
      }),
    );
    addTearDown(api.close);
    const uploader = UploaderSummary(id: '42', name: 'Uploader');

    await api.toggleUploaderSubscription(uploader: uploader, subscribe: true);
    await api.toggleUploaderSubscription(uploader: uploader, subscribe: false);

    expect(requests.map((request) => request.uri.path).toSet(), {
      '/members/42/',
    });
    expect(
      requests.every(
        (request) => request.uri.queryParameters['mode'] == 'async',
      ),
      isTrue,
    );
    expect(bodies[0], {'action': 'subscribe', 'subscribe_user_id': '42'});
    expect(bodies[1], {'action': 'unsubscribe', 'unsubscribe_user_id': '42'});
  });

  test('订阅列表中的上传者可以直接取消订阅', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        return _htmlResponse('<success/>');
      }),
    );
    addTearDown(api.close);

    await api.unsubscribeSubscription(
      const SubscriptionItem(
        title: 'Uploader',
        path: '/members/42/',
        kind: SubscriptionKind.member,
      ),
    );

    expect(requests.single.uri.path, '/members/42/');
    expect(_requestFields(requests.single.data), {
      'action': 'unsubscribe',
      'unsubscribe_user_id': '42',
    });
  });

  test('订阅列表中的艺术家通过其视频元数据取消订阅', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final requests = <RequestOptions>[];
    final api = Rule34VideoApi(
      sessionStore: harness.sessionStore,
      httpClientAdapter: _TestAdapter((options) {
        requests.add(options);
        if (options.method == 'POST') {
          return _htmlResponse('<success/>');
        }
        if (options.uri.path == '/models/hydrafxx/') {
          return _htmlResponse(
            _videoListItem(
              id: '4505897',
              slug: 'example',
              title: 'Example',
              published: '1 day ago',
            ),
          );
        }
        return _htmlResponse('''
          <link rel="canonical" href="/video/4505897/example/">
          <script>
            flashvars = {
              video_url: 'https://cdn.example.com/video_720p.mp4',
              video_url_text: '720p'
            };
          </script>
          <span class="js-video-vote-chip"
                data-item-type="model"
                data-item-id="639">
            <a href="/models/hydrafxx/"><span>HydraFXX</span></a>
          </span>
        ''');
      }),
    );
    addTearDown(api.close);

    await api.unsubscribeSubscription(
      const SubscriptionItem(
        title: 'HydraFXX',
        path: '/models/hydrafxx/',
        kind: SubscriptionKind.model,
      ),
    );

    expect(requests.map((request) => request.uri.path), [
      '/models/hydrafxx/',
      '/video/4505897/example/',
      '/video/4505897/example/',
    ]);
    expect(_requestFields(requests.last.data), {
      'action': 'unsubscribe',
      'unsubscribe_model_id': '639',
    });
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

String _videoListItem({
  required String id,
  required String slug,
  required String title,
  required String published,
}) {
  return '''
    <div class="item thumb video_$id">
      <a class="th js-open-popup" href="/video/$id/$slug/" title="$title">
        <img class="thumb" data-original="/$id.jpg" alt="$title">
      </a>
      <div class="time">1:00</div>
      <div class="thumb_title">$title</div>
      <div class="thumb_info">
        <div class="added">$published</div>
        <div class="rating">100% (1)</div>
        <div class="views">1</div>
      </div>
    </div>
  ''';
}

String? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

Map<String, String> _requestFields(Object? data) {
  if (data is FormData) {
    return Map<String, String>.fromEntries(data.fields);
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
  return const {};
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
