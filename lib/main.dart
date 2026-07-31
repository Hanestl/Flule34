import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/maintenance/legacy_debug_data_cleanup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearLegacyDebugLoggingData();

  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('未捕获异步异常：$error\n$stackTrace');
    return true;
  };

  runApp(const ProviderScope(child: AppBootstrap()));
}
