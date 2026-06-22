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
  const LevelDefinitionValidator();

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
      final direction = Direction.between(
        fromNode.coordinate,
        toNode.coordinate,
      );
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

    final edgeDefById = {for (final e in definition.edges) e.id: e};

    final coordToNodeId = <BoardCoordinate, String>{
      for (final entry in nodesById.entries) entry.value.coordinate: entry.key,
    };

    final arrowIds = <String>{};
    final claimedNodes = <String, String>{};
    final claimedEdges = <String, String>{};
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
      // Collect all nodes covered by this arrow (start, end, edge endpoints).
      final coveredNodes = <String>{
        arrow.startNodeId,
        arrow.endNodeId,
        for (final eId in arrow.occupiedEdgeIds)
          if (edgeDefById[eId] != null) ...[
            edgeDefById[eId]!.fromNodeId,
            edgeDefById[eId]!.toNodeId,
          ],
      };
      for (final nodeId in coveredNodes) {
        final prior = claimedNodes[nodeId];
        if (prior != null) {
          throw LevelDefinitionException(
            'Node $nodeId is shared by arrows $prior and ${arrow.id}.',
          );
        }
        claimedNodes[nodeId] = arrow.id;
      }
      for (final eId in arrow.occupiedEdgeIds) {
        final prior = claimedEdges[eId];
        if (prior != null) {
          throw LevelDefinitionException(
            'Edge $eId is shared by arrows $prior and ${arrow.id}.',
          );
        }
        claimedEdges[eId] = arrow.id;
      }

      // Shape checks only apply to arrows with at least one body edge.
      if (arrow.occupiedEdgeIds.isNotEmpty) {
        // Cycle check: a simple path of N edges spans exactly N+1 distinct nodes.
        final bodyNodeSet = <String>{};
        for (final eId in arrow.occupiedEdgeIds) {
          final e = edgeDefById[eId];
          if (e != null) {
            bodyNodeSet.add(e.fromNodeId);
            bodyNodeSet.add(e.toNodeId);
          }
        }
        if (arrow.occupiedEdgeIds.length >= bodyNodeSet.length) {
          throw LevelDefinitionException(
            'Arrow ${arrow.id} occupiedEdgeIds form a cycle.',
          );
        }

        // Branching-head check: endNodeId must have exactly one incident body edge.
        final headEdgeCount = arrow.occupiedEdgeIds.where((eId) {
          final e = edgeDefById[eId];
          return e != null &&
              (e.fromNodeId == arrow.endNodeId || e.toNodeId == arrow.endNodeId);
        }).length;
        if (headEdgeCount != 1) {
          throw LevelDefinitionException(
            'Arrow ${arrow.id} head ${arrow.endNodeId} has $headEdgeCount incident '
            'body edges (expected exactly 1).',
          );
        }

        // Head-direction check: the body edge at the head must lead opposite to direction.
        final dir = arrow.direction;
        final headNode = nodesById[arrow.endNodeId]!;
        final behindCoord = BoardCoordinate(
          x: headNode.coordinate.x - dir.dx,
          y: headNode.coordinate.y - dir.dy,
        );
        final hasBehindEdge = arrow.occupiedEdgeIds.any((eId) {
          final e = edgeDefById[eId];
          if (e == null) return false;
          if (e.fromNodeId != arrow.endNodeId && e.toNodeId != arrow.endNodeId) {
            return false;
          }
          final otherId =
              e.fromNodeId == arrow.endNodeId ? e.toNodeId : e.fromNodeId;
          final otherNode = nodesById[otherId];
          return otherNode != null && otherNode.coordinate == behindCoord;
        });
        if (!hasBehindEdge) {
          throw LevelDefinitionException(
            'Arrow ${arrow.id} head direction ${arrow.direction} is inconsistent '
            'with its body (body edge at head must lead opposite to direction).',
          );
        }

        // Self-intersection check: the head sweep must never pass through a node
        // that belongs to the same arrow's body. Such U/spiral arrows look like
        // closed loops and exit confusingly by "crossing" their own tail.
        final ownBody = <String>{
          arrow.startNodeId,
          for (final eId in arrow.occupiedEdgeIds)
            if (edgeDefById[eId] != null) ...[
              edgeDefById[eId]!.fromNodeId,
              edgeDefById[eId]!.toNodeId,
            ],
        }..remove(arrow.endNodeId);
        var sweepX = headNode.coordinate.x + dir.dx;
        var sweepY = headNode.coordinate.y + dir.dy;
        while (true) {
          final sweepCoord = BoardCoordinate(x: sweepX, y: sweepY);
          final sweepNodeId = coordToNodeId[sweepCoord];
          if (sweepNodeId == null) break;
          if (ownBody.contains(sweepNodeId)) {
            throw LevelDefinitionException(
              'Arrow ${arrow.id} head sweep in direction ${arrow.direction} '
              'self-intersects own body at node $sweepNodeId.',
            );
          }
          sweepX += dir.dx;
          sweepY += dir.dy;
        }
      }

      arrows.add(
        ArrowPath(
          id: arrow.id,
          occupiedEdgeIds: arrow.occupiedEdgeIds,
          orderedNodeIds: _deriveOrderedNodeIds(
            startNodeId: arrow.startNodeId,
            occupiedEdgeIds: arrow.occupiedEdgeIds,
            edgeDefById: edgeDefById,
          ),
          startNodeId: arrow.startNodeId,
          endNodeId: arrow.endNodeId,
          direction: arrow.direction,
        ),
      );
    }

    return Level(
      id: definition.id,
      number: definition.number,
      name: definition.name,
      boardGraph: BoardGraph(
        nodes: nodesById.values.toList(growable: false),
        edges: edges,
      ),
      arrows: arrows,
      metadata: definition.metadata,
    );
  }

  static List<String> _deriveOrderedNodeIds({
    required String startNodeId,
    required List<String> occupiedEdgeIds,
    required Map<String, GraphEdgeDefinition> edgeDefById,
  }) {
    if (occupiedEdgeIds.isEmpty) return [startNodeId];
    final nodes = <String>[startNodeId];
    final remaining = List<String>.from(occupiedEdgeIds);
    var current = startNodeId;
    while (remaining.isNotEmpty) {
      final idx = remaining.indexWhere((id) {
        final e = edgeDefById[id];
        return e != null && (e.fromNodeId == current || e.toNodeId == current);
      });
      if (idx == -1) break;
      final e = edgeDefById[remaining.removeAt(idx)]!;
      current = e.fromNodeId == current ? e.toNodeId : e.fromNodeId;
      nodes.add(current);
    }
    return nodes;
  }
}
