import 'arrow_path.dart';
import 'board_coordinate.dart';
import 'board_graph.dart';
import 'direction.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'level.dart';
import 'level_definition.dart';

class LevelDefinitionException implements Exception {
  const LevelDefinitionException(this.message);

  final String message;

  @override
  String toString() => 'LevelDefinitionException: $message';
}

class LevelDefinitionValidator {
  Level validate(LevelDefinition definition) {
    if (definition.metadata.isEmpty) {
      throw const LevelDefinitionException('Level metadata is required.');
    }

    final nodeIds = <String>{};
    for (final node in definition.nodes) {
      if (!nodeIds.add(node.id)) {
        throw LevelDefinitionException('Duplicate node id: ${node.id}.');
      }
    }

    final nodesById = {
      for (final node in definition.nodes)
        node.id: GraphNode(
          id: node.id,
          coordinate: BoardCoordinate(x: node.x, y: node.y),
        ),
    };

    final edgeIds = <String>{};
    final edges = <GraphEdge>[];
    for (final edge in definition.edges) {
      if (!edgeIds.add(edge.id)) {
        throw LevelDefinitionException('Duplicate edge id: ${edge.id}.');
      }
      final fromNode = nodesById[edge.fromNodeId];
      final toNode = nodesById[edge.toNodeId];
      if (fromNode == null || toNode == null) {
        throw LevelDefinitionException(
          'Edge ${edge.id} references a node that does not exist.',
        );
      }
      final direction = Direction.between(fromNode.coordinate, toNode.coordinate);
      if (direction == null) {
        throw LevelDefinitionException('Edge ${edge.id} must be orthogonal.');
      }
      edges.add(
        GraphEdge(
          id: edge.id,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          isBlocked: definition.blockedEdgeIds.contains(edge.id),
        ),
      );
    }

    for (final blockedEdgeId in definition.blockedEdgeIds) {
      if (!edgeIds.contains(blockedEdgeId)) {
        throw LevelDefinitionException(
          'Blocked edge $blockedEdgeId does not exist.',
        );
      }
    }

    final arrowIds = <String>{};
    final arrows = <ArrowPath>[];
    for (final arrow in definition.arrows) {
      if (!arrowIds.add(arrow.id)) {
        throw LevelDefinitionException('Duplicate arrow id: ${arrow.id}.');
      }
      if (!nodesById.containsKey(arrow.startNodeId) ||
          !nodesById.containsKey(arrow.endNodeId)) {
        throw LevelDefinitionException(
          'Arrow ${arrow.id} references a node that does not exist.',
        );
      }
      for (final edgeId in arrow.occupiedEdgeIds) {
        if (!edgeIds.contains(edgeId)) {
          throw LevelDefinitionException(
            'Arrow ${arrow.id} references missing edge $edgeId.',
          );
        }
      }
      arrows.add(
        ArrowPath(
          id: arrow.id,
          occupiedEdgeIds: arrow.occupiedEdgeIds,
          startNodeId: arrow.startNodeId,
          endNodeId: arrow.endNodeId,
          direction: arrow.direction,
        ),
      );
    }

    return Level(
      id: definition.id,
      name: definition.name,
      boardGraph: BoardGraph(
        nodes: nodesById.values.toList(growable: false),
        edges: edges,
      ),
      arrows: arrows,
      metadata: definition.metadata,
    );
  }
}
