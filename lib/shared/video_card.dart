import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/models/video_models.dart';

class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    return ListenableBuilder(
      listenable: settingsRepository,
      builder: (context, _) {
        final blurThumbnail = settingsRepository.settings.blurThumbnails;
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.thumbnailUrl != null)
                        blurThumbnail
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: _Thumbnail(url: video.thumbnailUrl!),
                              )
                            : _Thumbnail(url: video.thumbnailUrl!)
                      else
                        const ColoredBox(
                          color: Color(0xff25252d),
                          child: Center(
                            child: Icon(Icons.movie_outlined, size: 42),
                          ),
                        ),
                      if (blurThumbnail)
                        const Positioned(
                          left: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (video.duration != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                video.duration!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (progress != null)
                  LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _MetaText(
                              text: video.publishedLabel ?? '',
                              alignment: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            child: _MetaText(
                              text: video.rating == null
                                  ? ''
                                  : video.ratingVotes == null
                                  ? '${video.rating}%'
                                  : '${video.rating}% (${formatCount(video.ratingVotes!)})',
                              alignment: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: _MetaText(
                              text: video.views == null
                                  ? ''
                                  : formatCount(video.views!),
                              alignment: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(
        color: Color(0xff25252d),
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xff25252d),
        child: Center(child: Icon(Icons.broken_image_outlined, size: 42)),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, required this.alignment});

  final String text;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String formatCount(int value) {
  if (value >= 1000000) {
    return _compact(value / 1000000, 'M');
  }
  if (value >= 1000) {
    return _compact(value / 1000, 'K');
  }
  return value.toString();
}

String _compact(double value, String suffix) {
  final digits = value >= 10 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(digits)}$suffix';
}
