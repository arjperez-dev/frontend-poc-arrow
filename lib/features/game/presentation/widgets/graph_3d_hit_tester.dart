import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_session.dart';
import 'graph_3d_projector.dart';

/// Resolves a tap on the 3D board to an arrow id, in screen space, through
/// the same [Graph3DProjector] the painter used — so what you see is exactly
/// what you hit at any camera orientation.
///
/// Candidates within the slop radius of an arrow's head or body segment are
/// collected; when several overlap (arrows on different layers projecting
/// close together), the one **nearest the camera** wins, matching what the
/// player visually taps.
class Graph3DHitTester {
  const Graph3DHitTester({this.maxHitSlop = 28, this.minHitSlop = 12});

  final double maxHitSlop;
  final double minHitSlop;

  String? findArrowAt({
    required GameSession session,
    required Graph3DProjector projector,
    required Offset position,
  }) {
    String? bestId;
    var bestDepth = double.infinity;

    for (final arrow in session.activeArrows) {
      final head = projector.pointFor(arrow.endNodeId);
      if (head == null) continue;
      final slop = _hitSlopFor(head.pixelScale);

      var hit = (position - head.screen).distance <= slop;

      if (!hit) {
        final nodes = arrow.orderedNodeIds;
        for (var i = nodes.length - 1; i > 0; i--) {
          final from = projector.pointFor(nodes[i - 1]);
          final to = projector.pointFor(nodes[i]);
          if (from == null || to == null) continue;
          if (_distanceToSegment(position, from.screen, to.screen) <= slop) {
            hit = true;
            break;
          }
        }
      }

      if (hit && head.depth < bestDepth) {
        bestDepth = head.depth;
        bestId = arrow.id;
      }
    }

    return bestId;
  }

  /// Slop scales with the projected cell size at the arrow's depth, capped
  /// at 45% of a cell (same reasoning as the 2D hit tester: the tolerance
  /// radius must never reach halfway to a neighbouring node).
  double _hitSlopFor(double pixelScale) {
    return math.max(minHitSlop, math.min(maxHitSlop, pixelScale * 0.45));
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared =
        segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) {
      return (point - start).distance;
    }
    final t = (((point.dx - start.dx) * segment.dx) +
            ((point.dy - start.dy) * segment.dy)) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + (segment.dx * clamped),
      start.dy + (segment.dy * clamped),
    );
    return (point - projection).distance;
  }
}
