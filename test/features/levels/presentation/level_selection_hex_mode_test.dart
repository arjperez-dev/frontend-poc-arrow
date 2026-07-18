import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_controller.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_scope.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/routing/app_routes.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_topology.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

// Hex-mode coverage for the level selection screen, mirroring
// level_selection_screen_game_mode_filter_test.dart's 2D/3D pattern.
// Confirms: hex levels appear in hex mode only, and the 2D/3D lists are
// unchanged in content and order when a hex level is present in the same
// loaded list (proves the three-way partition never leaks across modes).
void main() {
  testWidgets('should_show_only_hex_levels_when_game_mode_is_hex', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(levels: _mixedThreeModeLevels(), gameMode: GameMode.hex),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(GameUiKeys.levelCard(31)), findsOneWidget);
    expect(find.byKey(GameUiKeys.levelCard(35)), findsOneWidget);
    expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
    expect(find.byKey(GameUiKeys.levelCard(21)), findsNothing);
  });

  testWidgets(
    'should_leave_2d_and_3d_lists_unchanged_when_hex_levels_are_present',
    (tester) async {
      final levels = _mixedThreeModeLevels();

      await tester.pumpWidget(_TestApp(levels: levels, gameMode: GameMode.twoD));
      await tester.pumpAndSettle();
      expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(20)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(21)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(31)), findsNothing);

      await tester.pumpWidget(
        _TestApp(levels: levels, gameMode: GameMode.threeD),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(GameUiKeys.levelCard(21)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(23)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(31)), findsNothing);
    },
  );

  testWidgets(
    'should_display_hex_levels_as_positions_1_to_n_in_sorted_progression',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(levels: _mixedThreeModeLevels(), gameMode: GameMode.hex),
      );
      await tester.pumpAndSettle();

      // Internal 31 -> displayed "Level 1"; internal 35 -> displayed
      // "Level 2" (position in the hex progression alone).
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Level 31'), findsNothing);
      expect(find.text('Level 35'), findsNothing);
    },
  );

  testWidgets(
    'should_open_internal_level_31_when_displayed_hex_level_1_is_tapped',
    (tester) async {
      Object? capturedGameArgument;

      await tester.pumpWidget(
        _TestApp(
          levels: _mixedThreeModeLevels(),
          gameMode: GameMode.hex,
          allUnlocked: true,
          onGameRoutePushed: (settings) {
            capturedGameArgument = settings.arguments;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GameUiKeys.levelCard(31)));
      await tester.pumpAndSettle();

      expect(capturedGameArgument, 31);
    },
  );
}

List<Level> _mixedThreeModeLevels() {
  Level flat(int number, {BoardTopology topology = BoardTopology.square}) =>
      Level(
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

  Level multiLayer(int number) => Level(
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
    metadata: const {'difficulty': 'test'},
  );

  return [
    flat(1),
    flat(20),
    multiLayer(21),
    multiLayer(23),
    flat(31, topology: BoardTopology.hex),
    flat(35, topology: BoardTopology.hex),
  ];
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.levels,
    required this.gameMode,
    this.allUnlocked = false,
    this.onGameRoutePushed,
  });

  final List<Level> levels;
  final GameMode gameMode;
  final bool allUnlocked;
  final void Function(RouteSettings settings)? onGameRoutePushed;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: AppSettingsController(initialGameMode: gameMode),
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LevelSelectionScreen(
          loadLevels: () async => levels,
          loadProgress: () async => allUnlocked
              ? LocalProgress.initial().copyWith(lastUnlockedLevel: 40)
              : LocalProgress.initial(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.game) {
            onGameRoutePushed?.call(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Center(child: Text('Game'))),
            );
          }
          return null;
        },
      ),
    );
  }
}
