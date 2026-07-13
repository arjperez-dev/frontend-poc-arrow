# PHASE 28 — 3D Audit and Polish

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md` *(§16 — 3D-level model)*
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task (list below).
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

This phase is **audit-first**. Deliverable step 1 is a written findings report; no
rendering, animation, or level-geometry change may be made until the audit is reviewed and
the specific fixes are approved.

### Files to audit first

3D presentation (rotatable board):
- `lib/features/game/presentation/widgets/graph_3d_board.dart` — orbit/pitch/zoom gesture
  handling, exit-animation controller, reset-view button.
- `lib/features/game/presentation/widgets/graph_3d_board_painter.dart` — depth-sorted
  drawing, node/edge/arrow/arrowhead rendering, exit translation + fade.
- `lib/features/game/presentation/widgets/graph_3d_projector.dart` — single source of truth
  for 3D screen positions (painter draws through it; hit-tester tests through it).
- `lib/features/game/presentation/widgets/graph_3d_hit_tester.dart` — tap → arrow resolution.
- `lib/features/game/presentation/game_screen.dart` — the single `isMultiLayer` conditional
  that selects `Graph3DBoard` vs the flat `GraphBoard`.

3D level content:
- `assets/levels/manual_levels_3d.json` — levels 21–30 (authoritative; do not regenerate).
- `tool/gen_levels.js` — `Builder3D`, `build3DLevel21..30`, `hasRealInteriorGapExit3D`,
  the 3D branch of `validateAll` (for reference only — no regeneration this phase).

---

## Context (audited baseline — confirm, do not re-litigate)

- 3D levels are internal numbers **21–30**, displayed as 3D **1–10** via the presentation
  offset in `level_mode_filter.dart` (`internal − 20`). The offset is out of scope.
- Multi-layer levels render through `Graph3DBoard`. One-finger drag orbits (yaw) and tilts
  (pitch, clamped so the scene never flips); pinch zooms; the reset-view button restores the
  initial camera. Tap activates an arrow through `Graph3DHitTester`.
- The 3D **exit animation** currently translates the whole arrow shape as a rigid piece along
  the exit direction (`unit * size.longestSide * 1.1 * exitProgress`) while fading — it does
  **not** path-follow the way the 2D board does ("train on tracks", Phase 13). Bent 3D arrows
  do not round their own corners on exit.
- Arrows render as depth-sorted polylines plus an arrowhead glyph; z-edges/vertical arrows
  are slanted lines between layers (no special glyphs). All world-unit sizes scale through
  the projector.
- `MovementResolver` is dimension-agnostic (coordinate sweep) and is **not** in scope for
  this phase — this is a visual/interaction audit, not a physics change.

---

## Task

### Task A — 3D level audit (levels 21–30)

Perform a comprehensive audit of all ten 3D levels and produce **actionable, per-level
findings** (a written report saved under `harness/` or `docs/`, plus a summary in the
handoff). For each level, evaluate and record concrete findings on:

1. **Arrow exit animations** — does the exit read correctly in 3D for straight AND bent
   arrows? Note where the current rigid-translate-and-fade looks wrong (e.g. bent arrows not
   following their own path, arrows sliding through the board interior, fade timing,
   arrowhead position during exit, depth-sort artifacts mid-exit).
2. **Arrow visual representation on the 3D board** — legibility of head vs. tail, vertical
   (z-spanning) arrows vs. planar arrows, arrowhead orientation under orbit, occlusion and
   depth cues, stroke/size scaling at zoom extremes, color/opacity of active vs.
   escaped/inactive arrows.
3. **Board level design** — does each figure read as intended under orbit (21 baseline …
   30 hollow pyramid)? Note ambiguous silhouettes, layers that are hard to distinguish,
   arrow density/placement that obscures the shape, and any spatial-reasoning traps.

Each finding must name the level, the symptom, and a proposed fix (concrete enough to
implement). Rank findings by severity.

### Task B — 3D visualization & interaction evaluation

Evaluate the current 3D board visualization and interaction model as a whole, and produce
actionable findings to make the three-dimensional perspective more **intuitive, comfortable
to navigate, and easier to spatially reason about** during gameplay. Cover at least:

- Camera defaults (initial yaw/pitch/zoom) and whether they present the figures well.
- Orbit/tilt/zoom feel: sensitivity, clamps, and whether pitch/zoom limits are comfortable.
- Depth perception aids: layer separation, grounding cues (floor/shadow/axis), edge shading,
  fog/opacity by depth, highlighting the active layer or the tapped arrow.
- Discoverability of the controls (that the board is rotatable; reset-view affordance).
- Legibility of which arrows can currently exit vs. which are blocked, in a rotated scene.

### Task C — Polish implementation (only after audit approval)

Implement the **approved** subset of Task A/B findings. Likely candidates (subject to
approval):

- Bring the 3D exit animation closer to the 2D path-following model for bent arrows, OR a
  deliberate simpler 3D-appropriate exit — decided from the audit.
- Depth/legibility improvements in `graph_3d_board_painter.dart` (all screen positions must
  still flow through `Graph3DProjector` — never compute a 3D position by another path, or
  taps will disagree with pixels).
- Camera-default / interaction-comfort tuning in `graph_3d_board.dart`.
- Any level-content fix that requires editing `manual_levels_3d.json` must be treated as an
  intentional, reviewed edit — hand-edit or a scoped regenerate, then `--validate-only` must
  pass. Preserve internal numbers 21–30 and the no-single-node-arrow / real-gap invariants.

Keep every change presentation-scoped unless a level-content finding is explicitly approved
for a data edit. Do not touch `MovementResolver`, `Graph3DProjector`'s projection contract,
`level_mode_filter.dart`, or the 2D board stack.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code. If a finding requires a backend
  change, **STOP and report** before touching it.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes. Do not commit or push automatically.
- Domain layer stays pure Dart (no Flutter/HTTP/storage imports). Screens/controllers must
  not call `http.Client` or `SharedPreferences` directly.
- Graph-based runtime only — no grid/matrix/tile logic.
- `manual_levels_2d.json` and `manual_levels_3d.json` are authoritative. Do NOT run
  `--generate` / `--generate-3d` unless a level-content fix was explicitly approved.
  `--validate-only` is always safe.
- Do not change the 3D display offset in `level_mode_filter.dart`.
- Do not modify the 2D board (`GraphBoard`) for 3D concerns — the selection point is the
  single conditional in `game_screen.dart`.
- Preserve the `Graph3DProjector` single-source-of-truth rule: painter and hit-tester must
  share the same instance/parameters.

---

## Validation

Run these after any implementation. All must pass.

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only   # only if 3D level files were touched
```

Also verify manually on device/emulator (3D mode):
- Orbit, tilt, and pinch-zoom each 3D level 21–30; each figure reads under rotation.
- Trigger an exit on a straight AND a bent 3D arrow; confirm the animation reads correctly
  and the arrowhead/depth-sort behave through the whole exit.
- Reset-view restores the intended camera; the board is discoverably rotatable.
- Backend directory shows no diff.

---

## After Completion

1. Deliver the audit findings report (Task A/B) and record all changes made, files touched,
   and architectural decisions.
2. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
3. Update `harness/context/phase_registry.md`.
4. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
