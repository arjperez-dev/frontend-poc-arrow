# PHASE 37.3 — Hexagonal Boards: Rendering & Hit-Testing

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/harness/phases/phase_37_audit_findings.md` **(§1.4–1.5 — the painter and hit-tester are already position-driven; this phase is mostly a layout change, not a painter rewrite)**

**Depends on:** 37.1 and 37.2 (merged). Real hex levels must exist to render.
**Blocks:** 37.4.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit `graph_board_layout.dart`, `graph_board_painter.dart`, `graph_board.dart`, `graph_board_hit_tester.dart`, `board_geometry.dart`, `arrow_head.dart`, `board_style.dart`, and how `Graph3DBoard` was added alongside `GraphBoard` in Phase 27 (the precedent for a parallel board widget).
2. Explain your understanding of the current state — specifically, confirm that the painter never reads `BoardCoordinate` directly and works purely off `layout.positionOf(nodeId)`.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Task

Render hex levels with visible hexagonal cells, and make taps land correctly.

### 1. `lib/features/game/presentation/widgets/hex_board_layout.dart` (new)

Axial → pixel, pointy-top:

```
px = hexSize * √3 * (q + r / 2)
py = hexSize * 1.5 * r
```

Same public shape as `GraphBoardLayout`: `positionsByNodeId`, a `step`
equivalent for stroke/arrowhead scaling, `positionOf(nodeId)`, and a
`fromGraph({graph, size, padding})` factory that fits the board to the
available size and centres it.

`step` should be the **centre-to-centre distance between adjacent hexes**
(`hexSize * √3`), not `hexSize` — downstream code (stroke width, arrowhead
size, hit slop) all treats `step` as neighbour spacing, and passing `hexSize`
would silently make everything ~15% too small.

Fitting must use the true pixel bounding box of the hex silhouette (compute
min/max of the mapped pixel positions), **not** the axial coordinate extents —
axial extents are skewed and would misfit the board.

Also expose `hexVertices(Offset centre)` returning the 6 corner offsets, for
the painter.

### 2. `lib/features/game/presentation/widgets/hex_board_painter.dart` (new)

Modelled on `GraphBoardPainter`. Reuse, do not duplicate: `ArrowHead`,
`BoardStyle`, `AppTheme`, the arrow polyline logic, the exit path-following
sampling, and the collision shake. Extract shared helpers into a common file
rather than copy-pasting the 349-line painter — if extraction proves invasive,
report it and propose the smaller alternative rather than silently duplicating.

New drawing work, and the only genuinely new part:

- Per node, stroke a hexagon outline at the node's centre (`hexVertices`), so
  the board visually reads as a hexagonal tiling. Keep it subtle — consistent
  with the existing convention where covered nodes stay near-invisible and only
  light up once the arrow covering them escapes.
- Edges remain straight lines between hex centres (already correct for hex).
- Arrowheads rotate to the six hex angles. `ArrowHead` takes an angle, so this
  is a direction→angle mapping addition, not a rewrite: east 0°, southEast 60°,
  southWest 120°, west 180°, northWest 240°, northEast 300° (screen-space,
  y-down).

### 3. `lib/features/game/presentation/widgets/hex_board.dart` (new)

Mirror `GraphBoard`: `InteractiveViewer` pan/zoom, reset-view button
(`GameUiKeys.resetViewButton`), tap `GestureDetector` inside the transformed
child, exit/shake animation controllers, `animate` flag defaulting true (tests
pass false), `onInteractionActiveChanged`. Same public constructor surface as
`GraphBoard` so `GameScreen` can swap between them cleanly.

### 4. `lib/features/game/presentation/widgets/graph_board_hit_tester.dart`

The existing metric tester works unchanged — it picks arrows by distance, with
no cell-shape assumption. Only retune: the `cellSize * 0.45` cap is calibrated
for square spacing. For pointy-top hexes, adjacent centres are `hexSize * √3`
apart horizontally but the inradius is smaller; verify the 0.45 factor still
keeps taps unambiguous at the densest shipped hex level and adjust if not.
Document any change with the measured spacing, as the existing `minHitSlop`
doc comment does.

### 5. `lib/features/game/presentation/game_screen.dart`

Select `HexBoard` when the level's `boardGraph.topology == BoardTopology.hex`,
alongside the existing `GraphBoard`/`Graph3DBoard` choice. Presentation-only;
do not change the controller.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes. Do not commit or push automatically.
- Feature branch only. Never `main`.
- **Presentation-only.** No changes to `domain/` or `application/`. Rules never live in presentation — this phase renders already-resolved state, exactly as `GraphBoard` does.
- Do not touch any level asset file.
- `GraphBoard`, `GraphBoardPainter`, `GraphBoardLayout`, and `Graph3DBoard` must remain behaviourally unchanged for square/3D levels. Shared-helper extraction is allowed; behaviour change is not.

---

## Validation

```bash
flutter analyze
flutter test
```

### New tests required

`test/features/game/presentation/hex_board_test.dart`:

- `should_map_axial_origin_and_neighbours_to_expected_pixel_offsets`
- `should_fit_board_within_available_size_using_pixel_bounding_box`
- `should_activate_arrow_when_tapping_its_head_on_a_hex_board`
- `should_not_activate_a_neighbouring_arrow_when_tapping_near_a_shared_edge`
- `should_render_hex_board_for_a_hex_topology_level` (widget test, `animate: false`)
- `should_still_render_square_board_for_a_square_level` (regression)

Reuse the `hexDefinition()` fixture from 37.1 plus a real shipped hex level
from 37.2 for the density-sensitive tap test.

---

## Definition of Done

- Hex levels render as a visible hexagonal tiling with correct edges, arrow
  polylines, and 6-way arrowheads.
- Taps select the intended arrow at the densest shipped hex level.
- Exit and collision animations behave as they do on square boards.
- No visual or behavioural regression on 2D/3D boards.

---

## Known Limitation To Expect

Visual correctness of hexagon outlines, arrowhead angles, exit path-following,
and tap feel **cannot be fully verified by the automated suite** — this matches
every prior rendering phase in this project (13, 27, 28). Automated tests pin
geometry and hit-testing; the visual read requires an on-device pass. State
this plainly in the handoff rather than implying visual verification happened.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report whether shared painter helpers were extracted or duplicated, and why.

---

Do not be verbose. Be direct.
