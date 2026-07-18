import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/hex_direction.dart';
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

// A centre node with its 6 axial hex neighbours, one per HexDirection.
// centre(0,0), east(1,0), northEast(1,-1), northWest(0,-1), west(-1,0),
// southWest(-1,1), southEast(0,1). Single arrow covers centre->east so the
// fixture validates and produces a hex BoardGraph out of the box; callers
// needing a different arrow shape should pass their own `arrows`.
LevelDefinition hexDefinition({
  List<ArrowPathDefinition>? arrows,
  Map<String, Object?>? metadata,
  int? number,
}) {
  return LevelDefinition(
    id: 'hex-test-level',
    number: number,
    name: 'Hex Test Level',
    nodes: const [
      GraphNodeDefinition(id: 'centre', x: 0, y: 0),
      GraphNodeDefinition(id: 'east', x: 1, y: 0),
      GraphNodeDefinition(id: 'northEast', x: 1, y: -1),
      GraphNodeDefinition(id: 'northWest', x: 0, y: -1),
      GraphNodeDefinition(id: 'west', x: -1, y: 0),
      GraphNodeDefinition(id: 'southWest', x: -1, y: 1),
      GraphNodeDefinition(id: 'southEast', x: 0, y: 1),
    ],
    edges: const [
      GraphEdgeDefinition(id: 'centre-east', fromNodeId: 'centre', toNodeId: 'east'),
      GraphEdgeDefinition(id: 'centre-northEast', fromNodeId: 'centre', toNodeId: 'northEast'),
      GraphEdgeDefinition(id: 'centre-northWest', fromNodeId: 'centre', toNodeId: 'northWest'),
      GraphEdgeDefinition(id: 'centre-west', fromNodeId: 'centre', toNodeId: 'west'),
      GraphEdgeDefinition(id: 'centre-southWest', fromNodeId: 'centre', toNodeId: 'southWest'),
      GraphEdgeDefinition(id: 'centre-southEast', fromNodeId: 'centre', toNodeId: 'southEast'),
    ],
    arrows: arrows ??
        const [
          ArrowPathDefinition(
            id: 'hex-arrow-1',
            occupiedEdgeIds: ['centre-east'],
            startNodeId: 'centre',
            endNodeId: 'east',
            direction: HexDirection.east,
          ),
        ],
    blockedEdgeIds: const [],
    metadata: metadata ?? const {'difficulty': 'test', 'topology': 'hex'},
  );
}
