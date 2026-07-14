import '../domain/level.dart';
import 'level_complexity.dart';

/// One level inside a [LevelProgression]: the level plus its computed
/// complexity.
class LevelProgressionEntry {
  const LevelProgressionEntry({required this.level, required this.complexity});

  final Level level;
  final LevelComplexity complexity;
}

/// The ordered progression for ONE game mode: levels sorted ascending by
/// computed complexity score (stable tie-break on internal number).
///
/// Callers must pass a single-mode list (already filtered 2D-only or
/// 3D-only) — 2D and 3D levels are never mixed in one progression; each mode
/// builds its own instance from its own filtered list.
///
/// The sorted position drives everything user-facing: display numbers are
/// 1..N by position, a level unlocks when the previous level IN THIS ORDER is
/// completed, and "next level" is the next entry. Internal level numbers stay
/// untouched everywhere else (storage, routing, leaderboard).
class LevelProgression {
  LevelProgression._(this.entries)
      : _indexByNumber = {
          for (var i = 0; i < entries.length; i++)
            if (entries[i].level.number != null) entries[i].level.number!: i,
        };

  factory LevelProgression.fromLevels(
    List<Level> levels, {
    LevelComplexityAnalyzer analyzer = const LevelComplexityAnalyzer(),
  }) {
    final entries = [
      for (final level in levels)
        LevelProgressionEntry(level: level, complexity: analyzer.analyze(level)),
    ]..sort((a, b) {
        final byScore = a.complexity.score.compareTo(b.complexity.score);
        if (byScore != 0) {
          return byScore;
        }
        return (a.level.number ?? 0).compareTo(b.level.number ?? 0);
      });
    return LevelProgression._(List.unmodifiable(entries));
  }

  /// Easiest → hardest.
  final List<LevelProgressionEntry> entries;

  final Map<int, int> _indexByNumber;

  List<Level> get levels =>
      [for (final entry in entries) entry.level];

  /// 1-based position of [internalNumber] in the progression — the number
  /// shown in the UI. Null when the level is not part of this progression.
  int? displayNumberOf(int internalNumber) {
    final index = _indexByNumber[internalNumber];
    return index == null ? null : index + 1;
  }

  LevelComplexity? complexityOf(int internalNumber) {
    final index = _indexByNumber[internalNumber];
    return index == null ? null : entries[index].complexity;
  }

  /// Internal number of the level preceding [internalNumber] in the
  /// progression; null for the first level (or an unknown number).
  int? previousInternalBefore(int internalNumber) {
    final index = _indexByNumber[internalNumber];
    if (index == null || index == 0) {
      return null;
    }
    return entries[index - 1].level.number;
  }

  /// Internal number of the level following [internalNumber] in the
  /// progression; null for the last level (or an unknown number).
  int? nextInternalAfter(int internalNumber) {
    final index = _indexByNumber[internalNumber];
    if (index == null || index >= entries.length - 1) {
      return null;
    }
    return entries[index + 1].level.number;
  }
}
