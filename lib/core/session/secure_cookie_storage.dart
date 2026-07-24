import 'package:cookie_jar/cookie_jar.dart';

import 'secret_store.dart';

final class SecureCookieStorage extends Storage {
  SecureCookieStorage(this._secretStore);

  static const _prefix = 'flule34.cookie.';

  final SecretStore _secretStore;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _secretStore.read(_key(key));

  @override
  Future<void> write(String key, String value) {
    return _secretStore.write(_key(key), value);
  }

  @override
  Future<void> delete(String key) => _secretStore.delete(_key(key));

  @override
  Future<void> deleteAll(List<String> keys) async {
    await Future.wait(keys.map(delete));
  }

  String _key(String key) => '$_prefix$key';
}
