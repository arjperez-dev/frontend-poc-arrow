import '../domain/level_best_result.dart';
import '../domain/local_progress.dart';
import '../domain/remote_progress_entry.dart';
import 'best_level_result_policy.dart';
import '../../../core/config/app_config.dart';

class MergeProgressUseCase {
  const MergeProgressUseCase({
    this.bestResultPolicy = const BestLevelResultPolicy(),
    this.maxManualLevel = AppConfig.manualLevelCount,
  });

  final BestLevelResultPolicy bestResultPolicy;
  final int maxManualLevel;

  LocalProgress call({
    required LocalProgress local,
    required List<RemoteProgressEntry> remoteEntries,
    required Map<int, String> levelIdsByNumber,
  }) {
    final levelNumbersById = levelIdsByNumber.map((number, id) {
      return MapEntry(id, number);
    });
    final completed = Set<int>.of(local.completedLevelNumbers);
    final bestResults = Map<int, LevelBestResult>.of(local.bestResultsByLevel);
    var lastUnlockedLevel = local.lastUnlockedLevel;

    for (final remote in remoteEntries) {
      final levelNumber = levelNumbersById[remote.levelId];
      if (levelNumber == null) {
        continue;
      }
      if (remote.completed) {
        completed.add(levelNumber);
        final unlockedCandidate = levelNumber + 1;
        if (unlockedCandidate <= maxManualLevel && unlockedCandidate > lastUnlockedLevel) {
          lastUnlockedLevel = unlockedCandidate;
        }
      }
      final remoteBest = _bestResultFrom(remote);
      if (remoteBest != null &&
          bestResultPolicy.isBetter(
            candidate: remoteBest,
            current: bestResults[levelNumber],
          )) {
        bestResults[levelNumber] = remoteBest;
      }
    }

    return local.copyWith(
      completedLevelNumbers: completed,
      bestResultsByLevel: bestResults,
      lastUnlockedLevel: lastUnlockedLevel,
    );
  }

  LevelBestResult? _bestResultFrom(RemoteProgressEntry remote) {
    final score = remote.bestScore;
    final moves = remote.bestMoves;
    final timeSeconds = remote.bestTimeSeconds;
    if (score == null || moves == null || timeSeconds == null) {
      return null;
    }
    return LevelBestResult(
      score: score,
      moves: moves,
      timeSeconds: timeSeconds,
    );
  }
}
