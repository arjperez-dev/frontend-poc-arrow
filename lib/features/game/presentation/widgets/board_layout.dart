import 'dart:ui';

/// Shared shape implemented by every flat board's coordinate->pixel mapping
/// ([GraphBoardLayout] for square boards, `HexBoardLayout` for hex boards).
///
/// Lets painter/hit-tester helpers work against either geometry without
/// caring how [step] or [positionOf] were derived.
abstract class BoardLayout {
  Offset? positionOf(String nodeId);

  /// Pixel distance between adjacent graph nodes. Used to scale stroke
  /// width, arrowhead size, and hit slop so dense boards don't draw or hit
  /// past their own cell.
  double get step;
}
