import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/database/app_database.dart';
import '../core/logging/app_log_service.dart';
import '../core/session/secret_store.dart';
import '../core/session/secure_cookie_storage.dart';
import '../core/session/session_store.dart';
import '../core/services/network_status_service.dart';
import '../core/services/predictive_prefetch_service.dart';
import '../core/services/media_volume_service.dart';
import '../core/services/screen_wake_lock_service.dart';
import '../core/services/share_service.dart';
import '../features/downloads/data/background_download_platform_service.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/downloads/domain/download_models.dart';
import '../features/library/data/local_library_repository.dart';
import '../features/library/data/curated_library_seeder.dart';
import '../features/playback/data/playback_repository.dart';
import '../features/search/data/search_history_repository.dart';
import '../features/settings/data/app_settings_repository.dart';
import '../features/settings/data/app_settings_store.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return SharedPreferencesAppSettingsStore();
});

final appLogServiceProvider = Provider<AppLogService>((ref) {
  return sharedAppLogService;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final repository = AppSettingsRepository(ref.watch(appSettingsStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  return ConnectivityNetworkStatusService();
});

final screenWakeLockServiceProvider = Provider<ScreenWakeLockService>((ref) {
  return WakelockScreenWakeLockService();
});

final mediaVolumeServiceProvider = Provider<MediaVolumeService>((ref) {
  return const PlatformMediaVolumeService();
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return PlatformShareService();
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return FlutterSecretStore();
});

final cookieJarProvider = Provider<PersistCookieJar>((ref) {
  return PersistCookieJar(
    persistSession: true,
    storage: SecureCookieStorage(ref.watch(secretStoreProvider)),
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore(
    cookieJar: ref.watch(cookieJarProvider),
    secretStore: ref.watch(secretStoreProvider),
    database: ref.watch(appDatabaseProvider),
  );
  ref.onDispose(store.dispose);
  return store;
});

final rule34VideoApiProvider = Provider<Rule34VideoApi>((ref) {
  final api = Rule34VideoApi(sessionStore: ref.watch(sessionStoreProvider));
  ref.onDispose(api.close);
  return api;
});

final predictivePrefetchServiceProvider = Provider<PredictivePrefetchService>((
  ref,
) {
  final sessionStore = ref.watch(sessionStoreProvider);
  final service = PredictivePrefetchService(
    api: ref.watch(rule34VideoApiProvider),
    sessionStore: sessionStore,
  );
  sessionStore.addListener(service.onSessionChanged);
  ref.onDispose(() {
    sessionStore.removeListener(service.onSessionChanged);
    service.dispose();
  });
  return service;
});

final downloadPlatformServiceProvider = Provider<DownloadPlatformService>((
  ref,
) {
  return BackgroundDownloadPlatformService(
    maxConcurrent: ref
        .watch(appSettingsRepositoryProvider)
        .settings
        .downloadConcurrentTasks,
    logService: ref.watch(appLogServiceProvider),
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repository = DownloadRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(rule34VideoApiProvider),
    ref.watch(downloadPlatformServiceProvider),
    ref.watch(appSettingsRepositoryProvider),
    logService: ref.watch(appLogServiceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
});

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>((ref) {
  return DriftLocalLibraryRepository(
    ref.watch(appDatabaseProvider),
    logService: ref.watch(appLogServiceProvider),
  );
});

final curatedLibrarySeederProvider = Provider<CuratedLibrarySeeder>((ref) {
  return CuratedLibrarySeeder(
    ref.watch(appDatabaseProvider),
    const AssetCuratedLibraryManifestLoader(),
    logService: ref.watch(appLogServiceProvider),
  );
});

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SearchHistoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  final logs = ref.read(appLogServiceProvider);
  try {
    await ref.read(appSettingsRepositoryProvider).load();
    await ref.read(curatedLibrarySeederProvider).seedIfNeeded();
    final sessionStore = ref.read(sessionStoreProvider);
    await sessionStore.load();
    await ref.read(rule34VideoApiProvider).restoreSession();
    ref.read(predictivePrefetchServiceProvider).scheduleStartup();
    await ref.read(downloadRepositoryProvider).initialize();
    unawaited(logs.info('bootstrap', 'App 初始化完成。'));
  } catch (error, stackTrace) {
    await logs.error(
      'bootstrap',
      'App 初始化失败。',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
});
