import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_session.dart';
import 'graph_board_layout.dart';

class GraphBoardHitTester {
  const GraphBoardHitTester({this.maxHitSlop = 28, this.minHitSlop = 6});

  /// Tap tolerance on boards spacious enough that this never reaches a
  /// neighbouring cell.
  final double maxHitSlop;

  /// Floor so taps stay usable on very dense boards. Must stay below
  /// `cellSize * 0.45` for the smallest step actually reached by any level
  /// (figure levels 16-20 run as low as ~15.3px/cell, cap ~6.9px) — a floor
  /// above that cap would override the 0.45 tolerance and let taps overlap
  /// a neighbouring node/arrow (found in Phase 19 audit).
  final double minHitSlop;

  String? findArrowAt({
    required GameSession session,
    required GraphBoardLayout layout,
    required Offset position,
  }) {
    final hitSlop = _hitSlopFor(layout.step);
    for (final arrow in session.activeArrows.reversed) {
      final headPosition = layout.positionOf(arrow.endNodeId);
      if (headPosition != null &&
          (position - headPosition).distance <= hitSlop) {
        return arrow.id;
      }

      final nodes = arrow.orderedNodeIds;
      for (int i = nodes.length - 1; i > 0; i--) {
        final from = layout.positionOf(nodes[i - 1]);
        final to = layout.positionOf(nodes[i]);
        if (from == null || to == null) continue;
        if (_distanceToSegment(position, from, to) <= hitSlop) {
          return arrow.id;
        }
      }
    }

    return null;
  }

  /// Capped at 45% of cell spacing so the tolerance radius around one node
  /// never reaches halfway to its neighbour — on a dense board, taps stay
  /// unambiguous between adjacent arrows instead of matching both.
  double _hitSlopFor(double cellSize) {
    return math.max(minHitSlop, math.min(maxHitSlop, cellSize * 0.45));
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
