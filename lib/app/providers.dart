import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/database/app_database.dart';
import '../core/session/secret_store.dart';
import '../core/session/secure_cookie_storage.dart';
import '../core/session/session_store.dart';
import '../core/services/network_status_service.dart';
import '../core/services/predictive_prefetch_service.dart';
import '../core/services/media_volume_service.dart';
import '../core/services/screen_wake_lock_service.dart';
import '../core/services/share_service.dart';
import '../core/services/subscription_activity_index.dart';
import '../core/services/video_preview_service.dart';
import '../shared/scroll_to_top_overlay.dart';
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

final scrollToTopControllerProvider = Provider<ScrollToTopController>((ref) {
  final controller = ScrollToTopController();
  ref.onDispose(controller.dispose);
  return controller;
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

final subscriptionActivityStoreProvider = Provider<SubscriptionActivityStore>((
  ref,
) {
  return _SettingsBackedSubscriptionActivityStore(
    ref.watch(appSettingsStoreProvider),
  );
});

final rule34VideoApiProvider = Provider<Rule34VideoApi>((ref) {
  final api = Rule34VideoApi(
    sessionStore: ref.watch(sessionStoreProvider),
    subscriptionActivityStore: ref.watch(subscriptionActivityStoreProvider),
  );
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
  );
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repository = DownloadRepository(
    ref.watch(appDatabaseProvider),
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
    ref.watch(appSettingsRepositoryProvider),
  );
});

final localLibraryRepositoryProvider = Provider<LocalLibraryRepository>((ref) {
  return DriftLocalLibraryRepository(ref.watch(appDatabaseProvider));
});

final videoPreviewResolverProvider = Provider<VideoPreviewResolver>((ref) {
  final api = ref.watch(rule34VideoApiProvider);
  final database = ref.watch(appDatabaseProvider);
  return VideoPreviewResolver(
    search: api.searchVideosForPreview,
    persist: ({required String videoId, required String? previewUrl}) =>
        database.updateLocalLibraryVideoPreviewUrl(
          videoId: videoId,
          previewUrl: previewUrl,
        ),
  );
});

final videoPreviewControllerProvider = Provider<VideoPreviewController>((ref) {
  final controller = VideoPreviewController();
  ref.onDispose(controller.dispose);
  return controller;
});

final curatedLibrarySeederProvider = Provider<CuratedLibrarySeeder>((ref) {
  return CuratedLibrarySeeder(
    ref.watch(appDatabaseProvider),
    const AssetCuratedLibraryManifestLoader(),
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
  await ref.read(curatedLibrarySeederProvider).seedIfNeeded();
  final sessionStore = ref.read(sessionStoreProvider);
  await sessionStore.load();
  await ref.read(rule34VideoApiProvider).restoreSession();
  await ref.read(rule34VideoApiProvider).subscriptionActivity.loadStored();
  ref.read(predictivePrefetchServiceProvider).scheduleStartup();
  await ref.read(downloadRepositoryProvider).initialize();
});

final class _SettingsBackedSubscriptionActivityStore
    implements SubscriptionActivityStore {
  const _SettingsBackedSubscriptionActivityStore(this._store);

  static const _keyPrefix = 'flule34.subscription_activity.';

  final AppSettingsStore _store;

  @override
  Future<String?> read(String userId) {
    return _store.readString('$_keyPrefix$userId');
  }

  @override
  Future<void> write(String userId, String value) {
    return _store.writeString('$_keyPrefix$userId', value);
  }

  @override
  Future<void> remove(String userId) {
    return _store.remove('$_keyPrefix$userId');
  }
}
