class BoardCoordinate {
  const BoardCoordinate({
    required this.x,
    required this.y,
  });

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCoordinate && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'BoardCoordinate(x: $x, y: $y)';
}
