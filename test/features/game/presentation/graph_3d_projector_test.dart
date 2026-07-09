import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_coordinate.dart';
import 'package:frontend_poc_arrow/features/game/domain/board_graph.dart';
import 'package:frontend_poc_arrow/features/game/domain/graph_node.dart';
import 'package:frontend_poc_arrow/features/game/presentation/widgets/graph_3d_projector.dart';

void main() {
  // 2×2 nodes on each of two layers (z=0 near the camera at pitch 0's
  // convention, z=1 behind it).
  BoardGraph twoLayerGraph() {
    return BoardGraph(
      nodes: const [
        GraphNode(id: 'a0', coordinate: BoardCoordinate(x: 0, y: 0, z: 0)),
        GraphNode(id: 'b0', coordinate: BoardCoordinate(x: 1, y: 0, z: 0)),
        GraphNode(id: 'c0', coordinate: BoardCoordinate(x: 0, y: 1, z: 0)),
        GraphNode(id: 'a1', coordinate: BoardCoordinate(x: 0, y: 0, z: 1)),
        GraphNode(id: 'b1', coordinate: BoardCoordinate(x: 1, y: 0, z: 1)),
        GraphNode(id: 'c1', coordinate: BoardCoordinate(x: 0, y: 1, z: 1)),
      ],
      edges: const [],
    );
  }

  const size = Size(400, 400);

  test('should_match_flat_layout_when_camera_is_not_rotated', () {
    final projector = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 0,
      pitch: 0,
      zoom: 1,
      size: size,
    );

    final a0 = projector.pointFor('a0')!;
    final b0 = projector.pointFor('b0')!;
    final c0 = projector.pointFor('c0')!;
    final a1 = projector.pointFor('a1')!;

    // x/y ordering preserved exactly like the 2D board.
    expect(b0.screen.dx, greaterThan(a0.screen.dx));
    expect(b0.screen.dy, closeTo(a0.screen.dy, 0.001));
    expect(c0.screen.dy, greaterThan(a0.screen.dy));
    // Looking straight down the layer axis, the far layer's copy of the same
    // cell projects on the ray from the viewport center through the near
    // copy, pulled toward the center (perspective: farther = smaller). With
    // a pinhole camera the two only fully coincide on the optical axis.
    const center = Offset(200, 200);
    final nearOffset = a0.screen - center;
    final farOffset = a1.screen - center;
    expect(farOffset.distance, lessThan(nearOffset.distance));
    final cosine =
        (nearOffset.dx * farOffset.dx + nearOffset.dy * farOffset.dy) /
            (nearOffset.distance * farOffset.distance);
    expect(cosine, greaterThan(0.999), reason: 'same ray from center');
    // Depth distinguishes the layers.
    expect(a1.depth, greaterThan(a0.depth));
  });

  test('should_separate_layers_on_screen_when_camera_is_tilted', () {
    final projector = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 25 * math.pi / 180,
      pitch: 30 * math.pi / 180,
      zoom: 1,
      size: size,
    );

    final a0 = projector.pointFor('a0')!;
    final a1 = projector.pointFor('a1')!;

    expect(
      (a1.screen - a0.screen).distance,
      greaterThan(20),
      reason: 'tilted camera must visibly separate the layers',
    );
  });

  test('should_foreshorten_the_farther_layer', () {
    final projector = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 25 * math.pi / 180,
      pitch: 30 * math.pi / 180,
      zoom: 1,
      size: size,
    );

    final near = projector.pointFor('a0')!;
    final far = projector.pointFor('a1')!;
    expect(far.depth, greaterThan(near.depth));
    expect(
      far.pixelScale,
      lessThan(near.pixelScale),
      reason: 'perspective: farther geometry must render smaller',
    );
  });

  test('should_fit_all_nodes_inside_the_viewport', () {
    final projector = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 0.9,
      pitch: 1.1,
      zoom: 1,
      size: size,
    );

    for (final entry in projector.entries) {
      final p = entry.value.screen;
      expect(p.dx, inInclusiveRange(0, size.width));
      expect(p.dy, inInclusiveRange(0, size.height));
    }
  });

  test('should_project_layer_axis_direction_onto_screen_when_tilted', () {
    final projector = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 25 * math.pi / 180,
      pitch: 30 * math.pi / 180,
      zoom: 1,
      size: size,
    );

    // A step along +z (LayerDirection.below) must have a nonzero on-screen
    // direction under a tilted camera — this is what orients the arrowheads
    // of above/below arrows.
    final dir = projector.directionOnScreen('a0', dx: 0, dy: 0, dz: 1)!;
    expect(dir.distance, greaterThan(1));

    // And it points (approximately) from a0's screen position toward a1's.
    final a0 = projector.pointFor('a0')!;
    final a1 = projector.pointFor('a1')!;
    final actual = a1.screen - a0.screen;
    final cosine = (dir.dx * actual.dx + dir.dy * actual.dy) /
        (dir.distance * actual.distance);
    expect(cosine, greaterThan(0.99));
  });

  test('should_scale_screen_positions_with_zoom', () {
    final at1 = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 0.4,
      pitch: 0.5,
      zoom: 1,
      size: size,
    );
    final at2 = Graph3DProjector(
      graph: twoLayerGraph(),
      yaw: 0.4,
      pitch: 0.5,
      zoom: 2,
      size: size,
    );

    final spread1 =
        (at1.pointFor('b0')!.screen - at1.pointFor('a0')!.screen).distance;
    final spread2 =
        (at2.pointFor('b0')!.screen - at2.pointFor('a0')!.screen).distance;
    expect(spread2, closeTo(spread1 * 2, 0.01));
  });
}
