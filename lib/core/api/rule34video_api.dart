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

final class HttpStatusException extends ApiException {
  const HttpStatusException(this.statusCode)
    : super('服务器返回了 HTTP $statusCode。');

  final int statusCode;
}

final class SessionExpiredException extends ApiException {
  const SessionExpiredException() : super('登录状态已过期，请重新登录。');
}

class Rule34VideoApi {
  static const _videoDetailsCacheTtl = Duration(minutes: 2);

  Rule34VideoApi({
    required this.sessionStore,
    HttpClientAdapter? httpClientAdapter,
  }) {
    _dio = Dio(_baseOptions());
    _publicDio = Dio(_baseOptions());
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
      _publicDio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(
      CookieManager(sessionStore.cookieJar, ignoreInvalidCookies: true),
    );
  }

  final SessionStore sessionStore;
  late final Dio _dio;
  late final Dio _publicDio;
  List<SubscriptionItem>? _subscriptionCache;
  String? _subscriptionCacheUserId;
  final Map<String, Future<SubscriptionItem>> _subscriptionResolutionRequests =
      {};
  final Map<String, _VideoDetailsCacheEntry> _videoDetailsCache = {};
  final Map<String, Future<VideoDetails>> _videoDetailsRequests = {};
  final Map<String, bool> _favoriteStatusByVideoId = {};
  String? _favoriteCacheUserId;
  MemberProfile? _currentUserProfileCache;
  String? _currentUserProfileCacheUserId;
  Future<MemberProfile>? _currentUserProfileRequest;
  bool _currentUserProfileRefreshed = false;

  void close() {
    _dio.close(force: true);
    _publicDio.close(force: true);
  }

  Future<void> restoreSession() async {
    if (!sessionStore.isLoggedIn) {
      await _tryRestoreWithCredentials();
      return;
    }
    try {
      final body = await _get('/');
      final userId = SiteParser.userId(body);
      if (userId == null) {
        await _tryRestoreWithCredentials();
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
    return _paginatedVideoList(
      kind.pagePath(page),
      page: page,
      query: _searchQuery(filters),
    );
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
    if (spec.kind == DiscoveryKind.channel && page > 1) {
      return const [];
    }
    final String body;
    if (spec.kind == DiscoveryKind.tag && page > 1) {
      body = await _get(
        spec.path,
        query: <String, String>{
          'mode': 'async',
          'function': 'get_block',
          'block_id': 'list_tags_tags_list',
          'section': 'All',
          'sort_by': 'tag',
          'from': '$page',
        },
      );
    } else {
      final path = page > 1 ? '${spec.path}$page/' : spec.path;
      body = await _get(path);
    }
    return SiteParser.contentCollections(body, spec.kind);
  }

  Future<List<VideoItem>> loadCollectionVideos(
    ContentCollectionItem collection,
    int page, {
    VideoSort sort = VideoSort.newest,
  }) {
    final path = page > 1 ? '${collection.path}$page/' : collection.path;
    return _paginatedVideoList(
      path,
      page: page,
      query: sort.parameter == null
          ? null
          : <String, String>{'sort_by': sort.parameter!},
    );
  }

  Future<ContentCollectionItem> resolveCollection(
    ContentCollectionItem collection,
  ) async {
    if (collection.thumbnailUrl != null ||
        (collection.kind != DiscoveryKind.model &&
            collection.kind != DiscoveryKind.category)) {
      return collection;
    }
    final body = await _get(
      '/${collection.kind.pathSegment}/',
      query: <String, String>{'q': collection.title},
    );
    final candidates = SiteParser.contentCollections(body, collection.kind);
    final normalizedTitle = collection.title.trim().toLowerCase();
    ContentCollectionItem? match;
    for (final candidate in candidates) {
      if (candidate.effectiveFilterId == collection.effectiveFilterId) {
        match = candidate;
        break;
      }
      if (match == null &&
          candidate.title.trim().toLowerCase() == normalizedTitle) {
        match = candidate;
      }
    }
    if (match == null) {
      return collection;
    }
    return collection.copyWith(
      path: match.path,
      filterId: match.filterId,
      thumbnailUrl: match.thumbnailUrl,
      total: match.total,
    );
  }

  Future<List<VideoItem>> searchVideos(
    String query,
    int page, {
    SearchFilters filters = const SearchFilters(),
  }) async {
    final normalizedQuery = query.trim();
    final encoded = Uri.encodeComponent(normalizedQuery);
    if (encoded.isEmpty && filters.isEmpty) {
      return const [];
    }
    final parameters = <String, String>{...?_searchQuery(filters)};
    if (page > 1) {
      parameters.addAll({
        'mode': 'async',
        'function': 'get_block',
        'block_id': 'custom_list_videos_videos_list_search',
        'q': normalizedQuery,
        'from_videos': '$page',
        'from_albums': '$page',
      });
      return _paginatedVideoList('/search/', page: page, query: parameters);
    }
    final path = encoded.isEmpty ? '/search/' : '/search/$encoded/';
    return _paginatedVideoList(
      path,
      page: page,
      query: parameters.isEmpty ? null : parameters,
    );
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
        'q': query.trim(),
      },
      SearchSuggestionKind.category => <String, String>{
        'id': 'true',
        'q': query.trim(),
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

  Future<VideoDetails> loadVideoDetails(VideoItem video) {
    final key = _videoDetailsCacheKey(video.id);
    final cached = _videoDetailsCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _videoDetailsCacheTtl) {
      return Future.value(_applyKnownFavorite(cached.details));
    }
    final pending = _videoDetailsRequests[key];
    if (pending != null) {
      return pending;
    }
    late final Future<VideoDetails> request;
    request = _fetchVideoDetails(video)
        .then((details) {
          if (identical(_videoDetailsRequests[key], request)) {
            _videoDetailsCache[key] = _VideoDetailsCacheEntry(
              details: details,
              createdAt: DateTime.now(),
            );
          }
          return details;
        })
        .whenComplete(() {
          if (identical(_videoDetailsRequests[key], request)) {
            _videoDetailsRequests.remove(key);
          }
        });
    _videoDetailsRequests[key] = request;
    return request;
  }

  Future<VideoDetails> refreshVideoDetails(VideoItem video) {
    final key = _videoDetailsCacheKey(video.id);
    _videoDetailsCache.remove(key);
    _videoDetailsRequests.remove(key);
    return loadVideoDetails(video);
  }

  Future<VideoDetails> _fetchVideoDetails(VideoItem video) async {
    String body;
    var usedPublicRequest = false;
    try {
      body = await _get(video.detailPath);
    } on SessionExpiredException {
      body = await _getPublic(video.detailPath);
      usedPublicRequest = true;
    } on HttpStatusException catch (error) {
      if (error.statusCode != 403) {
        rethrow;
      }
      body = await _getPublic(video.detailPath);
      usedPublicRequest = true;
    }
    var details = SiteParser.videoDetails(source: body, fallback: video);
    if (details.sources.isEmpty && !usedPublicRequest) {
      final publicBody = await _getPublic(video.detailPath);
      final publicDetails = SiteParser.videoDetails(
        source: publicBody,
        fallback: video,
      );
      if (publicDetails.sources.isNotEmpty) {
        details = publicDetails.copyWith(
          video: publicDetails.video.copyWith(isFavorite: details.isFavorite),
          isFavorite: details.isFavorite,
        );
      } else if (!SiteParser.isVideoDetailsPage(body, video.id) &&
          !SiteParser.isVideoDetailsPage(publicBody, video.id)) {
        throw const ApiException('视频详情响应异常，请稍后重试。');
      }
    } else if (details.sources.isEmpty &&
        !SiteParser.isVideoDetailsPage(body, video.id)) {
      throw const ApiException('视频详情响应异常，请稍后重试。');
    }
    _syncFavoriteCache();
    _favoriteStatusByVideoId[video.id] = details.isFavorite;
    return details;
  }

  VideoDetails _applyKnownFavorite(VideoDetails details) {
    _syncFavoriteCache();
    final known = _favoriteStatusByVideoId[details.video.id];
    if (known == null || known == details.isFavorite) {
      return details;
    }
    return details.copyWith(
      video: details.video.copyWith(isFavorite: known),
      isFavorite: known,
    );
  }

  Future<bool> favoriteStatus(VideoItem video) async {
    _requireLogin();
    _syncFavoriteCache();
    final known = video.isFavorite ?? _favoriteStatusByVideoId[video.id];
    if (known != null) {
      return known;
    }
    return (await loadVideoDetails(video)).isFavorite;
  }

  Future<MemberProfile?> loadCachedCurrentUserProfile() async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    _syncCurrentUserProfileCache(userId);
    final cached = _currentUserProfileCache;
    if (cached != null) {
      return cached;
    }
    final account = await sessionStore.database.findAccount(userId);
    if (account == null ||
        (account.displayName == null && account.avatarUrl == null)) {
      return null;
    }
    final profile = MemberProfile(
      id: userId,
      displayName: account.displayName ?? 'Rule34Video 账号',
      avatarUrl: account.avatarUrl,
    );
    _currentUserProfileCache = profile;
    return profile;
  }

  Future<MemberProfile> loadCurrentUserProfile({bool force = false}) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    _syncCurrentUserProfileCache(userId);
    if (!force &&
        _currentUserProfileRefreshed &&
        _currentUserProfileCache != null) {
      return _currentUserProfileCache!;
    }
    final pending = _currentUserProfileRequest;
    if (!force && pending != null) {
      return pending;
    }
    final request = _fetchCurrentUserProfile(userId);
    if (!force) {
      _currentUserProfileRequest = request;
    }
    try {
      final profile = await request;
      if (sessionStore.currentUserId == userId) {
        _currentUserProfileCache = profile;
        _currentUserProfileRefreshed = true;
      }
      return profile;
    } finally {
      if (identical(_currentUserProfileRequest, request)) {
        _currentUserProfileRequest = null;
      }
    }
  }

  Future<MemberProfile> _fetchCurrentUserProfile(String userId) async {
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

  Future<MemberProfile> loadMemberProfile(String userId) async {
    final profile = SiteParser.memberProfile(
      await _get('/members/$userId/'),
      userId,
    );
    if (profile == null) {
      throw const ApiException('无法解析上传者资料，请稍后重试。');
    }
    return profile;
  }

  Future<List<VideoItem>> loadUploaderVideos(
    UploaderSummary uploader,
    int page,
  ) {
    final path = page > 1
        ? '${uploader.videosPath}$page/'
        : uploader.videosPath;
    return _paginatedVideoList(path, page: page);
  }

  Future<void> login({
    required String email,
    required String password,
    bool rememberCredentials = true,
  }) {
    return _login(
      email: email,
      password: password,
      rememberCredentials: rememberCredentials,
      preserveExistingIdentityOnFailure: false,
    );
  }

  Future<void> _login({
    required String email,
    required String password,
    required bool rememberCredentials,
    required bool preserveExistingIdentityOnFailure,
  }) async {
    if (preserveExistingIdentityOnFailure) {
      await sessionStore.clearCookies();
    } else {
      await sessionStore.clear();
    }
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
      if (rememberCredentials) {
        await sessionStore.saveCredentials(email: email, password: password);
      }
    } catch (_) {
      if (preserveExistingIdentityOnFailure) {
        await sessionStore.clearCookies();
      } else {
        await sessionStore.clear();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _get('/logout/');
    } finally {
      await sessionStore.clear(forgetCredentials: true);
    }
  }

  Future<List<VideoItem>> loadFavorites(int page) async {
    _requireLogin();
    final path = page > 1
        ? '/my/favourites/videos/$page/'
        : '/my/favourites/videos/';
    final items = await _paginatedVideoList(path, page: page);
    _syncFavoriteCache();
    for (final item in items) {
      _favoriteStatusByVideoId[item.id] = true;
    }
    return items
        .map((item) => item.copyWith(isFavorite: true))
        .toList(growable: false);
  }

  Future<List<VideoItem>> loadHistory(int page) async {
    _requireLogin();
    final path = page > 1 ? '/my/history/$page/' : '/my/history/';
    return _paginatedVideoList(path, page: page);
  }

  Future<List<SubscriptionItem>> loadSubscriptions({bool force = false}) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    if (!force &&
        _subscriptionCache != null &&
        _subscriptionCacheUserId == userId) {
      return _subscriptionCache!;
    }
    if (force || _subscriptionCacheUserId != userId) {
      _subscriptionResolutionRequests.clear();
    }
    final result = SiteParser.subscriptions(await _get('/my/subscriptions/'));
    _subscriptionCache = result;
    _subscriptionCacheUserId = userId;
    return result;
  }

  Future<SubscriptionItem> resolveSubscription(SubscriptionItem subscription) {
    if (subscription.thumbnailUrl?.isNotEmpty == true) {
      return Future.value(subscription);
    }
    return _subscriptionResolutionRequests.putIfAbsent(
      subscription.path,
      () => _resolveSubscription(subscription),
    );
  }

  Future<SubscriptionItem> _resolveSubscription(
    SubscriptionItem subscription,
  ) async {
    try {
      final thumbnailUrl = switch (subscription.kind) {
        SubscriptionKind.model => (await resolveCollection(
          ContentCollectionItem(
            id: _pathIdentifier(subscription.path),
            title: subscription.title,
            path: subscription.path,
            kind: DiscoveryKind.model,
          ),
        )).thumbnailUrl,
        SubscriptionKind.member => await _memberSubscriptionAvatar(
          subscription.path,
        ),
        _ => null,
      };
      if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
        return subscription;
      }
      return subscription.copyWith(thumbnailUrl: thumbnailUrl);
    } on Object {
      return subscription;
    }
  }

  Future<String?> _memberSubscriptionAvatar(String path) async {
    final match = RegExp(r'/members/(\d+)/').firstMatch(path);
    if (match == null) {
      return null;
    }
    return (await loadMemberProfile(match.group(1)!)).avatarUrl;
  }

  Future<List<VideoItem>> loadSubscriptionVideos(
    SubscriptionItem subscription,
    int page,
  ) async {
    _requireLogin();
    final basePath = subscription.kind == SubscriptionKind.member
        ? _memberVideosPath(subscription.path)
        : subscription.path;
    final path = page > 1 ? '$basePath$page/' : basePath;
    return _paginatedVideoList(path, page: page);
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
    _syncFavoriteCache();
    _favoriteStatusByVideoId[video.id] = add;
    _videoDetailsCache.removeWhere((key, _) => key.endsWith(':${video.id}'));
  }

  Future<void> toggleUploaderSubscription({
    required UploaderSummary uploader,
    required bool subscribe,
  }) async {
    _requireLogin();
    await _post(
      uploader.profilePath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': subscribe ? 'subscribe' : 'unsubscribe',
        '${subscribe ? 'subscribe' : 'unsubscribe'}_user_id': uploader.id,
      },
      ajax: true,
    );
    _subscriptionCache = null;
    _subscriptionCacheUserId = null;
    _subscriptionResolutionRequests.clear();
  }

  Future<bool> isUploaderSubscribed(UploaderSummary uploader) async {
    if (!sessionStore.isLoggedIn) {
      return false;
    }
    final subscriptions = await loadSubscriptions();
    return subscriptions.any(
      (item) =>
          item.kind == SubscriptionKind.member &&
          RegExp('/members/${RegExp.escape(uploader.id)}/').hasMatch(item.path),
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
    _subscriptionResolutionRequests.clear();
  }

  Future<List<VideoItem>> _videoList(
    String path, {
    Map<String, String>? query,
  }) async {
    final body = await _get(path, query: query);
    return SiteParser.videoList(body);
  }

  Future<List<VideoItem>> _paginatedVideoList(
    String path, {
    required int page,
    Map<String, String>? query,
  }) async {
    try {
      return await _videoList(path, query: query);
    } on HttpStatusException catch (error) {
      if (page > 1 && error.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<String> _get(
    String path, {
    Map<String, String>? query,
    bool retryExpiredSession = true,
  }) async {
    try {
      final response = await _dio.get<String>(path, queryParameters: query);
      return _readResponse(await _followRedirects(response));
    } on SessionExpiredException {
      if (retryExpiredSession && await _tryRestoreWithCredentials()) {
        return _get(path, query: query, retryExpiredSession: false);
      }
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  Future<String> _getPublic(String path, {Map<String, String>? query}) async {
    try {
      final response = await _publicDio.get<String>(
        path,
        queryParameters: query,
      );
      final resolved = await _followRedirects(
        response,
        client: _publicDio,
        detectSessionExpiry: false,
      );
      final status = resolved.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw HttpStatusException(status);
      }
      return resolved.data ?? '';
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
      result['tag_ids'] =
          'all,${filters.tags.map((item) => item.id).join(',')}';
    }
    if (filters.categories.isNotEmpty) {
      result['category_ids'] =
          'all,${filters.categories.map((item) => item.id).join(',')}';
    }
    if (filters.models.isNotEmpty) {
      result['model_ids'] =
          'all,${filters.models.map((item) => item.id).join(',')}';
    }
    final excluded = <String>[
      ...filters.excludedTags.map((item) => 'tag:${item.id}'),
      ...filters.excludedCategories.map((item) => 'cat:${item.id}'),
      ...filters.excludedModels.map((item) => 'model:${item.id}'),
    ];
    if (excluded.isNotEmpty) {
      result['temp_skip_items'] = excluded.join(',');
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
    bool retryExpiredSession = true,
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
      if (retryExpiredSession && await _tryRestoreWithCredentials()) {
        return _post(
          path,
          data: data,
          query: query,
          ajax: ajax,
          followRedirects: followRedirects,
          retryExpiredSession: false,
        );
      }
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      throw ApiException(_networkMessage(error));
    }
  }

  String _readResponse(Response<String> response) {
    final status = response.statusCode ?? 0;
    if (_isLoginRedirect(response) ||
        (sessionStore.isLoggedIn && status == 401)) {
      throw const SessionExpiredException();
    }
    if (status < 200 || status >= 300) {
      throw HttpStatusException(status);
    }
    return response.data ?? '';
  }

  Future<Response<String>> _followRedirects(
    Response<String> response, {
    Dio? client,
    bool detectSessionExpiry = true,
  }) async {
    var current = response;
    final requestClient = client ?? _dio;
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
      if (detectSessionExpiry &&
          sessionStore.isLoggedIn &&
          _isLoginUri(nextUri)) {
        throw const SessionExpiredException();
      }
      current = await requestClient.getUri<String>(
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
    _subscriptionResolutionRequests.clear();
    await sessionStore.clear();
  }

  Future<bool> _tryRestoreWithCredentials() async {
    try {
      final credentials = await sessionStore.loadCredentials();
      if (credentials == null) {
        await sessionStore.clearCookies();
        return false;
      }
      await _login(
        email: credentials.email,
        password: credentials.password,
        rememberCredentials: true,
        preserveExistingIdentityOnFailure: true,
      );
      return true;
    } on Object {
      return false;
    }
  }

  void _requireLogin() {
    if (!sessionStore.isLoggedIn) {
      throw const ApiException('请先登录后再使用此功能。');
    }
  }

  void _syncFavoriteCache() {
    final userId = sessionStore.currentUserId;
    if (_favoriteCacheUserId == userId) {
      return;
    }
    _favoriteStatusByVideoId.clear();
    _favoriteCacheUserId = userId;
  }

  void _syncCurrentUserProfileCache(String userId) {
    if (_currentUserProfileCacheUserId == userId) {
      return;
    }
    _currentUserProfileCacheUserId = userId;
    _currentUserProfileCache = null;
    _currentUserProfileRequest = null;
    _currentUserProfileRefreshed = false;
  }

  String _memberVideosPath(String path) {
    final match = RegExp(r'/members/(\d+)/').firstMatch(path);
    return match == null ? path : '/members/${match.group(1)}/videos/';
  }

  String _videoDetailsCacheKey(String videoId) {
    return '${sessionStore.currentUserId ?? 'public'}:$videoId';
  }

  String _pathIdentifier(String path) {
    final segments = Uri(path: path).pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? path : segments.last;
  }

  static BaseOptions _baseOptions() {
    return BaseOptions(
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
    );
  }
}

final class _VideoDetailsCacheEntry {
  const _VideoDetailsCacheEntry({
    required this.details,
    required this.createdAt,
  });

  final VideoDetails details;
  final DateTime createdAt;
}
