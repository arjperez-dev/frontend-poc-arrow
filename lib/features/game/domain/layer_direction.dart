import 'board_coordinate.dart';
import 'move_direction.dart';

/// Z-axis directions. Named `above`/`below` rather than `up`/`down` — those
/// names are already the Y-axis screen directions in [Direction] and in
/// level JSON.
enum LayerDirection implements MoveDirection {
  above(0, 0, -1),
  below(0, 0, 1);

  const LayerDirection(this.dx, this.dy, this.dz);

  @override
  final int dx;
  @override
  final int dy;
  @override
  final int dz;

  @override
  BoardCoordinate applyTo(BoardCoordinate coordinate) {
    return BoardCoordinate(
      x: coordinate.x + dx,
      y: coordinate.y + dy,
      z: coordinate.z + dz,
    );
  }

  @override
  MoveDirection get opposite {
    return switch (this) {
      LayerDirection.above => LayerDirection.below,
      LayerDirection.below => LayerDirection.above,
    };
  }
}
