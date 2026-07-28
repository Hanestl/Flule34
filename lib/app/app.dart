import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import '../shared/video_preview_overlay.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class Flule34App extends ConsumerWidget {
  const Flule34App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsRepository = ref.watch(appSettingsRepositoryProvider);

    return ListenableBuilder(
      listenable: settingsRepository,
      builder: (context, _) {
        final preference = settingsRepository.settings.theme;
        return MaterialApp.router(
          title: 'Flule34',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: switch (preference) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          routerConfig: router,
          builder: (context, child) => VideoPreviewOverlay(
            navigationListenable: router.routerDelegate,
            bottomInsetBuilder: (context) {
              final path = router.routerDelegate.currentConfiguration.uri.path;
              if (!_showsBottomNavigation(path)) {
                return 0;
              }
              return NavigationBarTheme.of(context).height ?? 80;
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

bool _showsBottomNavigation(String path) {
  return path == '/' ||
      path == '/discover' ||
      path == '/library' ||
      path.startsWith('/library/') ||
      path == '/profile' ||
      path.startsWith('/profile/');
}
