import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_dependencies.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen_controller.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';

void main() {
  testWidgets('should_display_manual_levels_when_level_selection_loads', (
    tester,
  ) async {
    final levels = await _loadRealManualLevels(tester);
    await tester.pumpWidget(_TestManualLevelsApp(levels: levels));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    expect(find.byKey(GameUiKeys.levelCard(1)), findsOneWidget);
    expect(find.text('Level 1'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.byKey(GameUiKeys.levelCard(15)),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.byKey(GameUiKeys.levelCard(15)), findsOneWidget);
    expect(find.text('Level 15'), findsOneWidget);
  });

  testWidgets('should_open_game_screen_when_manual_level_is_selected', (
    tester,
  ) async {
    await _openLevelOne(tester, await _loadRealManualLevels(tester));

    expect(find.text('Level 1'), findsAtLeastNWidgets(1));
    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(find.byKey(GameUiKeys.movesLabel), findsOneWidget);
    expect(find.byKey(GameUiKeys.scoreLabel), findsOneWidget);
    expect(find.byKey(GameUiKeys.livesLabel), findsOneWidget);
  });

  testWidgets('should_render_game_screen_with_graph_nodes', (tester) async {
    final semantics = tester.ensureSemantics();

    await _openLevelOne(tester, await _loadRealManualLevels(tester));

    // Level 1 (Phase 12 regeneration): 36 nodes, 10 arrows.
    expect(
      find.bySemanticsLabel('Graph board with 36 nodes and 10 active arrows'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('should_update_moves_when_arrow_attempt_is_made', (tester) async {
    // Use the single-node exit fixture — one tap = one exit attempt.
    await tester.pumpWidget(_TestGameApp(level: _singleNodeExitLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.movesLabel),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    // Tap at the arrow's position (single node is at canvas (32, 32)).
    await tester.tapAt(_singleNodePosition(tester));
    await tester.pump();

    // One tap = 1 move.
    expect(
      find.descendant(
        of: find.byKey(GameUiKeys.movesLabel),
        matching: find.text('1'),
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

  testWidgets('should_show_lives_display_in_hud', (tester) async {
    await tester.pumpWidget(_TestGameApp(level: _singleNodeExitLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    expect(find.byKey(GameUiKeys.livesLabel), findsOneWidget);
    // Three heart icons: all filled at start.
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
  });

  testWidgets('should_show_reset_view_button_and_keep_taps_working', (
    tester,
  ) async {
    await tester.pumpWidget(_TestGameApp(level: _singleNodeExitLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    // Pan/zoom reset control is present and tappable (no crash).
    expect(find.byKey(GameUiKeys.resetViewButton), findsOneWidget);
    await tester.tap(find.byKey(GameUiKeys.resetViewButton));
    await tester.pump();

    // Tap-to-activate still works with InteractiveViewer wrapping the board.
    await tester.tapAt(_singleNodePosition(tester));
    await tester.pump();
    expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
  });

  testWidgets('should_show_game_over_when_lives_reach_zero', (tester) async {
    await tester.pumpWidget(_TestGameApp(level: _blockedArrowLevel()));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    // 6 collision taps → lives = 0 → game over. Each tap needs a pump.
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(_singleNodePosition(tester));
      // Wait for flash delay to clear (320 ms) between taps.
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.byKey(GameUiKeys.gameOverCard), findsOneWidget);
    expect(find.text('Game Over'), findsOneWidget);
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

  testWidgets('should_keep_gameplay_available_when_backend_is_unreachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestGameApp(
        level: _singleNodeExitLevel(),
        notifyRemoteLevelCompletion:
            ({
              required int levelNumber,
              required int score,
              required int moves,
              required int timeSeconds,
            }) async {
              throw Exception('Backend unavailable');
            },
      ),
    );
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

    await tester.tapAt(_singleNodePosition(tester));
    await tester.pump();

    expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
    expect(find.byKey(GameUiKeys.retryButton), findsOneWidget);
    expect(find.byKey(GameUiKeys.backToLevelsButton), findsOneWidget);
  });

  testWidgets('should_not_open_locked_level_when_level_is_locked', (
    tester,
  ) async {
    final levels = await _loadRealManualLevels(tester);
    await tester.pumpWidget(
      _TestManualLevelsApp(levels: levels, progress: LocalProgress.initial()),
    );
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    // Internal level 2 sits mid-list in the complexity-sorted progression
    // (no longer second), so bring its card into the viewport first.
    await tester.scrollUntilVisible(find.byKey(GameUiKeys.levelCard(2)), 100);
    await tester.ensureVisible(find.byKey(GameUiKeys.levelCard(2)));
    await tester.pump();

    await tester.tap(find.byKey(GameUiKeys.levelCard(2)));
    await tester.pump();

    expect(find.byKey(GameUiKeys.gameBoard), findsNothing);
    expect(
      find.text('Complete previous levels to unlock this level.'),
      findsOneWidget,
    );
  });

  testWidgets('should_update_level_selection_after_level_completion', (
    tester,
  ) async {
    final levels = await _loadRealManualLevels(tester);
    final progress = LocalProgress.initial().copyWith(
      completedLevelNumbers: {1},
      lastUnlockedLevel: 2,
    );

    await tester.pumpWidget(
      _TestManualLevelsApp(levels: levels, progress: progress),
    );
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(2)));

    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.textContaining('Unlocked'), findsWidgets);
  });

  testWidgets(
    'should_save_completion_on_victory_before_next_level_is_tapped',
    (tester) async {
      var saveCalls = 0;
      var remoteCalls = 0;

      await tester.pumpWidget(
        _TestGameApp(
          level: _singleNodeExitLevel(),
          saveLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {
                saveCalls++;
              },
          notifyRemoteLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {
                remoteCalls++;
              },
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();

      // Save and remote notification both fire on the victory transition
      // itself — before any victory-overlay button (e.g. "Next Level") is
      // ever tapped.
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
      expect(saveCalls, 1);
      expect(remoteCalls, 1);
    },
  );

  testWidgets(
    'should_not_duplicate_completion_save_when_victory_overlay_is_tapped_repeatedly',
    (tester) async {
      var saveCalls = 0;

      await tester.pumpWidget(
        _TestGameApp(
          level: _singleNodeExitLevel(),
          saveLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {
                saveCalls++;
              },
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);
      expect(saveCalls, 1);

      // Tapping "Retry" on the victory overlay restarts the session locally;
      // it must not re-trigger the completion save for the same victory.
      await tester.tap(find.byKey(GameUiKeys.retryButton));
      await tester.pump();

      expect(saveCalls, 1);
    },
  );

  testWidgets(
    'should_persist_completion_save_when_player_backs_out_immediately_after_victory',
    (tester) async {
      var saveCalls = 0;

      final levels = await _loadRealManualLevels(tester);
      await tester.pumpWidget(
        _TestManualLevelsApp(
          levels: levels,
          level1Override: _singleNodeExitLevel(),
          onSaveLevelCompletion:
              ({
                required int levelNumber,
                required int score,
                required int moves,
                required int timeSeconds,
              }) async {
                saveCalls++;
              },
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

      await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      // Player backs out via the app-bar back button immediately after
      // victory, without tapping "Next Level" — the save already happened
      // on the victory transition, so it must have been recorded.
      await tester.pageBack();
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

      expect(saveCalls, 1);
    },
  );

  testWidgets(
    'should_await_completion_save_before_navigating_on_back_to_levels_tap',
    (tester) async {
      final saveCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(
            levelNumber: 1,
            enableBoardAnimations: false,
            loadLevelByNumber: (_) async => _singleNodeExitLevel(),
            loadLevels: () async =>
                throw StateError('no level list in harness'),
            saveLevelCompletion:
                ({
                  required int levelNumber,
                  required int score,
                  required int moves,
                  required int timeSeconds,
                }) => saveCompleter.future,
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
            if (settings.name == AppRoutes.levels) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('LEVELS_SCREEN')),
              );
            }
            return null;
          },
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      await tester.tap(find.byKey(GameUiKeys.backToLevelsButton));
      await tester.pump();

      // Save is still pending — navigation must not have happened yet.
      expect(find.text('LEVELS_SCREEN'), findsNothing);
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('LEVELS_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    'should_await_completion_save_before_navigating_on_next_level_tap',
    (tester) async {
      final saveCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(
            levelNumber: 1,
            enableBoardAnimations: false,
            loadLevelByNumber: (_) async => _singleNodeExitLevel(),
            loadLevels: () async =>
                throw StateError('no level list in harness'),
            saveLevelCompletion:
                ({
                  required int levelNumber,
                  required int score,
                  required int moves,
                  required int timeSeconds,
                }) => saveCompleter.future,
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
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    const Scaffold(body: Text('NEXT_LEVEL_SCREEN')),
              );
            }
            return null;
          },
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      await tester.tap(find.byKey(GameUiKeys.nextLevelButton));
      await tester.pump();

      // Save is still pending — navigation must not have happened yet.
      expect(find.text('NEXT_LEVEL_SCREEN'), findsNothing);
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('NEXT_LEVEL_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    'should_observe_completed_level_on_first_return_when_backing_out_fast_via_app_bar',
    (tester) async {
      final levels = await _loadRealManualLevels(tester);

      // Fake save that completes on a delayed future — simulates a slow
      // SharedPreferences read-modify-write racing against a fast pop.
      Future<void> delayedSave({
        required int levelNumber,
        required int score,
        required int moves,
        required int timeSeconds,
      }) => Future<void>.delayed(const Duration(milliseconds: 50));

      var progressCalls = 0;
      Future<LocalProgress> loadProgress() async {
        progressCalls++;
        // Reflect completion only once the save has actually settled.
        if (progressCalls <= 1) {
          return LocalProgress.initial().copyWith(lastUnlockedLevel: 1);
        }
        return LocalProgress.initial().copyWith(
          completedLevelNumbers: {1},
          lastUnlockedLevel: 2,
        );
      }

      await tester.pumpWidget(
        _TestManualLevelsApp(
          levels: levels,
          level1Override: _singleNodeExitLevel(),
          loadProgress: loadProgress,
          onSaveLevelCompletion: delayedSave,
        ),
      );
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

      await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));

      await tester.tapAt(_singleNodePosition(tester));
      await tester.pump();
      expect(find.byKey(GameUiKeys.victoryCard), findsOneWidget);

      // Back out immediately via the app-bar back button — before the
      // 50 ms delayed save would have settled on its own.
      await tester.pageBack();
      // Pump through the awaited completionSettled + the delayed save.
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

      // The level-selection screen's post-return progress read must observe
      // the completed level on the first return.
      expect(find.textContaining('Completed'), findsOneWidget);
    },
  );

  testWidgets('should_refresh_progress_when_returning_from_game', (
    tester,
  ) async {
    final levels = await _loadRealManualLevels(tester);

    // Progress changes between the first load and the load after returning:
    // first only level 1 is unlocked; after returning, level 1 is completed.
    var calls = 0;
    Future<LocalProgress> loadProgress() async {
      calls++;
      if (calls <= 1) {
        return LocalProgress.initial().copyWith(lastUnlockedLevel: 1);
      }
      return LocalProgress.initial().copyWith(
        completedLevelNumbers: {1},
        lastUnlockedLevel: 2,
      );
    }

    await tester.pumpWidget(
      _TestManualLevelsApp(levels: levels, loadProgress: loadProgress),
    );
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    // Initially nothing is completed.
    expect(find.textContaining('Completed'), findsNothing);

    // Open level 1, then return via the app-bar back button (covers pop).
    await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));
    await tester.pageBack();
    await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

    // Progress was reloaded → level 1 now shows Completed.
    expect(find.textContaining('Completed'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _openLevelOne(WidgetTester tester, List<Level> levels) async {
  await tester.pumpWidget(_TestManualLevelsApp(levels: levels));
  await _pumpUntilFound(tester, find.byKey(GameUiKeys.levelCard(1)));

  await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
  await _pumpUntilFound(tester, find.byKey(GameUiKeys.gameBoard));
}

Future<List<Level>> _loadRealManualLevels(WidgetTester tester) async {
  late final List<Level> levels;
  await tester.runAsync(() async {
    levels = await (await LocalLevelDependencies.createGetLocalLevelsUseCase())();
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

/// Level with one arrow that immediately exits (no graph boundary in direction).
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
        orderedNodeIds: ['a'],
        startNodeId: 'a',
        endNodeId: 'a',
        direction: Direction.right,
      ),
    ],
    metadata: const {'difficulty': 'test'},
  );
}

/// Level with one arrow that always collides — the only edge in its
/// direction is blocked, so every tap returns a collision. Used to
/// drive the lives counter to 0 for game-over testing.
Level _blockedArrowLevel() {
  return Level(
    id: 'fixture-blocked',
    number: 99,
    name: 'Fixture Blocked',
    boardGraph: BoardGraph(
      nodes: const [
        GraphNode(id: 'a', coordinate: BoardCoordinate(x: 0, y: 0)),
        GraphNode(id: 'b', coordinate: BoardCoordinate(x: 1, y: 0)),
      ],
      edges: const [
        // Blocked edge in the arrow's direction → always collides.
        GraphEdge(
          id: 'ab',
          fromNodeId: 'a',
          toNodeId: 'b',
          isBlocked: true,
        ),
      ],
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

// ---------------------------------------------------------------------------
// Test app wrappers
// ---------------------------------------------------------------------------

class _TestGameApp extends StatelessWidget {
  const _TestGameApp({
    required this.level,
    this.notifyRemoteLevelCompletion,
    this.saveLevelCompletion,
  });

  final Level level;
  final NotifyRemoteLevelCompletion? notifyRemoteLevelCompletion;
  final SaveLevelCompletion? saveLevelCompletion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GameScreen(
        levelNumber: level.number,
        enableBoardAnimations: false,
        loadLevelByNumber: (_) async => level,
        // Deterministically unavailable: these single-level tests exercise
        // the internal-number fallback (display number, "next level" = +1),
        // not the complexity-sorted progression. Progression behavior is
        // covered by game_screen_display_number_test.dart.
        loadLevels: () async => throw StateError('no level list in harness'),
        saveLevelCompletion:
            saveLevelCompletion ??
            ({
              required int levelNumber,
              required int score,
              required int moves,
              required int timeSeconds,
            }) async {},
        getBestLevelResult: (_) async => null,
        notifyRemoteLevelCompletion:
            notifyRemoteLevelCompletion ??
            ({
              required int levelNumber,
              required int score,
              required int moves,
              required int timeSeconds,
            }) async {},
        playGameAudio: (_) async {},
      ),
    );
  }
}

class _TestManualLevelsApp extends StatelessWidget {
  const _TestManualLevelsApp({
    required this.levels,
    this.progress,
    this.loadProgress,
    this.level1Override,
    this.onSaveLevelCompletion,
  });

  final List<Level> levels;
  final LocalProgress? progress;
  final Future<LocalProgress> Function()? loadProgress;

  /// When set, substitutes the level served for level number 1 — lets tests
  /// drive a fast, deterministic victory without depending on real level 1
  /// puzzle contents.
  final Level? level1Override;
  final SaveLevelCompletion? onSaveLevelCompletion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LevelSelectionScreen(
        loadLevels: () async => levels,
        loadProgress: loadProgress ??
            () async =>
                progress ??
                LocalProgress.initial()
                    .copyWith(lastUnlockedLevel: levels.length),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.game) {
          final levelNumber = settings.arguments as int?;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => GameScreen(
              levelNumber: levelNumber,
              enableBoardAnimations: false,
              // Real level list → the game screen resolves display/next
              // level from the same complexity-sorted progression the
              // selection screen lists.
              loadLevels: () async => levels,
              loadLevelByNumber: (number) async {
                if (level1Override != null && number == 1) {
                  return level1Override;
                }
                for (final level in levels) {
                  if (level.number == number) {
                    return level;
                  }
                }
                return null;
              },
              saveLevelCompletion:
                  onSaveLevelCompletion ??
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
          );
        }
        return null;
      },
    );
  }
}
