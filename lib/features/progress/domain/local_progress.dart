import '../../settings/domain/game_mode.dart';
import 'level_best_result.dart';

/// Last internal level number reserved for 2D content (1-20). Mirrors
/// `twoDLevelCount` in the presentation-layer `level_mode_filter.dart`; kept
/// here so the domain unlock rule needs no presentation import.
const int _twoDLevelCount = 20;

class LocalProgress {
  const LocalProgress({
    required this.completedLevelNumbers,
    required this.bestResultsByLevel,
    required this.lastUnlockedLevel,
  });

  factory LocalProgress.initial() {
    return const LocalProgress(
      completedLevelNumbers: <int>{},
      bestResultsByLevel: <int, LevelBestResult>{},
      lastUnlockedLevel: 1,
    );
  }

  final Set<int> completedLevelNumbers;
  final Map<int, LevelBestResult> bestResultsByLevel;
  final int lastUnlockedLevel;

  bool isCompleted(int levelNumber) {
    return completedLevelNumbers.contains(levelNumber);
  }

  bool isUnlocked(int levelNumber) {
    return levelNumber <= lastUnlockedLevel || isCompleted(levelNumber);
  }

  /// Mode-aware unlock computed from the shared [completedLevelNumbers] set,
  /// which is naturally partitioned because 2D (1-20) and 3D (21-25) internal
  /// numbers never overlap. The first level of a mode (2D→1, 3D→21) is always
  /// unlocked; any later level unlocks once the previous internal level was
  /// completed. This is the authoritative rule for the level-selection gate;
  /// [isUnlocked] (scalar [lastUnlockedLevel]) is retained only for reset /
  /// backward-compat.
  /// Progression-order unlock: a level is unlocked when it is the first of
  /// its mode's progression ([previousLevelNumber] == null) or when the level
  /// preceding it in that progression has been completed. The caller supplies
  /// the predecessor from the mode's complexity-sorted [LevelProgression]
  /// (never from another mode's list). This is the authoritative rule for the
  /// level-selection gate since the dynamic-difficulty resequencing;
  /// [isUnlockedForMode] (fixed internal-number order) is retained as legacy.
  bool isUnlockedAfter(int? previousLevelNumber) {
    return previousLevelNumber == null || isCompleted(previousLevelNumber);
  }

  bool isUnlockedForMode(int levelNumber, GameMode mode) {
    final firstInternalLevel = mode == GameMode.threeD ? _twoDLevelCount + 1 : 1;
    if (levelNumber == firstInternalLevel) {
      return true;
    }
    return isCompleted(levelNumber - 1);
  }

  LevelBestResult? bestResultFor(int levelNumber) {
    return bestResultsByLevel[levelNumber];
  }

  LocalProgress copyWith({
    Set<int>? completedLevelNumbers,
    Map<int, LevelBestResult>? bestResultsByLevel,
    int? lastUnlockedLevel,
  }) {
    return LocalProgress(
      completedLevelNumbers:
          completedLevelNumbers ?? this.completedLevelNumbers,
      bestResultsByLevel: bestResultsByLevel ?? this.bestResultsByLevel,
      lastUnlockedLevel: lastUnlockedLevel ?? this.lastUnlockedLevel,
    );
  }
}
