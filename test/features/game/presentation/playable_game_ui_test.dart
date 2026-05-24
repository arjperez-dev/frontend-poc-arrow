import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/routing/app_routes.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/game/domain/arrow_path.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_dependencies.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';

void main() {
  testWidgets('should_display_manual_levels_when_level_selection_loads', (
    tester,
  ) async {
    final levels = await _loadRealManualLevels(tester);
    await tester.pumpWidget(_TestManualLevelsApp(levels: levels));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
    expect(find.text('First Exit'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.byKey(GameUiKeys.levelCard(15)),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.byKey(GameUiKeys.levelCard(15)), findsOneWidget);
    expect(find.text('Final Grid'), findsOneWidget);
  });

  testWidgets('should_open_game_screen_when_manual_level_is_selected', (
    tester,
  ) async {
    await _openLevelOne(tester, await _loadRealManualLevels(tester));

    expect(find.text('First Exit'), findsAtLeastNWidgets(1));
    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(find.byKey(GameUiKeys.movesLabel), findsOneWidget);
    expect(find.byKey(GameUiKeys.scoreLabel), findsOneWidget);
  });

  testWidgets('should_render_game_screen_with_graph_nodes', (tester) async {
    final semantics = tester.ensureSemantics();

    await _openLevelOne(tester, await _loadRealManualLevels(tester));

    expect(
      find.bySemanticsLabel('Graph board with 9 nodes and 1 active arrows'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('should_update_moves_when_arrow_is_activated', (tester) async {
    await _openLevelOne(tester, await _loadRealManualLevels(tester));

    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.movesLabel),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.scoreLabel),
        matching: find.text('1000'),
      ),
      findsOneWidget,
    );

    await tester.tapAt(tester.getCenter(find.byKey(GameUiKeys.gameBoard)));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.movesLabel),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.scoreLabel),
        matching: find.text('990'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('should_show_victory_when_all_arrows_escape_for_simple_level', (
    tester,
  ) async {
    await tester.pumpWidget(_TestGameApp(level: _singleNodeExitLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    await tester.tapAt(_singleNodePosition(tester));
    await tester.pump();

    expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
    expect(find.text('Victory'), findsOneWidget);
  });

  testWidgets('should_keep_graph_nodes_visible_after_arrow_exits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_TestGameApp(level: _singleNodeExitLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    await tester.tapAt(_singleNodePosition(tester));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Graph board with 1 nodes and 0 active arrows'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

Future<void> _openLevelOne(WidgetTester tester, List<Level> levels) async {
  await tester.pumpWidget(_TestManualLevelsApp(levels: levels));
  await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

  await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
  await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));
}

Future<List<Level>> _loadRealManualLevels(WidgetTester tester) async {
  late final List<Level> levels;
  await tester.runAsync(() async {
    levels = await LocalLevelDependencies.createGetLocalLevelsUseCase()();
  });
  return levels;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleText = tester.widgetList<Text>(find.byType(Text)).map((text) {
    return text.data ?? text.textSpan?.toPlainText();
  }).toList();
  fail(
    'Expected widget was not found: $finder. '
    'Exception: ${tester.takeException()}. Text: $visibleText',
  );
}

Offset _singleNodePosition(WidgetTester tester) {
  return tester.getTopLeft(find.byKey(GameUiKeys.gameBoard)) +
      const Offset(32, 32);
}

Level _singleNodeExitLevel() {
  return Level(
    id: 'fixture-exit',
    number: 1,
    name: 'Fixture Exit',
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
        startNodeId: 'a',
        endNodeId: 'a',
        direction: Direction.right,
      ),
    ],
    metadata: const {'difficulty': 'test'},
  );
}

class _TestGameApp extends StatelessWidget {
  const _TestGameApp({required this.level});

  final Level level;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GameScreen(
        levelNumber: level.number,
        loadLevelByNumber: (_) async => level,
      ),
    );
  }
}

class _TestManualLevelsApp extends StatelessWidget {
  const _TestManualLevelsApp({required this.levels});

  final List<Level> levels;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LevelSelectionScreen(loadLevels: () async => levels),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.game) {
          final levelNumber = settings.arguments as int?;
          return MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              levelNumber: levelNumber,
              loadLevelByNumber: (number) async {
                for (final level in levels) {
                  if (level.number == number) {
                    return level;
                  }
                }
                return null;
              },
            ),
          );
        }

        return null;
      },
    );
  }
}
