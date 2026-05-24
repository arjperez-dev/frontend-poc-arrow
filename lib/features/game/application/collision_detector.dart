import '../domain/game_session.dart';

class CollisionDetector {
  const CollisionDetector();

  bool isEdgeOccupiedByAnotherActiveArrow({
    required GameSession session,
    required String edgeId,
    required String movingArrowId,
  }) {
    return session.activeArrows.any(
      (arrow) => arrow.id != movingArrowId && arrow.occupiesEdge(edgeId),
    );
  }
}
