import 'direction.dart';
import 'graph_edge.dart';
import 'graph_node.dart';

class BoardGraph {
  BoardGraph({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
  })  : _nodesById = {for (final node in nodes) node.id: node},
        _edgesById = {for (final edge in edges) edge.id: edge};

  final Map<String, GraphNode> _nodesById;
  final Map<String, GraphEdge> _edgesById;

  List<GraphNode> get nodes => List.unmodifiable(_nodesById.values);
  List<GraphEdge> get edges => List.unmodifiable(_edgesById.values);

  GraphNode? nodeById(String id) => _nodesById[id];

  GraphEdge? edgeById(String id) => _edgesById[id];

  GraphNode? getNeighbor(String nodeId, Direction direction) {
    final node = _nodesById[nodeId];
    if (node == null) {
      return null;
    }

    for (final edge in _edgesById.values.where((edge) => edge.connects(nodeId))) {
      final otherNodeId = edge.otherNodeId(nodeId);
      final otherNode = otherNodeId == null ? null : _nodesById[otherNodeId];
      if (otherNode == null) {
        continue;
      }

      final edgeDirection = Direction.between(node.coordinate, otherNode.coordinate);
      if (edgeDirection == direction) {
        return otherNode;
      }
    }

    return null;
  }

  GraphEdge? getEdgeInDirection(String nodeId, Direction direction) {
    final neighbor = getNeighbor(nodeId, direction);
    if (neighbor == null) {
      return null;
    }

    return getEdgeBetween(nodeId, neighbor.id);
  }

  GraphEdge? getEdgeBetween(String firstNodeId, String secondNodeId) {
    for (final edge in _edgesById.values) {
      final connectsBoth =
          edge.connects(firstNodeId) && edge.connects(secondNodeId);
      if (connectsBoth) {
        return edge;
      }
    }

    return null;
  }

  bool isEdgeBlocked(String edgeId) => _edgesById[edgeId]?.isBlocked ?? false;

  bool isExitMove(String nodeId, Direction direction) {
    return _nodesById.containsKey(nodeId) && getNeighbor(nodeId, direction) == null;
  }
}
