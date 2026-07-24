import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/database/app_database.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart';
import '../playback/data/playback_repository.dart';

class ContinueWatchingList extends StatelessWidget {
  const ContinueWatchingList({super.key, required this.repository});

  final PlaybackRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlaybackPosition>>(
      stream: repository.watchContinueWatching(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.requireData;
        if (records.isEmpty) {
          return const Center(child: Text('还没有可继续观看的视频。'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final video = VideoItem(
              id: record.videoId,
              title: record.title!,
              slug: record.slug!,
              thumbnailUrl: record.thumbnailUrl,
              duration: record.durationLabel,
            );
            final duration = record.durationMs ?? 0;
            final progress = duration > 0 ? record.positionMs / duration : null;
            return VideoCard(
              video: video,
              progress: progress,
              onTap: () => context.pushNamed(
                AppRouteNames.video,
                pathParameters: {'id': video.id, 'slug': video.slug},
                extra: video,
              ),
            );
          },
        );
      },
    );
  }
}
