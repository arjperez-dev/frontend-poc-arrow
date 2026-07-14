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
import 'package:frontend_poc_arrow/features/leaderboard/presentation/leaderboard_level_picker_screen.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

void main() {
  testWidgets(
    'should_render_one_tappable_card_per_level_with_name_and_number',
    (tester) async {
      final levels = _fakeLevels();

      await tester.pumpWidget(_TestApp(loadLevels: () async => levels));
      await tester.pumpAndSettle();

      expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(2)), findsOneWidget);
      // The card title is derived from the (2D-mode-unchanged) display
      // number, not the fixture's raw `name` field.
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
    },
  );

  testWidgets(
    'should_navigate_to_leaderboard_route_with_tapped_level_number_as_argument',
    (tester) async {
      final levels = _fakeLevels();
      Object? capturedArguments;
      var capturedRouteName = '';

      await tester.pumpWidget(
        _TestApp(
          loadLevels: () async => levels,
          onLeaderboardRoutePushed: (settings) {
            capturedRouteName = settings.name ?? '';
            capturedArguments = settings.arguments;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(GameUiKeys.levelCard(2)));
      await tester.pumpAndSettle();

      expect(capturedRouteName, AppRoutes.leaderboard);
      expect(capturedArguments, 2);
    },
  );

  testWidgets(
    'should_show_leaderboard_unavailable_message_and_no_cards_when_levels_list_is_empty',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(loadLevels: () async => const <Level>[]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard unavailable.'), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
    },
  );

  testWidgets(
    'should_show_leaderboard_unavailable_message_when_loading_levels_throws',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          loadLevels: () async => throw Exception('backend unreachable'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard unavailable.'), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
    },
  );

  testWidgets(
    'should_show_loading_indicator_before_levels_future_completes',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          loadLevels: () async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return _fakeLevels();
          },
        ),
      );

      // Pump once without settling — the future has not completed yet.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);

      // Let the delayed future resolve to avoid a pending-timer test failure.
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'should_filter_levels_by_active_game_mode_from_app_settings_scope',
    (tester) async {
      final levels = [..._fakeLevels(), _fakeThreeDLevel(21)];

      await tester.pumpWidget(
        _TestApp(
          loadLevels: () async => levels,
          gameMode: GameMode.threeD,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(GameUiKeys.levelCard(1)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(2)), findsNothing);
      expect(find.byKey(GameUiKeys.levelCard(21)), findsOneWidget);
    },
  );

  testWidgets(
    'should_display_3d_levels_as_positions_1_to_n_in_sorted_progression',
    (tester) async {
      final levels = [_fakeThreeDLevel(21), _fakeThreeDLevel(23)];

      await tester.pumpWidget(
        _TestApp(loadLevels: () async => levels, gameMode: GameMode.threeD),
      );
      await tester.pumpAndSettle();

      // Display numbers are positions in the complexity-sorted 3D
      // progression (fixtures tie on complexity, so internal-number order
      // holds): internal 21 -> "Level 1", internal 23 -> "Level 2".
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Level 21'), findsNothing);
      expect(find.text('Level 23'), findsNothing);
    },
  );

  testWidgets(
    'should_navigate_with_internal_level_number_when_displayed_3d_card_is_tapped',
    (tester) async {
      final levels = [_fakeThreeDLevel(21), _fakeThreeDLevel(23)];
      Object? capturedArguments;

      await tester.pumpWidget(
        _TestApp(
          loadLevels: () async => levels,
          gameMode: GameMode.threeD,
          onLeaderboardRoutePushed: (settings) {
            capturedArguments = settings.arguments;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Displayed "Level 1" card corresponds to internal level 21.
      await tester.tap(find.byKey(GameUiKeys.levelCard(21)));
      await tester.pumpAndSettle();

      expect(capturedArguments, 21);
    },
  );
}

Level _fakeThreeDLevel(int number) {
  return Level(
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
}

List<Level> _fakeLevels() {
  return [
    Level(
      id: 'fixture-1',
      number: 1,
      name: 'Level One',
      boardGraph: BoardGraph(
        nodes: [GraphNode(id: 'a', coordinate: BoardCoordinate(x: 0, y: 0))],
        edges: [],
      ),
      arrows: [],
      metadata: {'difficulty': 'test'},
    ),
    Level(
      id: 'fixture-2',
      number: 2,
      name: 'Level Two',
      boardGraph: BoardGraph(
        nodes: [GraphNode(id: 'a', coordinate: BoardCoordinate(x: 0, y: 0))],
        edges: [],
      ),
      arrows: [],
      metadata: {'difficulty': 'test'},
    ),
  ];
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.loadLevels,
    this.onLeaderboardRoutePushed,
    this.gameMode,
  });

  final LoadLocalLevels loadLevels;
  final void Function(RouteSettings settings)? onLeaderboardRoutePushed;
  final GameMode? gameMode;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LeaderboardLevelPickerScreen(loadLevels: loadLevels),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.leaderboard) {
          onLeaderboardRoutePushed?.call(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Leaderboard'))),
          );
        }
        return null;
      },
    );
    final gameMode = this.gameMode;
    if (gameMode == null) {
      return app;
    }
    return AppSettingsScope(
      controller: AppSettingsController(initialGameMode: gameMode),
      child: app,
    );
  }
}
