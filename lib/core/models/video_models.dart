enum FeedKind { newest, popular, topRated }

enum VideoSort {
  relevance('相关度', null),
  newest('最新', 'post_date'),
  mostViewed('最多观看', 'video_viewed'),
  topRated('最高评分', 'rating'),
  longest('最长', 'duration'),
  random('随机', 'pseudo_rand');

  const VideoSort(this.label, this.parameter);

  final String label;
  final String? parameter;
}

enum SearchResultScope {
  overview('综合'),
  videos('视频'),
  tags('标签'),
  models('艺术家'),
  categories('分类');

  const SearchResultScope(this.label);

  final String label;
}

enum SearchSuggestionKind {
  tag('标签', DiscoveryKind.tag),
  category('分类', DiscoveryKind.category),
  model('艺术家', DiscoveryKind.model);

  const SearchSuggestionKind(this.label, this.discoveryKind);

  final String label;
  final DiscoveryKind discoveryKind;
}

enum ContentOrientation {
  all('全部', null),
  straight('异性', '2109'),
  gay('同性', '192'),
  futa('扶她', '15'),
  music('音乐', '4747'),
  iwara('Iwara', '1821');

  const ContentOrientation(this.label, this.parameter);

  final String label;
  final String? parameter;
}

enum UploadPeriod {
  anytime('不限时间', null),
  past24Hours('过去 24 小时', Duration(days: 1)),
  past2Days('过去 2 天', Duration(days: 2)),
  pastWeek('过去 1 周', Duration(days: 7)),
  pastMonth('过去 1 月', Duration(days: 30)),
  past3Months('过去 3 月', Duration(days: 90)),
  pastYear('过去 1 年', Duration(days: 365));

  const UploadPeriod(this.label, this.duration);

  final String label;
  final Duration? duration;
}

enum VideoDurationPreset {
  any('不限时长', null, null),
  short('5 分钟以内', 0, 300),
  medium('5–20 分钟', 300, 1200),
  long('20–60 分钟', 1200, 3600),
  extraLong('60 分钟以上', 3600, 36000);

  const VideoDurationPreset(this.label, this.minSeconds, this.maxSeconds);

  final String label;
  final int? minSeconds;
  final int? maxSeconds;
}

enum DiscoveryKind {
  tag('标签', 'tags'),
  category('分类', 'categories'),
  model('艺术家', 'models'),
  channel('频道', 'channels');

  const DiscoveryKind(this.label, this.pathSegment);

  final String label;
  final String pathSegment;
}

class ContentCollectionItem {
  const ContentCollectionItem({
    required this.id,
    required this.title,
    required this.path,
    required this.kind,
    this.filterId,
    this.thumbnailUrl,
    this.total,
  });

  final String id;
  final String title;
  final String path;
  final DiscoveryKind kind;
  final String? filterId;
  final String? thumbnailUrl;
  final int? total;

  String get effectiveFilterId => filterId ?? id;

  ContentCollectionItem copyWith({
    String? id,
    String? title,
    String? path,
    DiscoveryKind? kind,
    String? filterId,
    String? thumbnailUrl,
    int? total,
  }) {
    return ContentCollectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      kind: kind ?? this.kind,
      filterId: filterId ?? this.filterId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      total: total ?? this.total,
    );
  }
}

class DiscoveryDirectorySpec {
  const DiscoveryDirectorySpec({
    required this.title,
    required this.path,
    required this.kind,
  });

  final String title;
  final String path;
  final DiscoveryKind kind;
}

class SearchSuggestion {
  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.total,
    required this.kind,
  });

  final String id;
  final String title;
  final int total;
  final SearchSuggestionKind kind;

  ContentCollectionItem get collection => ContentCollectionItem(
    id: id,
    title: title,
    path: '/${kind.discoveryKind.pathSegment}/$id/',
    kind: kind.discoveryKind,
    filterId: id,
    total: total,
  );
}

class SearchFilters {
  const SearchFilters({
    this.sort = VideoSort.relevance,
    this.orientation = ContentOrientation.all,
    this.uploadPeriod = UploadPeriod.anytime,
    this.duration = VideoDurationPreset.any,
    this.verifiedOnly = false,
    this.tags = const [],
    this.categories = const [],
    this.models = const [],
    this.excludedTags = const [],
    this.excludedCategories = const [],
    this.excludedModels = const [],
    this.minRating,
    this.minRatingVotes,
  });

  static const Object _unset = Object();

  final VideoSort sort;
  final ContentOrientation orientation;
  final UploadPeriod uploadPeriod;
  final VideoDurationPreset duration;
  final bool verifiedOnly;
  final List<SearchSuggestion> tags;
  final List<SearchSuggestion> categories;
  final List<SearchSuggestion> models;
  final List<SearchSuggestion> excludedTags;
  final List<SearchSuggestion> excludedCategories;
  final List<SearchSuggestion> excludedModels;
  final int? minRating;
  final int? minRatingVotes;

  bool get isEmpty =>
      sort == VideoSort.relevance &&
      orientation == ContentOrientation.all &&
      uploadPeriod == UploadPeriod.anytime &&
      duration == VideoDurationPreset.any &&
      !verifiedOnly &&
      tags.isEmpty &&
      categories.isEmpty &&
      models.isEmpty &&
      excludedTags.isEmpty &&
      excludedCategories.isEmpty &&
      excludedModels.isEmpty &&
      minRating == null &&
      minRatingVotes == null;

  bool get hasServerFilters =>
      sort != VideoSort.relevance ||
      orientation != ContentOrientation.all ||
      uploadPeriod != UploadPeriod.anytime ||
      duration != VideoDurationPreset.any ||
      verifiedOnly ||
      tags.isNotEmpty ||
      categories.isNotEmpty ||
      models.isNotEmpty ||
      excludedTags.isNotEmpty ||
      excludedCategories.isNotEmpty ||
      excludedModels.isNotEmpty;

  bool get hasQualityFilters => minRating != null || minRatingVotes != null;

  int get activeCount {
    var count = 0;
    if (sort != VideoSort.relevance) count += 1;
    if (orientation != ContentOrientation.all) count += 1;
    if (uploadPeriod != UploadPeriod.anytime) count += 1;
    if (duration != VideoDurationPreset.any) count += 1;
    if (verifiedOnly) count += 1;
    count += tags.length + categories.length + models.length;
    count +=
        excludedTags.length + excludedCategories.length + excludedModels.length;
    if (minRating != null) count += 1;
    if (minRatingVotes != null) count += 1;
    return count;
  }

  bool matchesQuality(VideoItem video) {
    final ratingThreshold = minRating;
    if (ratingThreshold != null &&
        (video.rating == null || video.rating! < ratingThreshold)) {
      return false;
    }
    final votesThreshold = minRatingVotes;
    if (votesThreshold != null &&
        (video.ratingVotes == null || video.ratingVotes! < votesThreshold)) {
      return false;
    }
    return true;
  }

  SearchFilters copyWith({
    VideoSort? sort,
    ContentOrientation? orientation,
    UploadPeriod? uploadPeriod,
    VideoDurationPreset? duration,
    bool? verifiedOnly,
    List<SearchSuggestion>? tags,
    List<SearchSuggestion>? categories,
    List<SearchSuggestion>? models,
    List<SearchSuggestion>? excludedTags,
    List<SearchSuggestion>? excludedCategories,
    List<SearchSuggestion>? excludedModels,
    Object? minRating = _unset,
    Object? minRatingVotes = _unset,
  }) {
    return SearchFilters(
      sort: sort ?? this.sort,
      orientation: orientation ?? this.orientation,
      uploadPeriod: uploadPeriod ?? this.uploadPeriod,
      duration: duration ?? this.duration,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      tags: tags ?? this.tags,
      categories: categories ?? this.categories,
      models: models ?? this.models,
      excludedTags: excludedTags ?? this.excludedTags,
      excludedCategories: excludedCategories ?? this.excludedCategories,
      excludedModels: excludedModels ?? this.excludedModels,
      minRating: identical(minRating, _unset)
          ? this.minRating
          : minRating as int?,
      minRatingVotes: identical(minRatingVotes, _unset)
          ? this.minRatingVotes
          : minRatingVotes as int?,
    );
  }
}

extension FeedKindPath on FeedKind {
  String pagePath(int page) {
    final suffix = page > 1 ? '$page/' : '';
    return switch (this) {
      FeedKind.newest => '/latest-updates/$suffix',
      FeedKind.popular => '/most-popular/$suffix',
      FeedKind.topRated => '/top-rated/$suffix',
    };
  }

  String get label => switch (this) {
    FeedKind.newest => '最新',
    FeedKind.popular => '热门',
    FeedKind.topRated => '高评分',
  };
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    this.previewUrl,
    this.duration,
    this.publishedLabel,
    this.views,
    this.rating,
    this.ratingVotes,
    this.isFavorite,
  });

  static const Object _unset = Object();

  final String id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? duration;
  final String? publishedLabel;
  final int? views;
  final int? rating;
  final int? ratingVotes;
  final bool? isFavorite;

  String get detailPath => '/video/$id/$slug/';

  String? get highResolutionThumbnailUrl {
    final value = thumbnailUrl;
    if (value == null) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }
    final upgradedPath = uri.path.replaceFirst(
      RegExp(r'/\d+x\d+/\d+\.[^/]+$'),
      '/preview.jpg',
    );
    if (upgradedPath == uri.path) {
      return value;
    }
    return uri.replace(path: upgradedPath).toString();
  }

  VideoItem copyWith({
    String? title,
    String? slug,
    String? thumbnailUrl,
    Object? previewUrl = _unset,
    String? duration,
    String? publishedLabel,
    int? views,
    int? rating,
    int? ratingVotes,
    Object? isFavorite = _unset,
  }) {
    return VideoItem(
      id: id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewUrl: identical(previewUrl, _unset)
          ? this.previewUrl
          : previewUrl as String?,
      duration: duration ?? this.duration,
      publishedLabel: publishedLabel ?? this.publishedLabel,
      views: views ?? this.views,
      rating: rating ?? this.rating,
      ratingVotes: ratingVotes ?? this.ratingVotes,
      isFavorite: identical(isFavorite, _unset)
          ? this.isFavorite
          : isFavorite as bool?,
    );
  }
}

class VideoSource {
  const VideoSource({
    required this.label,
    required this.url,
    required this.isHd,
  });

  final String label;
  final String url;
  final bool isHd;
}

class VideoDetails {
  const VideoDetails({
    required this.video,
    required this.sources,
    required this.categories,
    required this.tags,
    required this.models,
    required this.isFavorite,
    this.description,
    this.metadataItems = const [],
    this.relatedVideos = const [],
    this.ratingVotes,
    this.uploader,
    this.playlistIds = const {},
  });

  final VideoItem video;
  final String? description;
  final List<String> categories;
  final List<String> tags;
  final List<String> models;
  final List<VideoSource> sources;
  final bool isFavorite;
  final List<VideoMetadataItem> metadataItems;
  final List<VideoItem> relatedVideos;
  final int? ratingVotes;
  final UploaderSummary? uploader;
  final Set<String> playlistIds;

  VideoDetails copyWith({
    VideoItem? video,
    List<VideoSource>? sources,
    bool? isFavorite,
    Set<String>? playlistIds,
  }) {
    return VideoDetails(
      video: video ?? this.video,
      sources: sources ?? this.sources,
      categories: categories,
      tags: tags,
      models: models,
      isFavorite: isFavorite ?? this.isFavorite,
      description: description,
      metadataItems: metadataItems,
      relatedVideos: relatedVideos,
      ratingVotes: ratingVotes,
      uploader: uploader,
      playlistIds: playlistIds ?? this.playlistIds,
    );
  }
}

class UploaderSummary {
  const UploaderSummary({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool verified;

  String get profilePath => '/members/$id/';
  String get videosPath => '/members/$id/videos/';
}

class VideoMetadataItem {
  const VideoMetadataItem({
    required this.id,
    required this.title,
    required this.path,
    required this.kind,
    this.thumbnailUrl,
    this.upScore = 0,
    this.downScore = 0,
  });

  final String id;
  final String title;
  final String path;
  final DiscoveryKind kind;
  final String? thumbnailUrl;
  final int upScore;
  final int downScore;

  bool get canSubscribe =>
      kind == DiscoveryKind.category || kind == DiscoveryKind.model;

  ContentCollectionItem get collection => ContentCollectionItem(
    id: id,
    title: title,
    path: path,
    kind: kind,
    thumbnailUrl: thumbnailUrl,
  );
}

class TagSuggestion {
  const TagSuggestion({
    required this.id,
    required this.title,
    required this.total,
  });

  final String id;
  final String title;
  final int total;
}

class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.title,
    required this.path,
    this.thumbnailUrl,
    this.videoCount,
    this.views,
  });

  final String id;
  final String title;
  final String path;
  final String? thumbnailUrl;
  final int? videoCount;
  final int? views;
}

class PlaylistFormData {
  const PlaylistFormData({
    required this.title,
    this.description = '',
    this.isPrivate = false,
  });

  final String title;
  final String description;
  final bool isPrivate;
}

enum SubscriptionKind {
  category('分类'),
  model('艺术家'),
  member('用户'),
  playlist('播放列表'),
  channel('频道');

  const SubscriptionKind(this.label);

  final String label;
}

class SubscriptionItem {
  const SubscriptionItem({
    required this.title,
    required this.path,
    required this.kind,
    this.thumbnailUrl,
  });

  final String title;
  final String path;
  final SubscriptionKind kind;
  final String? thumbnailUrl;

  SubscriptionItem copyWith({String? thumbnailUrl}) {
    return SubscriptionItem(
      title: title,
      path: path,
      kind: kind,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
