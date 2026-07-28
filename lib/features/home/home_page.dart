import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';

enum _HomeChannel {
  newest('最新', FeedKind.newest),
  popular('热门', FeedKind.popular),
  topRated('高评分', FeedKind.topRated),
  following('关注', null);

  const _HomeChannel(this.label, this.feedKind);

  final String label;
  final FeedKind? feedKind;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _channel = _HomeChannel.newest;
  late ContentOrientation _orientation;
  var _duration = VideoDurationPreset.any;
  var _uploadPeriod = UploadPeriod.anytime;

  @override
  void initState() {
    super.initState();
    _orientation = ref
        .read(appSettingsRepositoryProvider)
        .settings
        .defaultOrientation;
  }

  SearchFilters get _filters => SearchFilters(
    orientation: _orientation,
    duration: _duration,
    uploadPeriod: _uploadPeriod,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.api.sessionStore,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              readOnly: true,
              leading: const Icon(Icons.search),
              hintText: '搜索视频、标签、分类或艺术家',
              onTap: () {
                ref
                    .read(predictivePrefetchServiceProvider)
                    .prioritizeForeground();
                context.pushNamed(AppRouteNames.search);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: _HomeChannel.values
                  .map(
                    (channel) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(channel.label),
                        selected: _channel == channel,
                        onSelected: (_) => setState(() => _channel = channel),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (_channel != _HomeChannel.following)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  _FilterMenu<ContentOrientation>(
                    label: _orientation == ContentOrientation.all
                        ? '内容取向'
                        : _orientation.label,
                    value: _orientation,
                    values: ContentOrientation.values,
                    labelFor: (value) => value.label,
                    onSelected: (value) => setState(() => _orientation = value),
                  ),
                  _FilterMenu<VideoDurationPreset>(
                    label: _duration == VideoDurationPreset.any
                        ? '时长'
                        : _duration.label,
                    value: _duration,
                    values: VideoDurationPreset.values,
                    labelFor: (value) => value.label,
                    onSelected: (value) => setState(() => _duration = value),
                  ),
                  _FilterMenu<UploadPeriod>(
                    label: _uploadPeriod == UploadPeriod.anytime
                        ? '发布时间'
                        : _uploadPeriod.label,
                    value: _uploadPeriod,
                    values: UploadPeriod.values,
                    labelFor: (value) => value.label,
                    onSelected: (value) =>
                        setState(() => _uploadPeriod = value),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final prefetch = ref.read(predictivePrefetchServiceProvider);
    if (_channel == _HomeChannel.following) {
      if (!widget.api.sessionStore.isLoggedIn) {
        return _FollowingSignedOut(
          onLogin: () => showLoginSheet(context, widget.api),
        );
      }
      final activity = widget.api.subscriptionActivity;
      return ListenableBuilder(
        listenable: activity,
        builder: (context, _) => Stack(
          children: [
            VideoFeed(
              key: ValueKey(
                'following:${widget.api.sessionStore.currentUserId}',
              ),
              initialItems: activity.cachedVideos
                  .take(30)
                  .toList(growable: false),
              loadPage: (page) => prefetch.runForeground(
                PredictivePrefetchKey.following,
                () => widget.api.loadFollowingFeed(page),
              ),
              refreshPage: (page) => prefetch.runForeground(
                PredictivePrefetchKey.following,
                () => widget.api.loadFollowingFeed(page, force: true),
              ),
              emptyMessage: '关注的分类、艺术家或用户暂时没有可展示的视频。',
              sortNewest: true,
              onItemsLoaded: prefetch.offerLikelyVideos,
              prefetchService: prefetch,
            ),
            if (activity.isScanning && activity.totalSources > 0)
              Positioned(
                left: 16,
                right: 16,
                top: 8,
                child: _FollowingProgress(
                  scanned: activity.scannedSources,
                  total: activity.totalSources,
                ),
              ),
          ],
        ),
      );
    }
    final kind = _channel.feedKind!;
    return VideoFeed(
      key: ValueKey(
        '${kind.name}:${_orientation.name}:${_duration.name}:${_uploadPeriod.name}',
      ),
      loadPage: (page) => prefetch.runForeground(
        PredictivePrefetchKey.feed(
          '${kind.name}:${_orientation.name}:${_duration.name}:${_uploadPeriod.name}',
          page,
        ),
        () => widget.api.loadFeed(kind, page, filters: _filters),
      ),
      onItemsLoaded: prefetch.offerLikelyVideos,
      prefetchService: prefetch,
    );
  }
}

class _FollowingProgress extends StatelessWidget {
  const _FollowingProgress({required this.scanned, required this.total});

  final int scanned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正在整理关注内容 $scanned/$total',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: total == 0 ? null : scanned / total),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onSelected,
        itemBuilder: (context) => values
            .map(
              (item) => CheckedPopupMenuItem<T>(
                value: item,
                checked: item == value,
                child: Text(labelFor(item)),
              ),
            )
            .toList(growable: false),
        child: Chip(
          label: Text(label),
          avatar: const Icon(Icons.tune, size: 16),
        ),
      ),
    );
  }
}

class _FollowingSignedOut extends StatelessWidget {
  const _FollowingSignedOut({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 52),
            const SizedBox(height: 16),
            Text('登录后查看关注内容', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '关注频道会汇总你在网站订阅的分类、艺术家、用户和播放列表。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
