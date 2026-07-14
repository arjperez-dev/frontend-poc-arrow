import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/progress/application/get_local_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/is_level_unlocked_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/local_progress_repository.dart';
import 'package:frontend_poc_arrow/features/progress/application/reset_local_progress_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/application/save_level_completion_use_case.dart';
import 'package:frontend_poc_arrow/features/progress/domain/level_best_result.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

void main() {
  test('should_unlock_level_one_by_default', () async {
    final repository = _InMemoryLocalProgressRepository();
    final isUnlocked = IsLevelUnlockedUseCase(repository);

    expect(await isUnlocked(1, GameMode.twoD), isTrue);
    expect(await isUnlocked(2, GameMode.twoD), isFalse);
  });

  test('should_unlock_first_3d_level_by_default', () async {
    final repository = _InMemoryLocalProgressRepository();
    final isUnlocked = IsLevelUnlockedUseCase(repository);

    // Internal 21 is the first 3D level; unlocked with empty progress.
    expect(await isUnlocked(21, GameMode.threeD), isTrue);
    expect(await isUnlocked(22, GameMode.threeD), isFalse);
  });

  test('should_isolate_unlock_between_modes', () async {
    // Completing 2D level 20 must NOT unlock 3D internal 21, and completing
    // 3D internal 21 must NOT unlock 2D level 2. The shared set is partitioned
    // purely by the globally-unique internal numbers.
    // Internal 21 is the first 3D level, so it is always unlocked — the
    // isolation guarantee is that completing 2D level 20 does not bleed forward
    // into the *second* 3D level (internal 22).
    final completed2D20 = LocalProgress.initial().copyWith(
      completedLevelNumbers: const <int>{20},
    );
    expect(completed2D20.isUnlockedForMode(22, GameMode.threeD), isFalse);

    final completed3D21 = LocalProgress.initial().copyWith(
      completedLevelNumbers: const <int>{21},
    );
    expect(completed3D21.isUnlockedForMode(2, GameMode.twoD), isFalse);
    // But it does unlock the next 3D level.
    expect(completed3D21.isUnlockedForMode(22, GameMode.threeD), isTrue);
  });

  test('should_unlock_progression_first_level_and_gate_on_predecessor', () {
    // isUnlockedAfter is the authoritative gate since the dynamic-difficulty
    // resequencing: null predecessor = first in the mode's sorted
    // progression (always open); otherwise the predecessor must be done.
    final progress = LocalProgress.initial().copyWith(
      completedLevelNumbers: const <int>{9},
    );

    expect(progress.isUnlockedAfter(null), isTrue);
    expect(progress.isUnlockedAfter(9), isTrue);
    expect(progress.isUnlockedAfter(4), isFalse);
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
