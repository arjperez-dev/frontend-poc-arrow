import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/game/domain/arrow_path.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';

import '../game/game_test_fixtures.dart';

/// A synthetic level with [arrowCount] arrows — limits depend only on the
/// arrow count and the difficulty tier, so board geometry is irrelevant.
Level _levelWith({required int arrowCount, required String difficulty}) {
  return Level(
    id: 'limits-test',
    name: 'Limits Test',
    boardGraph: BoardGraph(nodes: const [], edges: const []),
    arrows: List.generate(
      arrowCount,
      (i) => ArrowPath(
        id: 'a$i',
        occupiedEdgeIds: const [],
        orderedNodeIds: const ['x'],
        startNodeId: 'x',
        endNodeId: 'x',
        direction: Direction.right,
      ),
    ),
    metadata: {'difficulty': difficulty},
  );
}

void main() {
  group('calculated challenge limits', () {
    test('should_scale_time_limit_with_arrows_and_difficulty', () {
      // 20-arrow boards, minus the flat 20s tightening:
      // easy 20×5−20=80s, medium 20×4−20=60s, hard 20×3−20=40s.
      for (final (difficulty, expected) in [
        ('easy', 80),
        ('medium', 60),
        ('hard', 40),
      ]) {
        final context = ChallengeContext.forLevel(
          Challenge.timeAttack,
          _levelWith(arrowCount: 20, difficulty: difficulty),
        );
        expect(context.timeLimitSeconds, expected,
            reason: '$difficulty 20-arrow board');
      }
    });

    test('should_apply_the_20s_tightening_before_the_floor', () {
      // Medium 12 arrows: 48 − 20 = 28 → floored to 30.
      final context = ChallengeContext.forLevel(
        Challenge.timeAttack,
        _levelWith(arrowCount: 12, difficulty: 'medium'),
      );
      expect(context.timeLimitSeconds, ChallengeContext.minTimeLimitSeconds);
    });

    test('should_floor_the_clock_at_30_seconds_for_tiny_boards', () {
      final level = buildLevel(basicDefinition(
        metadata: const {'difficulty': 'hard'},
      ));
      final context = ChallengeContext.forLevel(Challenge.timeAttack, level);
      expect(context.timeLimitSeconds, 30);
    });

    test('should_compute_move_budget_as_minimal_moves_plus_difficulty_slack',
        () {
      for (final (difficulty, slack) in [
        ('easy', 5),
        ('medium', 3),
        ('hard', 2),
        ('anything-else', 3),
      ]) {
        final level = buildLevel(basicDefinition(
          metadata: {'difficulty': difficulty},
        ));
        final context = ChallengeContext.forLevel(Challenge.moveLimit, level);
        expect(
          context.maxMoves,
          level.arrows.length + slack,
          reason: '$difficulty: minimal moves (= arrow count) + $slack',
        );
      }
    });
  });

  group('challenge HUD', () {
    testWidgets('should_replace_hearts_with_the_challenge_stat', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(
            levelNumber: 1,
            challenge: Challenge.moveLimit,
            loadLevelByNumber: (_) async =>
                buildLevel(basicDefinition(number: 1)),
            loadLevels: () async =>
                throw StateError('no level list in harness'),
            saveLevelCompletion: ({
              required int levelNumber,
              required int score,
              required int moves,
              required int timeSeconds,
            }) async {},
            notifyRemoteLevelCompletion: ({
              required int levelNumber,
              required int score,
              required int moves,
              required int timeSeconds,
            }) async {},
            getBestLevelResult: (_) async => null,
            playGameAudio: (_) async {},
            saveChallengeRecord: ({
              required Challenge challenge,
              required int levelNumber,
              required int score,
            }) async => false,
            getChallengeBestScore: (_, _) async => null,
            enableBoardAnimations: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(GameUiKeys.challengeStatChip), findsOneWidget);
      expect(
        find.byKey(GameUiKeys.livesLabel),
        findsNothing,
        reason: 'hearts are campaign-only; challenges show their own stat',
      );
      expect(find.byKey(GameUiKeys.movesLabel), findsOneWidget);
      expect(find.byKey(GameUiKeys.scoreLabel), findsOneWidget);
    });
  });
}
