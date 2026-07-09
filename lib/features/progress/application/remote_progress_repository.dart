import '../domain/remote_progress_entry.dart';

abstract interface class RemoteProgressRepository {
  Future<List<RemoteProgressEntry>> getMyProgress();

  Future<void> syncProgress({
    required String levelId,
    required bool completed,
    required int? bestScore,
    required int? bestMoves,
    required int? bestTimeSeconds,
  });

  Future<void> resetProgress();
}
