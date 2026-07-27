import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final dark = colorScheme.brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: colorScheme.surface,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      useMaterial3: true,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
            fallbackColor: background,
          ),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(
            backgroundColor: background,
          ),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(
            backgroundColor: background,
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }
}
