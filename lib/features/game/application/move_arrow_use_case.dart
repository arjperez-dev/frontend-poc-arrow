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
    final arrow = session.arrowById(command.arrowId);
    if (arrow == null) {
      return MovementResult(
        session: session,
        outcome: MovementOutcome.arrowNotFound,
      );
    }

    final resolution = movementResolver.resolve(
      session: session,
      arrow: arrow,
    );

    if (resolution.outcome != MovementOutcome.moved &&
        resolution.outcome != MovementOutcome.escaped) {
      return MovementResult(
        session: session,
        outcome: resolution.outcome,
      );
    }

    final updatedArrow = resolution.outcome == MovementOutcome.escaped
        ? arrow.copyWith(isEscaped: true)
        : arrow.copyWith(
            endNodeId: resolution.targetNodeId,
            occupiedEdgeIds: [
              ...arrow.occupiedEdgeIds,
              resolution.targetEdgeId!,
            ],
          );

    final updatedArrows = _replaceArrow(session.arrows, updatedArrow);
    final updatedMoves = session.movesCount + 1;
    final score = scoreCalculator.calculate(
      movesCount: updatedMoves,
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
      outcome: resolution.outcome,
    );
  }

  List<ArrowPath> _replaceArrow(List<ArrowPath> arrows, ArrowPath updatedArrow) {
    return arrows
        .map((arrow) => arrow.id == updatedArrow.id ? updatedArrow : arrow)
        .toList(growable: false);
  }
}
