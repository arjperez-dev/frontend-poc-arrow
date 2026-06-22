import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

void main() {
  const resolver = MovementResolver();

  // -------------------------------------------------------------------------
  // Escaped outcomes
  // -------------------------------------------------------------------------

  test('should_escape_when_head_is_at_board_boundary', () {
    // arrow head at c; no right-neighbor for c → exit.
    final session = buildSession(
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
    final arrow = session.arrowById('arrow-1')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('should_escape_single_segment_arrow_through_full_path', () {
    // arrow-1: head at b going right; path is b→c (free), then c exits.
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('arrow-1')!;
    // b→c is free, c has no right-neighbor → escaped.
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('should_escape_multi_segment_arrow_sliding_to_boundary', () {
    // 2-segment arrow occupying ab+bc; head at c → exits right immediately.
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab', 'bc'],
            startNodeId: 'a',
            endNodeId: 'c',
            direction: Direction.right,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('arrow-1')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  // -------------------------------------------------------------------------
  // Collision outcomes
  // -------------------------------------------------------------------------

  test('should_collide_when_another_arrow_occupies_path_ahead', () {
    // arrow-1 head at b going right; arrow-2 occupies [c,d] — no shared nodes.
    // Sweep from b(1,0) steps to c(2,0) which is in arrow-2's covered set → blocked.
    final session = buildSession(
      collisionDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
          ArrowPathDefinition(
            id: 'arrow-2',
            occupiedEdgeIds: ['cd'],
            startNodeId: 'd',
            endNodeId: 'c',
            direction: Direction.left,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('arrow-1')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });

  test('should_collide_when_left_pointing_arrow_faces_right_pointing_arrow', () {
    // Symmetric of the opposite-direction test: tapping arrow-2 (head=c, left).
    // Sweep from c(2,0) leftward → b(1,0) ∈ arrow-1's covered set → collision.
    final session = buildSession(
      collisionDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
          ArrowPathDefinition(
            id: 'arrow-2',
            occupiedEdgeIds: ['cd'],
            startNodeId: 'd',
            endNodeId: 'c',
            direction: Direction.left,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('arrow-2')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });

  test('should_collide_when_edge_is_blocked', () {
    // Default fixture arrow head at b going right; bc is blocked.
    final session = buildSession(basicDefinition(blockedEdgeIds: ['bc']));
    final arrow = session.arrowById('arrow-1')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.collision);
  });

  test('should_not_self_collide_on_own_body_edges', () {
    // 2-segment arrow occupies ab+bc; head at c going right → exits (c is boundary).
    // The arrow's own edges must not be seen as blockers.
    final session = buildSession(
      basicDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['ab', 'bc'],
            startNodeId: 'a',
            endNodeId: 'c',
            direction: Direction.right,
          ),
        ],
      ),
    );
    final arrow = session.arrowById('arrow-1')!;
    expect(resolver.resolve(session: session, arrow: arrow), ExitAttemptOutcome.escaped);
  });

  test('should_escape_when_head_clear_and_body_sweep_would_overlap_another_arrow', () {
    // Head-only rule: only the head collides; body adjacency is not a collision.
    // Arrow A (a-b-c on row 0) exits RIGHT. Head c(2,0) sweeps off the right edge.
    // Arrow B sits on d-e (row 1, left of c). A's body node a is above d (B) —
    // under head-only physics that is irrelevant. Arrow A must escape.
    final session = buildSession(_grid3x2(
      arrows: const [
        ArrowPathDefinition(
          id: 'A',
          occupiedEdgeIds: ['a-b', 'b-c'],
          startNodeId: 'a',
          endNodeId: 'c',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'B',
          occupiedEdgeIds: ['d-e'],
          startNodeId: 'd',
          endNodeId: 'e',
          direction: Direction.right,
        ),
      ],
    ));

    final a = session.arrowById('A')!;
    expect(
      resolver.resolve(session: session, arrow: a),
      ExitAttemptOutcome.escaped,
    );
  });

  test('should_escape_when_full_shape_sweep_is_clear', () {
    // Arrow A (d-e-f on row 1) exits RIGHT. Head f(2,1) sweeps off the right edge.
    // No blocker on the right → escaped.
    final session = buildSession(_grid3x2(
      arrows: const [
        ArrowPathDefinition(
          id: 'A',
          occupiedEdgeIds: ['d-e', 'e-f'],
          startNodeId: 'd',
          endNodeId: 'f',
          direction: Direction.right,
        ),
      ],
    ));

    final a = session.arrowById('A')!;
    // Row-1 nodes have no node beneath them → whole shape exits down.
    expect(
      resolver.resolve(session: session, arrow: a),
      ExitAttemptOutcome.escaped,
    );
  });

  // -------------------------------------------------------------------------
  // Connected traversal graph — continuation through connector nodes
  // -------------------------------------------------------------------------

  test('should_not_escape_at_internal_visual_gap_when_traversal_graph_continues',
      () {
    // a-b-c-d-e in one connected row. Arrow A occupies a-b (head b, right).
    // c is an unoccupied continuation node (a "visual gap"). Arrow B sits on
    // d-e ahead. A must NOT escape at the gap — it sweeps through c and hits B.
    final session = buildSession(_lineGraph(
      arrows: const [
        ArrowPathDefinition(
          id: 'A',
          occupiedEdgeIds: ['a-b'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'B',
          occupiedEdgeIds: ['d-e'],
          startNodeId: 'd',
          endNodeId: 'e',
          direction: Direction.right,
        ),
      ],
    ));
    final a = session.arrowById('A')!;
    expect(
      resolver.resolve(session: session, arrow: a),
      isNot(ExitAttemptOutcome.escaped),
    );
  });

  test('should_collide_with_arrow_across_connector_path_when_trajectory_overlaps',
      () {
    // Same connected line. A's rightward trajectory continues through the
    // connector node c and overlaps B on d-e → collision.
    final session = buildSession(_lineGraph(
      arrows: const [
        ArrowPathDefinition(
          id: 'A',
          occupiedEdgeIds: ['a-b'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'B',
          occupiedEdgeIds: ['d-e'],
          startNodeId: 'd',
          endNodeId: 'e',
          direction: Direction.right,
        ),
      ],
    ));
    final a = session.arrowById('A')!;
    expect(
      resolver.resolve(session: session, arrow: a),
      ExitAttemptOutcome.collision,
    );
  });

  // -------------------------------------------------------------------------
  // Guard — already escaped
  // -------------------------------------------------------------------------

  test('should_return_already_escaped_for_escaped_arrow', () {
    final session = buildSession(basicDefinition());
    final escaped = session.arrowById('arrow-1')!.copyWith(isEscaped: true);
    expect(resolver.resolve(session: session, arrow: escaped), ExitAttemptOutcome.alreadyEscaped);
  });
}

/// One connected row a-b-c-d-e (c is a continuation/connector node).
LevelDefinition _lineGraph({required List<ArrowPathDefinition> arrows}) {
  return LevelDefinition(
    id: 'line',
    name: 'Line',
    nodes: const [
      GraphNodeDefinition(id: 'a', x: 0, y: 0),
      GraphNodeDefinition(id: 'b', x: 1, y: 0),
      GraphNodeDefinition(id: 'c', x: 2, y: 0),
      GraphNodeDefinition(id: 'd', x: 3, y: 0),
      GraphNodeDefinition(id: 'e', x: 4, y: 0),
    ],
    edges: const [
      GraphEdgeDefinition(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
      GraphEdgeDefinition(id: 'b-c', fromNodeId: 'b', toNodeId: 'c'),
      GraphEdgeDefinition(id: 'c-d', fromNodeId: 'c', toNodeId: 'd'),
      GraphEdgeDefinition(id: 'd-e', fromNodeId: 'd', toNodeId: 'e'),
    ],
    arrows: arrows,
    blockedEdgeIds: const [],
    metadata: const {'difficulty': 'test'},
  );
}

/// 3 columns x 2 rows grid:
///   a(0,0) b(1,0) c(2,0)
///   d(0,1) e(1,1) f(2,1)
LevelDefinition _grid3x2({required List<ArrowPathDefinition> arrows}) {
  return LevelDefinition(
    id: 'grid-3x2',
    name: 'Grid 3x2',
    nodes: const [
      GraphNodeDefinition(id: 'a', x: 0, y: 0),
      GraphNodeDefinition(id: 'b', x: 1, y: 0),
      GraphNodeDefinition(id: 'c', x: 2, y: 0),
      GraphNodeDefinition(id: 'd', x: 0, y: 1),
      GraphNodeDefinition(id: 'e', x: 1, y: 1),
      GraphNodeDefinition(id: 'f', x: 2, y: 1),
    ],
    edges: const [
      GraphEdgeDefinition(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
      GraphEdgeDefinition(id: 'b-c', fromNodeId: 'b', toNodeId: 'c'),
      GraphEdgeDefinition(id: 'd-e', fromNodeId: 'd', toNodeId: 'e'),
      GraphEdgeDefinition(id: 'e-f', fromNodeId: 'e', toNodeId: 'f'),
      GraphEdgeDefinition(id: 'a-d', fromNodeId: 'a', toNodeId: 'd'),
      GraphEdgeDefinition(id: 'b-e', fromNodeId: 'b', toNodeId: 'e'),
      GraphEdgeDefinition(id: 'c-f', fromNodeId: 'c', toNodeId: 'f'),
    ],
    arrows: arrows,
    blockedEdgeIds: const [],
    metadata: const {'difficulty': 'test'},
  );
}
