import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/site_avatar.dart';
import '../settings/domain/app_settings.dart';
import 'subscription_actions.dart';

enum SubscriptionSort {
  added('最新订阅'),
  name('按名字'),
  updated('最近更新');

  const SubscriptionSort(this.label);

  final String label;
}

class SubscriptionsList extends ConsumerStatefulWidget {
  const SubscriptionsList({super.key, required this.api, this.active = true});

  final Rule34VideoApi api;
  final bool active;

  @override
  ConsumerState<SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends ConsumerState<SubscriptionsList>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  List<SubscriptionItem> _subscriptions = const [];
  final Map<String, int?> _updatedAgeByPath = {};
  final Set<String> _removingPaths = {};
  var _loading = false;
  var _updatingSort = false;
  var _query = '';
  var _sort = SubscriptionSort.added;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.subscriptionActivity.addListener(_onActivityChanged);
    if (widget.active) {
      unawaited(_load(force: false));
    }
  }

  @override
  void didUpdateWidget(covariant SubscriptionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      oldWidget.api.subscriptionActivity.removeListener(_onActivityChanged);
      widget.api.subscriptionActivity.addListener(_onActivityChanged);
    }
    if (!oldWidget.active && widget.active && _subscriptions.isEmpty) {
      unawaited(_load(force: false));
    }
  }

  @override
  void dispose() {
    widget.api.subscriptionActivity.removeListener(_onActivityChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (mounted && _sort == SubscriptionSort.updated) {
      setState(() {});
    }
  }

  Future<void> _load({required bool force}) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (force) {
        _updatingSort = false;
        _updatedAgeByPath.clear();
      }
    });
    try {
      final subscriptions = await widget.api.loadSubscriptions(force: force);
      if (mounted) {
        setState(() => _subscriptions = subscriptions);
        if (_sort == SubscriptionSort.updated) {
          await _loadUpdatedAges(force: force);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setSort(SubscriptionSort sort) async {
    if (_sort == sort) {
      return;
    }
    setState(() {
      _sort = sort;
      if (sort != SubscriptionSort.updated) {
        _updatingSort = false;
      }
    });
    if (sort == SubscriptionSort.updated) {
      await _loadUpdatedAges();
    }
  }

  Future<void> _loadUpdatedAges({bool force = false}) async {
    if (_updatingSort || _subscriptions.isEmpty) {
      return;
    }
    setState(() {
      _updatingSort = true;
    });
    try {
      final ages = await widget.api.loadSubscriptionUpdatedAges(force: force);
      if (!mounted || _sort != SubscriptionSort.updated) {
        return;
      }
      setState(() {
        _updatedAgeByPath
          ..clear()
          ..addAll(ages);
      });
    } on Object {
      if (mounted) {
        setState(() {
          _updatedAgeByPath
            ..clear()
            ..addAll(widget.api.subscriptionActivity.updatedAgeByPath);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSort = false);
      }
    }
  }

  List<SubscriptionItem> get _visibleSubscriptions {
    final normalized = _query.trim().toLowerCase();
    final sourceIndex = <String, int>{
      for (var index = 0; index < _subscriptions.length; index += 1)
        _subscriptions[index].path: index,
    };
    final result = _subscriptions
        .where(
          (item) =>
              normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized),
        )
        .toList(growable: true);
    switch (_sort) {
      case SubscriptionSort.added:
        break;
      case SubscriptionSort.name:
        result.sort((left, right) {
          final compared = left.title.toLowerCase().compareTo(
            right.title.toLowerCase(),
          );
          return compared == 0
              ? (sourceIndex[left.path] ?? 0).compareTo(
                  sourceIndex[right.path] ?? 0,
                )
              : compared;
        });
      case SubscriptionSort.updated:
        result.sort((left, right) {
          final leftAge = _updatedAgeByPath[left.path];
          final rightAge = _updatedAgeByPath[right.path];
          if (leftAge == null && rightAge == null) {
            return (sourceIndex[left.path] ?? 0).compareTo(
              sourceIndex[right.path] ?? 0,
            );
          }
          if (leftAge == null) {
            return 1;
          }
          if (rightAge == null) {
            return -1;
          }
          final compared = leftAge.compareTo(rightAge);
          return compared == 0
              ? (sourceIndex[left.path] ?? 0).compareTo(
                  sourceIndex[right.path] ?? 0,
                )
              : compared;
        });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.active && _subscriptions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_subscriptions.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subscriptions.isEmpty && _error != null) {
      return _refreshableMessage(
        message: _error!,
        onRetry: () => _load(force: true),
      );
    }
    if (_subscriptions.isEmpty) {
      return _refreshableMessage(message: '还没有订阅内容。');
    }
    final subscriptions = _visibleSubscriptions;
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);
    return ListenableBuilder(
      listenable: settingsRepository,
      builder: (context, _) => _subscriptionScrollView(
        subscriptions,
        settingsRepository.settings.subscriptionLayout,
      ),
    );
  }

  Widget _subscriptionScrollView(
    List<SubscriptionItem> subscriptions,
    ContentLayout layout,
  ) {
    final activity = widget.api.subscriptionActivity;
    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              sliver: SliverToBoxAdapter(child: _toolbar(context)),
            ),
            if (_updatingSort)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    activity.totalSources > 0
                        ? '正在读取最近更新（${activity.scannedSources}/${activity.totalSources}）'
                        : '正在读取最近更新…',
                  ),
                ),
              ),
            if (subscriptions.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('没有符合条件的订阅。')),
              )
            else
              SliverPadding(
                padding: layout == ContentLayout.doubleColumn
                    ? const EdgeInsets.fromLTRB(7, 2, 7, 24)
                    : const EdgeInsets.fromLTRB(12, 2, 12, 24),
                sliver: layout == ContentLayout.doubleColumn
                    ? SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.05,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _subscriptionItem(
                            subscriptions[index],
                            compact: true,
                          ),
                          childCount: subscriptions.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _subscriptionItem(subscriptions[index]),
                          childCount: subscriptions.length,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionItem(SubscriptionItem item, {bool compact = false}) {
    return FutureBuilder<SubscriptionItem>(
      future: widget.api.resolveSubscription(item),
      initialData: item,
      builder: (context, resolvedSnapshot) {
        final resolved = resolvedSnapshot.data ?? item;
        final removing = _removingPaths.contains(resolved.path);
        return Card(
          margin: compact
              ? const EdgeInsets.all(5)
              : const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: removing ? null : () => _openSubscription(resolved),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 10 : 12,
              ),
              child: Row(
                children: [
                  SiteAvatar(
                    imageUrl: resolved.thumbnailUrl,
                    radius: compact ? 19 : 22,
                    fallbackIcon: _kindIcon(resolved.kind),
                  ),
                  SizedBox(width: compact ? 9 : 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolved.title,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          resolved.kind.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (removing)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (widget.api.canUnsubscribeSubscription(resolved))
                    SizedBox(
                      width: 36,
                      height: 40,
                      child: PopupMenuButton<_SubscriptionAction>(
                        tooltip: '更多操作',
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onSelected: (action) {
                          if (action == _SubscriptionAction.unsubscribe) {
                            unawaited(_unsubscribe(resolved));
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _SubscriptionAction.unsubscribe,
                            child: Row(
                              children: [
                                Icon(Icons.notifications_off_outlined),
                                SizedBox(width: 12),
                                Text('取消订阅'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSubscription(SubscriptionItem subscription) async {
    final removed = await context.pushNamed<bool>(
      AppRouteNames.subscription,
      pathParameters: {'kind': subscription.kind.name},
      queryParameters: {'path': subscription.path, 'title': subscription.title},
      extra: subscription,
    );
    if (removed == true && mounted) {
      _removeSubscription(subscription);
    }
  }

  Future<void> _unsubscribe(SubscriptionItem subscription) async {
    if (_removingPaths.contains(subscription.path) ||
        !await confirmUnsubscribeSubscription(context, subscription) ||
        !mounted) {
      return;
    }
    setState(() => _removingPaths.add(subscription.path));
    try {
      await widget.api.unsubscribeSubscription(subscription);
      if (!mounted) {
        return;
      }
      _removeSubscription(subscription);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已取消订阅。')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _removingPaths.remove(subscription.path));
      }
    }
  }

  void _removeSubscription(SubscriptionItem subscription) {
    setState(() {
      _subscriptions = _subscriptions
          .where((item) => item.path != subscription.path)
          .toList(growable: false);
      _updatedAgeByPath.remove(subscription.path);
      _removingPaths.remove(subscription.path);
    });
  }

  Widget _refreshableMessage({required String message, VoidCallback? onRetry}) {
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('重试'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: _searchController,
              leading: const Icon(Icons.search),
              hintText: '搜索订阅',
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: '清除',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<SubscriptionSort>(
            tooltip: '排序',
            initialValue: _sort,
            onSelected: (value) => unawaited(_setSort(value)),
            itemBuilder: (context) => SubscriptionSort.values
                .map(
                  (item) => PopupMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.sort),
            ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(SubscriptionKind kind) => switch (kind) {
    SubscriptionKind.category => Icons.category_outlined,
    SubscriptionKind.model => Icons.brush_outlined,
    SubscriptionKind.member => Icons.person_outline,
    SubscriptionKind.playlist => Icons.playlist_play,
    SubscriptionKind.channel => Icons.live_tv_outlined,
  };

  @override
  bool get wantKeepAlive => true;
}

enum _SubscriptionAction { unsubscribe }
