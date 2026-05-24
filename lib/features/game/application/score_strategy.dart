import '../domain/score.dart';

abstract interface class ScoreStrategy {
  Score calculate({
    required int movesCount,
    required int elapsedSeconds,
  });
}

class DefaultScoreStrategy implements ScoreStrategy {
  const DefaultScoreStrategy();

  @override
  Score calculate({
    required int movesCount,
    required int elapsedSeconds,
  }) {
    final value = 1000 - (movesCount * 10) - elapsedSeconds;
    return Score(value < 0 ? 0 : value);
  }
}
