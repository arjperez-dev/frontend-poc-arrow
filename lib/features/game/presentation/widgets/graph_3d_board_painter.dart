import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/arrow_path.dart';
import '../../domain/board_graph.dart';
import '../../domain/game_session.dart';
import 'arrow_head.dart';
import 'board_style.dart';
import 'graph_3d_projector.dart';

/// Paints a multi-layer board through a [Graph3DProjector] camera.
///
/// Rendering model:
/// - Painter's algorithm: floors, edges, arrows, and nodes are collected as
///   depth-tagged drawables and painted farthest-first, so near geometry
///   correctly occludes far geometry as the camera orbits. The exit-slide is
///   part of the same sorted pass, so a piece leaving away from the camera is
///   occluded by nearer geometry instead of always drawing on top.
/// - Z-edges render as slanted lines between the layers; vertical
///   (above/below) arrows render as ordinary arrows whose heads point along
///   the projected layer axis. When that axis projects to near-zero on screen
///   (camera looking down the stack) the head falls back to a filled disc so
///   the piece never loses its head/tail cue.
/// - World-unit sizes (stroke, node radius, arrowhead) are multiplied by
///   each point's [ProjectedPoint.pixelScale], producing real foreshortening.
/// - Depth cues: geometry farther from the camera is dimmed toward the
///   background, each arrow segment dims by its own depth (near-to-far shading
///   within a single spanning arrow), and a faint per-layer floor plate grounds
///   each layer so the stack reads as separate floors.
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

    // --- Per-layer floor plates (grounding cue) -------------------------
    _addLayerFloors(drawables, graph, projector, fade);

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
          (edge.isBlocked ? 0.10 : 0.06) *
          math.min(from.pixelScale, to.pixelScale);
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
                Paint()
                  ..color = AppTheme.softText.withValues(alpha: 0.16 * dim),
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
      final color = isFlashing ? collisionFlashColor : arrowColorFor(arrow.id);
      final shake = _shakeOffsetFor(arrow, projector);
      drawables.add(
        _Drawable(head.depth, (c) {
          _paintArrow(
            c,
            projector,
            arrow,
            color,
            fade: fade,
            translation: shake,
          );
        }),
      );
    }

    // --- Exit slide (depth-sorted with the rest of the scene) ------------
    final exiting = exitingArrow;
    if (exiting != null && exitProgress > 0 && exitProgress < 1) {
      final head = projector.pointFor(exiting.endNodeId);
      if (head != null) {
        drawables.add(
          _Drawable(head.depth, (c) {
            _paintExitingArrow(c, projector, exiting, size);
          }),
        );
      }
    }

    drawables.sort((a, b) => b.depth.compareTo(a.depth));
    for (final drawable in drawables) {
      drawable.draw(canvas);
    }
  }

  /// Faint filled convex hull under each z-layer's nodes, drawn behind that
  /// layer's geometry (sorted at the layer's farthest node) so the stack reads
  /// as separate floors instead of a floating point cloud.
  void _addLayerFloors(
    List<_Drawable> drawables,
    BoardGraph graph,
    Graph3DProjector projector,
    double Function(double) fade,
  ) {
    final byLayer = <int, List<Offset>>{};
    final layerDepth = <int, double>{};
    for (final node in graph.nodes) {
      final p = projector.pointFor(node.id);
      if (p == null) continue;
      final z = node.coordinate.z;
      (byLayer[z] ??= <Offset>[]).add(p.screen);
      layerDepth[z] = math.max(layerDepth[z] ?? p.depth, p.depth);
    }
    byLayer.forEach((z, points) {
      if (points.length < 3) return;
      final hull = _convexHull(points);
      if (hull.length < 3) return;
      final depth = layerDepth[z]!;
      final alpha = 0.05 * fade(depth);
      drawables.add(
        _Drawable(depth + 0.001, (c) {
          final path = Path()..moveTo(hull.first.dx, hull.first.dy);
          for (final p in hull.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          c.drawPath(
            path,
            Paint()
              ..color = AppTheme.softText.withValues(alpha: alpha)
              ..style = PaintingStyle.fill,
          );
        }),
      );
    });
  }

  /// Draws an active (or shaking) arrow: the polyline is drawn segment by
  /// segment so each segment can dim by its own depth (near-to-far shading
  /// within a spanning arrow), then the head glyph on top.
  void _paintArrow(
    Canvas canvas,
    Graph3DProjector projector,
    ArrowPath arrow,
    Color color, {
    required double Function(double) fade,
    required Offset translation,
  }) {
    final head = projector.pointFor(arrow.endNodeId);
    if (head == null) return;

    final emphasized = arrow.id == lastActivatedArrowId;
    final strokeWorld = emphasized ? 0.32 : 0.26;
    final strokeWidth = math
        .max(3.0, head.pixelScale * strokeWorld)
        .clamp(3.0, 14.0);

    // Selection ring so the just-tapped arrow stands out under orbit.
    if (emphasized) {
      canvas.drawCircle(
        head.screen + translation,
        strokeWidth * 1.6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * fade(head.depth))
          ..strokeWidth = math.max(1.5, strokeWidth * 0.35)
          ..style = PaintingStyle.stroke,
      );
    }

    // Resolve screen points for every node (tail → head).
    final ids = arrow.orderedNodeIds;
    final pts = <ProjectedPoint?>[
      for (final id in ids) projector.pointFor(id),
    ];

    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      if (a == null || b == null) continue;
      final segFade = fade((a.depth + b.depth) / 2);
      canvas.drawLine(
        a.screen + translation,
        b.screen + translation,
        Paint()
          ..color = color.withValues(alpha: segFade)
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    _paintHead(
      canvas,
      projector,
      arrow,
      head.screen + translation,
      head.pixelScale,
      color.withValues(alpha: fade(head.depth)),
      strokeWidth: strokeWidth,
      singleNode: ids.length <= 1,
    );
  }

  /// Path-following exit: each node slides forward along the arrow's own
  /// projected polyline (rounding its bends, "train on tracks"), then continues
  /// straight past the head in the projected exit direction. Mirrors the 2D
  /// board's arc-length model; the fly-out distance scales with the head's
  /// pixel scale so it reads the same at every zoom level.
  void _paintExitingArrow(
    Canvas canvas,
    Graph3DProjector projector,
    ArrowPath arrow,
    Size size,
  ) {
    final ids = arrow.orderedNodeIds;
    final n = ids.length;
    if (n == 0) return;

    final positions = <Offset?>[
      for (final id in ids) projector.pointFor(id)?.screen,
    ];
    final headPoint = projector.pointFor(arrow.endNodeId);
    final headPos = positions[n - 1];
    if (headPos == null || headPoint == null) return;

    // Screen-space unit exit direction (fall back to straight up).
    final rawDir = projector.directionOnScreen(
      arrow.endNodeId,
      dx: arrow.direction.dx.toDouble(),
      dy: arrow.direction.dy.toDouble(),
      dz: arrow.direction.dz.toDouble(),
    );
    final dir = (rawDir == null || rawDir.distance < 0.001)
        ? const Offset(0, -1)
        : rawDir / rawDir.distance;

    // Cumulative arc lengths along the projected node polyline (tail → head).
    final arcs = List<double>.filled(n, 0.0);
    for (var i = 1; i < n; i++) {
      final a = positions[i - 1];
      final b = positions[i];
      arcs[i] = arcs[i - 1] + (a != null && b != null ? (b - a).distance : 0.0);
    }

    // Total travel: enough to clear the head off-frame, scaled by pixel scale.
    final extra = math.max(headPoint.pixelScale * 3.0, size.shortestSide * 0.6);
    final totalDistance = arcs[n - 1] + extra;

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
      for (var j = i + 1; j < n; j++) {
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
    final color = arrowColorFor(arrow.id).withValues(alpha: opacity);

    final strokeWidth = math
        .max(3.0, headPoint.pixelScale * 0.26)
        .clamp(3.0, 14.0);

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
    if (started && n > 1) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    final displacedHead = displaced[n - 1] ?? headPos;
    final angle = math.atan2(dir.dy, dir.dx);
    final length = (headPoint.pixelScale * 0.42).clamp(6.0, 18.0);
    final width = (headPoint.pixelScale * 0.26).clamp(4.0, 11.0);
    if (n <= 1) {
      canvas.drawCircle(displacedHead, strokeWidth * 0.75, Paint()..color = color);
    }
    paintArrowHead(canvas, displacedHead, angle, color, length: length, width: width);
  }

  /// Draws the arrowhead at [headPos], falling back to a filled disc when the
  /// projected direction is degenerate (vertical arrow seen down the layer
  /// axis) so the head is never invisible.
  void _paintHead(
    Canvas canvas,
    Graph3DProjector projector,
    ArrowPath arrow,
    Offset headPos,
    double headPixelScale,
    Color color, {
    required double strokeWidth,
    required bool singleNode,
  }) {
    final dirOnScreen = projector.directionOnScreen(
      arrow.endNodeId,
      dx: arrow.direction.dx.toDouble(),
      dy: arrow.direction.dy.toDouble(),
      dz: arrow.direction.dz.toDouble(),
    );
    final length = (headPixelScale * 0.42).clamp(6.0, 18.0);
    final width = (headPixelScale * 0.26).clamp(4.0, 11.0);

    if (dirOnScreen == null || dirOnScreen.distance < 0.001) {
      // Degenerate projected direction (or a single-node arrow): a filled disc
      // marks the head end so the piece stays a legible, tappable object.
      canvas.drawCircle(headPos, math.max(strokeWidth, length * 0.55), Paint()..color = color);
      return;
    }

    if (singleNode) {
      canvas.drawCircle(headPos, strokeWidth * 0.75, Paint()..color = color);
    }
    final angle = math.atan2(dirOnScreen.dy, dirOnScreen.dx);
    paintArrowHead(canvas, headPos, angle, color, length: length, width: width);
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

  /// Andrew's monotone chain — convex hull of the layer's projected points,
  /// counter-clockwise. Used only for the faint floor plates.
  static List<Offset> _convexHull(List<Offset> input) {
    final points = [...input]..sort(
      (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
    );
    if (points.length < 3) return points;
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[];
    for (final p in points) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Offset>[];
    for (final p in points.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
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
