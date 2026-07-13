import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/levels/presentation/level_selection_screen.dart';
import 'package:frontend_poc_arrow/features/progress/domain/level_best_result.dart';
import 'package:frontend_poc_arrow/features/progress/domain/local_progress.dart';

import '../game/game_test_fixtures.dart';

void main() {
  // Two levels; the campaign has a best score on BOTH, but in challenge mode
  // only level 1 has a challenge record. Level 2's card must show no score.
  Widget buildScreen({required Challenge? challenge}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LevelSelectionScreen(
        challenge: challenge,
        loadLevels: () async => [
          buildLevel(basicDefinition(number: 1)),
          buildLevel(basicDefinition(number: 2)),
        ],
        loadProgress: () async => LocalProgress(
          completedLevelNumbers: const {1, 2},
          bestResultsByLevel: const {
            1: LevelBestResult(score: 850, moves: 4, timeSeconds: 0),
            2: LevelBestResult(score: 700, moves: 6, timeSeconds: 0),
          },
          lastUnlockedLevel: 3,
        ),
        loadChallengeRecords: (challenge) async => const {1: 1400},
      ),
    );
  }

  testWidgets('should_show_challenge_best_only_for_levels_played_in_challenge',
      (tester) async {
    await tester.pumpWidget(buildScreen(challenge: Challenge.moveLimit));
    await tester.pumpAndSettle();

    // Level 1: played in this challenge → challenge best, labeled as such.
    expect(find.textContaining('Challenge best: 1400'), findsOneWidget);
    // The campaign bests (850 / 700) must never appear in challenge mode.
    expect(find.textContaining('850'), findsNothing);
    expect(find.textContaining('700'), findsNothing);
    // Level 2: no challenge record → status only, no score at all.
    expect(find.textContaining('Best score'), findsNothing);
  });

  testWidgets('should_keep_campaign_bests_when_no_challenge_is_active',
      (tester) async {
    await tester.pumpWidget(buildScreen(challenge: null));
    await tester.pumpAndSettle();

    expect(find.textContaining('Best score: 850'), findsOneWidget);
    expect(find.textContaining('Best score: 700'), findsOneWidget);
    expect(find.textContaining('Challenge best'), findsNothing);
  });
}
