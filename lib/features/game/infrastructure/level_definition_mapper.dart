import '../domain/level_definition.dart';
import '../domain/move_direction.dart';
import 'manual_level_dto.dart';

class LevelDefinitionMapper {
  const LevelDefinitionMapper();

  LevelDefinition toDomain(ManualLevelDto dto) {
    final edgeIds = {for (final edge in dto.definitionJson.edges) edge.id};
    final metadata = Map<String, Object?>.from(dto.definitionJson.metadata)
      ..['number'] = dto.number
      ..['difficulty'] = dto.difficulty;

    return LevelDefinition(
      id: 'manual-${dto.number.toString().padLeft(3, '0')}',
      number: dto.number,
      name: dto.name,
      nodes: dto.definitionJson.nodes
          .map(
            (node) => GraphNodeDefinition(
              id: node.id,
              x: node.x,
              y: node.y,
              z: node.z,
            ),
          )
          .toList(growable: false),
      edges: dto.definitionJson.edges
          .map(
            (edge) => GraphEdgeDefinition(
              id: edge.id,
              fromNodeId: edge.fromNodeId,
              toNodeId: edge.toNodeId,
            ),
          )
          .toList(growable: false),
      arrows: dto.definitionJson.arrows
          .map(
            (arrow) => ArrowPathDefinition(
              id: arrow.id,
              occupiedEdgeIds: arrow.occupiedEdges
                  .map((edgeId) => _normalizeEdgeId(edgeId, edgeIds))
                  .toList(growable: false),
              startNodeId: arrow.startNodeId,
              endNodeId: arrow.endNodeId,
              direction: MoveDirection.parse(arrow.direction),
            ),
          )
          .toList(growable: false),
      blockedEdgeIds: dto.definitionJson.blockedEdges
          .map((edgeId) => _normalizeEdgeId(edgeId, edgeIds))
          .toList(growable: false),
      metadata: metadata,
    );
  }

  String _normalizeEdgeId(String edgeId, Set<String> edgeIds) {
    if (edgeIds.contains(edgeId)) {
      return edgeId;
    }

    final parts = edgeId.split('-');
    if (parts.length == 2) {
      final reversedEdgeId = '${parts[1]}-${parts[0]}';
      if (edgeIds.contains(reversedEdgeId)) {
        return reversedEdgeId;
      }
    }

    throw FormatException('Edge "$edgeId" does not exist in manual level.');
  }
}
