import 'board_coordinate.dart';
import 'direction.dart';
import 'layer_direction.dart';

/// A unit step on the board lattice, along exactly one axis.
///
/// [Direction] implements this for the X/Y plane; [LayerDirection]
/// implements it for the Z axis. New axes are added by writing a new
/// implementation, never by changing an existing one (Open/Closed).
abstract interface class MoveDirection implements Enum {
  int get dx;
  int get dy;
  int get dz;

  BoardCoordinate applyTo(BoardCoordinate coordinate);

  MoveDirection get opposite;

  /// Every known direction across all axes. The single place a new axis
  /// implementation must register itself.
  static List<MoveDirection> get all => [
        ...Direction.values,
        ...LayerDirection.values,
      ];

  /// The unit direction that steps from [from] to [to], or null if they are
  /// not lattice-adjacent along a single axis (not adjacent at all, or a
  /// diagonal/multi-step delta). Generalizes [Direction.between] across all
  /// registered axes.
  static MoveDirection? between(BoardCoordinate from, BoardCoordinate to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final dz = to.z - from.z;

    for (final direction in all) {
      if (direction.dx == dx && direction.dy == dy && direction.dz == dz) {
        return direction;
      }
    }

    return null;
  }

  /// Parses the lowercase name used in level JSON ('up', 'right', 'down',
  /// 'left', 'above', 'below'). Throws [FormatException] for unknown values.
  static MoveDirection parse(String value) {
    for (final direction in all) {
      if (direction.name == value) {
        return direction;
      }
    }
    throw FormatException('Unknown arrow direction "$value".');
  }
}
