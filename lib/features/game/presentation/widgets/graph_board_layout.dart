import 'dart:math' as math;
import 'dart:ui';

import '../../domain/board_graph.dart';
import '../../domain/graph_node.dart';

class GraphBoardLayout {
  const GraphBoardLayout._({required this.positionsByNodeId, required this.step});

  final Map<String, Offset> positionsByNodeId;

  /// Pixel distance between adjacent grid coordinates. Used to scale arrow
  /// stroke width and arrowhead size so dense boards don't draw arrowheads
  /// that reach past their own cell and over a neighbouring arrow.
  final double step;

  factory GraphBoardLayout.fromGraph({
    required BoardGraph graph,
    required Size size,
    double padding = 32,
  }) {
    if (graph.nodes.isEmpty) {
      return const GraphBoardLayout._(positionsByNodeId: {}, step: 1);
    }

    final minX = graph.nodes.map((node) => node.coordinate.x).reduce(math.min);
    final maxX = graph.nodes.map((node) => node.coordinate.x).reduce(math.max);
    final minY = graph.nodes.map((node) => node.coordinate.y).reduce(math.min);
    final maxY = graph.nodes.map((node) => node.coordinate.y).reduce(math.max);

    final graphWidth = math.max(1, maxX - minX);
    final graphHeight = math.max(1, maxY - minY);
    final availableWidth = math.max(1.0, size.width - (padding * 2));
    final availableHeight = math.max(1.0, size.height - (padding * 2));
    final step = math.min(
      availableWidth / graphWidth,
      availableHeight / graphHeight,
    );
    final drawnWidth = graphWidth * step;
    final drawnHeight = graphHeight * step;
    final origin = Offset(
      (size.width - drawnWidth) / 2,
      (size.height - drawnHeight) / 2,
    );

    return GraphBoardLayout._(
      positionsByNodeId: {
        for (final node in graph.nodes)
          node.id: _positionFor(node, minX, minY, step, origin),
      },
      step: step,
    );
  }

  Offset? positionOf(String nodeId) => positionsByNodeId[nodeId];

  static Offset _positionFor(
    GraphNode node,
    int minX,
    int minY,
    double step,
    Offset origin,
  ) {
    return Offset(
      origin.dx + ((node.coordinate.x - minX) * step),
      origin.dy + ((node.coordinate.y - minY) * step),
    );
  }
}
