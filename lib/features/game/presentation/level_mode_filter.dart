import '../../../core/config/app_config.dart';
import '../../progress/domain/local_progress.dart';
import '../../settings/domain/game_mode.dart';
import '../domain/board_topology.dart';
import '../domain/level.dart';

/// Last internal level number reserved for 2D content (1-20). Internal
/// numbers 21-[AppConfig.manualLevelCount] are 3D. Presentation-only: the
/// internal numbers themselves are never changed anywhere else.
const int twoDLevelCount = 20;

/// First internal number reserved for hex content. Internal numbers
/// [hexLevelRangeStart]-[hexLevelCount] are hex; the wider band
/// 31-50 is reserved (only 31-40 are shipped so far — see
/// `manual_levels_hex.json`), leaving headroom below the remote band.
const int hexLevelRangeStart = 31;

/// Last *shipped* internal hex level number. Distinct from the reserved
/// band's upper bound (50) — this is the actual max playable hex level today.
const int hexLevelCount = 40;

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
///
/// Does NOT distinguish hex from 2D/3D — callers that need all three modes
/// must use [modeOfLevel] instead, which checks hex first. Kept for the
/// remaining 2D/3D-only callers (e.g. the legacy [LocalProgress] unlock
/// rule) so their behavior stays byte-for-byte unchanged.
bool isThreeDLevel(Level level) {
  final number = level.number ?? 0;
  if (number >= _remoteLevelNumberFloor) {
    return level.boardGraph.isMultiLayer;
  }
  return level.boardGraph.isMultiLayer || number > twoDLevelCount;
}

/// The authoritative mode router across all three modes.
///
/// **Important, non-obvious departure from the 2D/3D rule:** 2D vs. 3D is
/// decided from graph shape alone (`isMultiLayer`, Phase 34.1's "graph shape
/// is the source of truth" rule). Hex canNOT use that rule: axial `(q, r)`
/// hex coordinates and square `(x, y)` coordinates both live in the same
/// integer `BoardCoordinate.x/y` lattice, so a hex graph and a square graph
/// are structurally indistinguishable by node coordinates alone — a
/// single-layer hex board and a single-layer square board look identical to
/// any shape-based check. Hex is therefore read from
/// [BoardTopology] (itself sourced from the level's `metadata.topology`
/// field, threaded through by `LevelDefinitionValidator`/`BoardGraph` in
/// Phase 37.1), checked BEFORE the shape-based 2D/3D fallback. Do not "fix"
/// this back to a shape-only check — it would silently misroute every hex
/// level (their local numbers are 31+, above [twoDLevelCount], so
/// [isThreeDLevel]'s numeric fallback would otherwise classify them as 3D).
GameMode modeOfLevel(Level level) {
  if (level.boardGraph.topology == BoardTopology.hex) {
    return GameMode.hex;
  }
  return isThreeDLevel(level) ? GameMode.threeD : GameMode.twoD;
}

List<Level> filterLevelsByGameMode(
  List<Level> levels, {
  required GameMode mode,
}) {
  return levels.where((level) => modeOfLevel(level) == mode).toList(
    growable: false,
  );
}

/// Maps an internal level number to the number shown in the UI: 1-based
/// position within [mode]'s own range. 2D displays unchanged (1-20); 3D
/// displays 1-10 instead of 21-30; hex displays 1-10 instead of 31-40. The
/// internal number is never mutated — only what's rendered changes.
int displayNumberFor(int internalLevel, GameMode mode) {
  return internalLevel - firstInternalLevelFor(mode) + 1;
}

/// The last *internal* level number playable in [mode] — used to decide
/// whether a "next level" exists, instead of comparing against the global
/// [AppConfig.manualLevelCount] regardless of mode.
int maxInternalLevelFor(GameMode mode) {
  return switch (mode) {
    GameMode.twoD => twoDLevelCount,
    GameMode.threeD => AppConfig.manualLevelCount,
    GameMode.hex => hexLevelCount,
  };
}

bool hasNextLevelFor(int internalLevel, GameMode mode) {
  return internalLevel < maxInternalLevelFor(mode);
}

/// First internal level number playable in [mode]: 1 for 2D, 21 for 3D, 31
/// for hex.
int firstInternalLevelFor(GameMode mode) {
  return switch (mode) {
    GameMode.twoD => 1,
    GameMode.threeD => twoDLevelCount + 1,
    GameMode.hex => hexLevelRangeStart,
  };
}

/// LEGACY (Phase 29 dynamic-difficulty resequencing): fixed internal-number
/// unlock order, superseded by the complexity-sorted progression gate
/// (`LevelProgression` + [LocalProgress.isUnlockedAfter]) used by the level
/// selection screen. Kept, with its tests, for the pre-resequencing rule.
/// Not extended to hex — [LocalProgress.isUnlockedForMode] stays 2D/3D-only,
/// since the progression gate is what actually drives every mode's unlock,
/// including hex's, in production.
///
/// Mode-aware unlock: the first level of a mode is always unlocked; any later
/// level unlocks once the previous internal level was completed. Uses the
/// shared completedLevelNumbers set, which is naturally partitioned because
/// 2D (1-20) and 3D (21-30) internal numbers never overlap. Delegates to the
/// domain rule ([LocalProgress.isUnlockedForMode]).
bool isLevelUnlockedForMode(
  LocalProgress progress,
  int internalLevel,
  GameMode mode,
) {
  return progress.isUnlockedForMode(internalLevel, mode);
}
