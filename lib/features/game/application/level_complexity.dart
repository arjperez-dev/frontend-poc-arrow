import '../domain/arrow_path.dart';
import '../domain/board_coordinate.dart';
import '../domain/board_graph.dart';
import '../domain/layer_direction.dart';
import '../domain/level.dart';
import 'movement_resolver.dart';

/// Dynamically computed difficulty band for a level. Replaces the hardcoded
/// `difficulty` string shipped in the level JSON (which stays in the file as
/// dormant metadata, like `timeLimit`/`maxMoves`): every level — including
/// future ones — is categorized from its own structure at load time.
enum ComplexityTier {
  easy,
  medium,
  hard;

  /// Uppercase label for the level card, matching the previous convention of
  /// showing the raw metadata string uppercased (unlocalized, as before).
  String get label => name.toUpperCase();
}

/// The measured complexity of one level: the raw metrics, the weighted
/// composite [score], and the [tier] band the score falls into.
class LevelComplexity {
  const LevelComplexity({
    required this.score,
    required this.tier,
    required this.arrowCount,
    required this.blockedArrowCount,
    required this.bentArrowCount,
    required this.coverageDensity,
    required this.layerCount,
    required this.verticalArrowCount,
  });

  final double score;
  final ComplexityTier tier;

  /// Active arrows — the minimum number of taps to solve the level.
  final int arrowCount;

  /// Arrows whose initial exit sweep is blocked by another arrow's body
  /// (same coordinate sweep as [MovementResolver]) — a proxy for how deep
  /// the required untangle ordering is ("crossing paths").
  final int blockedArrowCount;

  /// Arrows whose path changes direction at least once.
  final int bentArrowCount;

  /// Fraction of board nodes covered by arrows (congestion), 0.0–1.0.
  final double coverageDensity;

  /// Distinct z-layers; 1 for a purely 2D board.
  final int layerCount;

  /// Arrows whose path crosses layers (any z-step, or a vertical direction).
  final int verticalArrowCount;
}

/// Evaluates a level's complexity from its structure alone — no metadata is
/// read, so newly authored levels are categorized automatically.
///
/// The composite score is a weighted sum of the metrics on [LevelComplexity];
/// the tier thresholds below are the only fixed constants and were calibrated
/// against the 30 shipped levels (see `level_complexity_test.dart`).
class LevelComplexityAnalyzer {
  const LevelComplexityAnalyzer();

  static const double _blockedWeight = 1.5;
  static const double _bentWeight = 0.5;
  static const double _densityWeight = 10.0;
  static const double _layerWeight = 2.0;
  static const double _verticalWeight = 0.5;

  // Calibrated against the 30 shipped levels (2026-07-13): 2D scores span
  // 33-103.5 and band as 5 easy / 7 medium / 8 hard; 3D scores span 75-121,
  // all hard — truthful, since every 3D level is deliberately hard-tier.
  static const double _easyUpperBound = 45.0;
  static const double _mediumUpperBound = 62.0;

  LevelComplexity analyze(Level level) {
    final graph = level.boardGraph;
    final arrows = level.arrows.where((arrow) => arrow.isActive).toList();

    final coveredByArrow = <String, Set<String>>{
      for (final arrow in arrows)
        arrow.id: MovementResolver.coveredNodeIds(graph, arrow),
    };

    var blockedCount = 0;
    var bentCount = 0;
    var verticalCount = 0;
    final allCovered = <String>{};

    for (final arrow in arrows) {
      allCovered.addAll(coveredByArrow[arrow.id] ?? const <String>{});
      if (_isInitiallyBlocked(graph, arrow, arrows, coveredByArrow)) {
        blockedCount++;
      }
      if (_isBent(graph, arrow)) {
        bentCount++;
      }
      if (_crossesLayers(graph, arrow)) {
        verticalCount++;
      }
    }

    final nodeCount = graph.nodes.length;
    final density = nodeCount == 0 ? 0.0 : allCovered.length / nodeCount;
    final layerCount = graph.layers.length;

    final score = arrows.length +
        blockedCount * _blockedWeight +
        bentCount * _bentWeight +
        density * _densityWeight +
        (layerCount - 1) * _layerWeight +
        verticalCount * _verticalWeight;

    return LevelComplexity(
      score: score,
      tier: _tierFor(score),
      arrowCount: arrows.length,
      blockedArrowCount: blockedCount,
      bentArrowCount: bentCount,
      coverageDensity: density,
      layerCount: layerCount,
      verticalArrowCount: verticalCount,
    );
  }

  ComplexityTier _tierFor(double score) {
    if (score < _easyUpperBound) {
      return ComplexityTier.easy;
    }
    if (score < _mediumUpperBound) {
      return ComplexityTier.medium;
    }
    return ComplexityTier.hard;
  }

  /// Same head-only coordinate sweep as [MovementResolver.resolve], evaluated
  /// against the level's initial arrow layout: blocked edge or another
  /// arrow's covered node before the boundary → blocked.
  bool _isInitiallyBlocked(
    BoardGraph graph,
    ArrowPath arrow,
    List<ArrowPath> arrows,
    Map<String, Set<String>> coveredByArrow,
  ) {
    final blockerNodes = <String>{};
    for (final other in arrows) {
      if (other.id == arrow.id) continue;
      blockerNodes.addAll(coveredByArrow[other.id] ?? const <String>{});
    }

    var currentNode = graph.nodeById(arrow.endNodeId);
    while (currentNode != null) {
      final nextCoord = arrow.direction.applyTo(currentNode.coordinate);
      final nextNode = graph.nodeByCoordinate(nextCoord);
      if (nextNode == null) {
        return false; // boundary → free to exit
      }
      final edge = graph.getEdgeBetween(currentNode.id, nextNode.id);
      if (edge != null && edge.isBlocked) {
        return true;
      }
      if (blockerNodes.contains(nextNode.id)) {
        return true;
      }
      currentNode = nextNode;
    }
    return false;
  }

  bool _isBent(BoardGraph graph, ArrowPath arrow) {
    final coordinates = _pathCoordinates(graph, arrow);
    for (var i = 2; i < coordinates.length; i++) {
      final previous = _delta(coordinates[i - 2], coordinates[i - 1]);
      final current = _delta(coordinates[i - 1], coordinates[i]);
      if (previous != current) {
        return true;
      }
    }
    return false;
  }

  bool _crossesLayers(BoardGraph graph, ArrowPath arrow) {
    if (arrow.direction is LayerDirection) {
      return true;
    }
    final coordinates = _pathCoordinates(graph, arrow);
    return coordinates.map((coordinate) => coordinate.z).toSet().length > 1;
  }

  List<BoardCoordinate> _pathCoordinates(BoardGraph graph, ArrowPath arrow) {
    return [
      for (final nodeId in arrow.orderedNodeIds)
        if (graph.nodeById(nodeId) != null) graph.nodeById(nodeId)!.coordinate,
    ];
  }

  (int, int, int) _delta(BoardCoordinate from, BoardCoordinate to) {
    return (to.x - from.x, to.y - from.y, to.z - from.z);
  }
}
