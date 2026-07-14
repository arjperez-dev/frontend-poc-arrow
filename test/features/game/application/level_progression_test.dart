import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/level_progression.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';

import '../game_test_fixtures.dart';

void main() {
  // One free arrow — minimal complexity.
  Level simple(int number) => buildLevel(
    basicDefinition(
      number: number,
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'b',
          endNodeId: 'a',
          direction: Direction.left,
        ),
      ],
    ),
  );

  // Two arrows, one initially blocked — strictly higher complexity than
  // [simple] regardless of exact weights.
  Level complex(int number) => buildLevel(
    collisionDefinition(
      number: number,
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
          startNodeId: 'c',
          endNodeId: 'd',
          direction: Direction.right,
        ),
      ],
    ),
  );

  test('should_sort_levels_ascending_by_complexity_score', () {
    final progression = LevelProgression.fromLevels([complex(1), simple(9)]);

    expect(
      progression.levels.map((level) => level.number).toList(),
      [9, 1],
    );
    for (var i = 1; i < progression.entries.length; i++) {
      expect(
        progression.entries[i].complexity.score,
        greaterThanOrEqualTo(progression.entries[i - 1].complexity.score),
      );
    }
  });

  test('should_break_score_ties_by_internal_number', () {
    final progression = LevelProgression.fromLevels([simple(7), simple(4)]);

    expect(
      progression.levels.map((level) => level.number).toList(),
      [4, 7],
    );
  });

  test('should_expose_display_numbers_as_sorted_positions', () {
    final progression = LevelProgression.fromLevels([complex(1), simple(9)]);

    expect(progression.displayNumberOf(9), 1);
    expect(progression.displayNumberOf(1), 2);
    expect(progression.displayNumberOf(999), isNull);
  });

  test('should_walk_previous_and_next_in_sorted_order', () {
    final progression = LevelProgression.fromLevels([complex(1), simple(9)]);

    expect(progression.previousInternalBefore(9), isNull);
    expect(progression.previousInternalBefore(1), 9);
    expect(progression.nextInternalAfter(9), 1);
    expect(progression.nextInternalAfter(1), isNull);
    expect(progression.nextInternalAfter(999), isNull);
    expect(progression.previousInternalBefore(999), isNull);
  });

  test('should_expose_complexity_of_each_level', () {
    final progression = LevelProgression.fromLevels([complex(1), simple(9)]);

    expect(progression.complexityOf(1)!.arrowCount, 2);
    expect(progression.complexityOf(9)!.arrowCount, 1);
    expect(progression.complexityOf(999), isNull);
  });

  test('should_handle_empty_level_list', () {
    final progression = LevelProgression.fromLevels(const []);

    expect(progression.entries, isEmpty);
    expect(progression.displayNumberOf(1), isNull);
    expect(progression.nextInternalAfter(1), isNull);
  });
}
