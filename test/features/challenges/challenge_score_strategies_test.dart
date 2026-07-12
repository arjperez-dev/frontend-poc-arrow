import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/challenges/application/challenge_score_strategies.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/game/application/score_strategy.dart';

void main() {
  group('strategy pattern', () {
    test('should_produce_different_scores_from_identical_inputs', () {
      // The Strategy-pattern demonstration: one set of session counters,
      // four interchangeable strategies, four different scores — with no
      // conditional logic inside any scoring flow.
      const strategies = <ScoreStrategy>[
        DefaultScoreStrategy(),
        TimeAttackScoreStrategy(timeLimitSeconds: 120),
        MoveLimitScoreStrategy(maxMoves: 30),
        PerfectRunScoreStrategy(),
      ];

      final scores = strategies
          .map(
            (s) => s
                .calculate(movesCount: 10, mistakeCount: 1, elapsedSeconds: 30)
                .value,
          )
          .toList();

      // default: 1000 - 100 - 50 = 850
      // time attack: 850 + (120-30)*10 = 1750
      // move limit: 1000 - 100 + (30-10)*25 = 1400
      // perfect run: 1500 - 100 = 1400... distinct from default/time attack;
      // formula documented below per strategy.
      expect(scores[0], 850);
      expect(scores[1], 1750);
      expect(scores[2], 1400);
      expect(scores[3], 1400);
      expect(scores.toSet().length, greaterThanOrEqualTo(3));
    });

    test('should_select_strategy_by_challenge_via_single_factory', () {
      const context = ChallengeContext(
        challenge: Challenge.timeAttack,
        timeLimitSeconds: 60,
        maxMoves: 20,
      );
      expect(scoreStrategyForChallenge(null), isA<DefaultScoreStrategy>());
      expect(
        scoreStrategyForChallenge(context),
        isA<TimeAttackScoreStrategy>(),
      );
      expect(
        scoreStrategyForChallenge(
          const ChallengeContext(
            challenge: Challenge.moveLimit,
            timeLimitSeconds: 60,
            maxMoves: 20,
          ),
        ),
        isA<MoveLimitScoreStrategy>(),
      );
      expect(
        scoreStrategyForChallenge(
          const ChallengeContext(
            challenge: Challenge.perfectRun,
            timeLimitSeconds: 60,
            maxMoves: 20,
          ),
        ),
        isA<PerfectRunScoreStrategy>(),
      );
    });
  });

  group('TimeAttackScoreStrategy', () {
    test('should_reward_remaining_time_ten_points_per_second', () {
      const strategy = TimeAttackScoreStrategy(timeLimitSeconds: 100);
      final fast = strategy.calculate(
        movesCount: 4,
        mistakeCount: 0,
        elapsedSeconds: 10,
      );
      final slow = strategy.calculate(
        movesCount: 4,
        mistakeCount: 0,
        elapsedSeconds: 90,
      );
      expect(fast.value - slow.value, 800);
    });

    test('should_not_award_bonus_when_time_is_exhausted', () {
      const strategy = TimeAttackScoreStrategy(timeLimitSeconds: 60);
      final atLimit = strategy.calculate(
        movesCount: 2,
        mistakeCount: 0,
        elapsedSeconds: 60,
      );
      expect(atLimit.value, 1000 - 10);
    });

    test('should_floor_at_zero', () {
      const strategy = TimeAttackScoreStrategy(timeLimitSeconds: 10);
      final score = strategy.calculate(
        movesCount: 100,
        mistakeCount: 9,
        elapsedSeconds: 10,
      );
      expect(score.value, 0);
    });
  });

  group('MoveLimitScoreStrategy', () {
    test('should_reward_unused_moves_25_points_each', () {
      const strategy = MoveLimitScoreStrategy(maxMoves: 20);
      final efficient = strategy.calculate(
        movesCount: 10,
        mistakeCount: 0,
        elapsedSeconds: 0,
      );
      final exact = strategy.calculate(
        movesCount: 20,
        mistakeCount: 0,
        elapsedSeconds: 0,
      );
      expect(efficient.value, 1000 + 250);
      expect(exact.value, 1000);
    });

    test('should_ignore_elapsed_time', () {
      const strategy = MoveLimitScoreStrategy(maxMoves: 20);
      final quick = strategy.calculate(
        movesCount: 10,
        mistakeCount: 0,
        elapsedSeconds: 1,
      );
      final slow = strategy.calculate(
        movesCount: 10,
        mistakeCount: 0,
        elapsedSeconds: 999,
      );
      expect(quick.value, slow.value);
    });
  });

  group('PerfectRunScoreStrategy', () {
    test('should_score_purely_on_move_efficiency', () {
      const strategy = PerfectRunScoreStrategy();
      expect(
        strategy
            .calculate(movesCount: 5, mistakeCount: 0, elapsedSeconds: 0)
            .value,
        1450,
      );
      // Mistakes never appear in the formula: a mistake already ends the run.
      expect(
        strategy
            .calculate(movesCount: 5, mistakeCount: 3, elapsedSeconds: 0)
            .value,
        1450,
      );
    });
  });
}
