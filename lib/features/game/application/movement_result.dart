import '../domain/game_session.dart';

enum MovementOutcome {
  moved,
  escaped,
  blocked,
  occupied,
  arrowNotFound,
  alreadyEscaped,
}

class MovementResult {
  const MovementResult({
    required this.session,
    required this.outcome,
  });

  final GameSession session;
  final MovementOutcome outcome;
}
