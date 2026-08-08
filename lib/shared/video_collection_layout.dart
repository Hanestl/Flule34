import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../features/settings/domain/app_settings.dart';

typedef VideoCollectionItemBuilder =
    Widget Function(BuildContext context, int index, bool compact);

class VideoCollectionSliver extends StatelessWidget {
  const VideoCollectionSliver({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemBuilder,
    this.listPadding = EdgeInsets.zero,
  });

  final ContentLayout layout;
  final int itemCount;
  final VideoCollectionItemBuilder itemBuilder;
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    if (layout == ContentLayout.doubleColumn) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        sliver: SliverMasonryGrid.count(
          key: const ValueKey('double-column-masonry'),
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childCount: itemCount,
          itemBuilder: (context, index) => itemBuilder(context, index, true),
        ),
      );
    }
    return SliverPadding(
      padding: listPadding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => itemBuilder(context, index, false),
          childCount: itemCount,
        ),
      ),
    );
  }
}

class VideoCollectionBox extends StatelessWidget {
  const VideoCollectionBox({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemBuilder,
  });

  final ContentLayout layout;
  final int itemCount;
  final VideoCollectionItemBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (layout == ContentLayout.doubleColumn) {
      return MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        itemCount: itemCount,
        itemBuilder: (context, index) => itemBuilder(context, index, true),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < itemCount; index += 1)
          itemBuilder(context, index, false),
      ],
    );
  }
}
