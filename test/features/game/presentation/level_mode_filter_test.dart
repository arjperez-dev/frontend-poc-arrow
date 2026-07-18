import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_topology.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/level_mode_filter.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

LocalProgress _progressWith(Set<int> completed) {
  return LocalProgress.initial().copyWith(completedLevelNumbers: completed);
}

Level _flatLevel(int number, {BoardTopology topology = BoardTopology.square}) {
  return Level(
    id: 'fixture-$number',
    number: number,
    name: 'Level $number',
    boardGraph: BoardGraph(
      nodes: [GraphNode(id: 'a', coordinate: const BoardCoordinate(x: 0, y: 0))],
      edges: const [],
      topology: topology,
    ),
    arrows: const [],
    metadata: {'difficulty': 'test'},
  );
}

Level _multiLayerLevel(int number) {
  return Level(
    id: 'fixture-$number',
    number: number,
    name: 'Level $number',
    boardGraph: BoardGraph(
      nodes: [
        GraphNode(id: 'a', coordinate: const BoardCoordinate(x: 0, y: 0, z: 0)),
        GraphNode(id: 'b', coordinate: const BoardCoordinate(x: 0, y: 0, z: 1)),
      ],
      edges: const [],
    ),
    arrows: const [],
    metadata: {'difficulty': 'test'},
  );
}

void main() {
  group('firstInternalLevelFor', () {
    test('returns 1 for 2D, 21 for 3D, and 31 for hex', () {
      expect(firstInternalLevelFor(GameMode.twoD), 1);
      expect(firstInternalLevelFor(GameMode.threeD), 21);
      expect(firstInternalLevelFor(GameMode.hex), 31);
    });
  });

  group('modeOfLevel', () {
    test('should_route_hex_topology_level_to_hex_mode', () {
      final level = _flatLevel(31, topology: BoardTopology.hex);

      expect(modeOfLevel(level), GameMode.hex);
    });

    test('should_still_route_square_and_3d_levels_unchanged', () {
      expect(modeOfLevel(_flatLevel(5)), GameMode.twoD);
      expect(modeOfLevel(_multiLayerLevel(22)), GameMode.threeD);
    });

    // The regression this phase most plausibly introduces: a hex level's
    // internal number (31+) is above twoDLevelCount, so isThreeDLevel's
    // local-only numeric fallback would misclassify it as 3D if
    // modeOfLevel didn't check topology BEFORE that fallback.
    test('should_not_route_a_single_layer_hex_level_as_2d_or_3d', () {
      final hexLevel = _flatLevel(31, topology: BoardTopology.hex);

      expect(modeOfLevel(hexLevel), GameMode.hex);
      expect(modeOfLevel(hexLevel), isNot(GameMode.twoD));
      expect(modeOfLevel(hexLevel), isNot(GameMode.threeD));
    });
  });

  group('filterLevelsByGameMode', () {
    test('partitions all three modes independently', () {
      final levels = [
        _flatLevel(1),
        _flatLevel(20),
        _multiLayerLevel(21),
        _multiLayerLevel(23),
        _flatLevel(31, topology: BoardTopology.hex),
        _flatLevel(35, topology: BoardTopology.hex),
      ];

      final twoD = filterLevelsByGameMode(levels, mode: GameMode.twoD);
      final threeD = filterLevelsByGameMode(levels, mode: GameMode.threeD);
      final hex = filterLevelsByGameMode(levels, mode: GameMode.hex);

      expect(twoD.map((l) => l.number), [1, 20]);
      expect(threeD.map((l) => l.number), [21, 23]);
      expect(hex.map((l) => l.number), [31, 35]);
    });
  });

  group('isLevelUnlockedForMode', () {
    test('3D first level (internal 21) is unlocked with empty progress', () {
      final progress = _progressWith(const <int>{});
      expect(isLevelUnlockedForMode(progress, 21, GameMode.threeD), isTrue);
    });

    test('3D internal 22 locked until 21 completed, unlocked after', () {
      expect(
        isLevelUnlockedForMode(_progressWith(const <int>{}), 22, GameMode.threeD),
        isFalse,
      );
      expect(
        isLevelUnlockedForMode(
          _progressWith(const <int>{21}),
          22,
          GameMode.threeD,
        ),
        isTrue,
      );
    });

    test('completing 2D level 20 does not unlock 3D internal 21', () {
      final progress = _progressWith(const <int>{20});
      // 21 is unlocked anyway because it is the first 3D level, but not *because
      // of* level 20 — 22 must stay locked.
      expect(isLevelUnlockedForMode(progress, 22, GameMode.threeD), isFalse);
    });

    test('completing 3D internal 21 does not unlock 2D level 2', () {
      final progress = _progressWith(const <int>{21});
      expect(isLevelUnlockedForMode(progress, 2, GameMode.twoD), isFalse);
    });

    test('2D level 1 unlocked by default; level 2 locked until 1 completed', () {
      expect(
        isLevelUnlockedForMode(_progressWith(const <int>{}), 1, GameMode.twoD),
        isTrue,
      );
      expect(
        isLevelUnlockedForMode(_progressWith(const <int>{}), 2, GameMode.twoD),
        isFalse,
      );
      expect(
        isLevelUnlockedForMode(_progressWith(const <int>{1}), 2, GameMode.twoD),
        isTrue,
      );
    });
  });
}
