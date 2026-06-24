import '../domain/level_best_result.dart';
import 'best_level_result_policy.dart';
import 'local_progress_repository.dart';
import '../../../core/config/app_config.dart';


class SaveLevelCompletionUseCase {
  const SaveLevelCompletionUseCase(
    this._repository, {
    this.bestResultPolicy = const BestLevelResultPolicy(),
    this.maxManualLevel = AppConfig.manualLevelCount,
  });

  final LocalProgressRepository _repository;
  final BestLevelResultPolicy bestResultPolicy;
  final int maxManualLevel;

  Future<void> call({
    required int levelNumber,
    required int score,
    required int moves,
    required int timeSeconds,
  }) async {
    final progress = await _repository.getProgress();
    final candidate = LevelBestResult(
      score: score,
      moves: moves,
      timeSeconds: timeSeconds,
    );
    final currentBest = progress.bestResultFor(levelNumber);
    final updatedBestResults = Map<int, LevelBestResult>.of(
      progress.bestResultsByLevel,
    );

    if (bestResultPolicy.isBetter(candidate: candidate, current: currentBest)) {
      updatedBestResults[levelNumber] = candidate;
    }

    final updatedCompleted = Set<int>.of(progress.completedLevelNumbers)
      ..add(levelNumber);
    final unlockedCandidate = levelNumber + 1;
    final updatedLastUnlocked = unlockedCandidate > maxManualLevel
        ? progress.lastUnlockedLevel
        : unlockedCandidate > progress.lastUnlockedLevel
        ? unlockedCandidate
        : progress.lastUnlockedLevel;

    await _repository.saveProgress(
      progress.copyWith(
        completedLevelNumbers: updatedCompleted,
        bestResultsByLevel: updatedBestResults,
        lastUnlockedLevel: updatedLastUnlocked,
      ),
    );
  }
}
