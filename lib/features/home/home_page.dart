import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_feed.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _kind = FeedKind.newest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Rule34Video',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const Icon(Icons.verified_user_outlined, size: 20),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: FeedKind.values
                .map((kind) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        Expanded(
          child: VideoFeed(
            key: ValueKey(_kind),
            api: widget.api,
            loadPage: (page) => widget.api.loadFeed(_kind, page),
          ),
        ),
      ],
    );
  }
}
