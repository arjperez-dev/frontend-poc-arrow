import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_controller.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_scope.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/routing/app_routes.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

void main() {
  testWidgets(
    'should_show_only_2d_levels_when_game_mode_is_2d',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(levels: _mixedLevels(), gameMode: GameMode.twoD),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(20)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(21)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(23)), findsNothing);
    },
  );

  testWidgets(
    'should_show_only_3d_levels_when_game_mode_is_3d',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(levels: _mixedLevels(), gameMode: GameMode.threeD),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(20)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(21)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(23)), findsOneWidget);
    },
  );

  testWidgets(
    'should_display_2d_levels_as_positions_in_sorted_progression',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(levels: _mixedLevels(), gameMode: GameMode.twoD),
      );
      await tester.pumpAndSettle();

      // Both 2D fixtures tie on complexity, so order falls back to internal
      // number: internal 1 -> "Level 1", internal 20 -> "Level 2" (display
      // numbers are 1..N positions in the sorted progression).
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Level 20'), findsNothing);
    },
  );

  testWidgets(
    'should_display_3d_levels_as_positions_1_to_n_in_sorted_progression',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(levels: _mixedLevels(), gameMode: GameMode.threeD),
      );
      await tester.pumpAndSettle();

      // Internal 21 -> displayed "Level 1"; internal 23 -> displayed
      // "Level 2" (position in the 3D progression, never the internal
      // number and never influenced by the 2D list).
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Level 21'), findsNothing);
      expect(find.text('Level 23'), findsNothing);
    },
  );

  testWidgets(
    'should_open_internal_level_21_when_displayed_3d_level_1_is_tapped',
    (tester) async {
      Object? capturedGameArgument;

      await tester.pumpWidget(
        _TestApp(
          levels: _mixedLevels(),
          gameMode: GameMode.threeD,
          allUnlocked: true,
          onGameRoutePushed: (settings) {
            capturedGameArgument = settings.arguments;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GameUiKeys.levelCard(21)));
      await tester.pumpAndSettle();

      expect(capturedGameArgument, 21);
    },
  );
}

List<Level> _mixedLevels() {
  Level flat(int number) => Level(
    id: 'fixture-$number',
    number: number,
    name: 'Level $number',
    boardGraph: BoardGraph(
      nodes: [GraphNode(id: 'a', coordinate: const BoardCoordinate(x: 0, y: 0))],
      edges: [],
    ),
    arrows: [],
    metadata: {'difficulty': 'test'},
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
      edges: [],
    ),
    arrows: [],
    metadata: {'difficulty': 'test'},
  );

  return [flat(1), flat(20), multiLayer(21), multiLayer(23)];
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
              ? LocalProgress.initial().copyWith(lastUnlockedLevel: 25)
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
