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

  test('should_not_move_arrow_when_edge_is_blocked', () {
    final session = buildSession(
      basicDefinition(
        blockedEdgeIds: ['bc'],
      ),
    );

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.outcome, MovementOutcome.blocked);
    expect(result.session.arrowById('arrow-1')?.endNodeId, 'b');
    expect(result.session.movesCount, 0);
  });

  test('should_not_move_arrow_when_target_path_is_occupied', () {
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
          ArrowPathDefinition(
            id: 'arrow-2',
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

    expect(result.outcome, MovementOutcome.occupied);
    expect(result.session.arrowById('arrow-1')?.endNodeId, 'b');
    expect(result.session.movesCount, 0);
  });

  test('should_remove_arrow_when_it_exits_graph', () {
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
          ArrowPathDefinition(
            id: 'arrow-2',
            occupiedEdgeIds: ['ab'],
            startNodeId: 'a',
            endNodeId: 'b',
            direction: Direction.down,
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
    expect(result.session.activeArrows.map((arrow) => arrow.id), isNot(contains('arrow-1')));

    final followUp = useCase.execute(
      session: result.session,
      command: const MoveArrowCommand(arrowId: 'arrow-2'),
    );
    expect(followUp.outcome, MovementOutcome.moved);
    expect(followUp.session.arrowById('arrow-2')?.occupiedEdgeIds, contains('bd'));
  });

  test('should_keep_graph_nodes_when_arrow_exits', () {
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
    final nodeCountBeforeExit = session.level.boardGraph.nodes.length;

    final result = useCase.execute(
      session: session,
      command: const MoveArrowCommand(arrowId: 'arrow-1'),
    );

    expect(result.session.level.boardGraph.nodes, hasLength(nodeCountBeforeExit));
    expect(result.session.level.boardGraph.nodeById('c'), isNotNull);
  });

  test('should_return_victory_when_all_arrows_escape', () {
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
}
