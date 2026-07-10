import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';

void main() {
  // a(0,0,0) — b(1,0,0)
  //                |  (z-edge: b above, c below, same x/y)
  //            c(1,0,1)
  //
  // Arrow occupies ab (planar) + bc (layer), head=c, direction=below.
  // Exercises a single arrow whose body crosses from the X/Y plane onto
  // the Z axis — the case the flat 2D graph could never express.
  LevelDefinition bentAcrossLayersDefinition() {
    return const LevelDefinition(
      id: '3d-bent',
      name: '3D Bent',
      nodes: [
        GraphNodeDefinition(id: 'a', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0, z: 0),
        GraphNodeDefinition(id: 'c', x: 1, y: 0, z: 1),
      ],
      edges: [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
      ],
      arrows: [
        ArrowPathDefinition(
          id: 'arrow1',
          occupiedEdgeIds: ['ab', 'bc'],
          startNodeId: 'a',
          endNodeId: 'c',
          direction: LayerDirection.below,
        ),
      ],
      blockedEdgeIds: [],
      metadata: {'difficulty': 'test'},
    );
  }

  test('should_accept_edge_between_z_adjacent_nodes_as_orthogonal', () {
    final level = LevelDefinitionValidator().validate(bentAcrossLayersDefinition());

    expect(level.boardGraph.nodes, hasLength(3));
    expect(level.boardGraph.edges, hasLength(2));
    expect(level.arrows.single.direction, LayerDirection.below);
  });

  test('should_derive_ordered_node_ids_across_the_layer_edge', () {
    final level = LevelDefinitionValidator().validate(bentAcrossLayersDefinition());

    expect(level.arrows.single.orderedNodeIds, ['a', 'b', 'c']);
  });

  test('should_reject_edge_with_diagonal_xz_delta_as_non_orthogonal', () {
    const definition = LevelDefinition(
      id: '3d-diagonal',
      name: '3D Diagonal',
      nodes: [
        GraphNodeDefinition(id: 'a', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0, z: 1),
      ],
      edges: [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
      ],
      arrows: [],
      blockedEdgeIds: [],
      metadata: {'difficulty': 'test'},
    );

    expect(
      () => LevelDefinitionValidator().validate(definition),
      throwsA(isA<LevelDefinitionException>()),
    );
  });

  test('should_expose_two_layers_on_the_resulting_board_graph', () {
    final level = LevelDefinitionValidator().validate(bentAcrossLayersDefinition());

    expect(level.boardGraph.layers, [0, 1]);
    expect(level.boardGraph.isMultiLayer, isTrue);
  });

  test('should_isolate_a_single_layer_via_layerSubgraph', () {
    final level = LevelDefinitionValidator().validate(bentAcrossLayersDefinition());

    final ground = level.boardGraph.layerSubgraph(0);
    expect(ground.nodes.map((n) => n.id), unorderedEquals(['a', 'b']));
    expect(ground.edges, hasLength(1));
    expect(ground.isMultiLayer, isFalse);
  });
}
