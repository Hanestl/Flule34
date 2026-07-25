import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xff4f6f91);
  static const _lightBackground = Color(0xfff7f7f8);
  static const _darkBackground = Color(0xff1b1c1f);

  static final light = _base(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xfff1f2f4),
      surfaceContainer: const Color(0xffebecef),
      surfaceContainerHigh: const Color(0xffe5e6e9),
      surfaceContainerHighest: const Color(0xffdfe1e5),
    ),
    _lightBackground,
  );

  static final dark = _base(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xff232427),
      surfaceContainerLowest: _darkBackground,
      surfaceContainerLow: const Color(0xff242529),
      surfaceContainer: const Color(0xff292a2e),
      surfaceContainerHigh: const Color(0xff303135),
      surfaceContainerHighest: const Color(0xff38393e),
    ),
    _darkBackground,
  );

  static ThemeData _base(ColorScheme colorScheme, Color background) {
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }
}
