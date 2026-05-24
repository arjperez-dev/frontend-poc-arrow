import 'direction.dart';

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.name,
    required this.nodes,
    required this.edges,
    required this.arrows,
    required this.blockedEdgeIds,
    required this.metadata,
  });

  final String id;
  final String name;
  final List<GraphNodeDefinition> nodes;
  final List<GraphEdgeDefinition> edges;
  final List<ArrowPathDefinition> arrows;
  final List<String> blockedEdgeIds;
  final Map<String, Object?> metadata;
}

class GraphNodeDefinition {
  const GraphNodeDefinition({
    required this.id,
    required this.x,
    required this.y,
  });

  final String id;
  final int x;
  final int y;
}

class GraphEdgeDefinition {
  const GraphEdgeDefinition({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
}

class ArrowPathDefinition {
  const ArrowPathDefinition({
    required this.id,
    required this.occupiedEdgeIds,
    required this.startNodeId,
    required this.endNodeId,
    required this.direction,
  });

  final String id;
  final List<String> occupiedEdgeIds;
  final String startNodeId;
  final String endNodeId;
  final Direction direction;
}
