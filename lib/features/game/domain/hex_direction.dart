import 'board_coordinate.dart';
import 'move_direction.dart';

/// Pointy-top axial hex directions. Axial `(q, r)` is stored directly in
/// [BoardCoordinate.x]/[BoardCoordinate.y]; `dz` is always 0 — hex boards
/// are planar-only (see [BoardTopology]).
///
/// Names are deliberately distinct from [Direction] and [LayerDirection] so
/// [MoveDirection.parse] stays unambiguous even though this set is never
/// merged with the square set.
enum HexDirection implements MoveDirection {
  east(1, 0),
  northEast(1, -1),
  northWest(0, -1),
  west(-1, 0),
  southWest(-1, 1),
  southEast(0, 1);

  const HexDirection(this.dx, this.dy);

  @override
  final int dx;
  @override
  final int dy;

  @override
  int get dz => 0;

  @override
  BoardCoordinate applyTo(BoardCoordinate coordinate) {
    return BoardCoordinate(
      x: coordinate.x + dx,
      y: coordinate.y + dy,
      z: coordinate.z,
    );
  }

  @override
  HexDirection get opposite {
    return switch (this) {
      HexDirection.east => HexDirection.west,
      HexDirection.west => HexDirection.east,
      HexDirection.northEast => HexDirection.southWest,
      HexDirection.southWest => HexDirection.northEast,
      HexDirection.northWest => HexDirection.southEast,
      HexDirection.southEast => HexDirection.northWest,
    };
  }
}
