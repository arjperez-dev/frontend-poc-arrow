import 'arrow_path.dart';
import 'board_graph.dart';

class Level {
  const Level({
    required this.id,
    required this.name,
    required this.boardGraph,
    required this.arrows,
    required this.metadata,
  });

  final String id;
  final String name;
  final BoardGraph boardGraph;
  final List<ArrowPath> arrows;
  final Map<String, Object?> metadata;
}
