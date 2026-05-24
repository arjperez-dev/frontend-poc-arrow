import '../domain/score.dart';
import 'score_strategy.dart';

class ScoreCalculator {
  const ScoreCalculator({
    this.strategy = const DefaultScoreStrategy(),
  });

  final ScoreStrategy strategy;

  Score calculate({
    required int movesCount,
    required int elapsedSeconds,
  }) {
    return strategy.calculate(
      movesCount: movesCount,
      elapsedSeconds: elapsedSeconds,
    );
  }
}
