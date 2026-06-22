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

  // Two arrows on the same horizontal path (a→b→c→d), one right, one left,
  // share node b and edge ab.  The validator must reject with an exception.
  test('no_opposite_arrows_on_same_path', () {
    final definition = LevelDefinition(
      id: 'shared-path',
      name: 'Shared Path',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0),
        GraphNodeDefinition(id: 'c', x: 2, y: 0),
        GraphNodeDefinition(id: 'd', x: 3, y: 0),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
        GraphEdgeDefinition(id: 'cd', fromNodeId: 'c', toNodeId: 'd'),
      ],
      // arrow1 covers a→b (right); arrow2 covers c→b (left) — they share node b
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'arrow2',
          occupiedEdgeIds: ['bc'],
          startNodeId: 'c',
          endNodeId: 'b',
          direction: Direction.left,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  // An arrow whose occupiedEdges close a loop must be rejected.
  test('should_reject_arrow_with_cyclic_path', () {
    // 4 nodes in a square: a(0,0) b(1,0) c(1,1) d(0,1)
    // Edges: ab, bc, cd, da — 4 edges, 4 nodes → cycle.
    final definition = LevelDefinition(
      id: 'cyclic',
      name: 'Cyclic',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0),
        GraphNodeDefinition(id: 'c', x: 1, y: 1),
        GraphNodeDefinition(id: 'd', x: 0, y: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
        GraphEdgeDefinition(id: 'cd', fromNodeId: 'c', toNodeId: 'd'),
        GraphEdgeDefinition(id: 'da', fromNodeId: 'd', toNodeId: 'a'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: ['ab', 'bc', 'cd', 'da'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  // An arrow whose head node has two incident body edges must be rejected.
  test('should_reject_arrow_with_branching_head', () {
    // 4 nodes: a(0,0) b(1,0) c(2,0) d(1,1)
    // Arrow: tail=a, head=b, occupiedEdges=[ab, bc, db]
    // b has edges ab, bc, db incident → branching head.
    final definition = LevelDefinition(
      id: 'branching',
      name: 'Branching',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0),
        GraphNodeDefinition(id: 'c', x: 2, y: 0),
        GraphNodeDefinition(id: 'd', x: 1, y: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
        GraphEdgeDefinition(id: 'db', fromNodeId: 'd', toNodeId: 'b'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: ['ab', 'bc', 'db'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  // Two arrows that share the same edge must be rejected.
  test('no_shared_nodes_between_arrows', () {
    final definition = LevelDefinition(
      id: 'shared-nodes',
      name: 'Shared Nodes',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0),
        GraphNodeDefinition(id: 'c', x: 2, y: 0),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
      ],
      // Both arrows claim node b as start/end — explicit node overlap
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'arrow2',
          occupiedEdgeIds: ['bc'],
          startNodeId: 'b',
          endNodeId: 'c',
          direction: Direction.right,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  // An arrow whose head sweep passes through its own body must be rejected.
  // Mirrors arrow a15 in Level 12: a U-shaped path where the head points back
  // into the tail, making the arrow appear to form a closed loop.
  //
  // Path: start=(2,0) → (2,1) → (1,1) → (0,1) → (0,0) → head=(1,0) dir=right
  // Sweep from (1,0) going right → (2,0) = startNodeId → self-intersection.
  test('should_reject_arrow_with_self_intersecting_sweep', () {
    final definition = LevelDefinition(
      id: 'self-intersect',
      name: 'Self Intersect',
      nodes: const [
        GraphNodeDefinition(id: 'n0_0', x: 0, y: 0),
        GraphNodeDefinition(id: 'n1_0', x: 1, y: 0),
        GraphNodeDefinition(id: 'n2_0', x: 2, y: 0),
        GraphNodeDefinition(id: 'n0_1', x: 0, y: 1),
        GraphNodeDefinition(id: 'n1_1', x: 1, y: 1),
        GraphNodeDefinition(id: 'n2_1', x: 2, y: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'n2_0-n2_1', fromNodeId: 'n2_0', toNodeId: 'n2_1'),
        GraphEdgeDefinition(id: 'n2_1-n1_1', fromNodeId: 'n2_1', toNodeId: 'n1_1'),
        GraphEdgeDefinition(id: 'n1_1-n0_1', fromNodeId: 'n1_1', toNodeId: 'n0_1'),
        GraphEdgeDefinition(id: 'n0_1-n0_0', fromNodeId: 'n0_1', toNodeId: 'n0_0'),
        GraphEdgeDefinition(id: 'n0_0-n1_0', fromNodeId: 'n0_0', toNodeId: 'n1_0'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: [
            'n2_0-n2_1',
            'n2_1-n1_1',
            'n1_1-n0_1',
            'n0_1-n0_0',
            'n0_0-n1_0',
          ],
          startNodeId: 'n2_0',
          endNodeId: 'n1_0',
          direction: Direction.right,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });
}
