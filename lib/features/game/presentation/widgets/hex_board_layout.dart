import 'dart:math' as math;
import 'dart:ui';

import '../../domain/board_coordinate.dart';
import '../../domain/board_graph.dart';
import 'board_layout.dart';

/// Axial (q, r) -> pixel mapping for pointy-top hexagons. Axial coordinates
/// are stored directly in [BoardCoordinate.x]/[BoardCoordinate.y] (see
/// [HexDirection] in the domain layer); `z` is unused.
class HexBoardLayout implements BoardLayout {
  const HexBoardLayout._({
    required this.positionsByNodeId,
    required this.step,
    required this.hexSize,
  });

  final Map<String, Offset> positionsByNodeId;

  /// Centre-to-centre distance between adjacent hexes (`hexSize * sqrt(3)`).
  /// Every one of the 6 neighbour directions is exactly this far apart, so
  /// downstream code that scales off [step] (stroke width, arrowhead size,
  /// hit slop) behaves the same as it does on a square board's `step`.
  @override
  final double step;

  /// Distance from a hex's centre to each of its 6 corners.
  final double hexSize;

  factory HexBoardLayout.fromGraph({
    required BoardGraph graph,
    required Size size,
    double padding = 32,
  }) {
    if (graph.nodes.isEmpty) {
      return const HexBoardLayout._(
        positionsByNodeId: {},
        step: 1,
        hexSize: 1,
      );
    }

    // Map at hexSize=1 first so the fit can be computed from the true pixel
    // bounding box of the hex silhouette, not the skewed axial extents.
    final unitPositions = {
      for (final node in graph.nodes)
        node.id: _axialToPixel(node.coordinate, 1.0),
    };
    final unitXs = unitPositions.values.map((o) => o.dx);
    final unitYs = unitPositions.values.map((o) => o.dy);
    final unitWidth = math.max(
      1e-6,
      unitXs.reduce(math.max) - unitXs.reduce(math.min),
    );
    final unitHeight = math.max(
      1e-6,
      unitYs.reduce(math.max) - unitYs.reduce(math.min),
    );

    final availableWidth = math.max(1.0, size.width - (padding * 2));
    final availableHeight = math.max(1.0, size.height - (padding * 2));
    final hexSize = math.min(
      availableWidth / unitWidth,
      availableHeight / unitHeight,
    );

    final scaledPositions = {
      for (final node in graph.nodes)
        node.id: _axialToPixel(node.coordinate, hexSize),
    };
    final scaledXs = scaledPositions.values.map((o) => o.dx);
    final scaledYs = scaledPositions.values.map((o) => o.dy);
    final minX = scaledXs.reduce(math.min);
    final maxX = scaledXs.reduce(math.max);
    final minY = scaledYs.reduce(math.min);
    final maxY = scaledYs.reduce(math.max);
    final drawnWidth = maxX - minX;
    final drawnHeight = maxY - minY;
    final origin = Offset(
      ((size.width - drawnWidth) / 2) - minX,
      ((size.height - drawnHeight) / 2) - minY,
    );

    return HexBoardLayout._(
      positionsByNodeId: {
        for (final node in graph.nodes)
          node.id: scaledPositions[node.id]! + origin,
      },
      step: hexSize * math.sqrt(3),
      hexSize: hexSize,
    );
  }

  @override
  Offset? positionOf(String nodeId) => positionsByNodeId[nodeId];

  /// The 6 corner offsets of a pointy-top hex centred at [centre].
  List<Offset> hexVertices(Offset centre) {
    return [
      for (int i = 0; i < 6; i++)
        centre +
            Offset(
              hexSize * math.cos(_cornerAngle(i)),
              hexSize * math.sin(_cornerAngle(i)),
            ),
    ];
  }

  static double _cornerAngle(int i) => (math.pi / 180) * (60 * i - 30);

  /// Width/height ratio of the graph's true pixel silhouette (hexSize=1),
  /// clamped like [GraphBoard]'s square-board aspect ratio. Axial extents
  /// are skewed relative to pixel extents, so this must go through the same
  /// axial->pixel mapping as [fromGraph] rather than using raw coordinate
  /// bounds.
  static double aspectRatioFor(BoardGraph graph) {
    if (graph.nodes.isEmpty) return 1;
    final positions = graph.nodes.map(
      (node) => _axialToPixel(node.coordinate, 1.0),
    );
    final xs = positions.map((o) => o.dx);
    final ys = positions.map((o) => o.dy);
    final width = math.max(1e-6, xs.reduce(math.max) - xs.reduce(math.min));
    final height = math.max(1e-6, ys.reduce(math.max) - ys.reduce(math.min));
    return (width / height).clamp(0.6, 1.6);
  }

  static Offset _axialToPixel(BoardCoordinate coordinate, double hexSize) {
    final q = coordinate.x.toDouble();
    final r = coordinate.y.toDouble();
    return Offset(
      hexSize * math.sqrt(3) * (q + (r / 2)),
      hexSize * 1.5 * r,
    );
  }
}
