import 'board_coordinate.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'move_direction.dart';

class BoardGraph {
  BoardGraph({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
  })  : _nodesById = {for (final node in nodes) node.id: node},
        _nodesByCoordinate = {for (final node in nodes) node.coordinate: node},
        _edgesById = {for (final edge in edges) edge.id: edge};

  final Map<String, GraphNode> _nodesById;
  final Map<BoardCoordinate, GraphNode> _nodesByCoordinate;
  final Map<String, GraphEdge> _edgesById;

  List<GraphNode> get nodes => List.unmodifiable(_nodesById.values);
  List<GraphEdge> get edges => List.unmodifiable(_edgesById.values);

  GraphNode? nodeById(String id) => _nodesById[id];

  GraphNode? nodeByCoordinate(BoardCoordinate coordinate) =>
      _nodesByCoordinate[coordinate];

  GraphEdge? edgeById(String id) => _edgesById[id];

  GraphNode? getNeighbor(String nodeId, MoveDirection direction) {
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

      final edgeDirection = MoveDirection.between(node.coordinate, otherNode.coordinate);
      if (edgeDirection == direction) {
        return otherNode;
      }
    }

    return null;
  }

  GraphEdge? getEdgeInDirection(String nodeId, MoveDirection direction) {
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

  bool isExitMove(String nodeId, MoveDirection direction) {
    return _nodesById.containsKey(nodeId) && getNeighbor(nodeId, direction) == null;
  }

  /// Distinct z-coordinates present in this graph, ascending. A purely 2D
  /// graph has exactly one layer (`[0]`).
  List<int> get layers {
    final zs = _nodesById.values.map((node) => node.coordinate.z).toSet().toList()
      ..sort();
    return zs;
  }

  bool get isMultiLayer => layers.length > 1;

  /// The nodes at [z] and the edges whose endpoints are both at [z]. Lets a
  /// 2D-only renderer draw one layer of a 3D level without knowing about the
  /// other layers.
  BoardGraph layerSubgraph(int z) {
    final layerNodes =
        _nodesById.values.where((node) => node.coordinate.z == z).toList(growable: false);
    final layerNodeIds = layerNodes.map((node) => node.id).toSet();
    final layerEdges = _edgesById.values
        .where(
          (edge) =>
              layerNodeIds.contains(edge.fromNodeId) && layerNodeIds.contains(edge.toNodeId),
        )
        .toList(growable: false);
    return BoardGraph(nodes: layerNodes, edges: layerEdges);
  }
}
