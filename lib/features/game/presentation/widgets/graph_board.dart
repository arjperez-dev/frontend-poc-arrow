import 'package:flutter/material.dart';

import '../game_ui_keys.dart';
import '../../domain/game_session.dart';
import 'graph_board_hit_tester.dart';
import 'graph_board_layout.dart';
import 'graph_board_painter.dart';

class GraphBoard extends StatelessWidget {
  const GraphBoard({
    required this.session,
    required this.onArrowActivated,
    this.lastActivatedArrowId,
    super.key,
  });

  final GameSession session;
  final ValueChanged<String> onArrowActivated;
  final String? lastActivatedArrowId;

  @override
  Widget build(BuildContext context) {
    final activeArrowCount = session.activeArrows.length;

    return Semantics(
      label:
          'Graph board with ${session.level.boardGraph.nodes.length} nodes and $activeArrowCount active arrows',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final layout = GraphBoardLayout.fromGraph(
              graph: session.level.boardGraph,
              size: size,
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final arrowId = const GraphBoardHitTester().findArrowAt(
                  session: session,
                  layout: layout,
                  position: details.localPosition,
                );
                if (arrowId != null) {
                  onArrowActivated(arrowId);
                }
              },
              child: CustomPaint(
                key: GameUiKeys.gameBoard,
                painter: GraphBoardPainter(
                  session: session,
                  lastActivatedArrowId: lastActivatedArrowId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
