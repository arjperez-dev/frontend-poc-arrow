import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/direction.dart';
import '../../domain/game_session.dart';
import 'graph_board_layout.dart';

class GraphBoardPainter extends CustomPainter {
  const GraphBoardPainter({required this.session, this.lastActivatedArrowId});

  final GameSession session;
  final String? lastActivatedArrowId;

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
      _drawArrow(canvas, layout, arrow);
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

  void _drawArrow(Canvas canvas, GraphBoardLayout layout, ArrowPath arrow) {
    final color = _colorForArrow(arrow.id);
    final pathPaint = Paint()
      ..color = color
      ..strokeWidth = arrow.id == lastActivatedArrowId ? 14 : 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final edgeId in arrow.occupiedEdgeIds) {
      final edge = session.level.boardGraph.edgeById(edgeId);
      if (edge == null) {
        continue;
      }
      final from = layout.positionOf(edge.fromNodeId);
      final to = layout.positionOf(edge.toNodeId);
      if (from == null || to == null) {
        continue;
      }
      canvas.drawLine(from, to, pathPaint);
    }

    final headPosition = layout.positionOf(arrow.endNodeId);
    if (headPosition != null) {
      _drawArrowHead(canvas, headPosition, arrow.direction, color);
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset position,
    Direction direction,
    Color color,
  ) {
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
        oldDelegate.lastActivatedArrowId != lastActivatedArrowId;
  }
}
