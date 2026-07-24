import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'rule34video_php_session';

  final FlutterSecureStorage _storage;
  String? _sessionId;

  bool get isLoggedIn => _sessionId != null && _sessionId!.isNotEmpty;

  String? get cookieHeader => isLoggedIn ? 'PHPSESSID=${_sessionId!}' : null;

  Future<void> load() async {
    _sessionId = await _storage.read(key: _sessionKey);
    notifyListeners();
  }

  Future<void> captureSetCookieHeaders(Iterable<String> values) async {
    for (final value in values) {
      final match = RegExp(
        r'PHPSESSID=([^;,\s]+)',
        caseSensitive: false,
      ).firstMatch(value);
      if (match != null) {
        await _save(match.group(1)!);
        return;
      }
    }
  }

  Future<void> _save(String sessionId) async {
    if (_sessionId == sessionId) {
      return;
    }
    _sessionId = sessionId;
    await _storage.write(key: _sessionKey, value: sessionId);
    notifyListeners();
  }

  Future<void> clear() async {
    _sessionId = null;
    await _storage.delete(key: _sessionKey);
    notifyListeners();
  }
}
