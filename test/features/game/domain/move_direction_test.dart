import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/move_direction.dart';

void main() {
  group('LayerDirection', () {
    test('should_step_z_only_and_leave_x_y_unchanged', () {
      const start = BoardCoordinate(x: 2, y: 3, z: 0);
      expect(LayerDirection.above.applyTo(start), const BoardCoordinate(x: 2, y: 3, z: -1));
      expect(LayerDirection.below.applyTo(start), const BoardCoordinate(x: 2, y: 3, z: 1));
    });

    test('should_be_opposite_of_each_other', () {
      expect(LayerDirection.above.opposite, LayerDirection.below);
      expect(LayerDirection.below.opposite, LayerDirection.above);
    });

    test('should_implement_move_direction', () {
      expect(LayerDirection.above, isA<MoveDirection>());
    });
  });

  group('Direction implements MoveDirection', () {
    test('should_have_zero_dz_for_every_planar_direction', () {
      for (final direction in Direction.values) {
        expect(direction.dz, 0);
      }
    });

    test('should_be_usable_anywhere_a_move_direction_is_expected', () {
      const MoveDirection direction = Direction.right;
      expect(direction.dx, 1);
    });
  });

  group('MoveDirection.between', () {
    test('should_find_planar_direction_between_x_adjacent_coordinates', () {
      const a = BoardCoordinate(x: 0, y: 0);
      const b = BoardCoordinate(x: 1, y: 0);
      expect(MoveDirection.between(a, b), Direction.right);
    });

    test('should_find_layer_direction_between_z_adjacent_coordinates', () {
      const top = BoardCoordinate(x: 2, y: 2, z: 0);
      const bottom = BoardCoordinate(x: 2, y: 2, z: 1);
      expect(MoveDirection.between(top, bottom), LayerDirection.below);
      expect(MoveDirection.between(bottom, top), LayerDirection.above);
    });

    test('should_return_null_for_diagonal_xz_delta', () {
      const a = BoardCoordinate(x: 0, y: 0, z: 0);
      const diagonal = BoardCoordinate(x: 1, y: 0, z: 1);
      expect(MoveDirection.between(a, diagonal), isNull);
    });

    test('should_return_null_for_non_adjacent_coordinates', () {
      const a = BoardCoordinate(x: 0, y: 0);
      const farAway = BoardCoordinate(x: 5, y: 0);
      expect(MoveDirection.between(a, farAway), isNull);
    });
  });

  group('MoveDirection.parse', () {
    test('should_parse_all_four_planar_direction_names', () {
      expect(MoveDirection.parse('up'), Direction.up);
      expect(MoveDirection.parse('right'), Direction.right);
      expect(MoveDirection.parse('down'), Direction.down);
      expect(MoveDirection.parse('left'), Direction.left);
    });

    test('should_parse_layer_direction_names', () {
      expect(MoveDirection.parse('above'), LayerDirection.above);
      expect(MoveDirection.parse('below'), LayerDirection.below);
    });

    test('should_throw_format_exception_for_unknown_name', () {
      expect(() => MoveDirection.parse('diagonal'), throwsFormatException);
    });
  });
}
