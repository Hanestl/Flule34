import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/account_models.dart';
import '../models/video_models.dart';
import '../security/error_redaction.dart';
import '../session/session_store.dart';
import 'site_parser.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SessionExpiredException extends ApiException {
  const SessionExpiredException() : super('登录状态已过期，请重新登录。');
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
  List<SubscriptionItem>? _subscriptionCache;
  String? _subscriptionCacheUserId;

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

  Future<List<VideoItem>> loadFeed(
    FeedKind kind,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    return _videoList(kind.pagePath(page), query: _searchQuery(filters));
  }

  Future<List<VideoItem>> loadFollowingFeed(int page) async {
    _requireLogin();
    final subscriptions = (await loadSubscriptions()).take(8).toList();
    if (subscriptions.isEmpty) {
      return const [];
    }
    final pages = await Future.wait(
      subscriptions.map((item) => loadSubscriptionVideos(item, page)),
    );
    final merged = <String, VideoItem>{};
    final longest = pages.fold<int>(
      0,
      (length, items) => items.length > length ? items.length : length,
    );
    for (var index = 0; index < longest; index += 1) {
      for (final items in pages) {
        if (index < items.length) {
          merged[items[index].id] = items[index];
        }
      }
    }
    return merged.values.take(30).toList(growable: false);
  }

  Future<List<ContentCollectionItem>> loadDiscoveryDirectory(
    DiscoveryDirectorySpec spec, {
    int page = 1,
  }) async {
    final path = page > 1 ? '${spec.path}$page/' : spec.path;
    final body = await _get(path);
    return SiteParser.contentCollections(body, spec.kind);
  }

  Future<List<VideoItem>> loadCollectionVideos(
    ContentCollectionItem collection,
    int page, {
    VideoSort sort = VideoSort.newest,
  }) {
    final path = page > 1 ? '${collection.path}$page/' : collection.path;
    return _videoList(
      path,
      query: sort.parameter == null
          ? null
          : <String, String>{'sort_by': sort.parameter!},
    );
  }

  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    final encoded = Uri.encodeComponent(query.trim());
    if (encoded.isEmpty) {
      return const [];
    }
    final suffix = page > 1 ? '/$page' : '';
    return _videoList('/search/$encoded$suffix/', query: _searchQuery(filters));
  }

  Future<List<TagSuggestion>> searchTags(String query) async {
    return (await searchSuggestions(query, SearchSuggestionKind.tag))
        .map(
          (item) =>
              TagSuggestion(id: item.id, title: item.title, total: item.total),
        )
        .toList(growable: false);
  }

  Future<List<SearchSuggestion>> searchSuggestions(
    String query,
    SearchSuggestionKind kind,
  ) async {
    if (query.trim().length < 2) {
      return const [];
    }
    final path = switch (kind) {
      SearchSuggestionKind.tag => '/tags_json.php',
      SearchSuggestionKind.category => '/categories_json.php',
      SearchSuggestionKind.model => '/models_json.php',
    };
    final parameters = switch (kind) {
      SearchSuggestionKind.tag => <String, String>{
        'id': 'true',
        'advanced_search': 'true',
        'term': query.trim(),
      },
      SearchSuggestionKind.category => <String, String>{
        'advanced_search': 'true',
        'term': query.trim(),
      },
      SearchSuggestionKind.model => <String, String>{'q': query.trim()},
    };
    final body = await _get(path, query: parameters);
    try {
      return SiteParser.searchSuggestions(body, kind);
    } on FormatException {
      return const [];
    }
  }

  Future<VideoDetails> loadVideoDetails(VideoItem video) async {
    final body = await _get(video.detailPath);
    return SiteParser.videoDetails(source: body, fallback: video);
  }

  Future<MemberProfile> loadCurrentUserProfile() async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    final profile = SiteParser.memberProfile(
      await _get('/members/$userId/'),
      userId,
    );
    if (profile == null) {
      throw const ApiException('无法解析当前账号资料，请稍后重试。');
    }
    await sessionStore.database.recordAuthenticatedAccount(
      userId,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
    );
    return profile;
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

  Future<List<SubscriptionItem>> loadSubscriptions({bool force = false}) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    if (!force &&
        _subscriptionCache != null &&
        _subscriptionCacheUserId == userId) {
      return _subscriptionCache!;
    }
    final result = SiteParser.subscriptions(await _get('/my/subscriptions/'));
    _subscriptionCache = result;
    _subscriptionCacheUserId = userId;
    return result;
  }

  Future<List<VideoItem>> loadSubscriptionVideos(
    SubscriptionItem subscription,
    int page,
  ) async {
    _requireLogin();
    final path = page > 1 ? '${subscription.path}$page/' : subscription.path;
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

  Future<void> rateVideo({required VideoItem video, required bool like}) async {
    _requireLogin();
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': 'rate',
        'video_id': video.id,
        'vote': like ? '5' : '0',
      },
      ajax: true,
    );
  }

  Future<void> voteMetadata({
    required VideoItem video,
    required VideoMetadataItem item,
    required bool upvote,
  }) async {
    _requireLogin();
    final idField = switch (item.kind) {
      DiscoveryKind.tag => 'tag_id',
      DiscoveryKind.category => 'category_id',
      DiscoveryKind.model => 'model_id',
      DiscoveryKind.channel => throw const ApiException('此类型不支持投票。'),
    };
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': 'rate',
        'video_id': video.id,
        idField: item.id,
        'vote': upvote ? '1' : '-1',
      },
      ajax: true,
    );
  }

  Future<void> addVideoToPlaylist({
    required VideoItem video,
    required String playlistId,
  }) async {
    _requireLogin();
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': 'add_to_favourites',
        'video_id': video.id,
        'fav_type': '10',
        'playlist_id': playlistId,
      },
      ajax: true,
    );
  }

  Future<void> toggleSubscription({
    required VideoItem video,
    required VideoMetadataItem item,
    required bool subscribe,
  }) async {
    _requireLogin();
    final type = switch (item.kind) {
      DiscoveryKind.category => 'category',
      DiscoveryKind.model => 'model',
      _ => throw const ApiException('此类型不支持订阅。'),
    };
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': subscribe ? 'subscribe' : 'unsubscribe',
        '${subscribe ? 'subscribe' : 'unsubscribe'}_${type}_id': item.id,
      },
      ajax: true,
    );
    _subscriptionCache = null;
    _subscriptionCacheUserId = null;
  }

  Future<void> postComment({
    required VideoItem video,
    required String comment,
  }) async {
    _requireLogin();
    final text = comment.trim();
    if (text.isEmpty) {
      throw const ApiException('评论内容不能为空。');
    }
    await _postMultipart(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, dynamic>{'comment': text, 'anonymous_username': ''},
    );
  }

  Future<void> voteComment({
    required VideoItem video,
    required VideoComment comment,
    required bool upvote,
  }) async {
    _requireLogin();
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': 'vote_comment',
        'vote': upvote ? '1' : '-1',
        'comment_id': comment.id,
      },
      ajax: true,
    );
  }

  Future<List<VideoItem>> _videoList(
    String path, {
    Map<String, String>? query,
  }) async {
    final body = await _get(path, query: query);
    return SiteParser.videoList(body);
  }

  Future<String> _get(String path, {Map<String, String>? query}) async {
    try {
      final response = await _dio.get<String>(path, queryParameters: query);
      return _readResponse(await _followRedirects(response));
    } on SessionExpiredException {
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Map<String, String>? _searchQuery(SearchFilters filters) {
    final result = <String, String>{};
    final sort = filters.sort.parameter;
    if (sort != null) {
      result['sort_by'] = sort;
    }
    final orientation = filters.orientation.parameter;
    if (orientation != null) {
      result['flag1'] = orientation;
    }
    final uploadDuration = filters.uploadPeriod.duration;
    if (uploadDuration != null) {
      final from = DateTime.now().subtract(uploadDuration);
      result['post_date_from'] = _date(from);
    }
    final durationFrom = filters.duration.minSeconds;
    if (durationFrom != null) {
      result['duration_from'] = '$durationFrom';
    }
    final durationTo = filters.duration.maxSeconds;
    if (durationTo != null) {
      result['duration_to'] = '$durationTo';
    }
    if (filters.verifiedOnly) {
      result['flag2'] = '1';
    }
    if (filters.tags.isNotEmpty) {
      result['tag_ids'] = filters.tags.map((item) => item.id).join(',');
    }
    if (filters.categories.isNotEmpty) {
      result['category_ids'] = filters.categories
          .map((item) => item.id)
          .join(',');
    }
    if (filters.models.isNotEmpty) {
      result['model_ids'] = filters.models.map((item) => item.id).join(',');
    }
    return result.isEmpty ? null : result;
  }

  String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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
      final body = _readResponse(
        followRedirects ? await _followRedirects(response) : response,
      );
      final actionError = SiteParser.asyncActionError(body);
      if (ajax && actionError != null) {
        throw ApiException(actionError);
      }
      return body;
    } on SessionExpiredException {
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Future<String> _postMultipart(
    String path, {
    required Map<String, dynamic> data,
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.post<String>(
        path,
        queryParameters: query,
        data: FormData.fromMap(data),
        options: Options(
          followRedirects: false,
          headers: const {'X-Requested-With': 'XMLHttpRequest'},
        ),
      );
      final body = _readResponse(response);
      final actionError = SiteParser.asyncActionError(body);
      if (actionError != null) {
        throw ApiException(actionError);
      }
      return body;
    } on SessionExpiredException {
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  String _readResponse(Response<String> response) {
    final status = response.statusCode ?? 0;
    if (_isLoginRedirect(response) ||
        (sessionStore.isLoggedIn && (status == 401 || status == 403))) {
      throw const SessionExpiredException();
    }
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
      if (sessionStore.isLoggedIn && _isLoginUri(nextUri)) {
        throw const SessionExpiredException();
      }
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
      _ => _genericNetworkMessage(error),
    };
  }

  String _genericNetworkMessage(DioException error) {
    final detail = redactSensitiveText(error.message).trim();
    return detail.isEmpty ? '请求失败，请稍后重试。' : '请求失败：$detail';
  }

  bool _isLoginRedirect(Response<String> response) {
    if (!sessionStore.isLoggedIn) {
      return false;
    }
    final status = response.statusCode ?? 0;
    if (status < 300 || status >= 400) {
      return false;
    }
    final location = response.headers.value(HttpHeaders.locationHeader);
    return location != null &&
        location.isNotEmpty &&
        _isLoginUri(response.realUri.resolve(location));
  }

  bool _isLoginUri(Uri uri) {
    return uri.path == '/' && uri.queryParameters.containsKey('login');
  }

  Future<void> _clearExpiredSession() async {
    _subscriptionCache = null;
    _subscriptionCacheUserId = null;
    await sessionStore.clear();
  }

  void _requireLogin() {
    if (!sessionStore.isLoggedIn) {
      throw const ApiException('请先登录后再使用此功能。');
    }
  }
}
