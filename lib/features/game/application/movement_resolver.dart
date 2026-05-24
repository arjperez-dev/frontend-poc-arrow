import '../domain/arrow_path.dart';
import '../domain/game_session.dart';
import 'collision_detector.dart';
import 'movement_result.dart';

class MovementResolver {
  const MovementResolver({
    this.collisionDetector = const CollisionDetector(),
  });

  final CollisionDetector collisionDetector;

  MovementResolution resolve({
    required GameSession session,
    required ArrowPath arrow,
  }) {
    if (arrow.isEscaped) {
      return const MovementResolution(
        outcome: MovementOutcome.alreadyEscaped,
      );
    }

    final graph = session.level.boardGraph;
    final targetEdge = graph.getEdgeInDirection(arrow.endNodeId, arrow.direction);

    if (targetEdge == null) {
      if (graph.isExitMove(arrow.endNodeId, arrow.direction)) {
        return const MovementResolution(
          outcome: MovementOutcome.escaped,
        );
      }

      return const MovementResolution(
        outcome: MovementOutcome.blocked,
      );
    }

    if (targetEdge.isBlocked) {
      return const MovementResolution(
        outcome: MovementOutcome.blocked,
      );
    }

    if (collisionDetector.isEdgeOccupiedByAnotherActiveArrow(
      session: session,
      edgeId: targetEdge.id,
      movingArrowId: arrow.id,
    )) {
      return const MovementResolution(
        outcome: MovementOutcome.occupied,
      );
    }

    final neighbor = graph.getNeighbor(arrow.endNodeId, arrow.direction);
    if (neighbor == null) {
      return const MovementResolution(
        outcome: MovementOutcome.blocked,
      );
    }

    return MovementResolution(
      outcome: MovementOutcome.moved,
      targetNodeId: neighbor.id,
      targetEdgeId: targetEdge.id,
    );
  }
}

class MovementResolution {
  const MovementResolution({
    required this.outcome,
    this.targetNodeId,
    this.targetEdgeId,
  });

  final MovementOutcome outcome;
  final String? targetNodeId;
  final String? targetEdgeId;
}
