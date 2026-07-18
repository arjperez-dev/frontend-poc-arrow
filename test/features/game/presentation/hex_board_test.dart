import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_topology.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/level.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/asset_text_loader.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/level_definition_mapper.dart';
import 'package:frontend_poc_arrow/features/game/infrastructure/manual_level_dto.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_board.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_board_hit_tester.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/hex_board.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/hex_board_layout.dart';

import '../game_test_fixtures.dart';

const _hexAssetPath = 'assets/levels/manual_levels_hex.json';

// Mirrors LocalLevelDataSource's DTO -> mapper -> validator pipeline; hex is
// not yet wired into that loader (Phase 37.4 scope), so tests that need a
// real shipped hex level load the asset directly (same pattern as
// manual_levels_hex_test.dart).
Future<List<Level>> _loadHexLevels() async {
  const loader = RootBundleAssetTextLoader();
  final source = await loader.loadString(_hexAssetPath);
  final dtos = ManualLevelCollectionDto.fromJsonString(source).levels;
  const mapper = LevelDefinitionMapper();
  const validator = LevelDefinitionValidator();
  return dtos.map(mapper.toDomain).map(validator.validate).toList(growable: false);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 400, height: 400, child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('should_map_axial_origin_and_neighbours_to_expected_pixel_offsets', () {
    // px = hexSize*sqrt3*(q + r/2), py = hexSize*1.5*r, with
    // step = hexSize*sqrt3. Express each neighbour delta as a ratio of
    // `step` so the assertions hold regardless of the hexSize the fitting
    // pass happens to choose for this board size.
    final layout = HexBoardLayout.fromGraph(
      graph: buildLevel(hexDefinition()).boardGraph,
      size: const Size(400, 400),
    );

    final centre = layout.positionOf('centre')!;
    final neighbourRatios = {
      'east': const Offset(1, 0),
      'southEast': Offset(0.5, math.sqrt(3) / 2),
      'southWest': Offset(-0.5, math.sqrt(3) / 2),
      'west': const Offset(-1, 0),
      'northWest': Offset(-0.5, -math.sqrt(3) / 2),
      'northEast': Offset(0.5, -math.sqrt(3) / 2),
    };

    for (final entry in neighbourRatios.entries) {
      final delta = layout.positionOf(entry.key)! - centre;
      final ratio = delta / layout.step;
      expect(ratio.dx, closeTo(entry.value.dx, 0.01), reason: entry.key);
      expect(ratio.dy, closeTo(entry.value.dy, 0.01), reason: entry.key);
      // Every neighbour is exactly `step` pixels from centre, regardless of
      // direction — the property GraphBoardHitTester's slop cap relies on.
      expect(delta.distance, closeTo(layout.step, 0.01), reason: entry.key);
    }
  });

  test('should_fit_board_within_available_size_using_pixel_bounding_box', () {
    final graph = buildLevel(hexDefinition()).boardGraph;
    const size = Size(300, 500);
    const padding = 32.0;
    final layout = HexBoardLayout.fromGraph(
      graph: graph,
      size: size,
      padding: padding,
    );

    final positions = graph.nodes.map((n) => layout.positionOf(n.id)!).toList();
    final minX = positions.map((p) => p.dx).reduce(math.min);
    final maxX = positions.map((p) => p.dx).reduce(math.max);
    final minY = positions.map((p) => p.dy).reduce(math.min);
    final maxY = positions.map((p) => p.dy).reduce(math.max);

    // The fitted silhouette must sit within the available (padded) area.
    expect(minX, greaterThanOrEqualTo(padding - 0.5));
    expect(maxX, lessThanOrEqualTo(size.width - padding + 0.5));
    expect(minY, greaterThanOrEqualTo(padding - 0.5));
    expect(maxY, lessThanOrEqualTo(size.height - padding + 0.5));

    // At least one axis should be pulled tight against the available space
    // (the fit is bounding-box-driven, not artificially shrunk).
    final width = maxX - minX;
    final height = maxY - minY;
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);
    expect(
      width > availableWidth - 1 || height > availableHeight - 1,
      isTrue,
      reason: 'fit should be tight against the available width or height',
    );
  });

  testWidgets('should_activate_arrow_when_tapping_its_head_on_a_hex_board',
      (tester) async {
    final session = buildSession(hexDefinition());
    final activated = <String>[];

    await tester.pumpWidget(
      _wrap(
        HexBoard(
          session: session,
          animate: false,
          onArrowActivated: activated.add,
        ),
      ),
    );

    final boardSize = tester.getSize(find.byKey(GameUiKeys.gameBoard));
    final layout = HexBoardLayout.fromGraph(
      graph: session.level.boardGraph,
      size: boardSize,
    );
    final headPosition = layout.positionOf('east')!;
    final boardTopLeft = tester.getTopLeft(find.byKey(GameUiKeys.gameBoard));

    await tester.tapAt(boardTopLeft + headPosition);
    await tester.pump();

    expect(activated, ['hex-arrow-1']);
  });

  test(
    'should_not_activate_a_neighbouring_arrow_when_tapping_near_a_shared_edge',
    () async {
      final levels = await _loadHexLevels();
      // Level 38 is the densest shipped hex level (87 nodes / 23 arrows).
      final level = levels.firstWhere((l) => l.number == 38);
      final session = GameSession.start(level);

      const boardSize = Size(380, 640);
      final layout = HexBoardLayout.fromGraph(
        graph: level.boardGraph,
        size: boardSize,
      );

      // Find the two active arrow heads that sit closest together on the
      // fitted board — the tightest real case for tap ambiguity.
      final heads = <String, Offset>{
        for (final arrow in session.activeArrows)
          arrow.id: layout.positionOf(arrow.endNodeId)!,
      };
      expect(heads.length, greaterThan(1));

      String? closestA;
      String? closestB;
      var minDistance = double.infinity;
      for (final a in heads.entries) {
        for (final b in heads.entries) {
          if (a.key == b.key) continue;
          final d = (a.value - b.value).distance;
          if (d < minDistance) {
            minDistance = d;
            closestA = a.key;
            closestB = b.key;
          }
        }
      }
      expect(closestA, isNotNull);
      expect(closestB, isNotNull);

      // Tap 25% of the way from A's head toward B's head (nearer to A) —
      // just past the shared edge boundary on A's side, mirroring a real
      // tap that landed close to but not exactly on A's head.
      const hitTester = GraphBoardHitTester();
      final a = heads[closestA]!;
      final b = heads[closestB]!;
      final nearASideOfEdge = Offset.lerp(a, b, 0.25)!;

      final result = hitTester.findArrowAt(
        session: session,
        layout: layout,
        position: nearASideOfEdge,
      );

      expect(result, closestA);
    },
  );

  testWidgets('should_render_hex_board_for_a_hex_topology_level',
      (tester) async {
    final session = buildSession(hexDefinition());

    await tester.pumpWidget(
      _wrap(
        HexBoard(
          session: session,
          animate: false,
          onArrowActivated: (_) {},
        ),
      ),
    );

    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(find.byKey(GameUiKeys.resetViewButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp('Hex board with 7 nodes')),
      findsOneWidget,
    );
  });

  testWidgets('should_still_render_square_board_for_a_square_level',
      (tester) async {
    final session = buildSession(basicDefinition());

    await tester.pumpWidget(
      _wrap(
        GraphBoard(
          session: session,
          animate: false,
          onArrowActivated: (_) {},
        ),
      ),
    );

    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(session.level.boardGraph.topology, BoardTopology.square);
  });
}
