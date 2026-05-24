import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';

LevelDefinition basicDefinition({
  List<GraphEdgeDefinition>? edges,
  List<ArrowPathDefinition>? arrows,
  List<String>? blockedEdgeIds,
  Map<String, Object?>? metadata,
}) {
  return LevelDefinition(
    id: 'test-level',
    name: 'Test Level',
    nodes: const [
      GraphNodeDefinition(id: 'a', x: 0, y: 0),
      GraphNodeDefinition(id: 'b', x: 1, y: 0),
      GraphNodeDefinition(id: 'c', x: 2, y: 0),
      GraphNodeDefinition(id: 'd', x: 1, y: 1),
    ],
    edges: edges ??
        const [
          GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
          GraphEdgeDefinition(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
          GraphEdgeDefinition(id: 'bd', fromNodeId: 'b', toNodeId: 'd'),
        ],
    arrows: arrows ??
        const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
        ],
    blockedEdgeIds: blockedEdgeIds ?? const [],
    metadata: metadata ?? const {'difficulty': 'test'},
  );
}

Level buildLevel(LevelDefinition definition) {
  return LevelDefinitionValidator().validate(definition);
}

GameSession buildSession(LevelDefinition definition) {
  return GameSession.start(buildLevel(definition));
}
