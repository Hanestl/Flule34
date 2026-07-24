import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_feed.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.api,
    required this.collection,
    this.initialSort = VideoSort.newest,
  });

  final Rule34VideoApi api;
  final ContentCollectionItem collection;
  final VideoSort initialSort;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late VideoSort _sort = widget.initialSort;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.title),
        actions: [
          PopupMenuButton<VideoSort>(
            tooltip: '排序',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => VideoSort.values
                .where((value) => value != VideoSort.relevance)
                .map(
                  (value) =>
                      PopupMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
          ),
        ],
      ),
      body: VideoFeed(
        key: ValueKey(_sort),
        loadPage: (page) => widget.api.loadCollectionVideos(
          widget.collection,
          page,
          sort: _sort,
        ),
        emptyMessage: '这个集合里暂时没有视频。',
      ),
    );
  }
}
