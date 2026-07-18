import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_ui_keys.dart';
import '../../domain/arrow_path.dart';
import '../../domain/game_session.dart';
import 'board_reset_view_button.dart';
import 'graph_board_hit_tester.dart';
import 'hex_board_layout.dart';
import 'hex_board_painter.dart';

/// Renders a hex-topology board. Mirrors [GraphBoard]'s structure, animation
/// controllers, and public surface exactly — only the layout/painter are
/// hex-specific. Game rules live in domain/application; this widget only
/// renders the already-resolved result.
class HexBoard extends StatefulWidget {
  const HexBoard({
    required this.session,
    required this.onArrowActivated,
    this.lastActivatedArrowId,
    this.flashingArrowId,
    this.animate = true,
    this.onInteractionActiveChanged,
    super.key,
  });

  final GameSession session;
  final ValueChanged<String> onArrowActivated;
  final String? lastActivatedArrowId;

  /// Arrow drawn in the collision-error colour for the flash duration.
  final String? flashingArrowId;

  /// When false (tests), no tickers/animations are started; the final resolved
  /// state is rendered immediately.
  final bool animate;

  /// Called with `true` while at least one finger is touching the board, and
  /// `false` once all of them lift. An ancestor scroll view should pause its
  /// own scrolling while this is `true`.
  final ValueChanged<bool>? onInteractionActiveChanged;

  @override
  State<HexBoard> createState() => _HexBoardState();
}

class _HexBoardState extends State<HexBoard> with TickerProviderStateMixin {
  AnimationController? _exitController;
  AnimationController? _shakeController;
  ArrowPath? _exitingArrow;
  Set<String> _activeIds = const {};
  String? _shakeArrowId;

  /// Pan/zoom transform for dense boards. Reset via the reset-view button.
  final TransformationController _viewController = TransformationController();

  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _activeIds = widget.session.activeArrows.map((a) => a.id).toSet();
    if (widget.animate) {
      _exitController =
          AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 700),
            )
            ..addListener(() => setState(() {}))
            ..addStatusListener((status) {
              if (status == AnimationStatus.completed) {
                setState(() => _exitingArrow = null);
              }
            });
      _shakeController =
          AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 300),
            )
            ..addListener(() => setState(() {}))
            ..addStatusListener((status) {
              if (status == AnimationStatus.completed) {
                setState(() => _shakeArrowId = null);
              }
            });
    }
  }

  @override
  void didUpdateWidget(covariant HexBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) {
      _activeIds = widget.session.activeArrows.map((a) => a.id).toSet();
      return;
    }

    final newActive = widget.session.activeArrows.map((a) => a.id).toSet();

    final escapedNow = _activeIds.difference(newActive);
    if (escapedNow.isNotEmpty) {
      final id = escapedNow.first;
      final arrow = widget.session.arrowById(id);
      if (arrow != null) {
        _exitingArrow = arrow;
        _exitController?.forward(from: 0);
      }
    }
    _activeIds = newActive;

    if (widget.flashingArrowId != null &&
        widget.flashingArrowId != oldWidget.flashingArrowId) {
      _shakeArrowId = widget.flashingArrowId;
      _shakeController?.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _exitController?.dispose();
    _shakeController?.dispose();
    _viewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeArrowCount = widget.session.activeArrows.length;

    return Semantics(
      label:
          'Hex board with ${widget.session.level.boardGraph.nodes.length} nodes and $activeArrowCount active arrows',
      child: AspectRatio(
        aspectRatio: HexBoardLayout.aspectRatioFor(
          widget.session.level.boardGraph,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final layout = HexBoardLayout.fromGraph(
              graph: widget.session.level.boardGraph,
              size: size,
            );

            final board = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final arrowId = const GraphBoardHitTester().findArrowAt(
                  session: widget.session,
                  layout: layout,
                  position: details.localPosition,
                );
                if (arrowId != null) {
                  widget.onArrowActivated(arrowId);
                }
              },
              child: CustomPaint(
                key: GameUiKeys.gameBoard,
                painter: HexBoardPainter(
                  session: widget.session,
                  lastActivatedArrowId: widget.lastActivatedArrowId,
                  flashingArrowId: widget.flashingArrowId,
                  exitingArrow: _exitingArrow,
                  exitProgress: _exitController?.value ?? 0,
                  shakeArrowId: _shakeArrowId,
                  shakeProgress: _shakeController?.value ?? 0,
                ),
              ),
            );

            return Listener(
              onPointerDown: (_) => _onPointerCountChanged(_activePointers + 1),
              onPointerUp: (_) => _onPointerCountChanged(_activePointers - 1),
              onPointerCancel: (_) =>
                  _onPointerCountChanged(_activePointers - 1),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _viewController,
                      minScale: 1.0,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(24),
                      child: board,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: BoardResetViewButton(
                      onPressed: _resetView,
                      icon: Icons.center_focus_strong,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _onPointerCountChanged(int newCount) {
    final wasActive = _activePointers > 0;
    _activePointers = math.max(0, newCount);
    final isActive = _activePointers > 0;
    if (isActive != wasActive) {
      widget.onInteractionActiveChanged?.call(isActive);
    }
  }

  void _resetView() {
    _viewController.value = Matrix4.identity();
  }
}
