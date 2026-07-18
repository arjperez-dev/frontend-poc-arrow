import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_topology.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/hex_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/level_definition_mapper.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/manual_level_dto.dart';

const _hexAssetPath = 'assets/levels/manual_levels_hex.json';

// Loads assets/levels/manual_levels_hex.json directly, bypassing
// LocalLevelDataSource: hex is not yet concatenated into the 2D+3D loader
// (that's Phase 37.4's mode-routing scope). Mirrors the exact DTO -> mapper
// -> validator pipeline LocalLevelDataSource uses internally, so this is the
// same real load-and-validate path the app will eventually use.
Future<List<Level>> _loadHexLevels() async {
  const loader = RootBundleAssetTextLoader();
  final source = await loader.loadString(_hexAssetPath);
  final dtos = ManualLevelCollectionDto.fromJsonString(source).levels;
  const mapper = LevelDefinitionMapper();
  const validator = LevelDefinitionValidator();
  return dtos.map(mapper.toDomain).map(validator.validate).toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should_load_ten_hex_levels_numbered_31_to_40', () async {
    final levels = await _loadHexLevels();

    expect(levels, hasLength(10));
    expect(
      levels.map((l) => l.number).toSet(),
      containsAll(List<int>.generate(10, (i) => i + 31)),
    );
  });

  test('should_declare_hex_topology_in_metadata', () async {
    final levels = await _loadHexLevels();

    for (final level in levels) {
      expect(
        level.metadata['topology'],
        'hex',
        reason: 'Level ${level.number}',
      );
      expect(
        level.boardGraph.topology,
        BoardTopology.hex,
        reason: 'Level ${level.number}',
      );
    }
  });

  test('should_have_no_free_nodes_at_level_start', () async {
    final levels = await _loadHexLevels();

    for (final level in levels) {
      final covered = <String>{};
      for (final arrow in level.arrows) {
        covered.addAll(MovementResolver.coveredNodeIds(level.boardGraph, arrow));
      }
      final free = level.boardGraph.nodes
          .where((n) => !covered.contains(n.id))
          .map((n) => n.id)
          .toList();
      expect(free, isEmpty, reason: 'Level ${level.number} has free nodes: $free');
    }
  });

  test('should_be_greedy_solvable', () async {
    // Drives the real MovementResolver — this is what proves the JS hex
    // physics mirror (canExit's coordinate sweep) and the Dart resolver
    // actually agree, not just that the JS-side generator thinks so.
    final levels = await _loadHexLevels();

    for (final level in levels) {
      expect(
        _isSolvable(GameSession.start(level)),
        isTrue,
        reason: 'Level ${level.number} is not solvable',
      );
    }
  });

  test('should_have_a_single_connected_component', () async {
    final levels = await _loadHexLevels();

    for (final level in levels) {
      expect(
        _componentCount(level),
        1,
        reason: 'Level ${level.number} is not a single connected graph',
      );
    }
  });

  test('should_use_all_six_hex_directions_across_the_set', () async {
    final levels = await _loadHexLevels();

    final used = <HexDirection>{};
    for (final level in levels) {
      for (final arrow in level.arrows) {
        final direction = arrow.direction;
        if (direction is HexDirection) used.add(direction);
      }
    }

    expect(used, containsAll(HexDirection.values));
  });

  test('should_have_no_interior_gap_exits', () async {
    // Mirrors hasRealInteriorGapExit in tool/gen_levels.js: a hex
    // silhouette's bounding box has empty corners by construction (a
    // hexagon isn't a rectangle), so those are legitimate concavities —
    // only a gap that hides an actual node further along the sweep is a
    // real defect (the resolver would exit at the gap while the player
    // sees a blocker beyond it).
    final levels = await _loadHexLevels();

    for (final level in levels) {
      final graph = level.boardGraph;
      final nodes = graph.nodes;
      final xs = nodes.map((n) => n.coordinate.x);
      final ys = nodes.map((n) => n.coordinate.y);
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);

      for (final arrow in level.arrows) {
        final head = graph.nodeById(arrow.endNodeId)!;
        final dir = arrow.direction;
        var cx = head.coordinate.x;
        var cy = head.coordinate.y;
        var sawGap = false;
        while (true) {
          cx += dir.dx;
          cy += dir.dy;
          if (cx < minX || cx > maxX || cy < minY || cy > maxY) break;
          final next = graph.nodeByCoordinate(BoardCoordinate(x: cx, y: cy));
          if (next == null) {
            sawGap = true;
            continue;
          }
          expect(
            sawGap,
            isFalse,
            reason: 'Level ${level.number} arrow ${arrow.id} exits through '
                'a gap and then hits node $next at ($cx,$cy) — real '
                'hidden-blocker defect, not a harmless shape concavity',
          );
          break;
        }
      }
    }
  });

  test('should_have_bent_arrows_in_every_difficulty_tier', () async {
    final levels = await _loadHexLevels();

    bool hasBent(int lo, int hi) => levels
        .where((l) => (l.number ?? 0) >= lo && (l.number ?? 0) <= hi)
        .any((l) => l.arrows.any((a) => a.orderedNodeIds.length >= 3));

    expect(hasBent(31, 33), isTrue, reason: 'Easy hex levels have no bent arrow');
    expect(hasBent(34, 37), isTrue, reason: 'Medium hex levels have no bent arrow');
    expect(hasBent(38, 40), isTrue, reason: 'Hard hex levels have no bent arrow');
  });
}

/// Greedy solver using the real [MovementResolver] (mirrors the helper in
/// manual_levels_test.dart): repeatedly escape every currently-exitable
/// arrow. Sound and complete because escaping only frees nodes (monotonic).
bool _isSolvable(GameSession session) {
  const resolver = MovementResolver();
  var s = session;
  while (true) {
    final active = s.activeArrows;
    if (active.isEmpty) {
      return true;
    }
    final exitableIds = active
        .where(
          (a) =>
              resolver.resolve(session: s, arrow: a) ==
              ExitAttemptOutcome.escaped,
        )
        .map((a) => a.id)
        .toSet();
    if (exitableIds.isEmpty) {
      return false;
    }
    s = s.copyWith(
      arrows: s.arrows
          .map((a) => exitableIds.contains(a.id) ? a.copyWith(isEscaped: true) : a)
          .toList(growable: false),
    );
  }
}

int _componentCount(Level level) {
  final nodeIds = level.boardGraph.nodes.map((n) => n.id).toSet();
  final edges = level.boardGraph.edges.map((e) => [e.fromNodeId, e.toNodeId]).toList();
  final adj = <String, List<String>>{for (final id in nodeIds) id: <String>[]};
  for (final e in edges) {
    adj[e[0]]?.add(e[1]);
    adj[e[1]]?.add(e[0]);
  }
  final seen = <String>{};
  var components = 0;
  for (final start in nodeIds) {
    if (seen.contains(start)) continue;
    components++;
    final stack = <String>[start];
    seen.add(start);
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final nb in adj[cur]!) {
        if (seen.add(nb)) stack.add(nb);
      }
    }
  }
  return components;
}
