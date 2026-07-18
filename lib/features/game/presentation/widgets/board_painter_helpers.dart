import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/board_graph.dart';
import '../../domain/move_direction.dart';
import 'arrow_head.dart';
import 'board_layout.dart';

/// Drawing logic shared by every flat board painter ([GraphBoardPainter] for
/// square boards, `HexBoardPainter` for hex boards). Board geometry differs
/// only in [BoardLayout] (coordinate->pixel mapping) and in how an arrow's
/// direction maps to a screen-space angle for its arrowhead — both are
/// passed in by the caller so this file has no square/hex knowledge itself.
///
/// Node dots, edges, arrow polylines, the exit-track slide animation, and
/// the collision shake are pixel-position-driven and therefore identical
/// regardless of the underlying lattice.

typedef ArrowHeadAngleFor = double Function(MoveDirection direction);

/// Angle straight from the direction's (dx, dy) delta. Correct for square
/// boards, where axis deltas already line up with screen angles.
double defaultAngleFor(MoveDirection direction) =>
    math.atan2(direction.dy.toDouble(), direction.dx.toDouble());

void paintBoardBackground(Canvas canvas, Size size) {
  final backgroundPaint = Paint()..color = AppTheme.surface;
  canvas.drawRRect(
    RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
    backgroundPaint,
  );
}

void paintGraphEdges(Canvas canvas, BoardLayout layout, BoardGraph graph) {
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
}

/// Draws the covered/free node dots. A node is "covered" while some active
/// arrow still occupies it; covered nodes stay near-invisible so the board
/// reads as pure arrows at the start of a level, and only light up once the
/// arrow covering them escapes.
void paintCoveredAndFreeNodes(
  Canvas canvas,
  BoardLayout layout,
  BoardGraph graph,
  Set<String> coveredNodeIds,
) {
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

/// Stroke width, capped relative to cell size so dense boards (small cell
/// spacing) draw thinner lines that don't bleed into a neighbouring cell.
double arrowStrokeWidth(double cellSize, {bool emphasized = false}) {
  final cap = emphasized ? 14.0 : 12.0;
  return math.max(3.0, math.min(cap, cellSize * (emphasized ? 0.32 : 0.28)));
}

void drawArrowHeadAt(
  Canvas canvas,
  Offset position,
  MoveDirection direction,
  Color color,
  double cellSize,
  ArrowHeadAngleFor angleFor,
) {
  final angle = angleFor(direction);
  // Capped relative to cell size: on dense boards the tip must not reach
  // far enough to draw over the next cell, where another arrow may sit.
  final length = math.max(5.0, math.min(18.0, cellSize * 0.42));
  final width = math.max(3.5, math.min(11.0, cellSize * 0.26));
  paintArrowHead(canvas, position, angle, color, length: length, width: width);
}

void paintArrowShape(
  Canvas canvas,
  BoardLayout layout,
  ArrowPath arrow,
  Color color,
  double opacity,
  Offset translation, {
  required bool emphasized,
  required ArrowHeadAngleFor angleFor,
}) {
  final pathPaint = Paint()
    ..color = color.withValues(alpha: opacity)
    ..strokeWidth = arrowStrokeWidth(layout.step, emphasized: emphasized)
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
    drawArrowHeadAt(
      canvas,
      headPosition + translation,
      arrow.direction,
      color.withValues(alpha: opacity),
      layout.step,
      angleFor,
    );
  }
}

/// Small back-and-forth nudge in the head direction during a collision.
///
/// Uses [angleFor] rather than the direction's raw (dx, dy) delta: on a
/// square board those coincide (unit axis deltas), but a hex direction's
/// axial delta (e.g. northEast = (1, -1)) does not point along its actual
/// screen-space exit angle once mapped through the pointy-top projection.
Offset shakeOffsetFor(
  ArrowPath arrow,
  String? shakeArrowId,
  double shakeProgress,
  ArrowHeadAngleFor angleFor,
) {
  if (arrow.id != shakeArrowId || shakeProgress <= 0 || shakeProgress >= 1) {
    return Offset.zero;
  }
  final amplitude = math.sin(shakeProgress * math.pi) * 6.0;
  final angle = angleFor(arrow.direction);
  return Offset(math.cos(angle), math.sin(angle)) * amplitude;
}

/// Slide-out animation for an arrow that just escaped: the head leaves
/// first, and each body node follows the exact sequence of pixel positions
/// the nodes ahead of it occupied (rounding corners), then continues past
/// the head in the exit direction. See Phase 13 ("train on tracks").
void paintExitingArrow(
  Canvas canvas,
  BoardLayout layout,
  ArrowPath arrow,
  Size size,
  double exitProgress,
  Color color,
  ArrowHeadAngleFor angleFor,
) {
  // Pixel-space exit direction, derived the same way the arrowhead angle
  // is — not from the raw (dx, dy) delta, which only lines up with screen
  // angles on a square lattice (see [shakeOffsetFor]).
  final exitAngle = angleFor(arrow.direction);
  final dir = Offset(math.cos(exitAngle), math.sin(exitAngle));
  final totalDistance = size.longestSide * 1.1;

  final nodes = arrow.orderedNodeIds; // tail → head
  final n = nodes.length;
  if (n == 0) return;

  final positions = List<Offset?>.generate(
    n,
    (i) => layout.positionOf(nodes[i]),
  );
  final headPos = positions[n - 1];
  if (headPos == null) return;

  // Cumulative arc lengths along the node polyline (tail→head).
  final arcs = List<double>.filled(n, 0.0);
  for (int i = 1; i < n; i++) {
    final a = positions[i - 1];
    final b = positions[i];
    arcs[i] = arcs[i - 1] + (a != null && b != null ? (b - a).distance : 0.0);
  }

  const perSegmentDelay = 0.10;
  final totalStagger = math.min((n - 1) * perSegmentDelay, 0.5);
  final effectiveDelay = n > 1 ? totalStagger / (n - 1) : 0.0;
  final window = 1.0 - totalStagger;

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
      return headPos + dir * (advance - arcToHead);
    }

    final targetArc = arcs[i] + advance;
    for (int j = i + 1; j < n; j++) {
      if (arcs[j] >= targetArc) {
        final segStart = positions[j - 1]!;
        final segEnd = positions[j]!;
        final segLen = arcs[j] - arcs[j - 1];
        if (segLen <= 0) return segEnd;
        return Offset.lerp(
          segStart,
          segEnd,
          (targetArc - arcs[j - 1]) / segLen,
        )!;
      }
    }
    return headPos;
  });

  final headLocalT = (exitProgress / window).clamp(0.0, 1.0);
  final opacity = (1.0 - headLocalT).clamp(0.0, 1.0);

  final pathPaint = Paint()
    ..color = color.withValues(alpha: opacity)
    ..strokeWidth = arrowStrokeWidth(layout.step)
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
    drawArrowHeadAt(
      canvas,
      displacedHead,
      arrow.direction,
      color.withValues(alpha: opacity),
      layout.step,
      angleFor,
    );
  }
}
