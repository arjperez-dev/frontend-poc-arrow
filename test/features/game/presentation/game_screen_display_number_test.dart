import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_controller.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_scope.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/routing/app_routes.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/game/domain/arrow_path.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_edge.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

void main() {
  testWidgets(
    'should_display_progression_position_in_app_bar',
    (tester) async {
      // Internal 9 is the easier of the two, so it is FIRST in the sorted
      // progression and displays as "Level 1" despite its internal number.
      final played = _singleNodeExitLevel(number: 9);
      await tester.pumpWidget(
        _TestApp(
          level: played,
          levels: [_blockedPairLevel(number: 4), played],
          gameMode: GameMode.twoD,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 9'), findsNothing);
    },
  );

  testWidgets(
    'should_fall_back_to_internal_number_mapping_when_level_list_unavailable',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          level: _singleNodeExitLevel(number: 5),
          levels: null, // loadLevels throws → arithmetic fallback
          gameMode: GameMode.twoD,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 5'), findsOneWidget);
    },
  );

  testWidgets(
    'should_fall_back_to_3d_offset_mapping_when_level_list_unavailable',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          level: _singleNodeExitLevel(number: 21),
          levels: null,
          gameMode: GameMode.threeD,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 21'), findsNothing);
    },
  );

  testWidgets(
    'should_display_3d_progression_position_isolated_from_2d_levels',
    (tester) async {
      // The level list mixes both modes; the 3D progression is built from
      // the 3D partition alone, so internal 21 is its first level.
      final played = _singleNodeExitLevel(number: 21);
      await tester.pumpWidget(
        _TestApp(
          level: played,
          levels: [
            _blockedPairLevel(number: 4),
            _singleNodeExitLevel(number: 9),
            played,
            _blockedPairLevel(number: 22),
          ],
          gameMode: GameMode.threeD,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 21'), findsNothing);
    },
  );

  testWidgets(
    'should_offer_next_level_in_progression_order_on_victory',
    (tester) async {
      // Progression: [9 (easy), 4 (harder)] — after beating internal 9 the
      // next level is internal 4, displayed as "2".
      final played = _singleNodeExitLevel(number: 9);
      int? pushedLevelNumber;
      await tester.pumpWidget(
        _TestApp(
          level: played,
          levels: [_blockedPairLevel(number: 4), played],
          gameMode: GameMode.twoD,
          onGameRoutePushed: (settings) {
            pushedLevelNumber = settings.arguments as int?;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getTopLeft(find.byKey(GameUiKeys.gameBoard)) +
            const Offset(32, 32),
      );
      await tester.pump();

      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
      expect(find.textContaining('Next level: 2'), findsOneWidget);

      await tester.tap(find.byKey(GameUiKeys.nextLevelButton));
      await tester.pumpAndSettle();

      // Navigation uses the INTERNAL number of the progression's next level.
      expect(pushedLevelNumber, 4);
    },
  );

  testWidgets(
    'should_hide_next_level_button_on_last_level_of_progression',
    (tester) async {
      // The played level is the ONLY (and therefore last) entry of its
      // progression → no next level, even though the internal-number
      // fallback (9 < 20) would have offered one.
      final played = _singleNodeExitLevel(number: 9);
      await tester.pumpWidget(
        _TestApp(level: played, levels: [played], gameMode: GameMode.twoD),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getTopLeft(find.byKey(GameUiKeys.gameBoard)) +
            const Offset(32, 32),
      );
      await tester.pump();

      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
      expect(find.byKey(GameUiKeys.nextLevelButton), findsNothing);
    },
  );
}

Level _singleNodeExitLevel({required int number}) {
  return Level(
    id: 'fixture-exit-$number',
    number: number,
    name: 'Level $number',
    boardGraph: BoardGraph(
      nodes: const [
        GraphNode(id: 'a', coordinate: BoardCoordinate(x: 0, y: 0)),
      ],
      edges: const [],
    ),
    arrows: const [
      ArrowPath(
        id: 'arrow-1',
        occupiedEdgeIds: [],
        orderedNodeIds: ['a'],
        startNodeId: 'a',
        endNodeId: 'a',
        direction: Direction.right,
      ),
    ],
    metadata: const {'difficulty': 'test'},
  );
}

/// Two arrows on a row where the left arrow's exit sweep is initially
/// blocked by the right arrow — strictly higher complexity score than
/// [_singleNodeExitLevel].
Level _blockedPairLevel({required int number}) {
  return Level(
    id: 'fixture-pair-$number',
    number: number,
    name: 'Level $number',
    boardGraph: BoardGraph(
      nodes: const [
        GraphNode(id: 'a', coordinate: BoardCoordinate(x: 0, y: 0)),
        GraphNode(id: 'b', coordinate: BoardCoordinate(x: 1, y: 0)),
        GraphNode(id: 'c', coordinate: BoardCoordinate(x: 2, y: 0)),
        GraphNode(id: 'd', coordinate: BoardCoordinate(x: 3, y: 0)),
      ],
      edges: const [
        GraphEdge(id: 'ab', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdge(id: 'bc', fromNodeId: 'b', toNodeId: 'c'),
        GraphEdge(id: 'cd', fromNodeId: 'c', toNodeId: 'd'),
      ],
    ),
    arrows: const [
      ArrowPath(
        id: 'arrow-1',
        occupiedEdgeIds: ['ab'],
        orderedNodeIds: ['a', 'b'],
        startNodeId: 'a',
        endNodeId: 'b',
        direction: Direction.right,
      ),
      ArrowPath(
        id: 'arrow-2',
        occupiedEdgeIds: ['cd'],
        orderedNodeIds: ['c', 'd'],
        startNodeId: 'c',
        endNodeId: 'd',
        direction: Direction.right,
      ),
    ],
    metadata: const {'difficulty': 'test'},
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.level,
    required this.levels,
    required this.gameMode,
    this.onGameRoutePushed,
  });

  final Level level;

  /// Level list served to the game screen's progression loader; null makes
  /// the loader throw so the screen uses the internal-number fallback.
  final List<Level>? levels;

  final GameMode gameMode;
  final void Function(RouteSettings settings)? onGameRoutePushed;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: AppSettingsController(initialGameMode: gameMode),
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(
          levelNumber: level.number,
          enableBoardAnimations: false,
          loadLevelByNumber: (_) async => level,
          loadLevels: () async =>
              levels ?? (throw StateError('level list unavailable')),
          saveLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {},
          getBestLevelResult: (_) async => null,
          notifyRemoteLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {},
          playGameAudio: (_) async {},
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.game) {
            onGameRoutePushed?.call(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Next game'))),
            );
          }
          return null;
        },
      ),
    );
  }
}
