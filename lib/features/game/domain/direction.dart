import 'board_coordinate.dart';

enum Direction {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const Direction(this.dx, this.dy);

  final int dx;
  final int dy;

  BoardCoordinate applyTo(BoardCoordinate coordinate) {
    return BoardCoordinate(
      x: coordinate.x + dx,
      y: coordinate.y + dy,
    );
  }

  Direction get opposite {
    return switch (this) {
      Direction.up => Direction.down,
      Direction.right => Direction.left,
      Direction.down => Direction.up,
      Direction.left => Direction.right,
    };
  }

  static Direction? between(BoardCoordinate from, BoardCoordinate to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    for (final direction in Direction.values) {
      if (direction.dx == dx && direction.dy == dy) {
        return direction;
      }
    }

    return null;
  }
}
