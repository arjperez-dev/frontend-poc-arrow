import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/score_calculator.dart';

void main() {
  test('should_calculate_score_based_on_moves_and_time', () {
    const calculator = ScoreCalculator();

    final score = calculator.calculate(
      movesCount: 3,
      elapsedSeconds: 25,
    );

    expect(score.value, 945);
  });
}
