# Phase 28 — 3D Audit Findings (Task A / Task B)

Audit-first deliverable. Findings on levels 21–30 and the 3D board
visualization/interaction model. All findings are presentation-fixable; **no
level-content (JSON) defect requiring a data edit was found** — the change stays
presentation-scoped and `manual_levels_3d.json` is untouched.

## Audited baseline (confirmed)

- Selection: single `if (level.boardGraph.isMultiLayer)` in `game_screen.dart`
  (~L301); both boards were passed `lastActivatedArrowId: null`.
- `Graph3DProjector` is the shared source of truth (rotate → perspective →
  fit-to-viewport → per-point `pixelScale`; `layerSpacing = 2.2`). Painter and
  hit-tester consume the same yaw/pitch/zoom/size. Contract unchanged this phase.
- Painter uses painter's-algorithm depth sort for edges/nodes/active arrows plus
  a depth-dimming `fade()` (≤45% toward background). Only `session.activeArrows`
  are drawn; escaped arrows vanish after the exit animation.
- Board: initial yaw 25° / pitch 30° / zoom 1; pitch clamp ±78°; zoom 0.5–3.
  Exit controller 700 ms, shake 300 ms.
- Levels (from JSON): 21 (2-layer 40n/20a), 22 (3-layer), 23 pyramid (4-layer
  120n/42a), 24 diamond (5-layer), 25 hourglass (5-layer), 26 cross (5-layer),
  27 star (7-layer), 28 cat (**2-layer 107n/43a — dense**), 29 helix (**10-layer
  80n/22a — tall**), 30 hollow pyramid (4-layer).

## Task A findings

### Exit animation
- **A1 [High]** Exit is a rigid translate-and-fade
  (`unit * size.longestSide * 1.1 * exitProgress`); bent 3D arrows (23, 27, 29,
  30) do not path-follow like the 2D board's arc-length model. → Adopt
  arc-length path following.
- **A2 [High]** Exit slide is drawn unconditionally on top, after the depth-sort
  loop; an arrow leaving away from the camera renders in front of nearer
  geometry (mid-exit depth-sort artifact). → Depth-sort the exit drawable.
- **A3 [Med]** Slide distance is a constant screen distance independent of
  `pixelScale`/zoom; looks tiny at zoom 3, flies off-frame at zoom 0.5. → Scale
  by head `pixelScale`.
- **A4 [Low]** Only `escapedNow.first` animates when several arrows free at once.
  Rare in single-tap play. Not scheduled.

### Arrow representation
- **A5 [High]** Vertical (`above`/`below`) arrows lose their arrowhead when the
  projected z-axis is near-degenerate (`directionOnScreen` length ≈ 0), so
  z-arrows read as headless dots when viewed near the layer axis. → Fallback
  head glyph.
- **A6 [Med]** Arrow opacity comes from head depth only; a layer-spanning arrow's
  far tail is drawn at head brightness (no intra-arrow depth cue). → Per-node
  opacity.
- **A7 [Med]** No highlight of the tapped arrow — `lastActivatedArrowId` is
  hard-wired `null`, so the painter's emphasized stroke is dead code. → Wire it
  through.

### Board design
- **A8 [High]** Level 28 (cat): 43 arrows / 2 layers → front layer occludes back
  under most orbit angles; fixed square aspect wastes space for a flat/wide
  figure.
- **A9 [Med]** Level 29 (helix): 10 layers × 2.2 spacing is very tall; default
  pitch/zoom under-present the twist at first paint.
- **A10 [Low]** Level 27 (star): spike arrowheads overlap near the core under
  orbit. Partly mitigated by A5/A6. Not separately scheduled.

## Task B findings
- **B1 [High]** No grounding cues (no floor/layer tint, no active-layer
  highlight); depth is conveyed only by dimming — weak across 4–10 layers.
- **B2 [Med]** Camera defaults and fixed `aspectRatio: 1.0` are identical for
  every level despite very different shapes.
- **B3 [Med]** No discoverability that the board rotates (reset icon exists, no
  first-use hint).
- **B4 [Low]** Orbit sensitivity/pitch clamp acceptable; zoom is board-centered
  not focal-point-centered. Not scheduled.

## Approved Task C scope
All four groups approved:
1. Exit animation: **A1 + A2 + A3**
2. Arrow legibility: **A5 + A6 + A7**
3. Depth/comfort: **B1 + B3**
4. Camera/aspect: **A8 + A9 + B2**

Kept presentation-scoped; no JSON, no `MovementResolver`, no projector
projection-contract, no `level_mode_filter.dart`, no 2D board changes.
