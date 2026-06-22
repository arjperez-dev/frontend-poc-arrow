import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/move_arrow_command.dart';
import 'package:frontend_poc_arrow/features/game/application/move_arrow_use_case.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_result.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_status.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

void main() {
  const useCase = MoveArrowUseCase();

  // -------------------------------------------------------------------------
  // Exit attempt — success
  // -------------------------------------------------------------------------

  test('should_escape_arrow_when_path_to_boundary_is_clear', () {
    // arrow-1 starts at b→c (rightward). c has no right-neighbor → exits.
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

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.outcome, MovementOutcome.escaped);
    expect(result.session.arrowById('arrow-1')?.isEscaped, isTrue);
    expect(result.session.movesCount, 1);
    expect(result.session.mistakeCount, 0);
  });

  test('should_set_victory_when_all_arrows_escape', () {
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

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.session.status, GameStatus.victory);
  });

  test('should_keep_graph_nodes_visible_after_arrow_exits', () {
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
    final nodeCountBefore = session.level.boardGraph.nodes.length;

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.session.level.boardGraph.nodes, hasLength(nodeCountBefore));
    expect(result.session.level.boardGraph.nodeById('c'), isNotNull);
  });

  // -------------------------------------------------------------------------
  // Exit attempt — collision (path blocked by another arrow)
  // -------------------------------------------------------------------------

  test('should_return_collision_when_path_is_blocked_by_another_arrow', () {
    // arrow-1 head at b going right; arrow-2 covers [c,d] — no shared nodes.
    // Sweep from b(1,0) hits c(2,0) which is occupied by arrow-2 → collision.
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

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.outcome, MovementOutcome.collision);
    // Arrow position must not change (no partial movement).
    expect(result.session.arrowById('arrow-1')?.endNodeId, 'b');
    expect(result.session.arrowById('arrow-1')?.occupiedEdgeIds, ['ab']);
    expect(result.session.mistakeCount, 1);
    expect(result.session.movesCount, 1);
  });

  test('should_return_collision_when_path_is_blocked_by_a_blocked_edge', () {
    final session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.outcome, MovementOutcome.collision);
    expect(result.session.arrowById('arrow-1')?.endNodeId, 'b');
    expect(result.session.mistakeCount, 1);
    expect(result.session.movesCount, 1);
  });

  // -------------------------------------------------------------------------
  // Rollback — no partial movement remains after collision
  // -------------------------------------------------------------------------

  test('should_leave_arrow_unchanged_after_collision', () {
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
    final originalEdges =
        List<String>.from(session.arrowById('arrow-1')!.occupiedEdgeIds);

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(
      result.session.arrowById('arrow-1')!.occupiedEdgeIds,
      equals(originalEdges),
    );
  });

  // -------------------------------------------------------------------------
  // Lives system
  // -------------------------------------------------------------------------

  test('should_start_with_3_lives', () {
    final session = buildSession(basicDefinition());
    expect(session.livesRemaining, 3);
  });

  test('should_keep_3_lives_after_1_mistake', () {
    final session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );
    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(result.session.livesRemaining, 3);
    expect(result.session.mistakeCount, 1);
  });

  test('should_have_2_lives_after_2_mistakes', () {
    final session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );
    var s = session;
    for (var i = 0; i < 2; i++) {
      final result = useCase.execute(
        session: s,
        command: const MoveArrowCommand(arrowId: 'arrow-1'),
      );
      s = result.session;
    }
    expect(s.livesRemaining, 2);
    expect(s.mistakeCount, 2);
  });

  test('should_trigger_game_over_when_lives_reach_zero', () {
    // 6 collisions → 0 lives → GameStatus.failed.
    var session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );
    MovementResult result =
        MovementResult(session: session, outcome: MovementOutcome.collision);
    for (var i = 0; i < 6; i++) {
      result = useCase.execute(
        session: result.session,
        command: const MoveArrowCommand(arrowId: 'arrow-1'),
      );
    }
    expect(result.outcome, MovementOutcome.gameOver);
    expect(result.session.status, GameStatus.failed);
    expect(result.session.livesRemaining, 0);
  });

  // -------------------------------------------------------------------------
  // Guards
  // -------------------------------------------------------------------------

  test('should_return_already_escaped_when_arrow_is_already_escaped', () {
    // arrow-1 covers [c,d] with head at d going right; d(3,0) has no right
    // neighbor → exits immediately. arrow-2 covers [a,b]; no shared nodes.
    // After arrow-1 escapes the session stays playing (arrow-2 not yet tapped).
    final session = buildSession(
      collisionDefinition(
        arrows: const [
          ArrowPathDefinition(
            id: 'arrow-1',
            occupiedEdgeIds: ['cd'],
            startNodeId: 'c',
            endNodeId: 'd',
            direction: Direction.right,
          ),
          ArrowPathDefinition(
            id: 'arrow-2',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.right,
          ),
        ],
      ),
    );
    // Escape arrow-1 (head at d(3,0), no right-neighbor → escapes).
    final afterEscape = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(afterEscape.outcome, MovementOutcome.escaped);
    // Session is still playing because arrow-2 is active.
    expect(afterEscape.session.status, GameStatus.playing);

    // Tap the already-escaped arrow-1.
    final followUp = useCase.execute(
      session: afterEscape.session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(followUp.outcome, MovementOutcome.alreadyEscaped);
  });

  test('should_return_arrow_not_found_for_unknown_arrow_id', () {
    final session = buildSession(basicDefinition());
    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'nonexistent'),
    );
    expect(result.outcome, MovementOutcome.arrowNotFound);
  });

  test('should_return_session_not_active_when_session_is_failed', () {
    // Drive session to failed state first.
    var session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );
    MovementResult r =
        MovementResult(session: session, outcome: MovementOutcome.collision);
    for (var i = 0; i < 6; i++) {
      r = useCase.execute(
        session: r.session,
        command: const MoveArrowCommand(arrowId: 'arrow-1'),
      );
    }
    expect(r.session.status, GameStatus.failed);

    // Further input must be ignored.
    final after = useCase.execute(
      session: r.session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(after.outcome, MovementOutcome.sessionNotActive);
  });

  // -------------------------------------------------------------------------
  // Score formula
  // -------------------------------------------------------------------------

  test('should_calculate_score_correctly_with_no_mistakes', () {
    // 1 move, 0 mistakes → 1000 - 0 - 5 = 995
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
    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(result.session.score.value, 995);
  });

  test('should_penalise_mistakes_heavily_in_score', () {
    // After 1 collision: moves=1, mistakes=1 → 1000 - 100 - 5 = 895
    final session = buildSession(
      basicDefinition(blockedEdgeIds: ['bc']),
    );
    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );
    expect(result.session.score.value, 895);
  });
}
