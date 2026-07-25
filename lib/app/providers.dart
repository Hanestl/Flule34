import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/database/app_database.dart';
import '../core/session/secret_store.dart';
import '../core/session/secure_cookie_storage.dart';
import '../core/session/session_store.dart';
import '../core/services/network_status_service.dart';
import '../core/services/screen_wake_lock_service.dart';
import '../core/services/share_service.dart';
import '../features/downloads/data/background_download_platform_service.dart';
import '../features/downloads/data/download_repository.dart';
import '../features/downloads/domain/download_models.dart';
import '../features/playback/data/playback_repository.dart';
import '../features/search/data/search_history_repository.dart';
import '../features/settings/data/app_settings_repository.dart';
import '../features/settings/data/app_settings_store.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return SharedPreferencesAppSettingsStore();
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

final downloadPlatformServiceProvider = Provider<DownloadPlatformService>((
  ref,
) {
  return BackgroundDownloadPlatformService(
    maxConcurrent: ref
        .watch(appSettingsRepositoryProvider)
        .settings
        .downloadConcurrentTasks,
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repository = DownloadRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(rule34VideoApiProvider),
    ref.watch(downloadPlatformServiceProvider),
    ref.watch(appSettingsRepositoryProvider),
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
  await ref.read(appSettingsRepositoryProvider).load();
  final sessionStore = ref.read(sessionStoreProvider);
  await sessionStore.load();
  await ref.read(rule34VideoApiProvider).restoreSession();
  await ref.read(downloadRepositoryProvider).initialize();
});
