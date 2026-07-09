import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/game_session.dart';
import 'graph_3d_projector.dart';

/// Paints a multi-layer board through a [Graph3DProjector] camera.
///
/// Rendering model:
/// - Painter's algorithm: edges, arrows, and nodes are collected as
///   depth-tagged drawables and painted farthest-first, so near geometry
///   correctly occludes far geometry as the camera orbits.
/// - Z-edges render as slanted lines between the layers; vertical
///   (above/below) arrows render as ordinary arrows whose heads point along
///   the projected layer axis — no special glyphs.
/// - World-unit sizes (stroke, node radius, arrowhead) are multiplied by
///   each point's [ProjectedPoint.pixelScale], producing real foreshortening.
/// - Depth cue: geometry farther from the camera is dimmed toward the
///   background so the stack stays readable.
///
/// Same contract as the 2D painter: rules are already resolved in the
/// domain; this only draws session state plus the exit/shake/flash
/// presentation effects.
class Graph3DBoardPainter extends CustomPainter {
  const Graph3DBoardPainter({
    required this.session,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    this.lastActivatedArrowId,
    this.flashingArrowId,
    this.exitingArrow,
    this.exitProgress = 0,
    this.shakeArrowId,
    this.shakeProgress = 0,
  });

  final GameSession session;
  final double yaw;
  final double pitch;
  final double zoom;
  final String? lastActivatedArrowId;
  final String? flashingArrowId;
  final ArrowPath? exitingArrow;
  final double exitProgress;
  final String? shakeArrowId;
  final double shakeProgress;

  static const Color _collisionColor = Color(0xFFFF4444);

  @override
  void paint(Canvas canvas, Size size) {
    final graph = session.level.boardGraph;
    final projector = Graph3DProjector(
      graph: graph,
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      size: size,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
      Paint()..color = AppTheme.surface,
    );

    // Depth range for the dimming cue.
    var minDepth = double.infinity, maxDepth = double.negativeInfinity;
    for (final entry in projector.entries) {
      minDepth = math.min(minDepth, entry.value.depth);
      maxDepth = math.max(maxDepth, entry.value.depth);
    }
    if (!minDepth.isFinite) return;
    final depthRange = math.max(0.001, maxDepth - minDepth);
    double fade(double depth) =>
        1.0 - 0.45 * ((depth - minDepth) / depthRange).clamp(0.0, 1.0);

    final drawables = <_Drawable>[];

    // --- Edges ---------------------------------------------------------
    final coveredNodeIds = <String>{};
    for (final arrow in session.activeArrows) {
      coveredNodeIds.addAll(arrow.orderedNodeIds);
    }

    for (final edge in graph.edges) {
      final from = projector.pointFor(edge.fromNodeId);
      final to = projector.pointFor(edge.toNodeId);
      if (from == null || to == null) continue;
      final depth = (from.depth + to.depth) / 2;
      final alpha = (edge.isBlocked ? 0.5 : 0.22) * fade(depth);
      final color = edge.isBlocked ? AppTheme.pastelAmber : AppTheme.mutedText;
      final width =
          (edge.isBlocked ? 0.10 : 0.06) * math.min(from.pixelScale, to.pixelScale);
      drawables.add(
        _Drawable(depth, (c) {
          c.drawLine(
            from.screen,
            to.screen,
            Paint()
              ..color = color.withValues(alpha: alpha)
              ..strokeWidth = math.max(1.5, width)
              ..strokeCap = StrokeCap.round,
          );
        }),
      );
    }

    // --- Nodes ----------------------------------------------------------
    for (final node in graph.nodes) {
      final p = projector.pointFor(node.id);
      if (p == null) continue;
      final dim = fade(p.depth);
      final covered = coveredNodeIds.contains(node.id);
      drawables.add(
        _Drawable(p.depth, (c) {
          if (covered) {
            c.drawCircle(
              p.screen,
              math.max(1.5, p.pixelScale * 0.05),
              Paint()..color = AppTheme.softText.withValues(alpha: 0.08 * dim),
            );
          } else {
            c
              ..drawCircle(
                p.screen,
                math.max(3.0, p.pixelScale * 0.12),
                Paint()..color = AppTheme.softText.withValues(alpha: 0.16 * dim),
              )
              ..drawCircle(
                p.screen,
                math.max(2.0, p.pixelScale * 0.07),
                Paint()..color = AppTheme.softText.withValues(alpha: 0.5 * dim),
              );
          }
        }),
      );
    }

    // --- Active arrows ----------------------------------------------------
    for (final arrow in session.activeArrows) {
      final head = projector.pointFor(arrow.endNodeId);
      if (head == null) continue;
      final isFlashing = arrow.id == flashingArrowId;
      final color = isFlashing ? _collisionColor : _colorForArrow(arrow.id);
      final shake = _shakeOffsetFor(arrow, projector);
      drawables.add(
        _Drawable(head.depth, (c) {
          _paintArrow(
            c,
            projector,
            arrow,
            color,
            opacity: fade(head.depth),
            translation: shake,
          );
        }),
      );
    }

    drawables.sort((a, b) => b.depth.compareTo(a.depth));
    for (final drawable in drawables) {
      drawable.draw(canvas);
    }

    // --- Exit slide (over everything: the arrow is leaving the scene) ----
    final exiting = exitingArrow;
    if (exiting != null && exitProgress > 0 && exitProgress < 1) {
      final dir = projector.directionOnScreen(
        exiting.endNodeId,
        dx: exiting.direction.dx.toDouble(),
        dy: exiting.direction.dy.toDouble(),
        dz: exiting.direction.dz.toDouble(),
      );
      if (dir != null) {
        final unit = dir.distance == 0 ? Offset.zero : dir / dir.distance;
        final translation = unit * size.longestSide * 1.1 * exitProgress;
        _paintArrow(
          canvas,
          projector,
          exiting,
          _colorForArrow(exiting.id),
          opacity: (1.0 - exitProgress).clamp(0.0, 1.0),
          translation: translation,
        );
      }
    }
  }

  void _paintArrow(
    Canvas canvas,
    Graph3DProjector projector,
    ArrowPath arrow,
    Color color, {
    required double opacity,
    required Offset translation,
  }) {
    final head = projector.pointFor(arrow.endNodeId);
    if (head == null) return;

    final emphasized = arrow.id == lastActivatedArrowId;
    final strokeWorld = emphasized ? 0.30 : 0.26;
    final strokeWidth =
        math.max(3.0, head.pixelScale * strokeWorld).clamp(3.0, 14.0);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;
    for (final nodeId in arrow.orderedNodeIds) {
      final p = projector.pointFor(nodeId);
      if (p == null) continue;
      final screen = p.screen + translation;
      if (!started) {
        path.moveTo(screen.dx, screen.dy);
        started = true;
      } else {
        path.lineTo(screen.dx, screen.dy);
      }
    }
    if (arrow.orderedNodeIds.length > 1 && started) {
      canvas.drawPath(path, paint);
    }

    // Arrowhead oriented by the projected direction vector — one formula for
    // all six directions, including above/below between layers.
    final dirOnScreen = projector.directionOnScreen(
      arrow.endNodeId,
      dx: arrow.direction.dx.toDouble(),
      dy: arrow.direction.dy.toDouble(),
      dz: arrow.direction.dz.toDouble(),
    );
    if (dirOnScreen == null || dirOnScreen.distance < 0.001) return;
    final angle = math.atan2(dirOnScreen.dy, dirOnScreen.dx);
    final headPos = head.screen + translation;
    final length = (head.pixelScale * 0.42).clamp(6.0, 18.0);
    final width = (head.pixelScale * 0.26).clamp(4.0, 11.0);

    // Single-node arrows (no body polyline) get a small base dot so the
    // piece reads as a tappable object, not a floating triangle.
    if (arrow.orderedNodeIds.length <= 1) {
      canvas.drawCircle(
        headPos,
        strokeWidth * 0.75,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }

    final tip = headPos + Offset(math.cos(angle), math.sin(angle)) * length;
    final left = headPos +
        Offset(
              math.cos(angle + (math.pi * 0.72)),
              math.sin(angle + (math.pi * 0.72)),
            ) *
            width;
    final right = headPos +
        Offset(
              math.cos(angle - (math.pi * 0.72)),
              math.sin(angle - (math.pi * 0.72)),
            ) *
            width;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );
  }

  Offset _shakeOffsetFor(ArrowPath arrow, Graph3DProjector projector) {
    if (arrow.id != shakeArrowId || shakeProgress <= 0 || shakeProgress >= 1) {
      return Offset.zero;
    }
    final dir = projector.directionOnScreen(
      arrow.endNodeId,
      dx: arrow.direction.dx.toDouble(),
      dy: arrow.direction.dy.toDouble(),
      dz: arrow.direction.dz.toDouble(),
    );
    if (dir == null || dir.distance == 0) return Offset.zero;
    final amplitude = math.sin(shakeProgress * math.pi) * 6.0;
    return (dir / dir.distance) * amplitude;
  }

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
  bool shouldRepaint(covariant Graph3DBoardPainter oldDelegate) {
    return oldDelegate.session != session ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.lastActivatedArrowId != lastActivatedArrowId ||
        oldDelegate.flashingArrowId != flashingArrowId ||
        oldDelegate.exitingArrow != exitingArrow ||
        oldDelegate.exitProgress != exitProgress ||
        oldDelegate.shakeArrowId != shakeArrowId ||
        oldDelegate.shakeProgress != shakeProgress;
  }
}

class _Drawable {
  const _Drawable(this.depth, this.draw);

  final double depth;
  final void Function(Canvas canvas) draw;
}
