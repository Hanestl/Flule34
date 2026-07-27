import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import 'secret_store.dart';

@immutable
final class SessionUser {
  const SessionUser({required this.id});

  final String id;
}

@immutable
final class StoredCredentials {
  const StoredCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class SessionStore extends ChangeNotifier {
  SessionStore({
    required this.cookieJar,
    required this.secretStore,
    required this.database,
  });

  static const _userIdKey = 'flule34.session.user_id';
  static const _emailKey = 'flule34.session.email';
  static const _passwordKey = 'flule34.session.password';
  static final _validUserId = RegExp(r'^\d+$');

  final PersistCookieJar cookieJar;
  final SecretStore secretStore;
  final AppDatabase database;

  SessionUser? _currentUser;
  bool _loaded = false;

  SessionUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.id;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    await cookieJar.forceInit();
    final storedUserId = await secretStore.read(_userIdKey);
    if (storedUserId != null && _validUserId.hasMatch(storedUserId)) {
      _currentUser = SessionUser(id: storedUserId);
      await database.recordAuthenticatedAccount(storedUserId);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> authenticate(String userId) async {
    final normalized = userId.trim();
    if (!_validUserId.hasMatch(normalized)) {
      throw ArgumentError.value(userId, 'userId', '用户 ID 格式无效');
    }

    await database.recordAuthenticatedAccount(normalized);
    await secretStore.write(_userIdKey, normalized);
    if (_currentUser?.id == normalized) {
      return;
    }
    _currentUser = SessionUser(id: normalized);
    notifyListeners();
  }

  Future<String?> cookieHeaderFor(Uri uri) async {
    final cookies = await cookieJar.loadForRequest(uri);
    if (cookies.isEmpty) {
      return null;
    }
    return cookies.map(_cookiePair).join('; ');
  }

  Future<StoredCredentials?> loadCredentials() async {
    final values = await Future.wait([
      secretStore.read(_emailKey),
      secretStore.read(_passwordKey),
    ]);
    final email = values[0]?.trim() ?? '';
    final password = values[1] ?? '';
    if (email.isEmpty || password.isEmpty) {
      return null;
    }
    return StoredCredentials(email: email, password: password);
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('账号和密码不能为空。');
    }
    await Future.wait([
      secretStore.write(_emailKey, normalizedEmail),
      secretStore.write(_passwordKey, password),
    ]);
  }

  Future<void> clearCookies() => cookieJar.deleteAll();

  Future<void> clear({bool forgetCredentials = false}) async {
    await Future.wait([
      cookieJar.deleteAll(),
      secretStore.delete(_userIdKey),
      if (forgetCredentials) secretStore.delete(_emailKey),
      if (forgetCredentials) secretStore.delete(_passwordKey),
    ]);
    if (_currentUser == null) {
      return;
    }
    _currentUser = null;
    notifyListeners();
  }

  String _cookiePair(Cookie cookie) => '${cookie.name}=${cookie.value}';
}
