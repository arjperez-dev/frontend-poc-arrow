import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

// Proves MovementResolver — unchanged since Phase 12.1 — already handles the
// Z axis correctly, because it sweeps via `direction.applyTo(coordinate)` +
// `nodeByCoordinate` rather than switching on Direction. No resolver code
// was touched to make these pass.
void main() {
  const resolver = MovementResolver();

  test('should_escape_downward_through_an_empty_layer', () {
    // a0(0,0,0), single-node arrow, direction=below. No node claims (0,0,1),
    // and z=2 has no node at all, so the sweep runs clear off the board.
    final definition = LevelDefinition(
      id: '3d-clear-descent',
      name: '3D Clear Descent',
      nodes: const [
        GraphNodeDefinition(id: 'a0', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'a1', x: 0, y: 0, z: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'a0-a1', fromNodeId: 'a0', toNodeId: 'a1'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'descender',
          occupiedEdgeIds: [],
          startNodeId: 'a0',
          endNodeId: 'a0',
          direction: LayerDirection.below,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );
    final session = buildSession(definition);
    final arrow = session.arrowById('descender')!;

    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('should_collide_when_another_arrow_occupies_the_layer_below', () {
    // Same board, but a second arrow's single node sits at a1 — the head's
    // very next coordinate stepping "below". No graph edge is needed for
    // the blocker to be detected (matches the sparse-graph coordinate sweep
    // proven for the X/Y plane in bent_arrow_test.dart).
    final definition = LevelDefinition(
      id: '3d-blocked-descent',
      name: '3D Blocked Descent',
      nodes: const [
        GraphNodeDefinition(id: 'a0', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'a1', x: 0, y: 0, z: 1),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'a0-a1', fromNodeId: 'a0', toNodeId: 'a1'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'descender',
          occupiedEdgeIds: [],
          startNodeId: 'a0',
          endNodeId: 'a0',
          direction: LayerDirection.below,
        ),
        ArrowPathDefinition(
          id: 'blocker',
          occupiedEdgeIds: [],
          startNodeId: 'a1',
          endNodeId: 'a1',
          direction: Direction.right,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );
    final session = buildSession(definition);
    final arrow = session.arrowById('descender')!;

    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });
}
