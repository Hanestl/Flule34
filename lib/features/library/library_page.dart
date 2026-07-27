import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
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
  });

  final Rule34VideoApi api;
  final LocalLibraryRepository localLibraryRepository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: api.sessionStore,
      builder: (context, _) => _LibraryTabs(
        key: ValueKey(api.sessionStore.currentUserId),
        api: api,
        localLibraryRepository: localLibraryRepository,
        loggedIn: api.sessionStore.isLoggedIn,
      ),
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({
    super.key,
    required this.api,
    required this.localLibraryRepository,
    required this.loggedIn,
  });

  final Rule34VideoApi api;
  final LocalLibraryRepository localLibraryRepository;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const Tab(text: '本地分类库'),
      if (loggedIn) const Tab(text: '收藏'),
      if (loggedIn) const Tab(text: '历史'),
      if (loggedIn) const Tab(text: '播放列表'),
      if (loggedIn) const Tab(text: '订阅'),
    ];
    final pages = <Widget>[
      LocalLibraryOverview(repository: localLibraryRepository),
      if (loggedIn)
        VideoFeed(
          loadPage: api.loadFavorites,
          emptyMessage: '收藏夹里还没有视频。',
          showSearchAndFilters: true,
          searchHint: '搜索收藏的视频',
        ),
      if (loggedIn)
        VideoFeed(
          loadPage: api.loadHistory,
          emptyMessage: '网站观看历史还是空的。',
          showSearchAndFilters: true,
          searchHint: '搜索观看历史',
        ),
      if (loggedIn) PlaylistsList(api: api),
      if (loggedIn) SubscriptionsList(api: api),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
          Expanded(child: TabBarView(children: pages)),
        ],
      ),
    );
  }
}
