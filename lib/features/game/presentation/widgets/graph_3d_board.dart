import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../game_ui_keys.dart';
import '../../domain/arrow_path.dart';
import '../../domain/game_session.dart';
import 'graph_3d_board_painter.dart';
import 'graph_3d_hit_tester.dart';
import 'graph_3d_projector.dart';

/// Interactive true-3D board for multi-layer levels.
///
/// - One-finger drag orbits the camera (yaw) and tilts it (pitch, clamped so
///   the scene never flips); pinch zooms. Tap activates an arrow through
///   [Graph3DHitTester] using the exact same projector the painter draws
///   with.
/// - The camera starts tilted so the level reads as 3D at first paint.
/// - Same external contract as [GraphBoard]: rules live in
///   domain/application; exit slide, collision shake, and flash are
///   presentation of already-resolved state. `onInteractionActiveChanged`
///   reports touch activity so the page scroll can lock while orbiting
///   (orbit drags must not scroll the page — see GraphBoard's doc comment).
class Graph3DBoard extends StatefulWidget {
  const Graph3DBoard({
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
  final String? flashingArrowId;

  /// When false (tests), no tickers/animations are started; resolved state
  /// renders immediately.
  final bool animate;

  final ValueChanged<bool>? onInteractionActiveChanged;

  @override
  State<Graph3DBoard> createState() => _Graph3DBoardState();
}

class _Graph3DBoardState extends State<Graph3DBoard>
    with TickerProviderStateMixin {
  static const double _initialYaw = 25 * math.pi / 180;
  static const double _initialPitch = 30 * math.pi / 180;
  static const double _maxPitch = 78 * math.pi / 180;

  double _yaw = _initialYaw;
  double _pitch = _initialPitch;
  double _zoom = 1.0;

  /// Zoom at the start of the current scale gesture (pinch is relative).
  double _zoomAtGestureStart = 1.0;

  AnimationController? _exitController;
  AnimationController? _shakeController;
  ArrowPath? _exitingArrow;
  Set<String> _activeIds = const {};
  String? _shakeArrowId;

  int _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _activeIds = widget.session.activeArrows.map((a) => a.id).toSet();
    if (widget.animate) {
      _exitController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )
        ..addListener(() => setState(() {}))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _exitingArrow = null);
          }
        });
      _shakeController = AnimationController(
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
  void didUpdateWidget(covariant Graph3DBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) {
      _activeIds = widget.session.activeArrows.map((a) => a.id).toSet();
      return;
    }

    final newActive = widget.session.activeArrows.map((a) => a.id).toSet();
    final escapedNow = _activeIds.difference(newActive);
    if (escapedNow.isNotEmpty) {
      final arrow = widget.session.arrowById(escapedNow.first);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layerCount = widget.session.level.boardGraph.layers.length;
    final activeArrowCount = widget.session.activeArrows.length;

    return Semantics(
      label:
          '3D graph board with $layerCount layers, ${widget.session.level.boardGraph.nodes.length} nodes and $activeArrowCount active arrows',
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            final board = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final projector = Graph3DProjector(
                  graph: widget.session.level.boardGraph,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                  size: size,
                );
                final arrowId = const Graph3DHitTester().findArrowAt(
                  session: widget.session,
                  projector: projector,
                  position: details.localPosition,
                );
                if (arrowId != null) {
                  widget.onArrowActivated(arrowId);
                }
              },
              onScaleStart: (_) => _zoomAtGestureStart = _zoom,
              onScaleUpdate: (details) {
                setState(() {
                  if (details.pointerCount >= 2) {
                    _zoom = (_zoomAtGestureStart * details.scale).clamp(0.5, 3.0);
                  }
                  _yaw += details.focalPointDelta.dx * 0.008;
                  _pitch = (_pitch + details.focalPointDelta.dy * 0.008)
                      .clamp(-_maxPitch, _maxPitch);
                });
              },
              child: CustomPaint(
                key: GameUiKeys.gameBoard,
                size: size,
                painter: Graph3DBoardPainter(
                  session: widget.session,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
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
                  Positioned.fill(child: board),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _ResetViewButton(onPressed: _resetView),
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
    setState(() {
      _yaw = _initialYaw;
      _pitch = _initialPitch;
      _zoom = 1.0;
    });
  }
}

class _ResetViewButton extends StatelessWidget {
  const _ResetViewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Tooltip(
      message: localizations.resetView,
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          key: GameUiKeys.resetViewButton,
          icon: const Icon(Icons.threed_rotation, size: 20),
          tooltip: localizations.resetView,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
