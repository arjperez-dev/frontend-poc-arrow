import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/hex_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

// Proves MovementResolver requires zero changes for hex boards (audit §1.3):
// it sweeps by coordinate (`direction.applyTo` -> `nodeByCoordinate`), which
// is geometry-agnostic as long as the direction set resolves correctly.
void main() {
  const resolver = MovementResolver();

  test('clear_hex_sweep_to_boundary_escapes', () {
    // hexDefinition()'s default arrow: centre(0,0) -> east(1,0), direction
    // east. No node at (2,0) -> head sweep runs off the board.
    final session = buildSession(hexDefinition());
    final arrow = session.arrowById('hex-arrow-1')!;

    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('blocker_on_heads_axial_ray_is_collision', () {
    final definition = LevelDefinition(
      id: 'hex-blocker',
      name: 'Hex Blocker',
      nodes: const [
        GraphNodeDefinition(id: 'centre', x: 0, y: 0),
        GraphNodeDefinition(id: 'east', x: 1, y: 0),
        GraphNodeDefinition(id: 'farEast', x: 2, y: 0),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'centre-east', fromNodeId: 'centre', toNodeId: 'east'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'A',
          occupiedEdgeIds: ['centre-east'],
          startNodeId: 'centre',
          endNodeId: 'east',
          direction: HexDirection.east,
        ),
        ArrowPathDefinition(
          id: 'B',
          occupiedEdgeIds: [],
          startNodeId: 'farEast',
          endNodeId: 'farEast',
          direction: HexDirection.east,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test', 'topology': 'hex'},
    );
    final session = buildSession(definition);
    final arrow = session.arrowById('A')!;

    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });

  test('bent_hex_arrow_escapes_along_its_own_axes', () {
    // west(-1,0) -> centre(0,0) -> southEast(0,1) [head], direction southEast.
    // Head sweep: (0,1) + southEast(0,1) = (0,2) -> no node -> escapes.
    final definition = LevelDefinition(
      id: 'hex-bent',
      name: 'Hex Bent',
      nodes: const [
        GraphNodeDefinition(id: 'west', x: -1, y: 0),
        GraphNodeDefinition(id: 'centre', x: 0, y: 0),
        GraphNodeDefinition(id: 'southEast', x: 0, y: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'west-centre', fromNodeId: 'west', toNodeId: 'centre'),
        GraphEdgeDefinition(id: 'centre-southEast', fromNodeId: 'centre', toNodeId: 'southEast'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'L',
          occupiedEdgeIds: ['west-centre', 'centre-southEast'],
          startNodeId: 'west',
          endNodeId: 'southEast',
          direction: HexDirection.southEast,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test', 'topology': 'hex'},
    );
    final session = buildSession(definition);
    final arrow = session.arrowById('L')!;

    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });
}
