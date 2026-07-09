import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';

void main() {
  test('should_default_z_to_zero_when_omitted', () {
    const coordinate = BoardCoordinate(x: 3, y: 4);
    expect(coordinate.z, 0);
  });

  test('should_be_equal_to_explicit_z_zero_coordinate', () {
    const withoutZ = BoardCoordinate(x: 3, y: 4);
    const withZ = BoardCoordinate(x: 3, y: 4, z: 0);
    expect(withoutZ, withZ);
    expect(withoutZ.hashCode, withZ.hashCode);
  });

  test('should_not_be_equal_when_z_differs', () {
    const layer0 = BoardCoordinate(x: 1, y: 1, z: 0);
    const layer1 = BoardCoordinate(x: 1, y: 1, z: 1);
    expect(layer0, isNot(layer1));
  });

  test('should_use_layer_zero_coordinate_as_map_key_for_2d_and_3d_alike', () {
    // A 2D-constructed key must find a 3D-constructed value at the same
    // point, and vice versa — proves 2D is genuinely the z=0 embedding
    // rather than a parallel type.
    final map = <BoardCoordinate, String>{
      const BoardCoordinate(x: 5, y: 6, z: 0): 'value',
    };
    expect(map[const BoardCoordinate(x: 5, y: 6)], 'value');
  });
}
