import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/hex_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';

void main() {
  test('should_step_to_all_six_axial_neighbours', () {
    const origin = BoardCoordinate(x: 0, y: 0);

    expect(HexDirection.east.applyTo(origin), const BoardCoordinate(x: 1, y: 0));
    expect(HexDirection.northEast.applyTo(origin), const BoardCoordinate(x: 1, y: -1));
    expect(HexDirection.northWest.applyTo(origin), const BoardCoordinate(x: 0, y: -1));
    expect(HexDirection.west.applyTo(origin), const BoardCoordinate(x: -1, y: 0));
    expect(HexDirection.southWest.applyTo(origin), const BoardCoordinate(x: -1, y: 1));
    expect(HexDirection.southEast.applyTo(origin), const BoardCoordinate(x: 0, y: 1));
  });

  test('should_pair_opposites_correctly', () {
    expect(HexDirection.east.opposite, HexDirection.west);
    expect(HexDirection.west.opposite, HexDirection.east);
    expect(HexDirection.northEast.opposite, HexDirection.southWest);
    expect(HexDirection.southWest.opposite, HexDirection.northEast);
    expect(HexDirection.northWest.opposite, HexDirection.southEast);
    expect(HexDirection.southEast.opposite, HexDirection.northWest);
  });

  test('should_preserve_z_when_applied', () {
    const coordinate = BoardCoordinate(x: 2, y: 3, z: 5);

    for (final direction in HexDirection.values) {
      expect(direction.applyTo(coordinate).z, 5);
    }
  });

  test('should_not_share_any_name_with_square_or_layer_directions', () {
    final squareNames = Direction.values.map((d) => d.name).toSet();
    final layerNames = LayerDirection.values.map((d) => d.name).toSet();
    final hexNames = HexDirection.values.map((d) => d.name).toSet();

    expect(hexNames.intersection(squareNames), isEmpty);
    expect(hexNames.intersection(layerNames), isEmpty);
  });
}
