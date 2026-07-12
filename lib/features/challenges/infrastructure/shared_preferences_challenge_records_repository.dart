import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/challenge_records_repository.dart';
import '../domain/challenge.dart';

/// Stores challenge bests as one JSON object:
/// `{ "timeAttack": {"1": 1450, "2": 990}, "moveLimit": {...}, ... }`.
/// Deliberately a different key namespace from `progress.*` — challenge
/// results are fully separate from campaign progress.
class SharedPreferencesChallengeRecordsRepository
    implements ChallengeRecordsRepository {
  const SharedPreferencesChallengeRecordsRepository(this._preferences);

  static const _recordsKey = 'challenges.bestScores';

  final SharedPreferences _preferences;

  @override
  Future<Map<int, int>> getRecords(Challenge challenge) async {
    return _readAll()[challenge.storageKey] ?? <int, int>{};
  }

  @override
  Future<bool> saveRecord({
    required Challenge challenge,
    required int levelNumber,
    required int score,
  }) async {
    final all = _readAll();
    final records = Map<int, int>.of(all[challenge.storageKey] ?? <int, int>{});
    final current = records[levelNumber];
    if (current != null && current >= score) {
      return false;
    }
    records[levelNumber] = score;
    all[challenge.storageKey] = records;

    await _preferences.setString(
      _recordsKey,
      jsonEncode(
        all.map(
          (challengeKey, byLevel) => MapEntry(
            challengeKey,
            byLevel.map((level, best) => MapEntry('$level', best)),
          ),
        ),
      ),
    );
    return true;
  }

  Map<String, Map<int, int>> _readAll() {
    final encoded = _preferences.getString(_recordsKey);
    if (encoded == null || encoded.isEmpty) {
      return <String, Map<int, int>>{};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        return <String, Map<int, int>>{};
      }
      final result = <String, Map<int, int>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map<String, Object?>) {
          continue;
        }
        final byLevel = <int, int>{};
        for (final levelEntry in value.entries) {
          final level = int.tryParse(levelEntry.key);
          final best = levelEntry.value;
          if (level != null && best is int) {
            byLevel[level] = best;
          }
        }
        result[entry.key] = byLevel;
      }
      return result;
    } catch (_) {
      return <String, Map<int, int>>{};
    }
  }
}
