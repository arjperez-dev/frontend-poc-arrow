class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.isBlocked = false,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final bool isBlocked;

  bool connects(String nodeId) => fromNodeId == nodeId || toNodeId == nodeId;

  String? otherNodeId(String nodeId) {
    if (fromNodeId == nodeId) {
      return toNodeId;
    }
    if (toNodeId == nodeId) {
      return fromNodeId;
    }
    return null;
  }
}
