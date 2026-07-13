# PHASE 28.1 — 3D Level Complexity Redesign (Hard Mode)

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

This is a **level-content regeneration** phase: it edits the 3D builders in
`tool/gen_levels.js` and regenerates `assets/levels/manual_levels_3d.json` via
`--generate-3d`. It builds directly on Phase 28's rendering improvements, which must not be
degraded by denser geometry. Before touching the builders, ASCII-render every current 3D
layer from the on-disk JSON so you have a per-level baseline of what each figure looks like.

### Files to audit first

3D level content (primary scope):
- `tool/gen_levels.js` — `Builder3D` (`colArrow`, `zColArrow`, `pathArrow`, `weaveLayers`),
  `build3DLevel21..30`, `build3DLevels()`, `hasRealInteriorGapExit3D`, the 3D branch of
  `validateAll`, and the `--generate-3d` CLI mode.
- `assets/levels/manual_levels_3d.json` — levels 21–30 (regeneration target).
- `test/features/game/infrastructure/manual_levels_test.dart` — the 3D group assertions
  (21–30, `hasLength(10)`, no-single-node, no-shared, greedy-solvable, no-real-gap).

3D presentation (must not be degraded — read to understand what dense geometry could break):
- `lib/features/game/presentation/widgets/graph_3d_board_painter.dart` — path-following exit,
  depth-sorted drawables, per-segment depth shading, arrowhead disc fallback, layer floor
  plates (Phase 28).
- `lib/features/game/presentation/widgets/graph_3d_projector.dart` — single source of truth
  for 3D screen positions.
- `lib/features/game/presentation/widgets/graph_3d_board.dart` — orbit/pitch/zoom, aspect
  from level footprint, selection ring, rotate hint.

---

## Context (audited baseline — confirm, do not re-litigate)

- 3D levels are internal numbers **21–30**, displayed as 3D **1–10** (`internal − 20`,
  `level_mode_filter.dart`). The display offset is out of scope.
- All 10 are currently: hard tier, `generationType: '3d'`, multi-layer, comp=1, no free
  nodes, no shared nodes/edges, no single-node arrows, greedy-solvable, no real interior-gap
  exits, vertical arrows spanning ≥1 z-edge. Arrow counts today are ~20–42, layer counts 2–8.
- Current figures: 21 baseline, 22 (P22.1), 23 pyramid, 24 diamond, 25 hourglass, 26 cross,
  27 starburst, 28 cat, 29 helix, 30 hollow pyramid. Phase 25 noted 26–30 "average fewer
  arrows than a dense 2D hard level by design" — this phase deliberately raises that.
- Phase 28 made the 3D board render well (path-following exit, depth sort, per-node opacity,
  arrowhead fallbacks, floor plates, camera aspect from footprint). Denser geometry must stay
  legible under that renderer — this is a redesign, not a rendering change.
- `MovementResolver` is dimension-agnostic and **not** in scope. Solvability is the
  established greedy-exit model.

---

## Task

### Task A — Redesign all 10 3D levels (21–30) as "hard mode"

Rework the `build3DLevel21..30` builders in `tool/gen_levels.js` so every 3D level is
significantly more complex and challenging than today, while still reading as its recognizable
figure/structure. Increase, per level:

1. **Arrow-shape variety** — more bent arrows, zigzags, multi-segment paths, and free-form
   paths that step across layers (use/extend `pathArrow`), not just straight `colArrow`/
   `zColArrow` spans.
2. **Board complexity** — more nodes, more arrows, denser inter-layer connectivity, and
   less-obvious escape sequences. Raise arrow counts meaningfully above the current 20–42
   band (propose target bands per tier in the audit; every level stays hard tier).
3. **Dependency depth** — arrows blocked by multiple other arrows across different layers, so
   solving requires real multi-step planning rather than a near-one-tap-per-arrow order.
   Keep it greedy-solvable (a valid exit order must always exist), but make that order deep.

### Task B — Preserve visual clarity (do not degrade Phase 28)

Every level must still read as its figure under the orbit camera, and the Phase 28 rendering
gains must survive the added density:

- Each figure's silhouette must stay recognizable — verify by ASCII-rendering every layer of
  every regenerated level before handover (the step whose absence caused the Phase 25
  first-pass rejection).
- Do not pack arrows so densely that path-following exit, depth sorting, per-segment/per-node
  opacity, arrowhead fallbacks, floor plates, or camera framing become unreadable. If a
  denser level fights the renderer, reduce density or respace — do **not** change the painter
  or projector to compensate.

### Task C — Maintain all architectural invariants

Every regenerated level must still satisfy, and the JS + Dart validators must still enforce:

- Graph-based runtime only — no grid/matrix/tile logic.
- Greedy-solvable; no single-node arrows; no shared nodes/edges between arrows; no free nodes
  at start; no self-intersecting arrows; no real interior-gap exits.
- Spanning vertical arrows only (each vertical arrow crosses ≥1 z-edge); multi-layer for
  every level; all 10 levels hard tier; comp=1.

### Task D — Regenerate the 3D asset

Regenerate `assets/levels/manual_levels_3d.json` via the updated
`node tool/gen_levels.js --generate-3d`. Leave `assets/levels/manual_levels_2d.json`
untouched (do NOT run `--generate-2d` or `--generate`). If the 3D group test literals in
`manual_levels_test.dart` assert specific arrow counts that change, update those assertions
to match (keep `hasLength(10)` and the internal 21–30 range).

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code. If a finding requires a backend
  change, **STOP and report** before touching it.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes. Do not commit or push automatically — manual audit required.
- Domain layer stays pure Dart (no Flutter/HTTP/storage imports). Screens/controllers must
  not call `http.Client` or `SharedPreferences` directly.
- Graph-based runtime only — no grid/matrix/tile logic.
- `manual_levels_2d.json` and `manual_levels_3d.json` are authoritative. Only `--generate-3d`
  is in scope; do NOT run `--generate-2d` or `--generate`. `--validate-only` is always safe.
- Do not degrade the Phase 28 rendering: no changes to `graph_3d_board_painter.dart`,
  `graph_3d_projector.dart`, or `graph_3d_board.dart` to accommodate density — respace the
  geometry instead.
- Preserve the `Graph3DProjector` single-source-of-truth rule.
- Do not change the 3D display offset in `level_mode_filter.dart`, and do not touch the 2D
  board stack for 3D concerns.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze
flutter test
node tool/gen_levels.js --generate-3d      # regenerate 21–30 (this phase intends it)
node tool/gen_levels.js --validate-only    # both sets ALL VALID, exit 0
```

Also confirm before handover:
- Per-layer ASCII silhouette render of all 10 regenerated levels — each figure still reads.
- `manual_levels_2d.json` is byte-identical to HEAD (untouched).
- Manual on device/emulator (3D mode): orbit/tilt/pinch-zoom each level 21–30; the figure
  reads under rotation; exit on a straight AND a bent arrow reads correctly through the whole
  animation; the deeper dependency chains are solvable by planning.

---

## After Completion

1. Report all changes made, files touched, and architectural decisions (per-level: new arrow
   count, layer count, shape-variety and dependency-depth summary).
2. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
3. Update `harness/context/phase_registry.md`.
4. Update `harness/metrics/improvement_log.md`.
5. Do NOT commit or push.

---

Do not be verbose. Be direct.
