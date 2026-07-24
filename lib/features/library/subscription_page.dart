import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_feed.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({
    super.key,
    required this.api,
    required this.subscription,
  });

  final Rule34VideoApi api;
  final SubscriptionItem subscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subscription.title)),
      body: VideoFeed(
        loadPage: (page) => api.loadSubscriptionVideos(subscription, page),
        emptyMessage: '这个订阅目前没有可显示的视频。',
      ),
    );
  }
}
