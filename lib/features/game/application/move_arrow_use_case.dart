import '../../challenges/application/challenge_score_strategies.dart';
import '../../challenges/domain/challenge.dart';
import '../domain/arrow_path.dart';
import '../domain/game_session.dart';
import '../domain/game_status.dart';
import 'check_victory_use_case.dart';
import 'move_arrow_command.dart';
import 'movement_resolver.dart';
import 'movement_result.dart';
import 'score_calculator.dart';

class MoveArrowUseCase {
  const MoveArrowUseCase({
    this.movementResolver = const MovementResolver(),
    this.checkVictory = const CheckVictoryUseCase(),
    this.scoreCalculator = const ScoreCalculator(),
  });

  final MovementResolver movementResolver;
  final CheckVictoryUseCase checkVictory;
  final ScoreCalculator scoreCalculator;

  MovementResult execute({
    required GameSession session,
    required MoveArrowCommand command,
  }) {
    // Guard: session must be in playing state.
    if (session.status != GameStatus.playing) {
      return MovementResult(
        session: session,
        outcome: MovementOutcome.sessionNotActive,
      );
    }

    final arrow = session.arrowById(command.arrowId);
    if (arrow == null) {
      return MovementResult(
        session: session,
        outcome: MovementOutcome.arrowNotFound,
      );
    }

    if (arrow.isEscaped) {
      return MovementResult(
        session: session,
        outcome: MovementOutcome.alreadyEscaped,
      );
    }

    // Simulate the full exit attempt (read-only).
    final outcome = movementResolver.resolve(session: session, arrow: arrow);

    // Every tap counts as one move regardless of success or failure.
    final updatedMoves = session.movesCount + 1;

    // Challenge scoring: the strategy is selected per session (Strategy
    // pattern) — campaign sessions keep the injected default calculator.
    final calculator = session.challenge == null
        ? scoreCalculator
        : ScoreCalculator(
            strategy: scoreStrategyForChallenge(session.challenge),
          );

    // Move Limit rule: the budget is spent BEFORE the attempt resolves —
    // a tap beyond the last budgeted move fails the run outright (the
    // attempt is not applied), mirroring how the HUD counts down to 0.
    final challengeContext = session.challenge;
    if (challengeContext != null &&
        challengeContext.challenge == Challenge.moveLimit &&
        updatedMoves > challengeContext.maxMoves) {
      return MovementResult(
        session: session.copyWith(
          movesCount: updatedMoves,
          status: GameStatus.failed,
        ),
        outcome: MovementOutcome.gameOver,
      );
    }

    if (outcome == ExitAttemptOutcome.escaped) {
      // Arrow successfully exits: mark as escaped, keep body in place
      // (nodes/edges remain visible; arrow becomes inactive).
      final escapedArrow = arrow.copyWith(isEscaped: true);
      final updatedArrows = _replaceArrow(session.arrows, escapedArrow);

      final score = calculator.calculate(
        movesCount: updatedMoves,
        mistakeCount: session.mistakeCount,
        elapsedSeconds: session.elapsedSeconds,
      );

      var updatedSession = session.copyWith(
        arrows: updatedArrows,
        movesCount: updatedMoves,
        score: score,
      );

      if (checkVictory.execute(updatedSession)) {
        updatedSession = updatedSession.copyWith(status: GameStatus.victory);
      }

      return MovementResult(
        session: updatedSession,
        outcome: MovementOutcome.escaped,
      );
    }

    // Collision: arrow stays in its original position (no mutation).
    final updatedMistakes = session.mistakeCount + 1;

    final score = calculator.calculate(
      movesCount: updatedMoves,
      mistakeCount: updatedMistakes,
      elapsedSeconds: session.elapsedSeconds,
    );

    var updatedSession = session.copyWith(
      movesCount: updatedMoves,
      mistakeCount: updatedMistakes,
      score: score,
    );

    // Perfect Run rule: the first mistake ends the run, regardless of lives.
    if (challengeContext != null &&
        challengeContext.challenge == Challenge.perfectRun) {
      updatedSession = updatedSession.copyWith(status: GameStatus.failed);
      return MovementResult(
        session: updatedSession,
        outcome: MovementOutcome.gameOver,
      );
    }

    // Lives are a CAMPAIGN rule only. A challenge run is judged solely by
    // its own constraint (clock / move budget / flawlessness) — collisions
    // in Time Attack and Move Limit cost score and budget, never the run.
    if (challengeContext == null && updatedSession.livesRemaining <= 0) {
      updatedSession = updatedSession.copyWith(status: GameStatus.failed);
      return MovementResult(
        session: updatedSession,
        outcome: MovementOutcome.gameOver,
      );
    }

    return MovementResult(
      session: updatedSession,
      outcome: MovementOutcome.collision,
    );
  }

  List<ArrowPath> _replaceArrow(
    List<ArrowPath> arrows,
    ArrowPath updatedArrow,
  ) {
    return arrows
        .map((a) => a.id == updatedArrow.id ? updatedArrow : a)
        .toList(growable: false);
  }
}
