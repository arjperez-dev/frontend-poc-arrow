import '../domain/game_session.dart';

class CheckVictoryUseCase {
  const CheckVictoryUseCase();

  bool execute(GameSession session) {
    return session.arrows.isNotEmpty && session.arrows.every((arrow) => arrow.isEscaped);
  }
}
