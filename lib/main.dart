import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/logging/app_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sharedAppLogService.initialize();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      sharedAppLogService.error(
        'flutter',
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('未捕获异步异常：$error\n$stackTrace');
    unawaited(
      sharedAppLogService.error(
        'platform',
        '未捕获异步异常',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return true;
  };

  runApp(const ProviderScope(child: AppBootstrap()));
}
