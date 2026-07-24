import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/video_models.dart';
import '../session/session_store.dart';
import 'site_parser.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Rule34VideoApi {
  Rule34VideoApi({
    required this.sessionStore,
    HttpClientAdapter? httpClientAdapter,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://rule34video.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        followRedirects: false,
        headers: const {
          'User-Agent': 'Flule34 Android/0.1',
          'Accept':
              'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(
      CookieManager(sessionStore.cookieJar, ignoreInvalidCookies: true),
    );
  }

  final SessionStore sessionStore;
  late final Dio _dio;

  void close() => _dio.close(force: true);

  Future<void> restoreSession() async {
    if (!sessionStore.isLoggedIn) {
      return;
    }
    try {
      final body = await _get('/');
      final userId = SiteParser.userId(body);
      if (userId == null) {
        await sessionStore.clear();
        return;
      }
      await sessionStore.authenticate(userId);
    } on ApiException {
      // 网络暂时不可用时保留本地账号，后续请求仍可重新验证会话。
    }
  }

  Future<String?> sessionCookieHeader() {
    return sessionStore.cookieHeaderFor(Uri.parse('https://rule34video.com/'));
  }

  Future<List<VideoItem>> loadFeed(FeedKind kind, int page) async {
    return _videoList(kind.pagePath(page));
  }

  Future<List<VideoItem>> searchVideos(String query, int page) async {
    final encoded = Uri.encodeComponent(query.trim());
    if (encoded.isEmpty) {
      return const [];
    }
    final suffix = page > 1 ? '/$page' : '';
    return _videoList('/search/$encoded$suffix/');
  }

  Future<List<TagSuggestion>> searchTags(String query) async {
    if (query.trim().length < 2) {
      return const [];
    }
    final body = await _get(
      '/tags_json.php',
      query: <String, String>{'q': query.trim()},
    );
    try {
      return SiteParser.tagSuggestions(body);
    } on FormatException {
      return const [];
    }
  }

  Future<VideoDetails> loadVideoDetails(VideoItem video) async {
    final body = await _get(video.detailPath);
    return SiteParser.videoDetails(source: body, fallback: video);
  }

  Future<void> login({required String email, required String password}) async {
    await sessionStore.clear();
    try {
      final body = await _post(
        '/login/',
        data: <String, String>{
          'username': email.trim(),
          'pass': password,
          'action': 'login',
          'email_link': 'https://rule34video.com/email/',
        },
        followRedirects: true,
      );
      final userId = SiteParser.userId(body);
      if (userId == null) {
        throw ApiException(
          SiteParser.genericError(body) ?? '登录失败，请检查账号、密码或验证码要求。',
        );
      }
      await sessionStore.authenticate(userId);
    } catch (_) {
      await sessionStore.clear();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _get('/logout/');
    } finally {
      await sessionStore.clear();
    }
  }

  Future<List<VideoItem>> loadFavorites(int page) async {
    _requireLogin();
    final path = page > 1
        ? '/my/favourites/videos/$page/'
        : '/my/favourites/videos/';
    return _videoList(path);
  }

  Future<List<VideoItem>> loadWatchLater(int page) async {
    _requireLogin();
    final path = page > 1
        ? '/my/favourites/videos-watch-later/$page/'
        : '/my/favourites/videos-watch-later/';
    return _videoList(path);
  }

  Future<List<VideoItem>> loadHistory(int page) async {
    _requireLogin();
    final path = page > 1 ? '/my/history/$page/' : '/my/history/';
    return _videoList(path);
  }

  Future<List<PlaylistItem>> loadMyPlaylists() async {
    _requireLogin();
    return SiteParser.playlists(await _get('/my/playlists/'));
  }

  Future<List<VideoItem>> loadPlaylistVideos(
    PlaylistItem playlist,
    int page,
  ) async {
    _requireLogin();
    final path = page > 1 ? '${playlist.path}$page/' : playlist.path;
    return _videoList(path);
  }

  Future<void> toggleFavorite({
    required VideoItem video,
    required bool add,
  }) async {
    _requireLogin();
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': add ? 'add_to_favourites' : 'delete_from_favourites',
        'video_id': video.id,
        'fav_type': '0',
        'playlist_id': '0',
      },
      ajax: true,
    );
  }

  Future<List<VideoItem>> _videoList(String path) async {
    final body = await _get(path);
    return SiteParser.videoList(body);
  }

  Future<String> _get(String path, {Map<String, String>? query}) async {
    try {
      final response = await _dio.get<String>(path, queryParameters: query);
      return _readResponse(await _followRedirects(response));
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Future<String> _post(
    String path, {
    required Map<String, String> data,
    Map<String, String>? query,
    bool ajax = false,
    bool followRedirects = false,
  }) async {
    try {
      final response = await _dio.post<String>(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          headers: ajax ? const {'X-Requested-With': 'XMLHttpRequest'} : null,
        ),
      );
      return _readResponse(
        followRedirects ? await _followRedirects(response) : response,
      );
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  String _readResponse(Response<String> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiException('服务器返回了 HTTP $status。');
    }
    return response.data ?? '';
  }

  Future<Response<String>> _followRedirects(Response<String> response) async {
    var current = response;
    for (var redirects = 0; redirects < 5; redirects += 1) {
      final status = current.statusCode ?? 0;
      if (status < 300 || status >= 400) {
        return current;
      }
      final location = current.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) {
        throw const ApiException('服务器返回了缺少目标地址的重定向。');
      }
      final nextUri = current.realUri.resolve(location);
      current = await _dio.getUri<String>(
        nextUri,
        options: Options(followRedirects: false),
      );
    }
    throw const ApiException('服务器重定向次数过多。');
  }

  String _networkMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => '网络请求超时，请稍后重试。',
      DioExceptionType.connectionError => '无法连接到网站，请检查网络。',
      _ => '请求失败：${error.message ?? '未知网络错误'}',
    };
  }

  void _requireLogin() {
    if (!sessionStore.isLoggedIn) {
      throw const ApiException('请先登录后再使用此功能。');
    }
  }
}
