import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/progress/application/get_local_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/is_level_unlocked_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/local_progress_repository.dart';
import 'package:frontend_poc_arrow/features/progress/application/reset_local_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/save_level_completion_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/domain/level_best_result.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';

void main() {
  test('should_unlock_level_one_by_default', () async {
    final repository = _InMemoryLocalProgressRepository();
    final isUnlocked = IsLevelUnlockedUseCase(repository);

    expect(await isUnlocked(1), isTrue);
    expect(await isUnlocked(2), isFalse);
  });

  test('should_unlock_next_level_when_current_level_is_completed', () async {
    final repository = _InMemoryLocalProgressRepository();
    final saveCompletion = SaveLevelCompletionUseCase(repository);

    await saveCompletion(levelNumber: 1, score: 990, moves: 1, timeSeconds: 0);

    final progress = await repository.getProgress();
    expect(progress.isCompleted(1), isTrue);
    expect(progress.isUnlocked(2), isTrue);
  });

  test('should_save_best_score_when_new_score_is_better', () async {
    final repository = _InMemoryLocalProgressRepository(
      LocalProgress.initial().copyWith(
        bestResultsByLevel: const {
          1: LevelBestResult(score: 900, moves: 2, timeSeconds: 0),
        },
      ),
    );
    final saveCompletion = SaveLevelCompletionUseCase(repository);

    await saveCompletion(levelNumber: 1, score: 990, moves: 1, timeSeconds: 0);

    final progress = await repository.getProgress();
    expect(progress.bestResultFor(1)?.score, 990);
    expect(progress.bestResultFor(1)?.moves, 1);
  });

  test('should_keep_existing_best_score_when_new_score_is_worse', () async {
    final repository = _InMemoryLocalProgressRepository(
      LocalProgress.initial().copyWith(
        bestResultsByLevel: const {
          1: LevelBestResult(score: 990, moves: 1, timeSeconds: 0),
        },
      ),
    );
    final saveCompletion = SaveLevelCompletionUseCase(repository);

    await saveCompletion(levelNumber: 1, score: 900, moves: 4, timeSeconds: 0);

    final progress = await repository.getProgress();
    expect(progress.bestResultFor(1)?.score, 990);
    expect(progress.bestResultFor(1)?.moves, 1);
  });

  test('should_reset_local_progress_when_confirmed', () async {
    final repository = _InMemoryLocalProgressRepository();
    final saveCompletion = SaveLevelCompletionUseCase(repository);
    final resetProgress = ResetLocalProgressUseCase(repository);
    final getProgress = GetLocalProgressUseCase(repository);

    await saveCompletion(levelNumber: 1, score: 990, moves: 1, timeSeconds: 0);
    await resetProgress();

    final progress = await getProgress();
    expect(progress.completedLevelNumbers, isEmpty);
    expect(progress.bestResultsByLevel, isEmpty);
    expect(progress.lastUnlockedLevel, 1);
  });
}

class _InMemoryLocalProgressRepository implements LocalProgressRepository {
  _InMemoryLocalProgressRepository([LocalProgress? initialProgress])
    : _progress = initialProgress ?? LocalProgress.initial();

  LocalProgress _progress;

  @override
  Future<LocalProgress> getProgress() async {
    return _progress;
  }

  @override
  Future<void> saveProgress(LocalProgress progress) async {
    _progress = progress;
  }

  @override
  Future<void> resetProgress() async {
    _progress = LocalProgress.initial();
  }

  @override
  Future<String?> getLastSyncedUserId() async => _lastSyncedUserId;

  @override
  Future<void> setLastSyncedUserId(String? userId) async {
    _lastSyncedUserId = userId;
  }

  String? _lastSyncedUserId;
}
