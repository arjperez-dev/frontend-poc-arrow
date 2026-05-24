import 'board_coordinate.dart';

class GraphNode {
  const GraphNode({
    required this.id,
    required this.coordinate,
  });

  final String id;
  final BoardCoordinate coordinate;
}
