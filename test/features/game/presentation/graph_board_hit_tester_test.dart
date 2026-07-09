import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/application/get_local_levels_use_case.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_level_repository.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/local_level_data_source.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_board_hit_tester.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_board_layout.dart';

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

  test(
    'should_keep_hit_slop_floor_below_half_cell_on_dense_figure_boards',
    () async {
      // Phase 19 finding: minHitSlop=12 exceeded cellSize*0.45 on every
      // figure level (16-20, steps ~15-20px), letting the floor override the
      // documented "never reach halfway to neighbour" cap and making taps
      // near adjacent nodes ambiguous. Fixed by lowering minHitSlop to 6.
      // This regression-tests the invariant against the actual shipped
      // figure-level layouts at a representative phone-sized viewport.
      const hitTester = GraphBoardHitTester();
      final levels = (await GetLocalLevelsUseCase(repository)())
          .where((level) => level.metadata['generationType'] == 'figure');

      for (final level in levels) {
        final layout = GraphBoardLayout.fromGraph(
          graph: level.boardGraph,
          size: const Size(380, 640),
        );
        final halfCell = layout.step * 0.45;
        expect(
          hitTester.minHitSlop,
          lessThanOrEqualTo(halfCell),
          reason: 'Level ${level.number} step=${layout.step}: minHitSlop '
              '(${hitTester.minHitSlop}) exceeds half-cell ($halfCell) — '
              'tap zones around adjacent nodes can overlap',
        );
      }
    },
  );
}
