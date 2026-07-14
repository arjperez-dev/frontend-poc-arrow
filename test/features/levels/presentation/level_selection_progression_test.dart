import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_controller.dart';
import 'package:frontend_poc_arrow/core/app/app_settings_scope.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/core/theme/app_theme.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';
import 'package:frontend_poc_arrow/features/settings/domain/game_mode.dart';

import '../../game/game_test_fixtures.dart';

// Internal level 1 is deliberately MORE complex than internal level 2, so the
// complexity-sorted progression must reverse the numeric order: [2, 1].
Level _simpleLevel(int number) => buildLevel(
  basicDefinition(
    number: number,
    arrows: const [
      ArrowPathDefinition(
        id: 'arrow-1',
        occupiedEdgeIds: ['ab'],
        startNodeId: 'b',
        endNodeId: 'a',
        direction: Direction.left,
      ),
    ],
  ),
);

Level _complexLevel(int number) => buildLevel(
  collisionDefinition(
    number: number,
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
        startNodeId: 'c',
        endNodeId: 'd',
        direction: Direction.right,
      ),
    ],
  ),
);

void main() {
  List<Level> levels() => [_complexLevel(1), _simpleLevel(2)];

  testWidgets('should_list_levels_in_ascending_complexity_order', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(levels: levels()));
    await tester.pumpAndSettle();

    final easyCardY = tester.getTopLeft(find.byKey(GameUiKeys.levelCard(2))).dy;
    final hardCardY = tester.getTopLeft(find.byKey(GameUiKeys.levelCard(1))).dy;
    expect(easyCardY, lessThan(hardCardY));

    // Display numbers follow the sorted position, not the internal number:
    // internal 2 (easiest) shows first as "Level 1".
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('should_show_computed_complexity_tier_on_cards', (tester) async {
    await tester.pumpWidget(_TestApp(levels: levels()));
    await tester.pumpAndSettle();

    // Rank-relative banding over the two-level progression: the easier
    // fixture is EASY, the harder one MEDIUM. The label comes from the
    // computed band, not from the levels' metadata (which says 'test').
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.text('TEST'), findsNothing);
  });

  testWidgets('should_gate_unlock_on_previous_level_in_sorted_order', (
    tester,
  ) async {
    // Empty progress: only the FIRST level of the sorted progression
    // (internal 2) is unlocked; internal 1 (harder) is locked even though its
    // internal number is lower.
    await tester.pumpWidget(_TestApp(levels: levels()));
    await tester.pumpAndSettle();

    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);

    await tester.tap(find.byKey(GameUiKeys.levelCard(1)));
    await tester.pump();
    expect(
      find.text('Complete previous levels to unlock this level.'),
      findsOneWidget,
    );
  });

  testWidgets('should_unlock_harder_level_once_sorted_predecessor_completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        levels: levels(),
        progress: LocalProgress.initial().copyWith(
          completedLevelNumbers: const <int>{2},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Internal 2 (first in progression) completed -> internal 1 unlocked.
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.levels, this.progress});

  final List<Level> levels;
  final LocalProgress? progress;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: AppSettingsController(initialGameMode: GameMode.twoD),
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LevelSelectionScreen(
          loadLevels: () async => levels,
          loadProgress: () async => progress ?? LocalProgress.initial(),
        ),
      ),
    );
  }
}
