import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/level_progression.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_topology.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/level_mode_filter.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

// The production unlock gate is LevelProgression.isUnlockedAfter (Phase 29),
// not the legacy LocalProgress.isUnlockedForMode (2D/3D-only, never extended
// to hex — see level_mode_filter.dart's doc comment). This proves hex's
// progression-order unlock works, and is isolated from 2D/3D completion,
// through that real production gate.
void main() {
  Level flat(int number, {BoardTopology topology = BoardTopology.square}) {
    return Level(
      id: 'fixture-$number',
      number: number,
      name: 'Level $number',
      boardGraph: BoardGraph(
        nodes: [
          GraphNode(id: 'a', coordinate: const BoardCoordinate(x: 0, y: 0)),
        ],
        edges: const [],
        topology: topology,
      ),
      arrows: const [],
      metadata: const {'difficulty': 'test'},
    );
  }

  final mixedLevels = [
    flat(1),
    flat(20),
    flat(31, topology: BoardTopology.hex),
    flat(35, topology: BoardTopology.hex),
  ];

  test('first hex level is always unlocked with empty progress', () {
    final progression = LevelProgression.fromLevels(
      filterLevelsByGameMode(mixedLevels, mode: GameMode.hex),
    );

    // Both hex fixtures tie on complexity (single flat node each), so order
    // falls back to internal number: 31 first, 35 second.
    expect(progression.entries[0].level.number, 31);
    expect(progression.previousInternalBefore(31), isNull);

    final progress = LocalProgress.initial();
    expect(progress.isUnlockedAfter(progression.previousInternalBefore(31)), isTrue);
  });

  test('second hex level locked until the first hex level is completed', () {
    final progression = LevelProgression.fromLevels(
      filterLevelsByGameMode(mixedLevels, mode: GameMode.hex),
    );
    final previous = progression.previousInternalBefore(35);

    final withoutCompletion = LocalProgress.initial();
    expect(withoutCompletion.isUnlockedAfter(previous), isFalse);

    final withCompletion = LocalProgress.initial().copyWith(
      completedLevelNumbers: {previous!},
    );
    expect(withCompletion.isUnlockedAfter(previous), isTrue);
  });

  test(
    'completing 2D level 1 (or 3D) does not unlock the second hex level',
    () {
      final progression = LevelProgression.fromLevels(
        filterLevelsByGameMode(mixedLevels, mode: GameMode.hex),
      );
      final previous = progression.previousInternalBefore(35)!;

      // Completing an unrelated 2D level must not satisfy the hex
      // predecessor gate.
      final progress = LocalProgress.initial().copyWith(
        completedLevelNumbers: const {1, 20},
      );

      expect(progress.isUnlockedAfter(previous), isFalse);
    },
  );

  test('completing hex level 31 does not unlock 2D level 2', () {
    final twoDProgression = LevelProgression.fromLevels(
      filterLevelsByGameMode(mixedLevels, mode: GameMode.twoD),
    );
    final previous = twoDProgression.previousInternalBefore(20);

    final progress = LocalProgress.initial().copyWith(
      completedLevelNumbers: const {31},
    );

    expect(progress.isUnlockedAfter(previous), isFalse);
  });
}
