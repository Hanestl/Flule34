import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/site_avatar.dart';
import '../../shared/video_list_filters.dart';

enum SubscriptionSort {
  added('最新订阅'),
  name('按名字'),
  updated('最近更新');

  const SubscriptionSort(this.label);

  final String label;
}

class SubscriptionsList extends StatefulWidget {
  const SubscriptionsList({super.key, required this.api, this.active = true});

  final Rule34VideoApi api;
  final bool active;

  @override
  State<SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<SubscriptionsList>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  List<SubscriptionItem> _subscriptions = const [];
  final Map<String, int?> _updatedAgeByPath = {};
  var _loading = false;
  var _updatingSort = false;
  var _updatedProgress = 0;
  var _updatedOperation = 0;
  var _query = '';
  var _sort = SubscriptionSort.added;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_load(force: false));
    }
  }

  @override
  void didUpdateWidget(covariant SubscriptionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && _subscriptions.isEmpty) {
      unawaited(_load(force: false));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool force}) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (force) {
        _updatedOperation += 1;
        _updatingSort = false;
        _updatedAgeByPath.clear();
        _updatedProgress = 0;
      }
    });
    try {
      final subscriptions = await widget.api.loadSubscriptions(force: force);
      if (mounted) {
        setState(() => _subscriptions = subscriptions);
        if (_sort == SubscriptionSort.updated) {
          await _loadUpdatedAges();
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
    if (sort != SubscriptionSort.updated) {
      _updatedOperation += 1;
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

  Future<void> _loadUpdatedAges() async {
    if (_updatingSort || _subscriptions.isEmpty) {
      return;
    }
    final missing = _subscriptions
        .where((item) => !_updatedAgeByPath.containsKey(item.path))
        .toList(growable: false);
    if (missing.isEmpty) {
      return;
    }
    final operation = ++_updatedOperation;
    setState(() {
      _updatingSort = true;
      _updatedProgress = 0;
    });
    const concurrency = 4;
    for (var offset = 0; offset < missing.length; offset += concurrency) {
      final batch = missing
          .skip(offset)
          .take(concurrency)
          .toList(growable: false);
      final results = await Future.wait(
        batch.map((item) async {
          try {
            final videos = await widget.api.loadSubscriptionVideos(item, 1);
            final latest = videos
                .map((video) => publishedAgeSeconds(video.publishedLabel))
                .whereType<int>()
                .fold<int?>(null, (current, age) {
                  return current == null || age < current ? age : current;
                });
            return (path: item.path, age: latest);
          } on Object {
            return (path: item.path, age: null);
          }
        }),
      );
      if (!mounted ||
          _sort != SubscriptionSort.updated ||
          operation != _updatedOperation) {
        return;
      }
      setState(() {
        for (final result in results) {
          _updatedAgeByPath[result.path] = result.age;
        }
        _updatedProgress += results.length;
      });
    }
    if (mounted && operation == _updatedOperation) {
      setState(() => _updatingSort = false);
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
      return _StateMessage(message: _error!, onRetry: () => _load(force: true));
    }
    if (_subscriptions.isEmpty) {
      return const Center(child: Text('还没有订阅内容。'));
    }
    final subscriptions = _visibleSubscriptions;
    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: subscriptions.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _toolbar(context);
            }
            if (index == 1) {
              if (_updatingSort) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    '正在读取最近更新（$_updatedProgress/${_subscriptions.length}）',
                  ),
                );
              }
              if (subscriptions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 44),
                  child: Center(child: Text('没有符合条件的订阅。')),
                );
              }
              return const SizedBox(height: 4);
            }
            final item = subscriptions[index - 2];
            return FutureBuilder<SubscriptionItem>(
              future: widget.api.resolveSubscription(item),
              initialData: item,
              builder: (context, resolvedSnapshot) {
                final resolved = resolvedSnapshot.data ?? item;
                return Card(
                  child: ListTile(
                    leading: SiteAvatar(
                      imageUrl: resolved.thumbnailUrl,
                      radius: 20,
                      fallbackIcon: _kindIcon(resolved.kind),
                    ),
                    title: Text(resolved.title),
                    subtitle: Text(resolved.kind.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed(
                      AppRouteNames.subscription,
                      pathParameters: {'kind': resolved.kind.name},
                      queryParameters: {
                        'path': resolved.path,
                        'title': resolved.title,
                      },
                      extra: resolved,
                    ),
                  ),
                );
              },
            );
          },
        ),
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

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
