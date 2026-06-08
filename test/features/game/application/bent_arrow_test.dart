import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

// Board used by most tests:
//   a(0,0) — b(1,0) — c(2,0)
//                |
//             d(1,1)
//
// Edges: ab (horizontal), bc (horizontal), bd (vertical).
// Arrow L occupies ab + bd: tail=a, bend=b, head=d, direction=down.

void main() {
  const resolver = MovementResolver();

  // ---------------------------------------------------------------------------
  // orderedNodeIds derivation
  // ---------------------------------------------------------------------------

  test('orderedNodeIds_for_L_arrow_is_tail_bend_head', () {
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'L',
            occupiedEdgeIds: ['ab', 'bd'],
            startNodeId: 'a',
            endNodeId: 'd',
            direction: Direction.down,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('L')!;
    expect(arrow.orderedNodeIds, equals(['a', 'b', 'd']));
  });

  test('orderedNodeIds_when_edges_supplied_in_reverse_order', () {
    // JSON may list edges in any order; derivation must follow the chain.
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'L',
            occupiedEdgeIds: ['bd', 'ab'], // reversed vs natural order
            startNodeId: 'a',
            endNodeId: 'd',
            direction: Direction.down,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('L')!;
    expect(arrow.orderedNodeIds, equals(['a', 'b', 'd']));
  });

  test('orderedNodeIds_for_single_edge_arrow_is_start_end', () {
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'S',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('S')!;
    expect(arrow.orderedNodeIds, equals(['a', 'b']));
  });

  // ---------------------------------------------------------------------------
  // MovementResolver — bent arrow collision / escape
  // ---------------------------------------------------------------------------

  test('bent_arrow_escapes_when_path_below_head_is_clear', () {
    // Head at d(1,1); no node below d → exits down.
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'L',
            occupiedEdgeIds: ['ab', 'bd'],
            startNodeId: 'a',
            endNodeId: 'd',
            direction: Direction.down,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('L')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('bent_arrow_collides_when_body_sweep_hits_another_arrow', () {
    // 2-column × 3-row grid:
    //   a(0,0) — b(1,0)
    //   c(0,1) — d(1,1)
    //   e(0,2) — f(1,2)
    //
    // Arrow L: L-shaped, occupies ab+bd (tail=a, bend=b, head=d, direction=down).
    //   Covered nodes: {a, b, d}.
    // Arrow B: occupies ce (tail=c, head=e, direction=down).
    //   Covered nodes: {c, e}. No overlap with L.
    //
    // When L moves down:
    //   • From a(0,0): sweep down → neighbour c(0,1) ∈ B's nodes → COLLISION.
    final definition = LevelDefinition(
      id: 'bent-collision',
      name: 'Bent Collision',
      nodes: const [
        GraphNodeDefinition(id: 'a', x: 0, y: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0),
        GraphNodeDefinition(id: 'c', x: 0, y: 1),
        GraphNodeDefinition(id: 'd', x: 1, y: 1),
        GraphNodeDefinition(id: 'e', x: 0, y: 2),
        GraphNodeDefinition(id: 'f', x: 1, y: 2),
      ],
      edges: const [
        GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'cd', fromNodeId: 'c', toNodeId: 'd'),
        GraphEdgeDefinition(id: 'ef', fromNodeId: 'e', toNodeId: 'f'),
        GraphEdgeDefinition(id: 'ac', fromNodeId: 'a', toNodeId: 'c'),
        GraphEdgeDefinition(id: 'bd', fromNodeId: 'b', toNodeId: 'd'),
        GraphEdgeDefinition(id: 'ce', fromNodeId: 'c', toNodeId: 'e'),
        GraphEdgeDefinition(id: 'df', fromNodeId: 'd', toNodeId: 'f'),
      ],
      arrows: const [
        ArrowPathDefinition(
          id: 'L',
          occupiedEdgeIds: ['ab', 'bd'],
          startNodeId: 'a',
          endNodeId: 'd',
          direction: Direction.down,
        ),
        ArrowPathDefinition(
          id: 'B',
          occupiedEdgeIds: ['ce'],
          startNodeId: 'c',
          endNodeId: 'e',
          direction: Direction.down,
        ),
      ],
      blockedEdgeIds: const [],
      metadata: const {'difficulty': 'test'},
    );
    final session = buildSession(definition);
    final arrow = session.arrowById('L')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });
}
