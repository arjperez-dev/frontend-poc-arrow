import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/local_progress_repository.dart';
import '../domain/level_best_result.dart';
import '../domain/local_progress.dart';

class SharedPreferencesLocalProgressRepository
    implements LocalProgressRepository {
  const SharedPreferencesLocalProgressRepository(this._preferences);

  static const _completedLevelsKey = 'progress.completedLevelNumbers';
  static const _bestResultsKey = 'progress.bestResultsByLevel';
  static const _lastUnlockedLevelKey = 'progress.lastUnlockedLevel';
  static const _lastSyncedUserIdKey = 'progress.lastSyncedUserId';

  final SharedPreferences _preferences;

  @override
  Future<LocalProgress> getProgress() async {
    final completedLevels =
        _preferences
            .getStringList(_completedLevelsKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .toSet() ??
        <int>{};
    final lastUnlockedLevel =
        _preferences.getInt(_lastUnlockedLevelKey) ??
        LocalProgress.initial().lastUnlockedLevel;
    final bestResults = _readBestResults();

    return LocalProgress(
      completedLevelNumbers: completedLevels,
      bestResultsByLevel: bestResults,
      lastUnlockedLevel: lastUnlockedLevel < 1 ? 1 : lastUnlockedLevel,
    );
  }

  @override
  Future<void> saveProgress(LocalProgress progress) async {
    await _preferences.setStringList(
      _completedLevelsKey,
      progress.completedLevelNumbers.map((level) => '$level').toList()..sort(),
    );
    await _preferences.setInt(
      _lastUnlockedLevelKey,
      progress.lastUnlockedLevel,
    );
    await _preferences.setString(
      _bestResultsKey,
      jsonEncode(
        progress.bestResultsByLevel.map((level, result) {
          return MapEntry('$level', result.toJson());
        }),
      ),
    );
  }

  @override
  Future<void> resetProgress() async {
    await _preferences.remove(_completedLevelsKey);
    await _preferences.remove(_bestResultsKey);
    await _preferences.remove(_lastUnlockedLevelKey);
  }

  @override
  Future<String?> getLastSyncedUserId() async {
    return _preferences.getString(_lastSyncedUserIdKey);
  }

  @override
  Future<void> setLastSyncedUserId(String? userId) async {
    if (userId == null) {
      await _preferences.remove(_lastSyncedUserIdKey);
      return;
    }
    await _preferences.setString(_lastSyncedUserIdKey, userId);
  }

  Map<int, LevelBestResult> _readBestResults() {
    final encoded = _preferences.getString(_bestResultsKey);
    if (encoded == null || encoded.isEmpty) {
      return <int, LevelBestResult>{};
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        return <int, LevelBestResult>{};
      }

      final results = <int, LevelBestResult>{};
      for (final entry in decoded.entries) {
        final levelNumber = int.tryParse(entry.key);
        final value = entry.value;
        if (levelNumber == null || value is! Map<String, Object?>) {
          continue;
        }
        results[levelNumber] = LevelBestResult.fromJson(value);
      }
      return results;
    } catch (_) {
      return <int, LevelBestResult>{};
    }
  }
}
