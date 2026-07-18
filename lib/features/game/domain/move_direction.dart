import 'board_coordinate.dart';
import 'board_topology.dart';
import 'direction.dart';
import 'hex_direction.dart';
import 'layer_direction.dart';

/// A unit step on the board lattice, along exactly one axis.
///
/// [Direction] implements this for the X/Y plane; [LayerDirection]
/// implements it for the Z axis; [HexDirection] implements it for the
/// planar hex lattice. New axes are added by writing a new implementation,
/// never by changing an existing one (Open/Closed).
abstract interface class MoveDirection implements Enum {
  int get dx;
  int get dy;
  int get dz;

  BoardCoordinate applyTo(BoardCoordinate coordinate);

  MoveDirection get opposite;

  /// Every known direction for [topology]. Direction resolution is scoped
  /// per topology, not global: `square` and `hex` deltas partially overlap
  /// (hex east/west/northWest/southEast share deltas with square
  /// right/left/up/down), so merging both sets into one flat list would
  /// make [between]/[parse] silently resolve a hex step to the wrong square
  /// direction, or start accepting square diagonals that must stay
  /// rejected. The two sets must never be merged.
  static List<MoveDirection> allFor(BoardTopology topology) {
    return switch (topology) {
      BoardTopology.square => [
          ...Direction.values,
          ...LayerDirection.values,
        ],
      BoardTopology.hex => [
          ...HexDirection.values,
          ...LayerDirection.values,
        ],
    };
  }

  /// The unit direction that steps from [from] to [to] within [topology],
  /// or null if they are not lattice-adjacent along a single axis of that
  /// topology (not adjacent at all, or a diagonal/multi-step delta).
  static MoveDirection? between(
    BoardCoordinate from,
    BoardCoordinate to, {
    BoardTopology topology = BoardTopology.square,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final dz = to.z - from.z;

    for (final direction in allFor(topology)) {
      if (direction.dx == dx && direction.dy == dy && direction.dz == dz) {
        return direction;
      }
    }

    return null;
  }

  /// Parses the lowercase name used in level JSON ('up', 'right', 'down',
  /// 'left', 'above', 'below', or the [HexDirection] names for hex levels)
  /// within [topology]. Throws [FormatException] for a name unknown to that
  /// topology — never falls back to the other topology's set.
  static MoveDirection parse(
    String value, {
    BoardTopology topology = BoardTopology.square,
  }) {
    for (final direction in allFor(topology)) {
      if (direction.name == value) {
        return direction;
      }
    }
    throw FormatException('Unknown arrow direction "$value".');
  }
}
