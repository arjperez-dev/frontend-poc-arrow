import 'direction.dart';

class ArrowPath {
  const ArrowPath({
    required this.id,
    required this.occupiedEdgeIds,
    required this.startNodeId,
    required this.endNodeId,
    required this.direction,
    this.isEscaped = false,
  });

  final String id;
  final List<String> occupiedEdgeIds;
  final String startNodeId;
  final String endNodeId;
  final Direction direction;
  final bool isEscaped;

  bool get isActive => !isEscaped;

  bool occupiesEdge(String edgeId) {
    return isActive && occupiedEdgeIds.contains(edgeId);
  }

  ArrowPath copyWith({
    List<String>? occupiedEdgeIds,
    String? endNodeId,
    Direction? direction,
    bool? isEscaped,
  }) {
    return ArrowPath(
      id: id,
      occupiedEdgeIds: occupiedEdgeIds ?? this.occupiedEdgeIds,
      startNodeId: startNodeId,
      endNodeId: endNodeId ?? this.endNodeId,
      direction: direction ?? this.direction,
      isEscaped: isEscaped ?? this.isEscaped,
    );
  }
}
