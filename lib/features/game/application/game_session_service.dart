import '../domain/game_session.dart';
import '../domain/level.dart';
import 'move_arrow_command.dart';
import 'move_arrow_use_case.dart';
import 'movement_result.dart';

class GameSessionService {
  const GameSessionService({
    this.moveArrow = const MoveArrowUseCase(),
  });

  final MoveArrowUseCase moveArrow;

  GameSession start(Level level) => GameSession.start(level);

  MovementResult activateArrow(GameSession session, String arrowId) {
    return moveArrow.execute(
      session: session,
      command: MoveArrowCommand(arrowId: arrowId),
    );
  }
}
