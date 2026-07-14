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
  int? number,
}) {
  return LevelDefinition(
    id: 'test-level',
    number: number,
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

// Four-node horizontal graph: a(0,0)—b(1,0)—c(2,0)—d(3,0).
// Use for collision tests where arrow-1 covers [a,b] and arrow-2 covers [c,d]:
// arrow-1's head at b sweeps right to c, which is occupied by arrow-2 → collision.
// No nodes are shared between the two arrows.
LevelDefinition collisionDefinition({
  required List<ArrowPathDefinition> arrows,
  int? number,
}) {
  return LevelDefinition(
    id: 'collision-test',
    number: number,
    name: 'Collision Test',
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
    arrows: arrows,
    blockedEdgeIds: const [],
    metadata: const {'difficulty': 'test'},
  );
}
