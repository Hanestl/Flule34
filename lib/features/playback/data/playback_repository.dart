import '../../../core/database/app_database.dart';
import '../../../core/session/session_store.dart';
import '../../settings/data/app_settings_repository.dart';

final class PlaybackRepository {
  PlaybackRepository(
    this._database,
    this._sessionStore,
    this._settingsRepository,
  );

  static const _minimumResume = Duration(seconds: 5);
  static const _completionThreshold = Duration(seconds: 15);

  final AppDatabase _database;
  final SessionStore _sessionStore;
  final AppSettingsRepository _settingsRepository;

  Future<Duration?> loadPosition(String videoId) async {
    final userId = _sessionStore.currentUserId;
    if (userId == null ||
        !_settingsRepository.settings.rememberPlaybackProgress) {
      return null;
    }
    final record = await _database.findPlaybackPosition(
      userId: userId,
      videoId: videoId,
    );
    if (record == null) {
      return null;
    }
    final position = Duration(milliseconds: record.positionMs);
    if (position < _minimumResume) {
      return null;
    }
    final durationMs = record.durationMs;
    if (durationMs != null &&
        Duration(milliseconds: durationMs) - position <= _completionThreshold) {
      return null;
    }
    return position;
  }

  Future<void> savePosition({
    required String videoId,
    required Duration position,
    required Duration duration,
  }) async {
    final userId = _sessionStore.currentUserId;
    if (userId == null ||
        !_settingsRepository.settings.rememberPlaybackProgress ||
        duration <= Duration.zero) {
      return;
    }
    final normalizedPosition = duration - position <= _completionThreshold
        ? Duration.zero
        : position;
    await _database.savePlaybackPosition(
      userId: userId,
      videoId: videoId,
      positionMs: normalizedPosition.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );
  }
}
