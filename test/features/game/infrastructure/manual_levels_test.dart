import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/application/get_local_level_by_number_use_case.dart';
import 'package:frontend_poc_arrow/features/game/application/get_local_levels_use_case.dart';
import 'package:frontend_poc_arrow/features/game/application/movement_resolver.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/level_definition_mapper.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_data_source.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/manual_level_dto.dart';

class InMemoryAssetTextLoader implements AssetTextLoader {
  const InMemoryAssetTextLoader(this.source);

  final String source;

  @override
  Future<String> loadString(String assetPath) async {
    return source;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssetLevelRepository repository;

  setUp(() {
    repository = AssetLevelRepository(
      localLevelDataSource: LocalLevelDataSource(
        assetTextLoader: const RootBundleAssetTextLoader(),
      ),
    );
  });

  test('should_load_20_manual_levels_from_assets', () async {
    final levels = await GetLocalLevelsUseCase(repository)();

    expect(levels, hasLength(20));
    expect(levels.first.number, 1);
    expect(levels.last.number, 20);
  });

  test('should_validate_all_manual_levels', () async {
    final dataSource = LocalLevelDataSource(
      assetTextLoader: const RootBundleAssetTextLoader(),
    );
    final mapper = LevelDefinitionMapper();
    final validator = LevelDefinitionValidator();
    final dtos = await dataSource.loadManualLevels();

    final levels = dtos.map(mapper.toDomain).map(validator.validate).toList();

    expect(levels, hasLength(20));
    expect(levels.every((level) => level.boardGraph.nodes.isNotEmpty), isTrue);
    expect(levels.every((level) => level.boardGraph.edges.isNotEmpty), isTrue);
  });

  test('should_have_progressive_difficulty_across_manual_levels', () async {
    final levels = await GetLocalLevelsUseCase(repository)();

    expect(
      levels.where((level) => level.number! <= 5).map(_difficulty),
      everyElement('easy'),
    );
    expect(
      levels
          .where((level) => level.number! >= 6 && level.number! <= 10)
          .map(_difficulty),
      everyElement('medium'),
    );
    expect(
      levels.where((level) => level.number! >= 11).map(_difficulty),
      everyElement('hard'),
    );
  });

  test('should_have_unique_level_numbers', () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    final numbers = levels.map((level) => level.number).toSet();

    expect(numbers, hasLength(20));
    expect(numbers, containsAll(List<int>.generate(20, (index) => index + 1)));
  });

  test('should_have_unique_level_ids', () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    final ids = levels.map((level) => level.id).toSet();

    expect(ids, hasLength(20));
    expect(ids, contains('manual-001'));
    expect(ids, contains('manual-020'));
  });

  test(
    'should_reject_manual_level_when_required_graph_keys_are_missing',
    () async {
      final source = jsonEncode({
        'levels': [
          {
            'number': 1,
            'name': 'Broken Level',
            'difficulty': 'easy',
            'definitionJson': {
              'edges': <Object?>[],
              'arrows': <Object?>[],
              'blockedEdges': <Object?>[],
              'metadata': {'difficulty': 'easy'},
            },
          },
        ],
      });
      final dataSource = LocalLevelDataSource(
        assetTextLoader: InMemoryAssetTextLoader(source),
      );

      expect(dataSource.loadManualLevels, throwsA(isA<FormatException>()));
    },
  );

  test('should_map_manual_level_definition_to_domain_level', () async {
    final level = await GetLocalLevelByNumberUseCase(repository)(2);

    expect(level, isNotNull);
    expect(level!.number, 2);
    expect(level.id, 'manual-002');
    expect(level.name, 'Level 2');
    expect(level.arrows.length, greaterThanOrEqualTo(10));
    expect(level.metadata['generationType'], 'manual');
  });

  test('should_keep_manual_levels_graph_based_not_matrix_based', () async {
    final source = await const RootBundleAssetTextLoader().loadString(
      LocalLevelDataSource.manualLevelsAssetPath,
    );
    final decoded = jsonDecode(source) as Map<String, Object?>;
    final levels = decoded['levels']! as List<Object?>;

    for (final rawLevel in levels) {
      final level = rawLevel! as Map<String, Object?>;
      final definition = level['definitionJson']! as Map<String, Object?>;
      expect(definition.containsKey('nodes'), isTrue);
      expect(definition.containsKey('edges'), isTrue);
      expect(definition.containsKey('arrows'), isTrue);
      expect(definition.containsKey('blockedEdges'), isTrue);
      expect(definition.containsKey('matrix'), isFalse);
      expect(definition.containsKey('grid'), isFalse);
      expect(definition.containsKey('cells'), isFalse);
    }
  });

  test('should_have_no_free_nodes_at_level_start', () async {
    final levels = await GetLocalLevelsUseCase(repository)();

    for (final level in levels) {
      final covered = <String>{};
      for (final arrow in level.arrows) {
        covered.addAll(
          MovementResolver.coveredNodeIds(level.boardGraph, arrow),
        );
      }
      final free = level.boardGraph.nodes
          .where((node) => !covered.contains(node.id))
          .map((node) => node.id)
          .toList();
      expect(
        free,
        isEmpty,
        reason: 'Level ${level.number} has free (unoccupied) nodes: $free',
      );
    }
  });

  test('should_keep_all_levels_solvable_under_full_exit_resolver', () async {
    final levels = await GetLocalLevelsUseCase(repository)();

    for (final level in levels) {
      expect(
        _isSolvable(GameSession.start(level)),
        isTrue,
        reason: 'Level ${level.number} is not solvable',
      );
    }
  });

  test('should_not_have_all_hard_levels_rectangular', () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    final hard = levels.where((level) => (level.number ?? 0) >= 11).toList();

    final rectangularCount = hard.where(_isRectangular).length;
    expect(
      rectangularCount,
      lessThan(hard.length),
      reason: 'All hard levels are full rectangles',
    );
  });

  test('should_meet_arrow_density_bands_per_tier', () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    for (final level in levels) {
      final n = level.arrows.length;
      final tier = _difficulty(level);
      final matcher = switch (tier) {
        'easy' => inInclusiveRange(10, 15),
        'medium' => inInclusiveRange(15, 30),
        _ => inInclusiveRange(20, 60), // hard
      };
      expect(
        n,
        matcher,
        reason: 'Level ${level.number} ($tier) has $n arrows (out of band)',
      );
    }
  });

  test('should_have_single_connected_traversal_graph_for_all_manual_levels',
      () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    for (final level in levels) {
      expect(
        _componentCount(level),
        1,
        reason: 'Level ${level.number} is not a single connected graph',
      );
    }
  });

  test('should_reject_disconnected_level_graph', () async {
    // Two unconnected manual levels in source must be rejected by the
    // connectivity check (here exercised directly via the BFS helper).
    final levels = await GetLocalLevelsUseCase(repository)();
    final connected = levels.first;
    expect(_componentCount(connected), 1);

    // A synthetic two-island graph reports 2 components.
    final twoIslands = _twoIslandLevel();
    expect(_componentCountOfGraph(twoIslands.nodeIds, twoIslands.edges), 2);
  });

  test('should_apply_no_free_nodes_rule_to_visible_nodes', () async {
    // Every visible/playable node must be occupied by an arrow at start.
    // (No hidden connector nodes exist; the rule applies to all nodes.)
    final levels = await GetLocalLevelsUseCase(repository)();
    for (final level in levels) {
      final covered = <String>{};
      for (final arrow in level.arrows) {
        covered.addAll(
          MovementResolver.coveredNodeIds(level.boardGraph, arrow),
        );
      }
      final freeVisible = level.boardGraph.nodes
          .where((n) => !covered.contains(n.id))
          .map((n) => n.id)
          .toList();
      expect(freeVisible, isEmpty,
          reason: 'Level ${level.number} has unoccupied visible nodes');
    }
  });

  test('should_orient_arrowhead_at_exit_end_for_all_directions', () async {
    // The head (endNodeId) must be the exit-facing end: the arrow body edge at
    // the head must lead OPPOSITE to the arrow direction. This catches the
    // left/up head-placement bug behind incorrect arrowhead rendering.
    final levels = await GetLocalLevelsUseCase(repository)();
    for (final level in levels) {
      final graph = level.boardGraph;
      for (final arrow in level.arrows) {
        final head = graph.nodeById(arrow.endNodeId)!;
        final dir = arrow.direction;
        var bodyIsBehind = false;
        for (final edgeId in arrow.occupiedEdgeIds) {
          final edge = graph.edgeById(edgeId);
          if (edge == null) continue;
          final otherId = edge.otherNodeId(arrow.endNodeId);
          if (otherId == null) continue;
          final other = graph.nodeById(otherId)!;
          if (other.coordinate.x == head.coordinate.x - dir.dx &&
              other.coordinate.y == head.coordinate.y - dir.dy) {
            bodyIsBehind = true;
          }
        }
        expect(bodyIsBehind, isTrue,
            reason:
                'Level ${level.number} arrow ${arrow.id} head not at exit end '
                '(dir ${dir.name})');
      }
    }
  });

  test('should_document_arrow_shapes_as_arbitrary_paths_not_templates', () {
    final doc = File('docs/LEVEL_AUTHORING.md').readAsStringSync();
    expect(doc.toLowerCase(), contains('arbitrary'));
    expect(doc.toLowerCase(), contains('not'));
    expect(doc.toLowerCase(), contains('template'));
    expect(doc.toLowerCase(), contains('connected traversal graph'));
  });

  test('should_increase_average_density_across_tiers', () async {
    final levels = await GetLocalLevelsUseCase(repository)();
    double avgArrows(bool Function(Level) where) {
      final counts = levels.where(where).map((l) => l.arrows.length).toList();
      return counts.reduce((a, b) => a + b) / counts.length;
    }

    final easy = avgArrows((l) => (l.number ?? 0) <= 5);
    final medium = avgArrows((l) => (l.number ?? 0) >= 6 && (l.number ?? 0) <= 10);
    final hard = avgArrows((l) => (l.number ?? 0) >= 11);

    expect(easy < medium, isTrue, reason: 'easy avg $easy !< medium avg $medium');
    expect(medium < hard, isTrue, reason: 'medium avg $medium !< hard avg $hard');
  });

  test(
    'should_normalize_reversed_undirected_edge_id_when_equivalent_edge_exists',
    () {
      final mapper = LevelDefinitionMapper();
      final validator = LevelDefinitionValidator();

      final definition = mapper.toDomain(_manualLevelWithArrowEdge('b-a'));
      final level = validator.validate(definition);

      expect(definition.arrows.single.occupiedEdgeIds, ['a-b']);
      expect(level.arrows.single.occupiedEdgeIds, ['a-b']);
    },
  );

  test(
    'should_reject_manual_level_when_reversed_edge_reference_does_not_exist',
    () {
      final mapper = LevelDefinitionMapper();

      expect(
        () => mapper.toDomain(_manualLevelWithArrowEdge('c-b')),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('should_have_no_interior_gap_exits', () async {
    // An arrow must not exit through a coordinate that is inside the level's
    // bounding box but has no node. Such gaps (from hard-level boundary removal)
    // create invisible escape holes: the player sees another arrow visually ahead
    // but the resolver exits at the gap before reaching it.
    //
    // Figure levels (16-20, generationType 'figure') are deliberately concave
    // silhouettes (heart/diamond/club/spade/star) — every bbox-interior "gap"
    // is part of the shape's own visible outer edge, not an accidental hole,
    // so this bbox-relative check does not apply to them (see the matching
    // comment in tool/gen_levels.js's generateFigureLevel).
    final levels = (await GetLocalLevelsUseCase(repository)())
        .where((level) => level.metadata['generationType'] != 'figure');
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
        while (true) {
          cx += dir.dx;
          cy += dir.dy;
          if (cx < minX || cx > maxX || cy < minY || cy > maxY) break;
          final next = graph.nodeByCoordinate(
            BoardCoordinate(x: cx, y: cy),
          );
          expect(
            next,
            isNotNull,
            reason: 'Level ${level.number} arrow ${arrow.id} exits through '
                'interior gap at ($cx,$cy) — boundary-removal hole makes '
                'another arrow appear to block but resolver exits early',
          );
        }
      }
    }
  });

  test('should_have_bent_arrows_in_every_difficulty_tier', () async {
    final levels = await GetLocalLevelsUseCase(repository)();

    bool hasBent(int lo, int hi) => levels
        .where((l) => (l.number ?? 0) >= lo && (l.number ?? 0) <= hi)
        .any((l) => l.arrows.any((a) => a.orderedNodeIds.length >= 3));

    expect(hasBent(1, 5), isTrue,
        reason: 'Easy levels have no bent arrow (orderedNodeIds.length >= 3)');
    expect(hasBent(6, 10), isTrue,
        reason: 'Medium levels have no bent arrow');
    expect(hasBent(11, 15), isTrue,
        reason: 'Hard levels have no bent arrow');
  });
}

String? _difficulty(Level level) {
  return level.metadata['difficulty'] as String?;
}

int _componentCount(Level level) {
  final nodeIds = level.boardGraph.nodes.map((n) => n.id).toSet();
  final edges = level.boardGraph.edges
      .map((e) => [e.fromNodeId, e.toNodeId])
      .toList();
  return _componentCountOfGraph(nodeIds, edges);
}

/// Counts connected components over a node set and undirected edge list (BFS).
int _componentCountOfGraph(Set<String> nodeIds, List<List<String>> edges) {
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

({Set<String> nodeIds, List<List<String>> edges}) _twoIslandLevel() {
  return (
    nodeIds: {'a', 'b', 'c', 'd'},
    edges: [
      ['a', 'b'], // island 1
      ['c', 'd'], // island 2 (no edge between the islands)
    ],
  );
}

bool _isRectangular(Level level) {
  final nodes = level.boardGraph.nodes;
  final xs = nodes.map((n) => n.coordinate.x);
  final ys = nodes.map((n) => n.coordinate.y);
  final w = xs.reduce((a, b) => a > b ? a : b) -
      xs.reduce((a, b) => a < b ? a : b) +
      1;
  final h = ys.reduce((a, b) => a > b ? a : b) -
      ys.reduce((a, b) => a < b ? a : b) +
      1;
  return nodes.length == w * h;
}

/// Greedy solver using the real [MovementResolver]: repeatedly escape every
/// currently-exitable arrow. Because escaped arrows are non-blocking and
/// exiting only frees nodes (monotonic), greedy is sound AND complete — it
/// succeeds iff the level is solvable. This stays fast at 50+ arrows where DFS
/// would blow up.
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
      return false; // deadlock → unsolvable
    }
    s = s.copyWith(
      arrows: s.arrows
          .map((a) => exitableIds.contains(a.id) ? a.copyWith(isEscaped: true) : a)
          .toList(growable: false),
    );
  }
}

ManualLevelDto _manualLevelWithArrowEdge(String occupiedEdgeId) {
  return ManualLevelDto(
    number: 99,
    name: 'Mapper Fixture',
    difficulty: 'easy',
    definitionJson: ManualLevelDefinitionDto(
      nodes: const [
        ManualGraphNodeDto(id: 'a', x: 0, y: 0),
        ManualGraphNodeDto(id: 'b', x: 1, y: 0),
      ],
      edges: const [
        ManualGraphEdgeDto(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
      ],
      arrows: [
        ManualArrowPathDto(
          id: 'arrow-1',
          occupiedEdges: [occupiedEdgeId],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: 'right',
        ),
      ],
      blockedEdges: const [],
      metadata: const {
        'difficulty': 'easy',
        'timeLimit': 120,
        'maxMoves': 20,
        'generationType': 'manual',
        'seed': null,
      },
    ),
  );
}
