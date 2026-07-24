import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/video_models.dart';
import '../../features/discover/discover_page.dart';
import '../../features/discover/collection_page.dart';
import '../../features/discover/discovery_directory_page.dart';
import '../../features/discover/rankings_page.dart';
import '../../features/home/home_page.dart';
import '../../features/library/library_page.dart';
import '../../features/library/playlist_page.dart';
import '../../features/library/subscription_page.dart';
import '../../features/profile/account_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/presentation/settings_pages.dart';
import '../../features/settings/presentation/support_pages.dart';
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
  final searchHistoryRepository = ref.watch(searchHistoryRepositoryProvider);
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
                routes: [
                  GoRoute(
                    path: 'account',
                    name: AppRouteNames.account,
                    builder: (context, state) => AccountPage(api: api),
                  ),
                  GoRoute(
                    path: 'appearance',
                    name: AppRouteNames.appearanceSettings,
                    builder: (context, state) => const AppearanceSettingsPage(),
                  ),
                  GoRoute(
                    path: 'playback',
                    name: AppRouteNames.playbackSettings,
                    builder: (context, state) => const PlaybackSettingsPage(),
                  ),
                  GoRoute(
                    path: 'content',
                    name: AppRouteNames.contentSettings,
                    builder: (context, state) => const ContentSettingsPage(),
                  ),
                  GoRoute(
                    path: 'downloads',
                    name: AppRouteNames.downloadSettings,
                    builder: (context, state) => const DownloadSettingsPage(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    name: AppRouteNames.privacySettings,
                    builder: (context, state) => PrivacySettingsPage(api: api),
                  ),
                  GoRoute(
                    path: 'app',
                    name: AppRouteNames.appSettings,
                    builder: (context, state) => const AppSettingsPage(),
                  ),
                  GoRoute(
                    path: 'help',
                    name: AppRouteNames.helpFeedback,
                    builder: (context, state) => const HelpFeedbackPage(),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    name: AppRouteNames.diagnostics,
                    builder: (context, state) => const DiagnosticsPage(),
                  ),
                  GoRoute(
                    path: 'update',
                    name: AppRouteNames.update,
                    builder: (context, state) => const AppUpdatePage(),
                  ),
                  GoRoute(
                    path: 'about',
                    name: AppRouteNames.about,
                    builder: (context, state) => const AboutPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        name: AppRouteNames.search,
        builder: (context, state) =>
            SearchPage(api: api, historyRepository: searchHistoryRepository),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/directory/:kind',
        name: AppRouteNames.discoveryDirectory,
        builder: (context, state) {
          final kindName = state.pathParameters['kind'];
          final kind = DiscoveryKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => DiscoveryKind.tag,
          );
          final extra = state.extra;
          final spec = extra is DiscoveryDirectorySpec
              ? extra
              : DiscoveryDirectorySpec(
                  title: kind.label,
                  path: '/${kind.pathSegment}/',
                  kind: kind,
                );
          return DiscoveryDirectoryPage(api: api, spec: spec);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/collection/:kind/:id',
        name: AppRouteNames.collection,
        builder: (context, state) {
          final kindName = state.pathParameters['kind'];
          final kind = DiscoveryKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => DiscoveryKind.tag,
          );
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          final collection = extra is ContentCollectionItem
              ? extra
              : ContentCollectionItem(
                  id: id,
                  title: state.uri.queryParameters['title'] ?? kind.label,
                  path:
                      state.uri.queryParameters['path'] ??
                      '/${kind.pathSegment}/$id/',
                  kind: kind,
                );
          final sortName = state.uri.queryParameters['sort'];
          final sort = VideoSort.values.firstWhere(
            (value) => value.name == sortName,
            orElse: () => VideoSort.newest,
          );
          return CollectionPage(
            api: api,
            collection: collection,
            initialSort: sort,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rankings',
        name: AppRouteNames.rankings,
        builder: (context, state) => const RankingsPage(),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/playlist/:id',
        name: AppRouteNames.playlist,
        builder: (context, state) {
          final extra = state.extra;
          final playlist = extra is PlaylistItem
              ? extra
              : PlaylistItem(
                  id: state.pathParameters['id']!,
                  title: '播放列表 ${state.pathParameters['id']!}',
                  path: '/my/playlists/${state.pathParameters['id']!}/',
                );
          return PlaylistPage(api: api, playlist: playlist);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/subscription/:kind',
        name: AppRouteNames.subscription,
        builder: (context, state) {
          final extra = state.extra;
          final kindName = state.pathParameters['kind'];
          final kind = SubscriptionKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => SubscriptionKind.category,
          );
          final subscription = extra is SubscriptionItem
              ? extra
              : SubscriptionItem(
                  title: state.uri.queryParameters['title'] ?? kind.label,
                  path: state.uri.queryParameters['path'] ?? '/',
                  kind: kind,
                );
          return SubscriptionPage(api: api, subscription: subscription);
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
