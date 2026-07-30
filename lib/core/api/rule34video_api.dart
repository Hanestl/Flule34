import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/account_models.dart';
import '../models/video_models.dart';
import '../security/error_redaction.dart';
import '../session/session_store.dart';
import '../services/subscription_activity_index.dart';
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

final class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('后台预加载已让位于当前操作。');
}

class Rule34VideoApi {
  static const _videoDetailsCacheTtl = Duration(minutes: 5);
  static const _videoPageCacheTtl = Duration(minutes: 5);

  Rule34VideoApi({
    required this.sessionStore,
    HttpClientAdapter? httpClientAdapter,
    SubscriptionActivityStore? subscriptionActivityStore,
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
    subscriptionActivity = SubscriptionActivityIndex(
      sessionStore: sessionStore,
      loadSubscriptions: _loadSubscriptions,
      loadSubscriptionVideos: _loadSubscriptionVideosForActivity,
      store: subscriptionActivityStore ?? MemorySubscriptionActivityStore(),
    );
    sessionStore.addListener(subscriptionActivity.onSessionChanged);
  }

  final SessionStore sessionStore;
  late final SubscriptionActivityIndex subscriptionActivity;
  late final Dio _dio;
  late final Dio _publicDio;
  List<SubscriptionItem>? _subscriptionCache;
  String? _subscriptionCacheUserId;
  final Map<int, List<SubscriptionItem>> _subscriptionPageCache = {};
  final Map<String, Future<SubscriptionItem>> _subscriptionResolutionRequests =
      {};
  final Map<String, String> _entityAvatarByPath = {};
  List<PlaylistItem>? _playlistCache;
  String? _playlistCacheUserId;
  final Map<String, _VideoDetailsCacheEntry> _videoDetailsCache = {};
  final Map<String, Future<VideoDetails>> _videoDetailsRequests = {};
  final Map<String, _VideoPageCacheEntry> _videoPageCache = {};
  final Map<String, Future<List<VideoItem>>> _videoPageRequests = {};
  final Map<String, bool> _favoriteStatusByVideoId = {};
  String? _favoriteCacheUserId;
  MemberProfile? _currentUserProfileCache;
  String? _currentUserProfileCacheUserId;
  Future<MemberProfile>? _currentUserProfileRequest;
  bool _currentUserProfileRefreshed = false;
  Future<List<PlaylistItem>>? _playlistRequest;
  Future<List<SubscriptionItem>>? _subscriptionRequest;
  var _subscriptionGeneration = 0;

  void close() {
    sessionStore.removeListener(subscriptionActivity.onSessionChanged);
    subscriptionActivity.dispose();
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

  Future<List<VideoItem>> loadFollowingFeed(
    int page, {
    bool force = false,
    CancelToken? cancelToken,
  }) {
    _requireLogin();
    return subscriptionActivity.loadFollowingPage(
      page,
      force: force,
      cancelToken: cancelToken,
    );
  }

  Future<void> prefetchFollowingFeed({required CancelToken cancelToken}) async {
    await subscriptionActivity.refresh(cancelToken: cancelToken);
  }

  Future<Map<String, int?>> loadSubscriptionUpdatedAges({
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    await subscriptionActivity.refresh(
      force: force,
      refreshSubscriptions: false,
      cancelToken: cancelToken,
    );
    return subscriptionActivity.updatedAgeByPath;
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

  Future<List<VideoItem>> searchVideosForPreview(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return Future.value(const <VideoItem>[]);
    }
    return _paginatedVideoList(
      '/search/',
      page: 1,
      query: <String, String>{'q': normalizedQuery},
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
    return _loadVideoDetails(video);
  }

  Future<void> prefetchVideoDetails(
    VideoItem video, {
    required CancelToken cancelToken,
  }) async {
    await _loadVideoDetails(video, cancelToken: cancelToken);
  }

  Future<VideoDetails> _loadVideoDetails(
    VideoItem video, {
    CancelToken? cancelToken,
  }) {
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
    request = _fetchVideoDetails(video, cancelToken: cancelToken)
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

  Future<VideoDetails> _fetchVideoDetails(
    VideoItem video, {
    CancelToken? cancelToken,
  }) async {
    String body;
    var usedPublicRequest = false;
    try {
      body = await _get(video.detailPath, cancelToken: cancelToken);
    } on SessionExpiredException {
      body = await _getPublic(video.detailPath, cancelToken: cancelToken);
      usedPublicRequest = true;
    } on HttpStatusException catch (error) {
      if (error.statusCode != 403) {
        rethrow;
      }
      body = await _getPublic(video.detailPath, cancelToken: cancelToken);
      usedPublicRequest = true;
    }
    var details = SiteParser.videoDetails(source: body, fallback: video);
    if (details.sources.isEmpty && !usedPublicRequest) {
      final publicBody = await _getPublic(
        video.detailPath,
        cancelToken: cancelToken,
      );
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
    for (final item in details.metadataItems) {
      final avatarUrl = item.thumbnailUrl;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        _entityAvatarByPath[item.path] = avatarUrl;
      }
    }
    final uploader = details.uploader;
    if (uploader?.avatarUrl?.isNotEmpty == true) {
      _entityAvatarByPath[uploader!.profilePath] = uploader.avatarUrl!;
    }
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

  bool? cachedFavoriteStatus(String videoId) {
    if (!sessionStore.isLoggedIn) {
      return null;
    }
    _syncFavoriteCache();
    return _favoriteStatusByVideoId[videoId];
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
      if (sessionStore.currentUserId == userId &&
          (force || identical(_currentUserProfileRequest, request))) {
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
      _resetSubscriptionCache();
      _clearPlaylistCache();
      _videoPageCache.clear();
      _videoPageRequests.clear();
      _videoDetailsCache.clear();
      _videoDetailsRequests.clear();
      await sessionStore.clear(forgetCredentials: true);
    }
  }

  Future<List<VideoItem>> loadFavorites(int page, {bool force = false}) {
    return _loadFavoritesPage(page, force: force);
  }

  Future<void> prefetchFavorites({required CancelToken cancelToken}) async {
    await _loadFavoritesPage(1, cancelToken: cancelToken);
  }

  Future<List<VideoItem>> _loadFavoritesPage(
    int page, {
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final path = page > 1
        ? '/my/favourites/videos/$page/'
        : '/my/favourites/videos/';
    final items = await _cachedVideoPage(
      key: _videoPageCacheKey('favorites', page),
      force: force,
      loader: () =>
          _paginatedVideoList(path, page: page, cancelToken: cancelToken),
    );
    _syncFavoriteCache();
    for (final item in items) {
      _favoriteStatusByVideoId[item.id] = true;
    }
    return items
        .map((item) => item.copyWith(isFavorite: true))
        .toList(growable: false);
  }

  Future<List<VideoItem>> loadHistory(int page, {bool force = false}) {
    return _loadHistoryPage(page, force: force);
  }

  Future<void> prefetchHistory({required CancelToken cancelToken}) async {
    await _loadHistoryPage(1, cancelToken: cancelToken);
  }

  void invalidateHistoryCache() {
    _clearVideoPageCache('history');
  }

  Future<List<VideoItem>> _loadHistoryPage(
    int page, {
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final path = page > 1 ? '/my/history/$page/' : '/my/history/';
    return _cachedVideoPage(
      key: _videoPageCacheKey('history', page),
      force: force,
      loader: () =>
          _paginatedVideoList(path, page: page, cancelToken: cancelToken),
    );
  }

  Future<List<PlaylistItem>> loadMyPlaylists({bool force = false}) async {
    return _loadMyPlaylists(force: force);
  }

  Future<void> prefetchPlaylists({required CancelToken cancelToken}) async {
    await _loadMyPlaylists(cancelToken: cancelToken);
  }

  Future<List<PlaylistItem>> _loadMyPlaylists({
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    if (!force && _playlistCache != null && _playlistCacheUserId == userId) {
      return _playlistCache!;
    }
    if (!force && _playlistRequest != null) {
      return _playlistRequest!;
    }
    late final Future<List<PlaylistItem>> request;
    request =
        () async {
          final result = <String, PlaylistItem>{};
          for (var page = 1; page <= 50; page += 1) {
            _throwIfCancelled(cancelToken);
            final items = await _loadMyPlaylistsPage(
              page,
              cancelToken: cancelToken,
            );
            if (items.isEmpty) {
              break;
            }
            final before = result.length;
            for (final item in items) {
              result[item.id] = item;
            }
            if (result.length == before) {
              break;
            }
          }
          final value = result.values.toList(growable: false);
          if (sessionStore.currentUserId == userId &&
              identical(_playlistRequest, request)) {
            _playlistCache = value;
            _playlistCacheUserId = userId;
          }
          return value;
        }().whenComplete(() {
          if (identical(_playlistRequest, request)) {
            _playlistRequest = null;
          }
        });
    _playlistRequest = request;
    return request;
  }

  Future<List<PlaylistItem>> loadMyPlaylistsPage(int page) async {
    return _loadMyPlaylistsPage(page);
  }

  Future<List<PlaylistItem>> _loadMyPlaylistsPage(
    int page, {
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final path = page > 1 ? '/my/playlists/$page/' : '/my/playlists/';
    try {
      return SiteParser.playlists(await _get(path, cancelToken: cancelToken));
    } on HttpStatusException catch (error) {
      if (page > 1 && error.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<List<VideoItem>> loadPlaylistVideos(
    PlaylistItem playlist,
    int page,
  ) async {
    _requireLogin();
    final path = page > 1 ? '${playlist.path}$page/' : playlist.path;
    return _paginatedVideoList(path, page: page);
  }

  Future<PlaylistFormData> loadPlaylistForm(String playlistId) async {
    _requireLogin();
    try {
      return SiteParser.playlistForm(await _get('/edit-playlist/$playlistId/'));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  Future<void> createPlaylist(PlaylistFormData form) async {
    _requireLogin();
    await _post(
      '/create-playlist/',
      data: _playlistFields(form, action: 'add_new_complete'),
      followRedirects: true,
    );
    _clearPlaylistCache();
  }

  Future<void> updatePlaylist({
    required String playlistId,
    required PlaylistFormData form,
  }) async {
    _requireLogin();
    await _post(
      '/edit-playlist/$playlistId/',
      data: _playlistFields(form, action: 'change_complete'),
      followRedirects: true,
    );
    _clearPlaylistCache();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _requireLogin();
    final body = await _get(
      '/my/playlists/',
      query: <String, String>{
        'mode': 'async',
        'format': 'json',
        'action': 'delete_playlists',
        'delete[]': playlistId,
      },
    );
    try {
      final response = jsonDecode(body);
      if (response is! Map || response['status'] != 'success') {
        throw const ApiException('删除播放列表失败。');
      }
    } on FormatException {
      throw const ApiException('删除播放列表时服务器返回了无效响应。');
    }
    _clearPlaylistCache();
  }

  Future<List<SubscriptionItem>> loadSubscriptions({bool force = false}) async {
    final subscriptions = await _loadSubscriptions(force: force);
    if (force) {
      subscriptionActivity.invalidate();
    }
    return subscriptions;
  }

  Future<void> prefetchSubscriptions({required CancelToken cancelToken}) async {
    await _loadSubscriptions(cancelToken: cancelToken);
  }

  Future<List<SubscriptionItem>> _loadSubscriptions({
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    final previousHadItems =
        _subscriptionCacheUserId == userId &&
        _subscriptionCache?.isNotEmpty == true;
    if (!force &&
        _subscriptionCache != null &&
        _subscriptionCacheUserId == userId) {
      return _subscriptionCache!;
    }
    if (force || _subscriptionCacheUserId != userId) {
      _resetSubscriptionCache();
      _subscriptionCacheUserId = userId;
    }
    if (!force && _subscriptionRequest != null) {
      return _subscriptionRequest!;
    }
    final generation = _subscriptionGeneration;
    late final Future<List<SubscriptionItem>> request;
    request =
        () async {
          Future<List<SubscriptionItem>> fetchAll() async {
            final result = <String, SubscriptionItem>{};
            for (var page = 1; page <= 50; page += 1) {
              _throwIfCancelled(cancelToken);
              final items = await _loadSubscriptionsPage(
                page,
                cancelToken: cancelToken,
                generation: generation,
              );
              if (items.isEmpty) {
                break;
              }
              for (final item in items) {
                result[item.path] = item;
              }
            }
            return result.values.toList(growable: false);
          }

          var value = await fetchAll();
          if (force &&
              previousHadItems &&
              value.isEmpty &&
              generation == _subscriptionGeneration) {
            // 网站偶尔会在异步区块刷新时返回一次空响应。已有订阅突然全部
            // 消失时复核一次，避免瞬时空页覆盖可靠缓存。
            _subscriptionPageCache.clear();
            value = await fetchAll();
          }
          if (sessionStore.currentUserId == userId &&
              generation == _subscriptionGeneration &&
              identical(_subscriptionRequest, request)) {
            _subscriptionCache = value;
            _subscriptionCacheUserId = userId;
          }
          return value;
        }().whenComplete(() {
          if (identical(_subscriptionRequest, request)) {
            _subscriptionRequest = null;
          }
        });
    _subscriptionRequest = request;
    return request;
  }

  Future<List<SubscriptionItem>> loadSubscriptionsPage(
    int page, {
    bool force = false,
  }) async {
    return _loadSubscriptionsPage(page, force: force);
  }

  Future<List<SubscriptionItem>> _loadSubscriptionsPage(
    int page, {
    bool force = false,
    CancelToken? cancelToken,
    int? generation,
  }) async {
    _requireLogin();
    final userId = sessionStore.currentUserId!;
    if (_subscriptionCacheUserId != userId) {
      _resetSubscriptionCache();
      _subscriptionCacheUserId = userId;
    }
    final effectiveGeneration = generation ?? _subscriptionGeneration;
    if (effectiveGeneration != _subscriptionGeneration) {
      throw const RequestCancelledException();
    }
    if (force) {
      if (page == 1) {
        _subscriptionPageCache.clear();
        _subscriptionResolutionRequests.clear();
      } else {
        _subscriptionPageCache.remove(page);
      }
      _subscriptionCache = null;
    }
    final cached = _subscriptionPageCache[page];
    if (cached != null) {
      return cached;
    }
    // 网站的订阅列表并不是普通的 /2/ 路径分页；第二页起必须请求
    // KVS 异步区块，否则会拿到空页面并错误地认为已经到底。
    final path = '/my/subscriptions/';
    final query = page > 1
        ? <String, String>{
            'mode': 'async',
            'function': 'get_block',
            'block_id': 'list_members_subscriptions_my_subscriptions',
            'sort_by': 'added_date',
            'from_my_subscriptions': '$page',
          }
        : null;
    try {
      final result = SiteParser.subscriptions(
        await _get(path, query: query, cancelToken: cancelToken),
      );
      if (effectiveGeneration == _subscriptionGeneration &&
          sessionStore.currentUserId == userId) {
        _subscriptionPageCache[page] = result;
      }
      return result;
    } on HttpStatusException catch (error) {
      if (page > 1 && error.statusCode == 404) {
        if (effectiveGeneration == _subscriptionGeneration &&
            sessionStore.currentUserId == userId) {
          _subscriptionPageCache[page] = const [];
        }
        return const [];
      }
      rethrow;
    }
  }

  Future<SubscriptionItem> resolveSubscription(SubscriptionItem subscription) {
    if (subscription.thumbnailUrl?.isNotEmpty == true) {
      return Future.value(subscription);
    }
    final knownAvatar = _entityAvatarByPath[subscription.path];
    if (knownAvatar != null && knownAvatar.isNotEmpty) {
      return Future.value(subscription.copyWith(thumbnailUrl: knownAvatar));
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
        SubscriptionKind.model => SiteParser.collectionAvatar(
          await _get(subscription.path),
        ),
        SubscriptionKind.member => await _memberSubscriptionAvatar(
          subscription.path,
        ),
        _ => null,
      };
      if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
        return subscription;
      }
      _entityAvatarByPath[subscription.path] = thumbnailUrl;
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
    int page, {
    CancelToken? cancelToken,
  }) {
    return _loadSubscriptionVideosForActivity(
      subscription,
      page,
      cancelToken: cancelToken,
    );
  }

  Future<List<VideoItem>> _loadSubscriptionVideosForActivity(
    SubscriptionItem subscription,
    int page, {
    CancelToken? cancelToken,
  }) async {
    _requireLogin();
    final basePath = subscription.kind == SubscriptionKind.member
        ? _memberVideosPath(subscription.path)
        : subscription.path;
    final path = page > 1 ? '$basePath$page/' : basePath;
    return _paginatedVideoList(path, page: page, cancelToken: cancelToken);
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
    _clearVideoPageCache('favorites');
    _videoDetailsCache.removeWhere((key, _) => key.endsWith(':${video.id}'));
  }

  Future<void> addVideoToPlaylist({
    required VideoItem video,
    required String playlistId,
  }) {
    return toggleVideoInPlaylist(
      video: video,
      playlistId: playlistId,
      add: true,
    );
  }

  Future<void> removeVideoFromPlaylist({
    required VideoItem video,
    required String playlistId,
  }) {
    return toggleVideoInPlaylist(
      video: video,
      playlistId: playlistId,
      add: false,
    );
  }

  Future<Set<String>> playlistIdsForVideo(VideoItem video) async {
    _requireLogin();
    return (await loadVideoDetails(video)).playlistIds;
  }

  Future<void> toggleVideoInPlaylist({
    required VideoItem video,
    required String playlistId,
    required bool add,
  }) async {
    _requireLogin();
    await _post(
      video.detailPath,
      query: const <String, String>{'mode': 'async'},
      data: <String, String>{
        'action': add ? 'add_to_favourites' : 'delete_from_favourites',
        'video_id': video.id,
        'fav_type': '10',
        'playlist_id': playlistId,
      },
      ajax: true,
    );
    _clearPlaylistCache();
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
    _resetSubscriptionCache();
    subscriptionActivity.invalidate();
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

  bool canUnsubscribeSubscription(SubscriptionItem subscription) {
    return switch (subscription.kind) {
      SubscriptionKind.category ||
      SubscriptionKind.model ||
      SubscriptionKind.member => true,
      SubscriptionKind.playlist || SubscriptionKind.channel => false,
    };
  }

  Future<void> unsubscribeSubscription(SubscriptionItem subscription) async {
    _requireLogin();
    switch (subscription.kind) {
      case SubscriptionKind.member:
        final match = RegExp(r'/members/(\d+)/').firstMatch(subscription.path);
        final id = match?.group(1);
        if (id == null) {
          throw const ApiException('无法识别这个上传者的订阅信息。');
        }
        await toggleUploaderSubscription(
          uploader: UploaderSummary(id: id, name: subscription.title),
          subscribe: false,
        );
        return;
      case SubscriptionKind.category:
      case SubscriptionKind.model:
        final videos = await loadSubscriptionVideos(subscription, 1);
        for (final video in videos.take(3)) {
          final details = await loadVideoDetails(video);
          final metadata = details.metadataItems
              .cast<VideoMetadataItem?>()
              .firstWhere(
                (item) =>
                    item?.path == subscription.path &&
                    item?.kind == subscription.kind.discoveryKind,
                orElse: () => null,
              );
          if (metadata == null) {
            continue;
          }
          await toggleSubscription(
            video: video,
            item: metadata,
            subscribe: false,
          );
          return;
        }
        throw const ApiException('无法识别这个订阅，请从相关视频详情页取消。');
      case SubscriptionKind.playlist:
      case SubscriptionKind.channel:
        throw const ApiException('此类型暂不支持在 App 内取消订阅。');
    }
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
    _resetSubscriptionCache();
    subscriptionActivity.invalidate();
  }

  Future<List<VideoItem>> _videoList(
    String path, {
    Map<String, String>? query,
    CancelToken? cancelToken,
  }) async {
    final body = await _get(path, query: query, cancelToken: cancelToken);
    return SiteParser.videoList(body);
  }

  Future<List<VideoItem>> _paginatedVideoList(
    String path, {
    required int page,
    Map<String, String>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _videoList(path, query: query, cancelToken: cancelToken);
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
    CancelToken? cancelToken,
  }) async {
    try {
      _throwIfCancelled(cancelToken);
      final response = await _dio.get<String>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      return _readResponse(
        await _followRedirects(response, cancelToken: cancelToken),
      );
    } on SessionExpiredException {
      if (retryExpiredSession && await _tryRestoreWithCredentials()) {
        return _get(
          path,
          query: query,
          retryExpiredSession: false,
          cancelToken: cancelToken,
        );
      }
      await _clearExpiredSession();
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      throw ApiException(_networkMessage(error));
    }
  }

  Future<String> _getPublic(
    String path, {
    Map<String, String>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      _throwIfCancelled(cancelToken);
      final response = await _publicDio.get<String>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final resolved = await _followRedirects(
        response,
        client: _publicDio,
        detectSessionExpiry: false,
        cancelToken: cancelToken,
      );
      final status = resolved.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw HttpStatusException(status);
      }
      return resolved.data ?? '';
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      throw ApiException(_networkMessage(error));
    }
  }

  Future<List<VideoItem>> _cachedVideoPage({
    required String key,
    required bool force,
    required Future<List<VideoItem>> Function() loader,
  }) {
    if (force) {
      _videoPageCache.remove(key);
      _videoPageRequests.remove(key);
    } else {
      final cached = _videoPageCache[key];
      if (cached != null &&
          DateTime.now().difference(cached.createdAt) < _videoPageCacheTtl) {
        return Future.value(cached.items);
      }
      final pending = _videoPageRequests[key];
      if (pending != null) {
        return pending;
      }
    }
    late final Future<List<VideoItem>> request;
    request = loader()
        .then((items) {
          if (identical(_videoPageRequests[key], request)) {
            _videoPageCache[key] = _VideoPageCacheEntry(
              items: items,
              createdAt: DateTime.now(),
            );
          }
          return items;
        })
        .whenComplete(() {
          if (identical(_videoPageRequests[key], request)) {
            _videoPageRequests.remove(key);
          }
        });
    _videoPageRequests[key] = request;
    return request;
  }

  String _videoPageCacheKey(String scope, int page) {
    return '${sessionStore.currentUserId ?? 'public'}:$scope:$page';
  }

  void _clearVideoPageCache(String scope) {
    final marker = ':$scope:';
    _videoPageCache.removeWhere((key, _) => key.contains(marker));
    _videoPageRequests.removeWhere((key, _) => key.contains(marker));
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw const RequestCancelledException();
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

  Map<String, String> _playlistFields(
    PlaylistFormData form, {
    required String action,
  }) {
    return <String, String>{
      'title': form.title.trim(),
      'description': form.description.trim(),
      'is_private': form.isPrivate ? '1' : '0',
      'action': action,
    };
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
    CancelToken? cancelToken,
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
        cancelToken: cancelToken,
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
    _resetSubscriptionCache();
    _clearPlaylistCache();
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

  void _resetSubscriptionCache() {
    _subscriptionGeneration += 1;
    _subscriptionCache = null;
    _subscriptionCacheUserId = null;
    _subscriptionPageCache.clear();
    _subscriptionResolutionRequests.clear();
    _subscriptionRequest = null;
  }

  void _clearPlaylistCache() {
    _playlistCache = null;
    _playlistCacheUserId = null;
    _playlistRequest = null;
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

  static BaseOptions _baseOptions() {
    return BaseOptions(
      baseUrl: 'https://rule34video.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
      followRedirects: false,
      headers: const {
        'User-Agent': 'Flule34 Android/1.4.4',
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

final class _VideoPageCacheEntry {
  const _VideoPageCacheEntry({required this.items, required this.createdAt});

  final List<VideoItem> items;
  final DateTime createdAt;
}
