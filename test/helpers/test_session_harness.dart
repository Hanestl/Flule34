import 'package:cookie_jar/cookie_jar.dart';
import 'package:drift/native.dart';

import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/session/secret_store.dart';
import 'package:flule34/core/session/secure_cookie_storage.dart';
import 'package:flule34/core/session/session_store.dart';

final class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

final class TestSessionHarness {
  TestSessionHarness._({
    required this.database,
    required this.secretStore,
    required this.sessionStore,
  });

  factory TestSessionHarness.create() {
    final database = AppDatabase(NativeDatabase.memory());
    final secretStore = MemorySecretStore();
    final cookieJar = PersistCookieJar(
      persistSession: true,
      storage: SecureCookieStorage(secretStore),
    );
    final sessionStore = SessionStore(
      cookieJar: cookieJar,
      secretStore: secretStore,
      database: database,
    );
    return TestSessionHarness._(
      database: database,
      secretStore: secretStore,
      sessionStore: sessionStore,
    );
  }

  final AppDatabase database;
  final MemorySecretStore secretStore;
  final SessionStore sessionStore;

  PersistCookieJar newCookieJar() {
    return PersistCookieJar(
      persistSession: true,
      storage: SecureCookieStorage(secretStore),
    );
  }

  Future<void> dispose() async {
    sessionStore.dispose();
    await database.close();
  }
}
