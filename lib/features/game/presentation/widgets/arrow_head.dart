import 'dart:math' as math;
import 'dart:ui';

/// Draws the arrowhead triangle shared by the 2D and 3D board painters:
/// tip one [length] ahead of [position] along [angle], wings swept back at
/// ±0.72π. Callers compute [angle], [length], and [width] from their own
/// geometry (cell size on the flat board, projected pixel scale on the 3D
/// board) — only the shape itself is shared, so heads render identically on
/// both boards.
void paintArrowHead(
  Canvas canvas,
  Offset position,
  double angle,
  Color color, {
  required double length,
  required double width,
}) {
  final tip = position + Offset(math.cos(angle), math.sin(angle)) * length;
  final left =
      position +
      Offset(
            math.cos(angle + (math.pi * 0.72)),
            math.sin(angle + (math.pi * 0.72)),
          ) *
          width;
  final right =
      position +
      Offset(
            math.cos(angle - (math.pi * 0.72)),
            math.sin(angle - (math.pi * 0.72)),
          ) *
          width;
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close(),
    Paint()
      ..color = color
      ..style = PaintingStyle.fill,
  );
}
