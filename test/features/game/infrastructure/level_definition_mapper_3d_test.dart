import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/level_definition_mapper.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/manual_level_dto.dart';

void main() {
  test('should_default_node_z_to_zero_when_json_omits_it', () {
    final dto = ManualGraphNodeDto.fromJson(const {'id': 'a', 'x': 1, 'y': 2});
    expect(dto.z, 0);
  });

  test('should_parse_explicit_node_z_from_json', () {
    final dto = ManualGraphNodeDto.fromJson(const {'id': 'a', 'x': 1, 'y': 2, 'z': 3});
    expect(dto.z, 3);
  });

  test('should_map_manual_level_z_through_to_domain_level_definition', () {
    final manualLevel = ManualLevelDto(
      number: 1,
      name: 'Level 1',
      difficulty: 'easy',
      definitionJson: const ManualLevelDefinitionDto(
        nodes: [
          ManualGraphNodeDto(id: 'a', x: 0, y: 0, z: 0),
          ManualGraphNodeDto(id: 'b', x: 0, y: 0, z: 1),
        ],
        edges: [
          ManualGraphEdgeDto(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
        ],
        arrows: [
          ManualArrowPathDto(
            id: 'arrow1',
            occupiedEdges: ['a-b'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: 'below',
          ),
        ],
        blockedEdges: [],
        metadata: {'difficulty': 'easy'},
      ),
    );

    final definition = const LevelDefinitionMapper().toDomain(manualLevel);

    final nodeB = definition.nodes.firstWhere((n) => n.id == 'b');
    expect(nodeB.z, 1);
    expect(definition.arrows.single.direction, LayerDirection.below);
  });

  test('should_still_parse_planar_direction_names_via_move_direction_parse', () {
    final manualLevel = ManualLevelDto(
      number: 2,
      name: 'Level 2',
      difficulty: 'easy',
      definitionJson: const ManualLevelDefinitionDto(
        nodes: [
          ManualGraphNodeDto(id: 'a', x: 0, y: 0),
          ManualGraphNodeDto(id: 'b', x: 1, y: 0),
        ],
        edges: [
          ManualGraphEdgeDto(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
        ],
        arrows: [
          ManualArrowPathDto(
            id: 'arrow1',
            occupiedEdges: ['a-b'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: 'right',
          ),
        ],
        blockedEdges: [],
        metadata: {'difficulty': 'easy'},
      ),
    );

    final definition = const LevelDefinitionMapper().toDomain(manualLevel);

    expect(definition.arrows.single.direction, Direction.right);
  });
}
