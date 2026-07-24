enum FeedKind { newest, popular, topRated }

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
    this.views,
    this.rating,
  });

  final String id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? duration;
  final int? views;
  final int? rating;

  String get detailPath => '/video/$id/$slug/';

  VideoItem copyWith({
    String? title,
    String? slug,
    String? thumbnailUrl,
    String? previewUrl,
    String? duration,
    int? views,
    int? rating,
  }) {
    return VideoItem(
      id: id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      duration: duration ?? this.duration,
      views: views ?? this.views,
      rating: rating ?? this.rating,
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
  });

  final VideoItem video;
  final String? description;
  final List<String> categories;
  final List<String> tags;
  final List<String> models;
  final List<VideoSource> sources;
  final bool isFavorite;
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
}
