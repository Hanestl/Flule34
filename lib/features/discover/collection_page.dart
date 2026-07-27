import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/site_avatar.dart';
import '../../shared/video_feed.dart';
import '../search/video_filter_sheet.dart';

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
  late SearchFilters _filters = _initialFilters();
  late Future<ContentCollectionItem> _resolvedCollection;
  late VideoSort _channelSort = widget.initialSort;

  bool get _supportsAdvancedFilters =>
      widget.collection.kind != DiscoveryKind.channel;

  @override
  void initState() {
    super.initState();
    _resolvedCollection = widget.api.resolveCollection(widget.collection);
  }

  SearchFilters _initialFilters() {
    final kind = switch (widget.collection.kind) {
      DiscoveryKind.tag => SearchSuggestionKind.tag,
      DiscoveryKind.category => SearchSuggestionKind.category,
      DiscoveryKind.model => SearchSuggestionKind.model,
      DiscoveryKind.channel => null,
    };
    if (kind == null) {
      return SearchFilters(sort: widget.initialSort);
    }
    final suggestion = SearchSuggestion(
      id: widget.collection.effectiveFilterId,
      title: widget.collection.title,
      total: widget.collection.total ?? 0,
      kind: kind,
    );
    return SearchFilters(
      sort: widget.initialSort,
      tags: kind == SearchSuggestionKind.tag ? [suggestion] : const [],
      categories: kind == SearchSuggestionKind.category
          ? [suggestion]
          : const [],
      models: kind == SearchSuggestionKind.model ? [suggestion] : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<ContentCollectionItem>(
          future: _resolvedCollection,
          initialData: widget.collection,
          builder: (context, snapshot) {
            final collection = snapshot.data ?? widget.collection;
            final thumbnailUrl = collection.thumbnailUrl;
            if (thumbnailUrl == null) {
              return Text(collection.title);
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SiteAvatar(
                  imageUrl: thumbnailUrl,
                  radius: 17,
                  fallbackIcon: Icons.brush_outlined,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    collection.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          if (_supportsAdvancedFilters)
            IconButton(
              tooltip: '筛选与排序',
              onPressed: _openFilters,
              icon: Badge(
                isLabelVisible: _filters.activeCount > 1,
                label: Text('${_filters.activeCount}'),
                child: const Icon(Icons.tune),
              ),
            )
          else
            PopupMenuButton<VideoSort>(
              tooltip: '排序',
              initialValue: _channelSort,
              onSelected: (value) => setState(() => _channelSort = value),
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
      body: _supportsAdvancedFilters
          ? Column(
              children: [
                _ActiveFilterBar(
                  filters: _filters,
                  onRemove: _removeEntity,
                  onClear: () => setState(
                    () => _filters = SearchFilters(sort: widget.initialSort),
                  ),
                ),
                Expanded(child: _buildFilteredFeed()),
              ],
            )
          : VideoFeed(
              key: ValueKey(_channelSort),
              loadPage: (page) => widget.api.loadCollectionVideos(
                widget.collection,
                page,
                sort: _channelSort,
              ),
              emptyMessage: '这个集合里暂时没有视频。',
            ),
    );
  }

  Widget _buildFilteredFeed() {
    final effectiveFilters = _filters.isEmpty
        ? _filters.copyWith(sort: VideoSort.newest)
        : _filters;
    return VideoFeed(
      key: ValueKey(_filterKey(effectiveFilters)),
      loadPage: (page) =>
          widget.api.searchVideos('', page, filters: effectiveFilters),
      itemFilter: effectiveFilters.hasQualityFilters
          ? effectiveFilters.matchesQuality
          : null,
      emptyMessage: '没有找到同时满足这些条件的视频。',
    );
  }

  Future<void> _openFilters() async {
    final selected = await showVideoFilterSheet(
      context: context,
      api: widget.api,
      initialFilters: _filters,
    );
    if (selected != null && mounted) {
      setState(() => _filters = selected);
    }
  }

  void _removeEntity(SearchSuggestion suggestion, bool excluded) {
    setState(() {
      _filters = switch ((suggestion.kind, excluded)) {
        (SearchSuggestionKind.tag, false) => _filters.copyWith(
          tags: _filters.tags
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
        (SearchSuggestionKind.category, false) => _filters.copyWith(
          categories: _filters.categories
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
        (SearchSuggestionKind.model, false) => _filters.copyWith(
          models: _filters.models
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
        (SearchSuggestionKind.tag, true) => _filters.copyWith(
          excludedTags: _filters.excludedTags
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
        (SearchSuggestionKind.category, true) => _filters.copyWith(
          excludedCategories: _filters.excludedCategories
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
        (SearchSuggestionKind.model, true) => _filters.copyWith(
          excludedModels: _filters.excludedModels
              .where((item) => item.id != suggestion.id)
              .toList(growable: false),
        ),
      };
    });
  }

  String _filterKey(SearchFilters value) {
    return [
      value.sort.name,
      value.orientation.name,
      value.uploadPeriod.name,
      value.duration.name,
      value.verifiedOnly,
      value.tags.map((item) => item.id).join(','),
      value.categories.map((item) => item.id).join(','),
      value.models.map((item) => item.id).join(','),
      value.excludedTags.map((item) => item.id).join(','),
      value.excludedCategories.map((item) => item.id).join(','),
      value.excludedModels.map((item) => item.id).join(','),
      value.minRating,
      value.minRatingVotes,
    ].join('|');
  }
}

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({
    required this.filters,
    required this.onRemove,
    required this.onClear,
  });

  final SearchFilters filters;
  final void Function(SearchSuggestion suggestion, bool excluded) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final entries = <({SearchSuggestion item, bool excluded})>[
      ...filters.tags.map((item) => (item: item, excluded: false)),
      ...filters.models.map((item) => (item: item, excluded: false)),
      ...filters.categories.map((item) => (item: item, excluded: false)),
      ...filters.excludedTags.map((item) => (item: item, excluded: true)),
      ...filters.excludedModels.map((item) => (item: item, excluded: true)),
      ...filters.excludedCategories.map((item) => (item: item, excluded: true)),
    ];
    if (entries.isEmpty && !filters.hasQualityFilters) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(
                  entry.excluded ? '排除：${entry.item.title}' : entry.item.title,
                ),
                onDeleted: () => onRemove(entry.item, entry.excluded),
              ),
            ),
          if (filters.minRating != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(label: Text('点赞率 ≥ ${filters.minRating}%')),
            ),
          if (filters.minRatingVotes != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(label: Text('投票数 ≥ ${filters.minRatingVotes}')),
            ),
          TextButton(onPressed: onClear, child: const Text('清除条件')),
        ],
      ),
    );
  }
}
