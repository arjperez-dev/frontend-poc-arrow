import 'dart:math' as math;
import 'dart:ui';

import '../../domain/board_graph.dart';

/// Projects a 3D board graph (x, y, z grid coordinates) onto the 2D canvas
/// with a rotatable perspective camera, so a multi-layer level renders as a
/// real 3D scene — layers separated in depth with true foreshortening.
///
/// Pure math over dart:ui types only (no widget dependencies), so it is
/// unit-testable and shared verbatim between [Graph3DBoardPainter] (drawing)
/// and [Graph3DHitTester] (tap resolution): both always agree on where
/// geometry sits on screen because both consume the same projector instance.
class Graph3DProjector {
  factory Graph3DProjector({
    required BoardGraph graph,
    required double yaw,
    required double pitch,
    required double zoom,
    required Size size,
  }) {
    final nodes = graph.nodes;
    if (nodes.isEmpty || size.width <= 0 || size.height <= 0) {
      return Graph3DProjector._(const {}, yaw: yaw, pitch: pitch);
    }

    final minX = nodes.map((n) => n.coordinate.x).reduce(math.min);
    final maxX = nodes.map((n) => n.coordinate.x).reduce(math.max);
    final minY = nodes.map((n) => n.coordinate.y).reduce(math.min);
    final maxY = nodes.map((n) => n.coordinate.y).reduce(math.max);
    final minZ = nodes.map((n) => n.coordinate.z).reduce(math.min);
    final maxZ = nodes.map((n) => n.coordinate.z).reduce(math.max);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;

    // Pass 1: rotate + perspective-project every node in camera space to
    // discover this orientation's raw on-screen extent.
    final raw = <String, _RawPoint>{
      for (final node in nodes)
        node.id: _projectWorld(
          node.coordinate.x - cx,
          node.coordinate.y - cy,
          (node.coordinate.z - cz) * layerSpacing,
          yaw: yaw,
          pitch: pitch,
        ),
    };

    var minSx = double.infinity, maxSx = double.negativeInfinity;
    var minSy = double.infinity, maxSy = double.negativeInfinity;
    for (final p in raw.values) {
      minSx = math.min(minSx, p.x);
      maxSx = math.max(maxSx, p.x);
      minSy = math.min(minSy, p.y);
      maxSy = math.max(maxSy, p.y);
    }
    final extentW = math.max(0.001, maxSx - minSx);
    final extentH = math.max(0.001, maxSy - minSy);

    // Pass 2: fit the raw extent into the viewport (with margin), apply the
    // user zoom, and finalize screen position + per-point pixel scale.
    final fit =
        math.min(size.width / extentW, size.height / extentH) * 0.78 * zoom;
    final center = Offset(size.width / 2, size.height / 2);
    final rawCenter = Offset((minSx + maxSx) / 2, (minSy + maxSy) / 2);

    final points = <String, ProjectedPoint>{
      for (final entry in raw.entries)
        entry.key: ProjectedPoint(
          screen:
              center + (Offset(entry.value.x, entry.value.y) - rawCenter) * fit,
          depth: entry.value.depth,
          pixelScale: entry.value.perspectiveScale * fit,
        ),
    };

    return Graph3DProjector._(points, yaw: yaw, pitch: pitch);
  }

  const Graph3DProjector._(this._points, {required this.yaw, required this.pitch});

  final Map<String, ProjectedPoint> _points;
  final double yaw;
  final double pitch;

  /// World-unit spacing between adjacent z-layers — noticeably more than one
  /// grid cell so stacked layers read as clearly separate floors.
  static const double layerSpacing = 2.2;

  static const double _cameraDistance = 14.0;
  static const double _focalLength = 14.0;

  ProjectedPoint? pointFor(String nodeId) => _points[nodeId];

  Iterable<MapEntry<String, ProjectedPoint>> get entries => _points.entries;

  /// Screen-space displacement of a small world-space step (dx, dy, dz in
  /// grid units) taken at [nodeId]'s depth. Used to orient arrowheads and to
  /// drive exit-slide animation vectors: the returned offset already includes
  /// this point's perspective scale. Linear (tangent) approximation of the
  /// projection around the node — visually exact for the ≤ ~1-unit steps it
  /// is used for.
  Offset? directionOnScreen(
    String nodeId, {
    required double dx,
    required double dy,
    required double dz,
  }) {
    final base = _points[nodeId];
    if (base == null) return null;
    final rotated = _rotate(dx, dy, dz * layerSpacing, yaw: yaw, pitch: pitch);
    return Offset(rotated.x, rotated.y) * base.pixelScale;
  }

  static _RawPoint _projectWorld(
    double x,
    double y,
    double z, {
    required double yaw,
    required double pitch,
  }) {
    final rotated = _rotate(x, y, z, yaw: yaw, pitch: pitch);
    final perspectiveScale =
        _focalLength / math.max(1.0, _cameraDistance + rotated.depth);
    return _RawPoint(
      x: rotated.x * perspectiveScale,
      y: rotated.y * perspectiveScale,
      depth: rotated.depth,
      perspectiveScale: perspectiveScale,
    );
  }

  /// At yaw = 0, pitch = 0 this is the identity: x/y map straight to the
  /// screen and z sits along the viewing axis — the camera looks down the
  /// layer stack exactly like the flat 2D board. Yaw orbits around the
  /// screen-vertical axis; pitch tilts around the screen-horizontal axis.
  static _Rotated _rotate(
    double x,
    double y,
    double z, {
    required double yaw,
    required double pitch,
  }) {
    final cosYaw = math.cos(yaw), sinYaw = math.sin(yaw);
    final x1 = x * cosYaw + z * sinYaw;
    final z1 = -x * sinYaw + z * cosYaw;
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final y2 = y * cosP - z1 * sinP;
    final z2 = y * sinP + z1 * cosP;
    return _Rotated(x1, y2, z2);
  }
}

class ProjectedPoint {
  const ProjectedPoint({
    required this.screen,
    required this.depth,
    required this.pixelScale,
  });

  final Offset screen;

  /// Rotated camera-space Z — larger is farther from the camera. Drawables
  /// are painted farthest-first (painter's algorithm) so near geometry
  /// occludes far geometry.
  final double depth;

  /// Multiply a world-unit size (stroke width, node radius, arrowhead
  /// length) by this to get its on-screen pixel size at this depth — this is
  /// what produces real foreshortening.
  final double pixelScale;
}

class _RawPoint {
  const _RawPoint({
    required this.x,
    required this.y,
    required this.depth,
    required this.perspectiveScale,
  });

  final double x;
  final double y;
  final double depth;
  final double perspectiveScale;
}

class _Rotated {
  const _Rotated(this.x, this.y, this.depth);

  final double x;
  final double y;
  final double depth;
}
