import 'dart:async';

import 'package:dio/dio.dart';

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
  Rule34VideoApi({required this.sessionStore}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://rule34video.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent': 'Flule34 Android/0.1',
          'Accept':
              'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final cookie = sessionStore.cookieHeader;
          if (cookie != null) {
            options.headers['Cookie'] = cookie;
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          await sessionStore.captureSetCookieHeaders(
            response.headers.map['set-cookie'] ?? const <String>[],
          );
          handler.next(response);
        },
      ),
    );
  }

  final SessionStore sessionStore;
  late final Dio _dio;

  void close() => _dio.close(force: true);

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
    final body = await _post(
      '/login/',
      data: <String, String>{
        'username': email.trim(),
        'pass': password,
        'action': 'login',
        'email_link': 'https://rule34video.com/email/',
      },
    );
    if (!sessionStore.isLoggedIn) {
      throw ApiException(
        SiteParser.genericError(body) ?? '登录失败，请检查账号、密码或验证码要求。',
      );
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
      return _readResponse(response);
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Future<String> _post(
    String path, {
    required Map<String, String> data,
    Map<String, String>? query,
    bool ajax = false,
  }) async {
    try {
      final response = await _dio.post<String>(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: ajax ? const {'X-Requested-With': 'XMLHttpRequest'} : null,
        ),
      );
      return _readResponse(response);
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  String _readResponse(Response<String> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 400) {
      throw ApiException('服务器返回了 HTTP $status。');
    }
    return response.data ?? '';
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
