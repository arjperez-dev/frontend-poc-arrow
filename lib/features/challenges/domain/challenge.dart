import '../../game/domain/level.dart';

/// A gameplay modifier applied on top of an existing level. Challenges are
/// fully separate from campaign progress: they never unlock levels, never
/// touch best scores or the leaderboard, and record their own bests.
/// [storageKey] is the stable persisted value (same pattern as [GameMode]).
enum Challenge {
  timeAttack('timeAttack'),
  moveLimit('moveLimit'),
  perfectRun('perfectRun');

  const Challenge(this.storageKey);

  final String storageKey;

  static Challenge? fromStorageKey(String? key) {
    for (final challenge in Challenge.values) {
      if (challenge.storageKey == key) {
        return challenge;
      }
    }
    return null;
  }
}

/// The active challenge plus the level-specific limits it plays under.
///
/// Limits are CALCULATED from the board, not read from static metadata.
/// The anchor is the minimal solve: greedy solvability guarantees an order
/// where every arrow escapes on its first tap, so the minimum number of
/// moves is exactly `level.arrows.length`. Both limits scale from it,
/// tightened by the level's difficulty tier:
///
/// - Time Attack: `max(30s, arrows × secondsPerArrow − 20s)` — 5s/arrow on
///   easy, 4s on medium, 3s on hard, with a flat 20s tightening so the
///   clock always presses. Bigger boards get more time; harder tiers get
///   proportionally less thinking room per arrow.
/// - Move Limit: `arrows + slack` — 5 spare moves on easy, 3 on medium,
///   2 on hard (a slack move is spent by every collision).
class ChallengeContext {
  const ChallengeContext({
    required this.challenge,
    required this.timeLimitSeconds,
    required this.maxMoves,
  });

  factory ChallengeContext.forLevel(Challenge challenge, Level level) {
    final minimalMoves = level.arrows.length;
    final difficulty = level.metadata['difficulty'] as String?;
    final computedTime =
        minimalMoves * _secondsPerArrow(difficulty) - timeTighteningSeconds;
    return ChallengeContext(
      challenge: challenge,
      timeLimitSeconds: computedTime < minTimeLimitSeconds
          ? minTimeLimitSeconds
          : computedTime,
      maxMoves: minimalMoves + _moveSlack(difficulty),
    );
  }

  /// Floor so tiny boards never get an unplayably short clock.
  static const int minTimeLimitSeconds = 30;

  /// Flat reduction applied to every Time Attack clock (playtest tuning:
  /// the per-arrow allowance alone left too much idle time).
  static const int timeTighteningSeconds = 20;

  static int _secondsPerArrow(String? difficulty) {
    return switch (difficulty) {
      'easy' => 5,
      'medium' => 4,
      'hard' => 3,
      _ => 4,
    };
  }

  static int _moveSlack(String? difficulty) {
    return switch (difficulty) {
      'easy' => 5,
      'medium' => 3,
      'hard' => 2,
      _ => 3,
    };
  }

  final Challenge challenge;
  final int timeLimitSeconds;
  final int maxMoves;
}
