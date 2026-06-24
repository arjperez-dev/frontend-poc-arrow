import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/direction.dart';
import '../../domain/game_session.dart';
import 'graph_board_layout.dart';

class GraphBoardPainter extends CustomPainter {
  const GraphBoardPainter({
    required this.session,
    this.lastActivatedArrowId,
    this.flashingArrowId,
    this.exitingArrow,
    this.exitProgress = 0,
    this.shakeArrowId,
    this.shakeProgress = 0,
  });

  final GameSession session;

  /// Arrow drawn slightly thicker (activated this tap).
  final String? lastActivatedArrowId;

  /// Arrow drawn in collision-error colour for the flash duration.
  final String? flashingArrowId;

  /// Arrow currently sliding out of the board (already escaped in the model).
  final ArrowPath? exitingArrow;

  /// 0..1 progress of the exit slide animation.
  final double exitProgress;

  /// Arrow currently playing a collision shake.
  final String? shakeArrowId;

  /// 0..1 progress of the shake animation.
  final double shakeProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = GraphBoardLayout.fromGraph(
      graph: session.level.boardGraph,
      size: size,
    );
    final graph = session.level.boardGraph;

    final backgroundPaint = Paint()..color = AppTheme.surface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
      backgroundPaint,
    );

    final edgePaint = Paint()
      ..color = AppTheme.mutedText.withValues(alpha: 0.22)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final blockedEdgePaint = Paint()
      ..color = AppTheme.pastelAmber.withValues(alpha: 0.5)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (final edge in graph.edges) {
      final from = layout.positionOf(edge.fromNodeId);
      final to = layout.positionOf(edge.toNodeId);
      if (from == null || to == null) {
        continue;
      }
      canvas.drawLine(from, to, edge.isBlocked ? blockedEdgePaint : edgePaint);
    }

    for (final arrow in session.activeArrows) {
      _drawArrow(canvas, layout, arrow, size);
    }

    // Slide-out animation for the arrow that just escaped (drawn over the graph;
    // it is no longer in activeArrows).
    final exiting = exitingArrow;
    if (exiting != null && exitProgress > 0 && exitProgress < 1) {
      _drawExitingArrow(canvas, layout, exiting, size);
    }

    // A node is "covered" while some active arrow still occupies it. Covered
    // nodes stay almost invisible so the board reads as pure arrows at the
    // start of a level (every node is covered then, by the no-free-nodes
    // rule); a node only lights up once the arrow covering it escapes.
    final coveredNodeIds = <String>{};
    for (final arrow in session.activeArrows) {
      coveredNodeIds.addAll(arrow.orderedNodeIds);
    }

    final coveredNodePaint = Paint()
      ..color = AppTheme.softText.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final freeNodeHaloPaint = Paint()
      ..color = AppTheme.softText.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final freeNodePaint = Paint()
      ..color = AppTheme.softText.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    for (final node in graph.nodes) {
      final position = layout.positionOf(node.id);
      if (position == null) {
        continue;
      }
      if (coveredNodeIds.contains(node.id)) {
        canvas.drawCircle(position, 3, coveredNodePaint);
      } else {
        canvas
          ..drawCircle(position, 7, freeNodeHaloPaint)
          ..drawCircle(position, 4, freeNodePaint);
      }
    }
  }

  void _drawArrow(
    Canvas canvas,
    GraphBoardLayout layout,
    ArrowPath arrow,
    Size size,
  ) {
    final isFlashing = arrow.id == flashingArrowId;
    final color = isFlashing ? _collisionColor : _colorForArrow(arrow.id);
    final offset = _shakeOffsetFor(arrow, size);
    _paintArrowShape(canvas, layout, arrow, color, 1, offset);
  }

  void _drawExitingArrow(
    Canvas canvas,
    GraphBoardLayout layout,
    ArrowPath arrow,
    Size size,
  ) {
    final color = _colorForArrow(arrow.id);
    final dir = Offset(arrow.direction.dx.toDouble(), arrow.direction.dy.toDouble());
    final totalDistance = size.longestSide * 1.1;

    final nodes = arrow.orderedNodeIds; // tail → head
    final n = nodes.length;
    if (n == 0) return;

    // Resolve pixel positions for every node (tail→head).
    final positions = List<Offset?>.generate(n, (i) => layout.positionOf(nodes[i]));
    final headPos = positions[n - 1];
    if (headPos == null) return;

    // Cumulative arc lengths along the node polyline (tail→head).
    // arcs[i] = pixel distance from tail to node i.
    final arcs = List<double>.filled(n, 0.0);
    for (int i = 1; i < n; i++) {
      final a = positions[i - 1];
      final b = positions[i];
      arcs[i] = arcs[i - 1] + (a != null && b != null ? (b - a).distance : 0.0);
    }

    // Stagger: head (fromHead=0) leads; each successive node toward the tail
    // starts its travel slightly later. Cap total stagger at 50% of the animation
    // so even long arrows keep a wide travel window.
    const perSegmentDelay = 0.10;
    final totalStagger = math.min((n - 1) * perSegmentDelay, 0.5);
    final effectiveDelay = n > 1 ? totalStagger / (n - 1) : 0.0;
    final window = 1.0 - totalStagger;

    // Compute displaced position for each node along the shared exit track.
    // Each node travels from its current position forward along the arrow's own
    // polyline, then continues past the head in the exit direction — so bent
    // arrows round their own corner on the way out (train on tracks).
    final displaced = List<Offset?>.generate(n, (i) {
      final pos = positions[i];
      if (pos == null) return null;
      final fromHead = (n - 1) - i; // 0 = head, n-1 = tail
      final localT = ((exitProgress - fromHead * effectiveDelay) / window)
          .clamp(0.0, 1.0);
      if (localT <= 0) return pos;

      final advance = totalDistance * localT;
      final arcToHead = arcs[n - 1] - arcs[i];

      if (advance > arcToHead) {
        // Past the head node — continue straight in exit direction.
        return headPos + dir * (advance - arcToHead);
      }

      // Still within the node polyline — walk forward from node i by `advance`.
      final targetArc = arcs[i] + advance;
      for (int j = i + 1; j < n; j++) {
        if (arcs[j] >= targetArc) {
          final segStart = positions[j - 1]!;
          final segEnd = positions[j]!;
          final segLen = arcs[j] - arcs[j - 1];
          if (segLen <= 0) return segEnd;
          return Offset.lerp(segStart, segEnd, (targetArc - arcs[j - 1]) / segLen)!;
        }
      }
      return headPos;
    });

    // Opacity driven by the head's local progress (head leads the fade).
    final headLocalT = (exitProgress / window).clamp(0.0, 1.0);
    final opacity = (1.0 - headLocalT).clamp(0.0, 1.0);

    final pathPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = _arrowStrokeWidth(layout.step)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;
    for (final p in displaced) {
      if (p == null) continue;
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, pathPaint);

    final displacedHead = displaced[n - 1];
    if (displacedHead != null) {
      _drawArrowHead(
        canvas,
        displacedHead,
        arrow.direction,
        color.withValues(alpha: opacity),
        layout.step,
      );
    }
  }

  /// Small back-and-forth nudge in the head direction during a collision.
  Offset _shakeOffsetFor(ArrowPath arrow, Size size) {
    if (arrow.id != shakeArrowId || shakeProgress <= 0 || shakeProgress >= 1) {
      return Offset.zero;
    }
    final amplitude = math.sin(shakeProgress * math.pi) * 6.0;
    final dir = arrow.direction;
    return Offset(dir.dx.toDouble(), dir.dy.toDouble()) * amplitude;
  }

  void _paintArrowShape(
    Canvas canvas,
    GraphBoardLayout layout,
    ArrowPath arrow,
    Color color,
    double opacity,
    Offset translation,
  ) {
    final pathPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = _arrowStrokeWidth(
        layout.step,
        emphasized: arrow.id == lastActivatedArrowId,
      )
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;
    for (final nodeId in arrow.orderedNodeIds) {
      final pos = layout.positionOf(nodeId);
      if (pos == null) continue;
      final p = pos + translation;
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) canvas.drawPath(path, pathPaint);

    final headPosition = layout.positionOf(arrow.endNodeId);
    if (headPosition != null) {
      _drawArrowHead(
        canvas,
        headPosition + translation,
        arrow.direction,
        color.withValues(alpha: opacity),
        layout.step,
      );
    }
  }

  /// Stroke width, capped relative to cell size so dense boards (small cell
  /// spacing) draw thinner lines that don't bleed into a neighbouring cell.
  double _arrowStrokeWidth(double cellSize, {bool emphasized = false}) {
    final cap = emphasized ? 14.0 : 12.0;
    return math.max(3.0, math.min(cap, cellSize * (emphasized ? 0.32 : 0.28)));
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset position,
    Direction direction,
    Color color,
    double cellSize,
  ) {
    // The arrowhead orientation depends ONLY on the arrow's head direction, not
    // on its body shape. `position` is the head (endNodeId) and the tip extends
    // one head-length along `direction`. The mapping is symmetric for all four
    // directions (left/right/up/down), so heads render correctly regardless of
    // which way the body bends. (Canvas y grows downward: down = +pi/2.)
    final angle = switch (direction) {
      Direction.up => -math.pi / 2,
      Direction.right => 0.0,
      Direction.down => math.pi / 2,
      Direction.left => math.pi,
    };
    // Capped relative to cell size: on dense boards the tip must not reach
    // far enough to draw over the next cell, where another arrow may sit.
    final length = math.max(5.0, math.min(18.0, cellSize * 0.42));
    final width = math.max(3.5, math.min(11.0, cellSize * 0.26));
    final tip = position + Offset(math.cos(angle), math.sin(angle)) * length;
    final left =
        position +
        Offset(
              math.cos(angle + (math.pi * 0.72)),
              math.sin(angle + (math.pi * 0.72)),
            ) *
            width;
    final right =
        position +
        Offset(
              math.cos(angle - (math.pi * 0.72)),
              math.sin(angle - (math.pi * 0.72)),
            ) *
            width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      paint,
    );
  }

  static const Color _collisionColor = Color(0xFFFF4444);

  Color _colorForArrow(String id) {
    const colors = [
      AppTheme.neonBlue,
      AppTheme.neonGreen,
      AppTheme.neonYellow,
      AppTheme.neonPink,
      AppTheme.neonPurple,
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  bool shouldRepaint(covariant GraphBoardPainter oldDelegate) {
    return oldDelegate.session != session ||
        oldDelegate.lastActivatedArrowId != lastActivatedArrowId ||
        oldDelegate.flashingArrowId != flashingArrowId ||
        oldDelegate.exitingArrow != exitingArrow ||
        oldDelegate.exitProgress != exitProgress ||
        oldDelegate.shakeArrowId != shakeArrowId ||
        oldDelegate.shakeProgress != shakeProgress;
  }
}
