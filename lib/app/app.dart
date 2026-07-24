import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/adult_gate.dart';
import '../features/settings/domain/app_settings.dart';
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
          darkTheme: preference == AppThemePreference.amoled
              ? AppTheme.amoled
              : AppTheme.dark,
          themeMode: switch (preference) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.dark ||
            AppThemePreference.amoled => ThemeMode.dark,
          },
          routerConfig: router,
          builder: (context, child) {
            return AdultGate(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
