import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/game_session.dart';
import '../../domain/hex_direction.dart';
import '../../domain/move_direction.dart';
import 'board_painter_helpers.dart';
import 'board_style.dart';
import 'hex_board_layout.dart';

/// Screen-space angle (y-down) per [HexDirection], for arrowhead rotation.
/// Not derivable from the axial (dx, dy) delta the way the square board's
/// [defaultAngleFor] is — axial deltas don't line up with pixel angles once
/// mapped through the pointy-top projection — so this is an explicit table.
double hexAngleFor(MoveDirection direction) {
  if (direction is! HexDirection) {
    return defaultAngleFor(direction);
  }
  switch (direction) {
    case HexDirection.east:
      return 0;
    case HexDirection.southEast:
      return math.pi / 3;
    case HexDirection.southWest:
      return 2 * math.pi / 3;
    case HexDirection.west:
      return math.pi;
    case HexDirection.northWest:
      return 4 * math.pi / 3;
    case HexDirection.northEast:
      return 5 * math.pi / 3;
  }
}

class HexBoardPainter extends CustomPainter {
  const HexBoardPainter({
    required this.session,
    this.lastActivatedArrowId,
    this.flashingArrowId,
    this.exitingArrow,
    this.exitProgress = 0,
    this.shakeArrowId,
    this.shakeProgress = 0,
  });

  final GameSession session;
  final String? lastActivatedArrowId;
  final String? flashingArrowId;
  final ArrowPath? exitingArrow;
  final double exitProgress;
  final String? shakeArrowId;
  final double shakeProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = HexBoardLayout.fromGraph(
      graph: session.level.boardGraph,
      size: size,
    );
    final graph = session.level.boardGraph;

    paintBoardBackground(canvas, size);

    final hexOutlinePaint = Paint()
      ..color = AppTheme.mutedText.withValues(alpha: 0.14)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final node in graph.nodes) {
      final position = layout.positionOf(node.id);
      if (position == null) continue;
      final vertices = layout.hexVertices(position);
      final path = Path()..moveTo(vertices[0].dx, vertices[0].dy);
      for (final v in vertices.skip(1)) {
        path.lineTo(v.dx, v.dy);
      }
      path.close();
      canvas.drawPath(path, hexOutlinePaint);
    }

    paintGraphEdges(canvas, layout, graph);

    for (final arrow in session.activeArrows) {
      _drawArrow(canvas, layout, arrow);
    }

    final exiting = exitingArrow;
    if (exiting != null && exitProgress > 0 && exitProgress < 1) {
      paintExitingArrow(
        canvas,
        layout,
        exiting,
        size,
        exitProgress,
        arrowColorFor(exiting.id),
        hexAngleFor,
      );
    }

    final coveredNodeIds = <String>{};
    for (final arrow in session.activeArrows) {
      coveredNodeIds.addAll(arrow.orderedNodeIds);
    }
    paintCoveredAndFreeNodes(canvas, layout, graph, coveredNodeIds);
  }

  void _drawArrow(Canvas canvas, HexBoardLayout layout, ArrowPath arrow) {
    final isFlashing = arrow.id == flashingArrowId;
    final color = isFlashing ? collisionFlashColor : arrowColorFor(arrow.id);
    final offset = shakeOffsetFor(
      arrow,
      shakeArrowId,
      shakeProgress,
      hexAngleFor,
    );
    paintArrowShape(
      canvas,
      layout,
      arrow,
      color,
      1,
      offset,
      emphasized: arrow.id == lastActivatedArrowId,
      angleFor: hexAngleFor,
    );
  }

  @override
  bool shouldRepaint(covariant HexBoardPainter oldDelegate) {
    return oldDelegate.session != session ||
        oldDelegate.lastActivatedArrowId != lastActivatedArrowId ||
        oldDelegate.flashingArrowId != flashingArrowId ||
        oldDelegate.exitingArrow != exitingArrow ||
        oldDelegate.exitProgress != exitProgress ||
        oldDelegate.shakeArrowId != shakeArrowId ||
        oldDelegate.shakeProgress != shakeProgress;
  }
}
