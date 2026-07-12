import '../../game/application/score_strategy.dart';
import '../../game/domain/score.dart';
import '../domain/challenge.dart';

/// Strategy-pattern showcase: each challenge swaps in its own concrete
/// [ScoreStrategy] behind the unchanged interface, so the same session
/// counters (moves, mistakes, elapsed time) produce challenge-appropriate
/// scores without a single `if (challenge == …)` inside the scoring flow.
/// The only selection point is [scoreStrategyForChallenge].

/// score = max(0, 1000 − mistakes·100 − moves·5 + remainingSeconds·10)
///
/// Speed dominates: every second left on the clock is worth 10 points —
/// finishing a 120s level in 30s adds +900, dwarfing the move penalty.
class TimeAttackScoreStrategy implements ScoreStrategy {
  const TimeAttackScoreStrategy({required this.timeLimitSeconds});

  final int timeLimitSeconds;

  @override
  Score calculate({
    required int movesCount,
    required int mistakeCount,
    required int elapsedSeconds,
  }) {
    final remaining = timeLimitSeconds - elapsedSeconds;
    final bonus = remaining > 0 ? remaining * 10 : 0;
    final value = 1000 - (mistakeCount * 100) - (movesCount * 5) + bonus;
    return Score(value < 0 ? 0 : value);
  }
}

/// score = max(0, 1000 − mistakes·100 + unusedMoves·25)
///
/// Efficiency dominates: every move left in the budget is worth 25 points,
/// so the per-move cost (vs. the campaign's flat −5) is what the player
/// optimizes. Time is irrelevant.
class MoveLimitScoreStrategy implements ScoreStrategy {
  const MoveLimitScoreStrategy({required this.maxMoves});

  final int maxMoves;

  @override
  Score calculate({
    required int movesCount,
    required int mistakeCount,
    required int elapsedSeconds,
  }) {
    final unused = maxMoves - movesCount;
    final bonus = unused > 0 ? unused * 25 : 0;
    final value = 1000 - (mistakeCount * 100) + bonus;
    return Score(value < 0 ? 0 : value);
  }
}

/// score = max(0, 1500 − moves·10)
///
/// Mistakes don't appear in the formula because a single mistake already
/// ends the run; the higher base rewards taking that risk, and only move
/// efficiency separates two perfect clears.
class PerfectRunScoreStrategy implements ScoreStrategy {
  const PerfectRunScoreStrategy();

  @override
  Score calculate({
    required int movesCount,
    required int mistakeCount,
    required int elapsedSeconds,
  }) {
    final value = 1500 - (movesCount * 10);
    return Score(value < 0 ? 0 : value);
  }
}

/// The single strategy-selection point. Campaign sessions (no challenge)
/// keep the existing [DefaultScoreStrategy] untouched.
ScoreStrategy scoreStrategyForChallenge(ChallengeContext? context) {
  if (context == null) {
    return const DefaultScoreStrategy();
  }
  return switch (context.challenge) {
    Challenge.timeAttack =>
      TimeAttackScoreStrategy(timeLimitSeconds: context.timeLimitSeconds),
    Challenge.moveLimit => MoveLimitScoreStrategy(maxMoves: context.maxMoves),
    Challenge.perfectRun => const PerfectRunScoreStrategy(),
  };
}
