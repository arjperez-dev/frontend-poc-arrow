import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/get_local_levels_use_case.dart';
import 'package:frontend_poc_arrow/features/game/application/level_complexity.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_data_source.dart';
import 'package:frontend_poc_arrow/features/game/presentation/level_mode_filter.dart';

import '../game_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analyzer = LevelComplexityAnalyzer();

  // Two arrows on a row a-b-c-d, both free to exit (left arrow exits left,
  // right arrow exits right).
  Level freeLevel() => buildLevel(
    collisionDefinition(
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'b',
          endNodeId: 'a',
          direction: Direction.left,
        ),
        ArrowPathDefinition(
          id: 'arrow-2',
          occupiedEdgeIds: ['cd'],
          startNodeId: 'c',
          endNodeId: 'd',
          direction: Direction.right,
        ),
      ],
    ),
  );

  // Same board, but arrow-1 now points right: its head at b sweeps into
  // arrow-2's body at c — initially blocked.
  Level blockedLevel() => buildLevel(
    collisionDefinition(
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'arrow-2',
          occupiedEdgeIds: ['cd'],
          startNodeId: 'c',
          endNodeId: 'd',
          direction: Direction.right,
        ),
      ],
    ),
  );

  // Single straight arrow a→b→c exiting right.
  Level straightLevel() => buildLevel(
    basicDefinition(
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab', 'bc'],
          startNodeId: 'a',
          endNodeId: 'c',
          direction: Direction.right,
        ),
      ],
    ),
  );

  // Single bent arrow a→b→d (right, then down) exiting down.
  Level bentLevel() => buildLevel(
    basicDefinition(
      arrows: const [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab', 'bd'],
          startNodeId: 'a',
          endNodeId: 'd',
          direction: Direction.down,
        ),
      ],
    ),
  );

  // Two layers connected by one vertical arrow exiting below (z increases
  // with LayerDirection.below; head at z1 sweeps to z2 → boundary).
  Level multiLayerLevel() => buildLevel(
    const LevelDefinition(
      id: 'test-3d',
      name: '3D Test Level',
      nodes: [
        GraphNodeDefinition(id: 'a', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'b', x: 0, y: 0, z: 1),
      ],
      edges: [GraphEdgeDefinition(id: 'ab', fromNodeId: 'a', toNodeId: 'b')],
      arrows: [
        ArrowPathDefinition(
          id: 'arrow-1',
          occupiedEdgeIds: ['ab'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: LayerDirection.below,
        ),
      ],
      blockedEdgeIds: [],
      metadata: {'difficulty': 'test'},
    ),
  );

  group('metric extraction', () {
    test('should_count_arrows_and_detect_no_blockers_on_free_level', () {
      final complexity = analyzer.analyze(freeLevel());

      expect(complexity.arrowCount, 2);
      expect(complexity.blockedArrowCount, 0);
      expect(complexity.bentArrowCount, 0);
      expect(complexity.layerCount, 1);
      expect(complexity.verticalArrowCount, 0);
    });

    test('should_detect_initially_blocked_arrow_via_head_sweep', () {
      final complexity = analyzer.analyze(blockedLevel());

      expect(complexity.blockedArrowCount, 1);
    });

    test('should_detect_bent_arrow_from_ordered_path', () {
      expect(analyzer.analyze(straightLevel()).bentArrowCount, 0);
      expect(analyzer.analyze(bentLevel()).bentArrowCount, 1);
    });

    test('should_detect_layers_and_vertical_arrows_on_3d_level', () {
      final complexity = analyzer.analyze(multiLayerLevel());

      expect(complexity.layerCount, 2);
      expect(complexity.verticalArrowCount, 1);
    });

    test('should_ignore_escaped_arrows', () {
      final level = freeLevel();
      final escaped = Level(
        id: level.id,
        number: level.number,
        name: level.name,
        boardGraph: level.boardGraph,
        arrows: [
          level.arrows.first,
          level.arrows.last.copyWith(isEscaped: true),
        ],
        metadata: level.metadata,
      );

      expect(analyzer.analyze(escaped).arrowCount, 1);
    });
  });

  group('score ordering', () {
    test('should_score_blocked_level_higher_than_free_level', () {
      expect(
        analyzer.analyze(blockedLevel()).score,
        greaterThan(analyzer.analyze(freeLevel()).score),
      );
    });

    test('should_score_bent_arrow_higher_than_straight_arrow', () {
      expect(
        analyzer.analyze(bentLevel()).score,
        greaterThan(analyzer.analyze(straightLevel()).score),
      );
    });

    test('should_categorize_small_fixture_levels_as_easy', () {
      expect(analyzer.analyze(freeLevel()).tier, ComplexityTier.easy);
      expect(analyzer.analyze(multiLayerLevel()).tier, ComplexityTier.easy);
    });
  });

  // Sanity over the real shipped levels: categorization is computed at load
  // time from structure alone, spreads 2D across all three tiers, and keeps
  // every (deliberately hard) 3D level in the hard band.
  group('shipped levels', () {
    late List<Level> levels;

    setUpAll(() async {
      final repository = AssetLevelRepository(
        localLevelDataSource: LocalLevelDataSource(
          assetTextLoader: const RootBundleAssetTextLoader(),
        ),
      );
      levels = await GetLocalLevelsUseCase(repository)();
    });

    test('should_assign_a_tier_and_positive_score_to_every_level', () {
      for (final level in levels) {
        final complexity = analyzer.analyze(level);
        expect(complexity.score, greaterThan(0), reason: 'L${level.number}');
        expect(ComplexityTier.values, contains(complexity.tier));
      }
    });

    test('should_spread_2d_levels_across_all_three_tiers', () {
      final tiers = levels
          .where((level) => !isThreeDLevel(level))
          .map((level) => analyzer.analyze(level).tier)
          .toSet();

      expect(tiers, ComplexityTier.values.toSet());
    });

    test('should_categorize_every_3d_level_as_hard', () {
      final tiers = levels
          .where(isThreeDLevel)
          .map((level) => analyzer.analyze(level).tier)
          .toSet();

      expect(tiers, {ComplexityTier.hard});
    });
  });
}
