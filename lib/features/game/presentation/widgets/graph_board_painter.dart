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

    final nodeHaloPaint = Paint()
      ..color = AppTheme.background.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    final nodePaint = Paint()
      ..color = AppTheme.softText
      ..style = PaintingStyle.fill;
    for (final node in graph.nodes) {
      final position = layout.positionOf(node.id);
      if (position == null) {
        continue;
      }
      canvas
        ..drawCircle(position, 7, nodeHaloPaint)
        ..drawCircle(position, 4, nodePaint);
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
    final slide = size.longestSide * 1.1 * exitProgress;
    final dir = arrow.direction;
    final offset = Offset(dir.dx.toDouble(), dir.dy.toDouble()) * slide;
    final opacity = (1 - exitProgress).clamp(0.0, 1.0);
    _paintArrowShape(canvas, layout, arrow, color, opacity, offset);
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
      ..strokeWidth = arrow.id == lastActivatedArrowId ? 14 : 12
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
      );
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset position,
    Direction direction,
    Color color,
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
    const length = 18.0;
    const width = 11.0;
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
      AppTheme.neonMint,
      Color(0xFFFF8FAB),
      Color(0xFF91C7FF),
      AppTheme.pastelAmber,
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
