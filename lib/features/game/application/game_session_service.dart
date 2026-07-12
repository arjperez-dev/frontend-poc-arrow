import '../../challenges/domain/challenge.dart';
import '../domain/game_session.dart';
import '../domain/game_status.dart';
import '../domain/level.dart';
import 'move_arrow_command.dart';
import 'move_arrow_use_case.dart';
import 'movement_result.dart';

class GameSessionService {
  const GameSessionService({
    this.moveArrow = const MoveArrowUseCase(),
  });

  final MoveArrowUseCase moveArrow;

  GameSession start(Level level, {ChallengeContext? challenge}) =>
      GameSession.start(level, challenge: challenge);

  MovementResult activateArrow(GameSession session, String arrowId) {
    return moveArrow.execute(
      session: session,
      command: MoveArrowCommand(arrowId: arrowId),
    );
  }

  /// Advances the session clock by one second. Only meaningful while the
  /// session is playing; a Time Attack session that reaches its limit fails.
  /// The presentation ticker merely calls this once per second — the rule
  /// lives here, not in the controller.
  GameSession tickClock(GameSession session) {
    if (session.status != GameStatus.playing) {
      return session;
    }
    var updated = session.copyWith(
      elapsedSeconds: session.elapsedSeconds + 1,
    );
    final context = updated.challenge;
    if (context != null &&
        context.challenge == Challenge.timeAttack &&
        updated.elapsedSeconds >= context.timeLimitSeconds) {
      updated = updated.copyWith(status: GameStatus.failed);
    }
    return updated;
  }
}
