import 'dart:ui';

/// Distance from [point] to the closest point on the segment [start]–[end].
/// Shared by the 2D and 3D hit testers so tap tolerance around arrow bodies
/// is computed identically on both boards.
double distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final t =
      (((point.dx - start.dx) * segment.dx) +
          ((point.dy - start.dy) * segment.dy)) /
      lengthSquared;
  final clamped = t.clamp(0.0, 1.0);
  final projection = Offset(
    start.dx + (segment.dx * clamped),
    start.dy + (segment.dy * clamped),
  );

  return (point - projection).distance;
}
