import '../../../core/config/app_config.dart';
import '../../progress/domain/local_progress.dart';
import '../../settings/domain/game_mode.dart';
import '../domain/level.dart';

/// Last internal level number reserved for 2D content (1-20). Internal
/// numbers 21-[AppConfig.manualLevelCount] are 3D. Presentation-only: the
/// internal numbers themselves are never changed anywhere else.
const int twoDLevelCount = 20;

/// Numbers at or above this floor are backend-served remote levels (Phase
/// 34.1 `DYNAMIC_LEVELS_CONTRACT.md` §2) — their graph shape is always the
/// real, reliable signal, so the local-only numeric fallback below must not
/// apply to them (a remote 2D level's number is always > [twoDLevelCount]
/// and would otherwise be misrouted as 3D).
const int _remoteLevelNumberFloor = 1000;

/// A level is 3D when its board has more than one layer, or — for a *local*
/// level whose board hasn't been fully resolved — its number falls in the
/// reserved 3D range (21-30). Presentation-only: does not touch domain,
/// application, or the level loader.
bool isThreeDLevel(Level level) {
  final number = level.number ?? 0;
  if (number >= _remoteLevelNumberFloor) {
    return level.boardGraph.isMultiLayer;
  }
  return level.boardGraph.isMultiLayer || number > twoDLevelCount;
}

List<Level> filterLevelsByGameMode(
  List<Level> levels, {
  required bool wantThreeD,
}) {
  return levels.where((level) => isThreeDLevel(level) == wantThreeD).toList(
    growable: false,
  );
}

/// Maps an internal level number to the number shown in the UI. 2D levels
/// display unchanged (1-20); 3D levels display as 1-5 instead of 21-25. The
/// internal number is never mutated — only what's rendered changes.
int displayNumberFor(int internalLevel, GameMode mode) {
  return mode == GameMode.threeD ? internalLevel - twoDLevelCount : internalLevel;
}

/// The last *internal* level number playable in [mode] — used to decide
/// whether a "next level" exists, instead of comparing against the global
/// [AppConfig.manualLevelCount] regardless of mode.
int maxInternalLevelFor(GameMode mode) {
  return mode == GameMode.threeD ? AppConfig.manualLevelCount : twoDLevelCount;
}

bool hasNextLevelFor(int internalLevel, GameMode mode) {
  return internalLevel < maxInternalLevelFor(mode);
}

/// First internal level number playable in [mode]: 1 for 2D, 21 for 3D.
int firstInternalLevelFor(GameMode mode) =>
    mode == GameMode.threeD ? twoDLevelCount + 1 : 1;

/// LEGACY (Phase 29 dynamic-difficulty resequencing): fixed internal-number
/// unlock order, superseded by the complexity-sorted progression gate
/// (`LevelProgression` + [LocalProgress.isUnlockedAfter]) used by the level
/// selection screen. Kept, with its tests, for the pre-resequencing rule.
///
/// Mode-aware unlock: the first level of a mode is always unlocked; any later
/// level unlocks once the previous internal level was completed. Uses the
/// shared completedLevelNumbers set, which is naturally partitioned because
/// 2D (1-20) and 3D (21-25) internal numbers never overlap. Delegates to the
/// domain rule ([LocalProgress.isUnlockedForMode]).
bool isLevelUnlockedForMode(
  LocalProgress progress,
  int internalLevel,
  GameMode mode,
) {
  return progress.isUnlockedForMode(internalLevel, mode);
}
