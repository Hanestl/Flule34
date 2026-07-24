import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/video_models.dart';
import '../../features/discover/discover_page.dart';
import '../../features/home/home_page.dart';
import '../../features/library/library_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/search/search_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/video/video_detail_page.dart';
import '../providers.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _discoverNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'discover');
final _libraryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouterProvider = Provider<GoRouter>((ref) {
  final api = ref.watch(rule34VideoApiProvider);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                name: AppRouteNames.home,
                builder: (context, state) => HomePage(api: api),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _discoverNavigatorKey,
            routes: [
              GoRoute(
                path: '/discover',
                name: AppRouteNames.discover,
                builder: (context, state) => const DiscoverPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _libraryNavigatorKey,
            routes: [
              GoRoute(
                path: '/library',
                name: AppRouteNames.library,
                builder: (context, state) => LibraryPage(api: api),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: AppRouteNames.profile,
                builder: (context, state) => ProfilePage(api: api),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        name: AppRouteNames.search,
        builder: (context, state) => SearchPage(api: api),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/video/:id/:slug',
        name: AppRouteNames.video,
        builder: (context, state) {
          final extra = state.extra;
          final video = extra is VideoItem
              ? extra
              : VideoItem(
                  id: state.pathParameters['id']!,
                  slug: state.pathParameters['slug']!,
                  title: '视频 ${state.pathParameters['id']!}',
                );
          return VideoDetailPage(api: api, video: video);
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
