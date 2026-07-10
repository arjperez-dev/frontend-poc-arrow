import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';
import 'package:frontend_poc_arrow/features/game/domain/direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/game_session.dart';
import 'package:frontend_poc_arrow/features/game/domain/layer_direction.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition.dart';
import 'package:frontend_poc_arrow/features/game/domain/level_definition_validator.dart';
import 'package:frontend_poc_arrow/features/game/presentation/game_ui_keys.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_3d_board.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_3d_projector.dart';

void main() {
  // Two-layer board: one planar arrow per layer plus a vertical arrow
  // spanning the layers, spread far apart so hit-testing is unambiguous.
  GameSession buildTwoLayerSession() {
    const definition = LevelDefinition(
      id: '3d-widget-test',
      name: '3D Widget Test',
      nodes: [
        GraphNodeDefinition(id: 'a', x: 0, y: 0, z: 0),
        GraphNodeDefinition(id: 'b', x: 1, y: 0, z: 0),
        GraphNodeDefinition(id: 'v0', x: 0, y: 3, z: 0),
        GraphNodeDefinition(id: 'v1', x: 0, y: 3, z: 1),
        GraphNodeDefinition(id: 'c', x: 0, y: 0, z: 1),
        GraphNodeDefinition(id: 'd', x: 1, y: 0, z: 1),
      ],
      edges: [
        GraphEdgeDefinition(id: 'a-b', fromNodeId: 'a', toNodeId: 'b'),
        GraphEdgeDefinition(id: 'c-d', fromNodeId: 'c', toNodeId: 'd'),
        GraphEdgeDefinition(id: 'v0-v1', fromNodeId: 'v0', toNodeId: 'v1'),
      ],
      arrows: [
        ArrowPathDefinition(
          id: 'top',
          occupiedEdgeIds: ['a-b'],
          startNodeId: 'a',
          endNodeId: 'b',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'bottom',
          occupiedEdgeIds: ['c-d'],
          startNodeId: 'c',
          endNodeId: 'd',
          direction: Direction.right,
        ),
        ArrowPathDefinition(
          id: 'vertical',
          occupiedEdgeIds: ['v0-v1'],
          startNodeId: 'v0',
          endNodeId: 'v1',
          direction: LayerDirection.below,
        ),
      ],
      blockedEdgeIds: [],
      metadata: {'difficulty': 'test'},
    );
    return GameSession.start(const LevelDefinitionValidator().validate(definition));
  }

  Widget wrap(Widget child) {
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

  testWidgets('should_render_multi_layer_session_without_errors',
      (tester) async {
    final session = buildTwoLayerSession();
    await tester.pumpWidget(
      wrap(
        Graph3DBoard(
          session: session,
          animate: false,
          onArrowActivated: (_) {},
        ),
      ),
    );

    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(find.byKey(GameUiKeys.resetViewButton), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('3D graph board with 2 layers')),
      findsOneWidget,
    );
  });

  testWidgets('should_activate_arrow_when_projected_head_is_tapped',
      (tester) async {
    final session = buildTwoLayerSession();
    final activated = <String>[];
    await tester.pumpWidget(
      wrap(
        Graph3DBoard(
          session: session,
          animate: false,
          onArrowActivated: activated.add,
        ),
      ),
    );

    // Recompute the widget's initial camera projection to find the screen
    // position of the top arrow's head (same constants as Graph3DBoard).
    final boardSize = tester.getSize(find.byKey(GameUiKeys.gameBoard));
    final projector = Graph3DProjector(
      graph: session.level.boardGraph,
      yaw: 25 * math.pi / 180,
      pitch: 30 * math.pi / 180,
      zoom: 1,
      size: boardSize,
    );
    final headScreen = projector.pointFor('b')!.screen;
    final boardTopLeft = tester.getTopLeft(find.byKey(GameUiKeys.gameBoard));

    await tester.tapAt(boardTopLeft + headScreen);
    await tester.pump();

    expect(activated, ['top']);
  });

  testWidgets('should_orbit_on_drag_and_restore_on_reset_view',
      (tester) async {
    final session = buildTwoLayerSession();
    await tester.pumpWidget(
      wrap(
        Graph3DBoard(
          session: session,
          animate: false,
          onArrowActivated: (_) {},
        ),
      ),
    );

    // Orbit: a one-finger drag must not throw and must keep the board alive.
    await tester.drag(find.byKey(GameUiKeys.gameBoard), const Offset(60, -40));
    await tester.pump();
    expect(find.byKey(GameUiKeys.gameBoard), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reset view restores the initial camera without errors.
    await tester.tap(find.byKey(GameUiKeys.resetViewButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
