import 'package:flutter/material.dart';

import '../core/models/video_models.dart';

enum VideoListSort {
  sourceOrder('默认顺序'),
  newest('最新'),
  title('标题'),
  rating('评分最高'),
  votes('票数最多'),
  duration('时长最长');

  const VideoListSort(this.label);

  final String label;
}

class VideoListFilters {
  const VideoListFilters({
    this.sort = VideoListSort.sourceOrder,
    this.duration = VideoDurationPreset.any,
    this.minRating = 0,
    this.minVotes = 0,
  });

  final VideoListSort sort;
  final VideoDurationPreset duration;
  final int minRating;
  final int minVotes;

  int get activeCount =>
      (sort == VideoListSort.sourceOrder ? 0 : 1) +
      (duration == VideoDurationPreset.any ? 0 : 1) +
      (minRating == 0 ? 0 : 1) +
      (minVotes == 0 ? 0 : 1);

  VideoListFilters copyWith({
    VideoListSort? sort,
    VideoDurationPreset? duration,
    int? minRating,
    int? minVotes,
  }) {
    return VideoListFilters(
      sort: sort ?? this.sort,
      duration: duration ?? this.duration,
      minRating: minRating ?? this.minRating,
      minVotes: minVotes ?? this.minVotes,
    );
  }
}

List<VideoItem> filterAndSortVideos(
  List<VideoItem> source, {
  String query = '',
  VideoListFilters filters = const VideoListFilters(),
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final sourceIndex = <String, int>{
    for (var index = 0; index < source.length; index += 1)
      source[index].id: index,
  };
  final result = source
      .where((video) {
        if (normalizedQuery.isNotEmpty &&
            !video.title.toLowerCase().contains(normalizedQuery)) {
          return false;
        }
        if (filters.minRating > 0 &&
            (video.rating == null || video.rating! < filters.minRating)) {
          return false;
        }
        if (filters.minVotes > 0 &&
            (video.ratingVotes == null ||
                video.ratingVotes! < filters.minVotes)) {
          return false;
        }
        final duration = videoDurationSeconds(video.duration);
        final minimum = filters.duration.minSeconds;
        final maximum = filters.duration.maxSeconds;
        if (minimum != null && (duration == null || duration < minimum)) {
          return false;
        }
        if (maximum != null && (duration == null || duration > maximum)) {
          return false;
        }
        return true;
      })
      .toList(growable: true);
  int sourceOrder(VideoItem left, VideoItem right) =>
      (sourceIndex[left.id] ?? 0).compareTo(sourceIndex[right.id] ?? 0);
  switch (filters.sort) {
    case VideoListSort.sourceOrder:
      break;
    case VideoListSort.newest:
      result.sort((left, right) {
        final leftAge = publishedAgeSeconds(left.publishedLabel);
        final rightAge = publishedAgeSeconds(right.publishedLabel);
        if (leftAge == null && rightAge == null) {
          return sourceOrder(left, right);
        }
        if (leftAge == null) {
          return 1;
        }
        if (rightAge == null) {
          return -1;
        }
        final compared = leftAge.compareTo(rightAge);
        return compared == 0 ? sourceOrder(left, right) : compared;
      });
    case VideoListSort.title:
      result.sort((left, right) {
        final compared = left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        );
        return compared == 0 ? sourceOrder(left, right) : compared;
      });
    case VideoListSort.rating:
      result.sort((left, right) {
        final compared = (right.rating ?? -1).compareTo(left.rating ?? -1);
        return compared == 0 ? sourceOrder(left, right) : compared;
      });
    case VideoListSort.votes:
      result.sort((left, right) {
        final compared = (right.ratingVotes ?? -1).compareTo(
          left.ratingVotes ?? -1,
        );
        return compared == 0 ? sourceOrder(left, right) : compared;
      });
    case VideoListSort.duration:
      result.sort((left, right) {
        final compared = (videoDurationSeconds(right.duration) ?? -1).compareTo(
          videoDurationSeconds(left.duration) ?? -1,
        );
        return compared == 0 ? sourceOrder(left, right) : compared;
      });
  }
  return result;
}

Future<VideoListFilters?> showVideoListFilters(
  BuildContext context, {
  required VideoListFilters initialValue,
  required String title,
  String defaultSortLabel = '默认顺序',
}) {
  var value = initialValue;
  return showModalBottomSheet<VideoListFilters>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<VideoListSort>(
              initialValue: value.sort,
              decoration: const InputDecoration(labelText: '排序'),
              items: VideoListSort.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item == VideoListSort.sourceOrder
                            ? defaultSortLabel
                            : item.label,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  setModalState(() => value = value.copyWith(sort: next));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VideoDurationPreset>(
              initialValue: value.duration,
              decoration: const InputDecoration(labelText: '时长'),
              items: VideoDurationPreset.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  setModalState(() => value = value.copyWith(duration: next));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: value.minRating,
              decoration: const InputDecoration(labelText: '最低点赞率'),
              items: const [0, 70, 80, 90, 95]
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item == 0 ? '不限' : '$item%'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  setModalState(() => value = value.copyWith(minRating: next));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: value.minVotes,
              decoration: const InputDecoration(labelText: '最低票数'),
              items: const [0, 5, 10, 25, 50, 100]
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item == 0 ? '不限' : '$item 票'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  setModalState(() => value = value.copyWith(minVotes: next));
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setModalState(() => value = const VideoListFilters()),
                  child: const Text('重置'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, value),
                  child: const Text('应用'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

int? videoDurationSeconds(String? label) {
  if (label == null) {
    return null;
  }
  final parts = label.split(':').map(int.tryParse).toList(growable: false);
  if (parts.any((part) => part == null) ||
      parts.length < 2 ||
      parts.length > 3) {
    return null;
  }
  if (parts.length == 2) {
    return parts[0]! * 60 + parts[1]!;
  }
  return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
}

int? publishedAgeSeconds(String? label, {DateTime? now}) {
  if (label == null) {
    return null;
  }
  final normalized = label.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized == 'just now' || normalized == 'today') {
    return 0;
  }
  if (normalized == 'yesterday') {
    return const Duration(days: 1).inSeconds;
  }
  final relative = RegExp(
    r'(\d+)\s*(second|minute|hour|day|week|month|year)s?\s+ago',
  ).firstMatch(normalized);
  if (relative != null) {
    final amount = int.parse(relative.group(1)!);
    final unitSeconds = switch (relative.group(2)) {
      'second' => 1,
      'minute' => 60,
      'hour' => 3600,
      'day' => 86400,
      'week' => 604800,
      'month' => 2592000,
      'year' => 31536000,
      _ => 0,
    };
    return amount * unitSeconds;
  }
  final date = DateTime.tryParse(normalized);
  if (date != null) {
    return (now ?? DateTime.now()).difference(date).inSeconds.clamp(0, 1 << 62);
  }
  return null;
}
