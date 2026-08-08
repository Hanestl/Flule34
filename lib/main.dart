import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/logging/app_log_service.dart';
import 'core/maintenance/legacy_debug_data_cleanup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearLegacyDebugLoggingData();
  await AppLogService.instance.initialize();

  FlutterError.onError = (details) {
    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
    unawaited(
      AppLogService.instance.error(
        details.exception,
        details.stack ?? StackTrace.current,
        component: 'flutter',
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    if (!kReleaseMode) {
      debugPrint('未捕获异步异常：$error\n$stackTrace');
    }
    unawaited(
      AppLogService.instance.error(error, stackTrace, component: 'async'),
    );
    return true;
  };

  runZonedGuarded(() => runApp(const ProviderScope(child: AppBootstrap())), (
    error,
    stackTrace,
  ) {
    unawaited(
      AppLogService.instance.error(error, stackTrace, component: 'zone'),
    );
  });
}
