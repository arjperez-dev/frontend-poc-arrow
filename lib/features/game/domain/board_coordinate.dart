class BoardCoordinate {
  const BoardCoordinate({
    required this.x,
    required this.y,
    this.z = 0,
  });

  final int x;
  final int y;

  /// Layer axis. Defaults to 0, so every existing 2D coordinate is the
  /// z=0 plane of the 3D lattice rather than a distinct type.
  final int z;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCoordinate && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'BoardCoordinate(x: $x, y: $y, z: $z)';
}
