import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_session.dart';
import 'graph_board_layout.dart';

class GraphBoardHitTester {
  const GraphBoardHitTester({this.hitSlop = 28});

  final double hitSlop;

  String? findArrowAt({
    required GameSession session,
    required GraphBoardLayout layout,
    required Offset position,
  }) {
    for (final arrow in session.activeArrows.reversed) {
      final headPosition = layout.positionOf(arrow.endNodeId);
      if (headPosition != null &&
          (position - headPosition).distance <= hitSlop) {
        return arrow.id;
      }

      for (final edgeId in arrow.occupiedEdgeIds.reversed) {
        final edge = session.level.boardGraph.edgeById(edgeId);
        if (edge == null) {
          continue;
        }
        final from = layout.positionOf(edge.fromNodeId);
        final to = layout.positionOf(edge.toNodeId);
        if (from == null || to == null) {
          continue;
        }
        if (_distanceToSegment(position, from, to) <= hitSlop) {
          return arrow.id;
        }
      }
    }

    return null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) {
      return (point - start).distance;
    }

    final t =
        (((point.dx - start.dx) * segment.dx) +
            ((point.dy - start.dy) * segment.dy)) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + (segment.dx * clamped),
      start.dy + (segment.dy * clamped),
    );

    return math.sqrt(
      math.pow(point.dx - projection.dx, 2) +
          math.pow(point.dy - projection.dy, 2),
    );
  }
}
