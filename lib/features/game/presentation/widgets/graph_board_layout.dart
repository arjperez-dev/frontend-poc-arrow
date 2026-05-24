import 'dart:math' as math;
import 'dart:ui';

import '../../domain/board_graph.dart';
import '../../domain/graph_node.dart';

class GraphBoardLayout {
  const GraphBoardLayout._({required this.positionsByNodeId});

  final Map<String, Offset> positionsByNodeId;

  factory GraphBoardLayout.fromGraph({
    required BoardGraph graph,
    required Size size,
    double padding = 32,
  }) {
    if (graph.nodes.isEmpty) {
      return const GraphBoardLayout._(positionsByNodeId: {});
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
