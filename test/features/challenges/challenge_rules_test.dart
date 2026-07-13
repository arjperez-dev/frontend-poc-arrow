import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/game/application/game_session_service.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_result.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_status.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game/game_test_fixtures.dart';

void main() {
  const service = GameSessionService();

  // arrow-1 covers [a,b] and collides against arrow-2 on [c,d].
  final collidingArrows = const [
    ArrowPathDefinition(
      id: 'arrow-1',
      occupiedEdgeIds: ['ab'],
      startNodeId: 'a',
      endNodeId: 'b',
      direction: Direction.right,
    ),
    ArrowPathDefinition(
      id: 'arrow-2',
      occupiedEdgeIds: ['cd'],
      startNodeId: 'd',
      endNodeId: 'c',
      direction: Direction.left,
    ),
  ];

  group('move limit', () {
    test('should_fail_when_move_budget_is_exceeded', () {
      const context = ChallengeContext(
        challenge: Challenge.moveLimit,
        timeLimitSeconds: 120,
        maxMoves: 1,
      );
      var session = service.start(
        buildLevel(collisionDefinition(arrows: collidingArrows)),
        challenge: context,
      );

      // Move 1 (collision) uses the entire budget.
      final first = service.activateArrow(session, 'arrow-1');
      expect(first.session.status, GameStatus.playing);
      session = first.session;

      // Move 2 exceeds the budget: run over, regardless of the attempt.
      final second = service.activateArrow(session, 'arrow-2');
      expect(second.outcome, MovementOutcome.gameOver);
      expect(second.session.status, GameStatus.failed);
    });

    test('should_allow_victory_on_the_last_budgeted_move', () {
      const context = ChallengeContext(
        challenge: Challenge.moveLimit,
        timeLimitSeconds: 120,
        maxMoves: 1,
      );
      final session = service.start(
        buildLevel(basicDefinition()),
        challenge: context,
      );

      final result = service.activateArrow(session, 'arrow-1');
      expect(result.outcome, MovementOutcome.escaped);
      expect(result.session.status, GameStatus.victory);
    });
  });

  group('perfect run', () {
    test('should_fail_on_the_first_mistake_regardless_of_lives', () {
      const context = ChallengeContext(
        challenge: Challenge.perfectRun,
        timeLimitSeconds: 120,
        maxMoves: 30,
      );
      final session = service.start(
        buildLevel(collisionDefinition(arrows: collidingArrows)),
        challenge: context,
      );

      final result = service.activateArrow(session, 'arrow-1');
      expect(result.outcome, MovementOutcome.gameOver);
      expect(result.session.status, GameStatus.failed);
      expect(result.session.mistakeCount, 1);
      expect(
        result.session.livesRemaining,
        greaterThan(0),
        reason: 'perfect run must fail before the lives system matters',
      );
    });
  });

  group('time attack clock', () {
    test('should_fail_when_the_clock_reaches_the_limit', () {
      const context = ChallengeContext(
        challenge: Challenge.timeAttack,
        timeLimitSeconds: 2,
        maxMoves: 30,
      );
      var session = service.start(
        buildLevel(basicDefinition()),
        challenge: context,
      );

      session = service.tickClock(session);
      expect(session.status, GameStatus.playing);
      expect(session.remainingSeconds, 1);

      session = service.tickClock(session);
      expect(session.status, GameStatus.failed);
      expect(session.remainingSeconds, 0);
    });

    test('should_not_tick_after_the_session_has_ended', () {
      const context = ChallengeContext(
        challenge: Challenge.timeAttack,
        timeLimitSeconds: 1,
        maxMoves: 30,
      );
      var session = service.start(
        buildLevel(basicDefinition()),
        challenge: context,
      );
      session = service.tickClock(session);
      expect(session.status, GameStatus.failed);

      final after = service.tickClock(session);
      expect(after.elapsedSeconds, session.elapsedSeconds);
    });
  });

  group('lives are campaign-only', () {
    test('should_not_game_over_on_six_collisions_during_time_attack', () {
      // Regression (user-reported): with time still on the clock, the sixth
      // collision used to trigger the campaign lives rule and end the run.
      const context = ChallengeContext(
        challenge: Challenge.timeAttack,
        timeLimitSeconds: 300,
        maxMoves: 30,
      );
      var session = service.start(
        buildLevel(collisionDefinition(arrows: collidingArrows)),
        challenge: context,
      );

      for (var i = 0; i < 8; i++) {
        final result = service.activateArrow(session, 'arrow-1');
        expect(
          result.outcome,
          MovementOutcome.collision,
          reason: 'collision ${i + 1} must not end a time attack run',
        );
        session = result.session;
      }
      expect(session.status, GameStatus.playing);
      expect(session.mistakeCount, 8);
      expect(session.livesRemaining <= 0, isTrue,
          reason: 'lives are exhausted, and it must not matter');
    });

    test('should_not_game_over_on_lives_during_move_limit', () {
      // Under Move Limit the only mistake cost is the wasted budget.
      const context = ChallengeContext(
        challenge: Challenge.moveLimit,
        timeLimitSeconds: 300,
        maxMoves: 10,
      );
      var session = service.start(
        buildLevel(collisionDefinition(arrows: collidingArrows)),
        challenge: context,
      );

      for (var i = 0; i < 7; i++) {
        session = service.activateArrow(session, 'arrow-1').session;
      }
      expect(session.status, GameStatus.playing);
      expect(session.remainingMoves, 3);
    });
  });

  group('campaign sessions (no challenge)', () {
    test('should_keep_pre_challenge_behavior_when_challenge_is_null', () {
      final session = service.start(
        buildLevel(collisionDefinition(arrows: collidingArrows)),
      );

      final result = service.activateArrow(session, 'arrow-1');
      // A single collision is a plain collision — no challenge rule fires,
      // lives system unchanged, clock helpers absent.
      expect(result.outcome, MovementOutcome.collision);
      expect(result.session.status, GameStatus.playing);
      expect(session.remainingSeconds, isNull);
      expect(session.remainingMoves, isNull);

      // The clock advances but never fails a campaign session.
      final ticked = service.tickClock(result.session);
      expect(ticked.elapsedSeconds, 1);
      expect(ticked.status, GameStatus.playing);
    });
  });
}
