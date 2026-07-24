import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import 'secret_store.dart';

@immutable
final class SessionUser {
  const SessionUser({required this.id});

  final String id;
}

class SessionStore extends ChangeNotifier {
  SessionStore({
    required this.cookieJar,
    required this.secretStore,
    required this.database,
  });

  static const _userIdKey = 'flule34.session.user_id';
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

  Future<void> clear() async {
    await Future.wait([cookieJar.deleteAll(), secretStore.delete(_userIdKey)]);
    if (_currentUser == null) {
      return;
    }
    _currentUser = null;
    notifyListeners();
  }

  String _cookiePair(Cookie cookie) => '${cookie.name}=${cookie.value}';
}
