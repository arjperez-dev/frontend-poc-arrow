import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';

import '../game_test_fixtures.dart';

void main() {
  test('should_create_graph_when_definition_is_valid', () {
    final level = buildLevel(basicDefinition());

    expect(level.boardGraph.nodes, hasLength(4));
    expect(level.boardGraph.edges, hasLength(3));
    expect(level.arrows, hasLength(1));
  });

  test('should_reject_edge_when_referenced_node_does_not_exist', () {
    final definition = basicDefinition(
      edges: const [
        GraphEdgeDefinition(id: 'missing', fromNodeId: 'a', toNodeId: 'z'),
      ],
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  test('should_reject_edge_when_edge_is_not_orthogonal', () {
    final definition = LevelDefinition(
      id: 'diagonal',
      name: 'Diagonal',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
      ],
      arrows: const [],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  test('should_find_neighbor_when_edge_exists_in_direction', () {
    final level = buildLevel(basicDefinition());
    final graph = level.boardGraph;

    expect(graph.getNeighbor('a', Direction.right)?.id, 'b');
    expect(graph.getNeighbor('b', Direction.left)?.id, 'a');
  });

  test('should_detect_exit_when_arrow_points_outside_graph', () {
    final level = buildLevel(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['bc'],
            startNodeId: 'b',
            endNodeId: 'c',
            direction: Direction.right,
          ),
        ],
      ),
    );

    expect(level.boardGraph.isExitMove('c', Direction.right), isTrue);
  });
}
