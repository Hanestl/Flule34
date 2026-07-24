import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xffd74576);

  static final light = _base(
    ColorScheme.fromSeed(seedColor: _seed),
    const Color(0xfffff8fa),
  );

  static final dark = _base(
    ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
    const Color(0xff101014),
  );

  static final amoled = _base(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(surface: Colors.black),
    Colors.black,
  );

  static ThemeData _base(ColorScheme colorScheme, Color background) {
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
      navigationBarTheme: const NavigationBarThemeData(height: 68),
    );
  }
}
