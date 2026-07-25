import '../../../core/database/app_database.dart';
import '../../../core/session/session_store.dart';
import '../../settings/data/app_settings_repository.dart';

class SearchHistoryRepository {
  const SearchHistoryRepository(
    this._database,
    this._sessionStore,
    this._settingsRepository,
  );

  final AppDatabase _database;
  final SessionStore _sessionStore;
  final AppSettingsRepository _settingsRepository;

  Stream<List<SearchHistory>> watch() {
    final userId = _sessionStore.currentUserId;
    if (userId == null) {
      return Stream.value(const []);
    }
    return _database.watchSearchHistory(userId);
  }

  Future<void> record(String query) async {
    final userId = _sessionStore.currentUserId;
    if (userId == null || !_settingsRepository.settings.saveSearchHistory) {
      return;
    }
    await _database.recordSearchQuery(userId: userId, query: query);
  }

  Future<void> delete(SearchHistory history) async {
    final userId = _sessionStore.currentUserId;
    if (userId == null || history.userId != userId) {
      return;
    }
    await _database.deleteSearchHistory(
      userId: userId,
      normalizedQuery: history.normalizedQuery,
    );
  }

  Future<void> clear() async {
    final userId = _sessionStore.currentUserId;
    if (userId == null) {
      return;
    }
    await _database.clearSearchHistory(userId);
  }
}
