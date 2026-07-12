import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/challenges/domain/challenge.dart';
import 'package:frontend_poc_arrow/features/challenges/infrastructure/shared_preferences_challenge_records_repository.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_test_fixtures.dart';

void main() {
  group('SharedPreferencesChallengeRecordsRepository', () {
    test('should_round_trip_records_and_only_keep_improvements', () async {
      SharedPreferences.setMockInitialValues(const {});
      final repository = SharedPreferencesChallengeRecordsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(await repository.getRecords(Challenge.timeAttack), isEmpty);

      expect(
        await repository.saveRecord(
          challenge: Challenge.timeAttack,
          levelNumber: 3,
          score: 900,
        ),
        isTrue,
      );
      // A worse score is not a record and does not overwrite.
      expect(
        await repository.saveRecord(
          challenge: Challenge.timeAttack,
          levelNumber: 3,
          score: 500,
        ),
        isFalse,
      );
      // Records are per (challenge, level) — other challenges are untouched.
      expect(
        await repository.saveRecord(
          challenge: Challenge.moveLimit,
          levelNumber: 3,
          score: 700,
        ),
        isTrue,
      );

      expect(await repository.getRecords(Challenge.timeAttack), {3: 900});
      expect(await repository.getRecords(Challenge.moveLimit), {3: 700});
      expect(await repository.getRecords(Challenge.perfectRun), isEmpty);
    });
  });

  group('GameScreenController with a challenge', () {
    test(
      'should_save_challenge_record_and_never_campaign_completion_on_victory',
      () async {
        var campaignSaves = 0;
        var remoteNotifies = 0;
        final challengeSaves = <(Challenge, int, int)>[];

        final controller = GameScreenController(
          levelNumber: 1,
          loadLevelByNumber: (_) async => buildLevel(basicDefinition(number: 1)),
          saveLevelCompletion: ({
            required int levelNumber,
            required int score,
            required int moves,
            required int timeSeconds,
          }) async {
            campaignSaves++;
          },
          notifyRemoteLevelCompletion: ({
            required int levelNumber,
            required int score,
            required int moves,
            required int timeSeconds,
          }) async {
            remoteNotifies++;
          },
          challenge: Challenge.moveLimit,
          saveChallengeRecord: ({
            required Challenge challenge,
            required int levelNumber,
            required int score,
          }) async {
            challengeSaves.add((challenge, levelNumber, score));
            return true;
          },
          getChallengeBestScore: (_, _) async => 800,
          enableChallengeTimer: false,
        );
        await controller.load();
        expect(controller.challengeBestScore, 800);

        controller.activateArrow('arrow-1');
        expect(controller.isVictory, isTrue);
        await Future<void>.delayed(Duration.zero);

        expect(challengeSaves, hasLength(1));
        expect(challengeSaves.single.$1, Challenge.moveLimit);
        expect(controller.isNewChallengeRecord, isTrue);
        expect(
          campaignSaves,
          0,
          reason: 'challenge wins must not write campaign progress',
        );
        expect(
          remoteNotifies,
          0,
          reason: 'challenge wins must not reach the backend',
        );
        controller.dispose();
      },
    );

    test('should_fail_time_attack_when_the_driven_clock_expires', () async {
      final controller = GameScreenController(
        levelNumber: 1,
        loadLevelByNumber: (_) async => buildLevel(basicDefinition()),
        challenge: Challenge.timeAttack,
        enableChallengeTimer: false,
      );
      await controller.load();
      final limit = controller.session!.challenge!.timeLimitSeconds;

      for (var i = 0; i < limit; i++) {
        controller.advanceClock();
      }

      expect(controller.isGameOver, isTrue);
      expect(controller.challengeFailReason, ChallengeFailReason.timeUp);

      // Restart resets the clock and the run.
      controller.restart();
      expect(controller.isGameOver, isFalse);
      expect(controller.session!.elapsedSeconds, 0);
      controller.dispose();
    });

    test('should_report_out_of_moves_fail_reason', () async {
      // Budget is CALCULATED: arrows + slack. The fixture's 2-arrow
      // collision board (default-tier slack of 3) gets 2 + 3 = 5 moves;
      // five collisions spend the budget and the sixth tap ends the run.
      final controller = GameScreenController(
        levelNumber: 1,
        loadLevelByNumber: (_) async => buildLevel(
          collisionDefinition(
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
                startNodeId: 'd',
                endNodeId: 'c',
                direction: Direction.left,
              ),
            ],
          ),
        ),
        challenge: Challenge.moveLimit,
        enableChallengeTimer: false,
      );
      await controller.load();
      expect(controller.session!.challenge!.maxMoves, 5,
          reason: '2 arrows + default-tier slack of 3');

      for (var tap = 0; tap < 6; tap++) {
        controller.activateArrow('arrow-1');
        // Wait out the collision-flash debounce so the next tap registers.
        await Future<void>.delayed(const Duration(milliseconds: 340));
      }

      expect(controller.isGameOver, isTrue);
      expect(controller.challengeFailReason, ChallengeFailReason.outOfMoves);
      controller.dispose();
    });
  });
}
