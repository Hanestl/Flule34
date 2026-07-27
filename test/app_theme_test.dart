import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/app/theme/app_theme.dart';

void main() {
  test('Android 页面过渡背景与 Scaffold 背景一致', () {
    final transition =
        AppTheme.dark.pageTransitionsTheme.builders[TargetPlatform.android]
            as PredictiveBackPageTransitionsBuilder;

    expect(transition.fallbackColor, AppTheme.dark.scaffoldBackgroundColor);
  });
}
