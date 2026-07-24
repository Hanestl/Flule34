import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/rule34video_api.dart';
import '../core/database/app_database.dart';
import '../core/session/secret_store.dart';
import '../core/session/secure_cookie_storage.dart';
import '../core/session/session_store.dart';

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

final appInitializationProvider = FutureProvider<void>((ref) async {
  final sessionStore = ref.read(sessionStoreProvider);
  await sessionStore.load();
  await ref.read(rule34VideoApiProvider).restoreSession();
});
