import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppSettingsStore {
  Future<String?> readString(String key);

  Future<bool?> readBool(String key);

  Future<void> writeString(String key, String value);

  Future<void> writeBool(String key, bool value);
}

final class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  SharedPreferencesAppSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readString(String key) => _preferences.getString(key);

  @override
  Future<bool?> readBool(String key) => _preferences.getBool(key);

  @override
  Future<void> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> writeBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }
}
