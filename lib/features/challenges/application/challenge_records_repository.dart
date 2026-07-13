import '../domain/challenge.dart';

/// Best challenge scores, keyed by challenge and internal level number.
/// Fully separate from campaign progress by design (user decision): saving
/// a challenge record never touches LocalProgress, sync, or the leaderboard.
abstract interface class ChallengeRecordsRepository {
  /// Best score per level number for [challenge]; empty when none.
  Future<Map<int, int>> getRecords(Challenge challenge);

  /// Persists [score] for ([challenge], [levelNumber]) if it beats the
  /// stored best. Returns true when a new record was written.
  Future<bool> saveRecord({
    required Challenge challenge,
    required int levelNumber,
    required int score,
  });
}
