import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_feed.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key, required this.api, required this.playlist});

  final Rule34VideoApi api;
  final PlaylistItem playlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(playlist.title)),
      body: VideoFeed(
        loadPage: (page) => api.loadPlaylistVideos(playlist, page),
        emptyMessage: '这个播放列表里还没有视频。',
      ),
    );
  }
}
