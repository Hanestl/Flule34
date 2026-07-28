import 'package:flutter/material.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_feed.dart';
import 'data/local_library_repository.dart';
import 'local_library_page.dart';
import 'playlists_list.dart';
import 'subscriptions_list.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.api,
    required this.localLibraryRepository,
    required this.prefetchService,
  });

  final Rule34VideoApi api;
  final LocalLibraryRepository localLibraryRepository;
  final PredictivePrefetchService prefetchService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) => _LibraryTabs(
        key: ValueKey(api.sessionStore.currentUserId),
        api: api,
        localLibraryRepository: localLibraryRepository,
        prefetchService: prefetchService,
        loggedIn: api.sessionStore.isLoggedIn,
      ),
    );
  }
}

class _LibraryTabs extends StatefulWidget {
  const _LibraryTabs({
    super.key,
    required this.api,
    required this.localLibraryRepository,
    required this.loggedIn,
    required this.prefetchService,
  });

  final Rule34VideoApi api;
  final LocalLibraryRepository localLibraryRepository;
  final bool loggedIn;
  final PredictivePrefetchService prefetchService;

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.loggedIn ? 5 : 1, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final index = _tabController.index;
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
    widget.prefetchService.prioritizeForeground(
      adoptKey: switch (index) {
        1 => PredictivePrefetchKey.favorites(1),
        2 => PredictivePrefetchKey.history(1),
        3 => PredictivePrefetchKey.playlists,
        4 => PredictivePrefetchKey.subscriptions,
        _ => null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.loggedIn;
    final api = widget.api;
    final prefetch = widget.prefetchService;
    final tabs = <Widget>[
      const Tab(text: '本地分类库'),
      if (loggedIn) const Tab(text: '收藏'),
      if (loggedIn) const Tab(text: '历史'),
      if (loggedIn) const Tab(text: '播放列表'),
      if (loggedIn) const Tab(text: '订阅'),
    ];
    final pages = <Widget>[
      LocalLibraryOverview(repository: widget.localLibraryRepository),
      if (loggedIn)
        VideoFeed(
          active: _selectedIndex == 1,
          loadPage: (page) => prefetch.runForeground(
            PredictivePrefetchKey.favorites(page),
            () => api.loadFavorites(page),
          ),
          refreshPage: (page) => prefetch.runForeground(
            PredictivePrefetchKey.favorites(page),
            () => api.loadFavorites(page, force: true),
          ),
          emptyMessage: '收藏夹里还没有视频。',
          showSearchAndFilters: true,
          searchHint: '搜索收藏的视频',
          prefetchService: prefetch,
        ),
      if (loggedIn)
        VideoFeed(
          active: _selectedIndex == 2,
          loadPage: (page) => prefetch.runForeground(
            PredictivePrefetchKey.history(page),
            () => api.loadHistory(page),
          ),
          refreshPage: (page) => prefetch.runForeground(
            PredictivePrefetchKey.history(page),
            () => api.loadHistory(page, force: true),
          ),
          emptyMessage: '网站观看历史还是空的。',
          showSearchAndFilters: true,
          searchHint: '搜索观看历史',
          prefetchService: prefetch,
        ),
      if (loggedIn) PlaylistsList(api: api, active: _selectedIndex == 3),
      if (loggedIn) SubscriptionsList(api: api, active: _selectedIndex == 4),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!loggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '本地分类库无需登录；登录后还可查看网站收藏、历史和订阅。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabs,
        ),
        Expanded(
          child: TabBarView(controller: _tabController, children: pages),
        ),
      ],
    );
  }
}
