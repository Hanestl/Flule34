import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffd74576),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xff101014),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    navigationBarTheme: const NavigationBarThemeData(height: 68),
  );
}
