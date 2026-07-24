import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/adult_gate.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class Flule34App extends ConsumerWidget {
  const Flule34App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Flule34',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        return AdultGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
