# Codex Handoff

## Current Repository

- Repository: `frontend-poc-arrow`
- Branch: `feat/frontend-backend-integration`
- Do not modify Git remotes automatically.
- Do not modify `backend-poc-arrow` unless a blocking API contract issue is found and reported first.

## Completed Phase

- Phase 8: Frontend Backend Integration.

Previous completed and merged phases:

- Phase 3 Flutter Bootstrap.
- Phase 4 Graph-Based Game Engine Domain.
- Phase 5 Manual Graph-Based Levels.
- Phase 6 Playable Game UI with Local Manual Levels.
- Phase 7 Local Progress, Level Unlocking, Settings, Audio Foundation, and UX Polish.

## Implemented Phase 8 State

- Added `http` as the only new dependency.
- Added `core/network` with `ApiClient`, `HttpApiClient`, and `ApiException`.
- Production HTTP uses injectable `http.Client`; no top-level `http.get`/`http.post` calls are used.
- Added optional auth:
  - Login/register use cases.
  - Auth API repository.
  - SharedPreferences token/session storage adapter.
  - Simple auth screen.
  - Settings login/logout status and actions.
- Added progress sync:
  - Remote progress repository.
  - Backend level-id mapping through `GET /levels`.
  - Merge policy that preserves better local progress.
  - Manual sync action in settings.
- Added leaderboard integration:
  - Fetch leaderboard for a backend level id.
  - Submit score after victory only when authenticated.
  - Leaderboard route opened from victory UI.
- Victory still saves local progress immediately and exactly once.
- Remote sync/leaderboard submission is best-effort and non-blocking.

## Architecture Decisions

- Local manual levels remain the default playable source.
- Remote levels are used only for backend `levelId` mapping and future compatibility.
- Auth is optional; logged-out users can play all local unlocked content.
- `SharedPreferences` token storage is allowed for Phase 8 academic/demo scope only.
- Production hardening should replace token storage with secure storage.
- HTTP access lives in `core/network` and infrastructure repositories.
- SharedPreferences access remains in infrastructure adapters.
- Screens/controllers do not directly call `http.Client` static helpers or `SharedPreferences`.
- Movement still goes through `GameSessionService`, `MoveArrowUseCase`, and `MovementResolver`.
- Gameplay remains graph-based; no matrix/grid-cell/tile runtime model was introduced.

## Progress Merge Policy

- Local progress remains the offline source of truth.
- Completed is true if either local or remote is completed.
- Best result policy:
  - Higher score is better.
  - If tied, fewer moves is better.
  - If tied, lower `timeSeconds` is better.
- Better local progress is never deleted because remote data is stale.
- If remote sync fails, local progress stays unchanged and usable.

## Leaderboard Behavior

- `POST /leaderboard` is attempted after victory only when authenticated and the backend level id can be resolved.
- `GET /leaderboard/:levelId` is used by the leaderboard screen.
- Leaderboard failures do not block victory, retry, next level, or back navigation.

## Local Fallback Behavior

- Backend unavailable: local level selection, gameplay, progress, unlocking, settings, and victory continue working.
- Auth unavailable: user can stay logged out and play locally.
- Remote level mapping unavailable: sync/leaderboard is skipped or reports unavailable, but local gameplay remains intact.

## Files Future Sessions Should Inspect First

- `lib/core/network/`
- `lib/features/auth/`
- `lib/features/progress/application/sync_progress_use_case.dart`
- `lib/features/progress/application/merge_progress_use_case.dart`
- `lib/features/progress/infrastructure/api_remote_level_repository.dart`
- `lib/features/progress/infrastructure/api_remote_progress_repository.dart`
- `lib/features/leaderboard/`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/game/presentation/game_screen_controller.dart`
- `test/core/network/http_api_client_test.dart`
- `test/features/auth/auth_integration_test.dart`
- `test/features/progress/progress_sync_test.dart`
- `test/features/leaderboard/leaderboard_submission_test.dart`
- `test/features/game/presentation/playable_game_ui_test.dart`

## Tests Added

- `should_login_user_when_credentials_are_valid`
- `should_store_token_when_login_succeeds`
- `should_attach_bearer_token_when_authenticated`
- `should_keep_local_progress_when_remote_progress_is_stale`
- `should_merge_remote_progress_when_remote_is_better`
- `should_submit_leaderboard_when_level_is_completed_and_user_is_authenticated`
- `should_skip_leaderboard_submission_when_user_is_not_authenticated`
- `should_keep_gameplay_available_when_backend_is_unreachable`
- Settings controller tests for logged-in/logout and sync failure behavior.

## Verification Results

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed with 51 tests.
- `docker compose up --build` from `backend-poc-arrow`: backend built and started successfully.
- `GET http://localhost:3000/health`: returned `status = ok`.
- `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000`: debug app built, installed, and launched on Android emulator.
- Manual in-app register/login/complete-level interaction was not performed in this pass.
- Docker containers were stopped with `docker compose down` after the launch check.
- Backend repository remained untouched.
- Git remotes were not modified.

## Phase 9 — Gameplay Rules Fixes, Lives System, Level Redesign, Stability

Phase 9 corrected the core gameplay model, added a lives/game-over system, redesigned all 15 manual levels, added exit/collision animations, and fixed level-selection refresh. All work is inside `frontend-poc-arrow`; backend and Git remotes were untouched.

### Full Exit Attempt Rule

- Tapping an arrow performs a single, atomic **full exit attempt** — not one-step movement.
- The arrow head defines the exit direction; the arrow travels strictly in its head direction (it never auto-turns). If there is no neighbor in that direction, that part of the arrow leaves the board.
- The attempt either fully escapes or leaves the arrow exactly as it was. No partial movement is ever committed.

### Full-Arrow Collision Behavior

- Collision detection considers the arrow's **entire occupied shape**, not just the head.
- `MovementResolver.resolve` computes the moving arrow's full covered-node set (`coveredNodeIds`: start node, head node, and both endpoints of every occupied edge), and the union of covered nodes of all other active arrows.
- It sweeps a forward ray (graph adjacency) from **every** covered node. If any forward node is occupied by another active arrow, or any traversed edge is blocked, the attempt is a `collision`. Otherwise it is `escaped`.
- This means a body/segment overlap causes a collision even when the head's own path is clear.
- The resolver is read-only and lives in application; rules never live in presentation.

### Collision Rollback Behavior

- On collision, `MoveArrowUseCase` returns without mutating the arrow: same `endNodeId`, same `occupiedEdgeIds`. No partial movement remains.
- `movesCount` increments on every attempt (success or failure). `mistakeCount` increments only on failure.

### Lives / Mistakes / Game-Over Behavior

- Each session starts with 3 lives. `GameSession.livesRemaining = 3 - (mistakeCount ~/ 2)`.
- 0-1 mistakes = 3 lives, 2-3 = 2 lives, 4-5 = 1 life, 6+ = 0 lives.
- When lives reach 0 the use case sets `GameStatus.failed` and returns `MovementOutcome.gameOver`.
- Once `victory` or `failed`, further input is ignored (`sessionNotActive`).
- Retry (`GameScreenController.restart`) rebuilds via `GameSession.start`, resetting mistakes, lives, trace, and flash state.
- Score formula: `max(0, 1000 - (mistakeCount * 100) - (movesCount * 5))`. No timer; `elapsedSeconds` stays 0 and is not displayed.

### Exit Animation Behavior

- Rules resolve instantly in the domain; presentation animates the already-resolved trace.
- `GraphBoard` is stateful (`TickerProviderStateMixin`). When an arrow transitions active to escaped, it runs a ~360 ms controller that translates the **whole arrow shape** (all segments + head) outward in the head direction while fading — L/U/zigzag arrows move as one piece. After completion the arrow is rendered escaped/inactive.
- On collision it plays a short shake (sine nudge) plus the existing red collision flash, then the arrow snaps back.
- Graph nodes and edges remain visible at all times.
- `GameScreenController.lastAttemptTrace` (`GameAttemptTrace`) exposes arrow id + outcome for non-brittle tests.
- Animations are gated by `GameScreen.enableBoardAnimations` (default true; widget tests pass false to avoid ticker flakiness).

### Level Selection Refresh Fix

- `LevelSelectionScreen._openLevel` awaits `Navigator.pushNamed(...)` and reloads progress on return.
- Because the await completes on any pop (in-app button, app-bar back, Android system back), unlocked/completed/best-score state is always refreshed after returning from a level.

### Redesigned Manual Levels

- All 15 levels in `assets/levels/manual_levels.json` were redesigned as deterministic, graph-based, varied-shape levels: L-shaped, narrow corridor, gapped lanes, staircase, plus/cross, T, branch/tree, H-ladder, and asymmetric multi-arm.
- Preserved: exactly 15 levels, numbers 1-15, difficulty progression (1-5 easy, 6-10 medium, 11-15 hard), and the existing graph-based JSON schema.
- `blockedEdges` is empty for all 15 levels; the main blocker is other active arrows. No matrix/grid/tile runtime logic.
- Hard levels 11-15 are not all rectangles (0 of them are full rectangles).
- All 15 pass `LevelDefinitionValidator` and remain solvable under the full-exit resolver.

### No-Free-Nodes Rule

- At the start of every level, every graph node is occupied by at least one arrow (via start node, head node, or an occupied edge endpoint).
- Validated both by the generator and by the Dart test `should_have_no_free_nodes_at_level_start`.

### tool/gen_levels.js Purpose

- A deterministic Node generator/validator for the 15 manual levels. It builds levels from straight/L "filled corridors," then verifies structure (orthogonal edges, unique ids, arrow edges/nodes exist), no-free-nodes, difficulty progression, hard-not-all-rectangular, and full-exit solvability (DFS using a JS mirror of the Dart resolver). It writes `assets/levels/manual_levels.json` only when every check passes. It is a build-time authoring tool, not runtime code, and does not perform random generation.

### Tests Added / Updated

- `exit_attempt_resolver_test.dart`: full-shape head and body collision, clear-sweep escape, multi-segment escape, blocked edge, self-non-collision, already-escaped (3x2 grid fixture added).
- `move_arrow_use_case_test.dart`: escape, collision + rollback (state unchanged), blocked edge, lives table, game-over trigger, guards, score formula.
- `lives_system_test.dart`: lives thresholds, game-over, restart reset.
- `score_calculator_test.dart`: new mistake/move formula, no time penalty.
- `manual_levels_test.dart`: `should_have_no_free_nodes_at_level_start`, all-levels-solvable (DFS via real resolver), hard-not-all-rectangular, graph-based (no matrix/grid/cells keys), difficulty progression, level mapping.
- `game_screen_controller_test.dart` (new): escape trace, collision trace + flash, restart resets trace/lives/mistakes.
- `playable_game_ui_test.dart`: lives HUD, game-over overlay, graph persistence after exit, backend-unreachable, locked level, and `should_refresh_progress_when_returning_from_game`.

### Phase 9 Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 92 tests.
- `node tool/gen_levels.js`: all 15 levels valid, no free nodes, all solvable, 0 hard rectangles; asset written.
- Manual emulator validation: not yet performed in this pass — see checklist below. Backend repository and Git remotes were not modified.

### Phase 9 Manual Emulator Validation (pending)

1. Tap an L/zigzag arrow with a clear path: whole shape slides out as one piece; nodes/edges remain.
2. Tap a blocked arrow: short shake + red flash, snaps back, no partial movement, mistake +1.
3. Confirm full-shape blocking where a body segment (not the head) is the blocker.
4. Lives deplete every 2 mistakes; game-over at 6; Retry resets to 3 lives.
5. Complete a level, return via system back and app-bar back: next level shows unlocked both ways.
6. Play all 15 levels to confirm documented solution orders and non-rectangular shapes render.
7. Backend up: login -> complete -> sync/leaderboard non-blocking. Backend down: full local play intact.

## Phase 10 — Level Authoring, Density Tuning, and Board UX Polish

Phase 10 documented level authoring, made `manual_levels.json` the authoritative hand-editable source, densified all 15 levels, and added board pan/zoom. Core Phase 9 gameplay rules were unchanged. All work is inside `frontend-poc-arrow`.

### Authoring guide
- `docs/LEVEL_AUTHORING.md` explains the JSON structure, nodes/edges/arrows, straight and L/U/zigzag arrows, the no-free-nodes rule, designing solvable levels (greedy-completeness), increasing density, difficulty rules, and the validate-after-edit workflow.

### Level tool (`tool/gen_levels.js`) — safe modes
- `node tool/gen_levels.js --validate-only` (also the default with no args): reads the on-disk `manual_levels.json`, runs all checks, prints a per-level report, exits non-zero on failure, and **never writes**.
- `node tool/gen_levels.js --generate`: rebuilds the denser levels from in-script builders, validates, and writes the JSON. Intentional use only.
- Solvability uses a **greedy** solver (repeatedly exit any currently-exitable arrow). Because escaped arrows are non-blocking and exiting only frees nodes, greedy is sound and complete, and stays fast at 50-60 arrows (the old DFS would blow up).
- Checks: structure (orthogonal/unit edges, unique ids, arrow edges/nodes exist), no-free-nodes, greedy solvability, difficulty progression, density bands, strictly increasing tier averages, hard-not-all-rectangular.

### Density tuning
- Easy 1-5: 10-15 arrows (soft ramp). Medium 6-10: 15-30. Hard 11-15: 20-50 (51-60 = warning, 61+ = failure).
- Current set: easy 10/11/12/13/15, medium 16/18/20/24/28, hard 22/27/34/40/50; tier averages 12.2 < 21.2 < 34.6 (strictly increasing); 0 hard levels are full rectangles; every visible node occupied; all greedy-solvable; every level a single connected component.
- Levels are built as a **single connected traversal graph**: left-aligned horizontal rows of arrow queues, woven with vertical connector edges (perpendicular to the arrows, so they never change exit sweeps). Ragged row widths give non-rectangular silhouettes; alternating left/right exit directions exercise both arrowhead orientations. Connectivity guarantees no disconnected islands while preserving solvability and density.

### Phase 10 corrections (post manual validation)
- **Connected traversal graph**: the disjoint-lane layout was replaced with one connected component per level. The tool and Dart tests now reject disconnected graphs (`comp` must be 1; `--validate-only` prints `DISCONNECTED(n)` and fails). No hidden connector nodes were needed (connectivity uses edges between visible nodes); the schema/validator nonetheless support an optional `hidden` node flag (exempt from visible no-free-nodes).
- **Visible no-free-nodes**: the rule is clarified to apply to visible nodes; hidden connector nodes (if ever used) are exempt. All current nodes are visible and occupied.
- **Arbitrary arrow paths**: documented that arrow shape is just the path from `occupiedEdges` (no "L/U/zigzag" templates). The head must be the exit-facing end.
- **Left/up arrowhead fix**: the generator previously put the head (`endNodeId`) on the inner end for left/up lanes, so arrowheads rendered at the wrong end. Fixed so the head is always the exit-facing node (verified: all 340 arrows have the body behind the head). The painter's direction→angle mapping was already correct for all four directions.

### Board UX (pan/zoom)
- `GraphBoard` wraps the board in `InteractiveViewer` (min 1x, max 4x, drag to pan) with a reset-view button (`GameUiKeys.resetViewButton`, localized `resetView` / "Reset view" / "Restablecer vista").
- Tap-to-activate is unaffected: the tap `GestureDetector` lives inside the transformed child, so hit testing stays in child coordinates.

### Phase 10 verification
- `node tool/gen_levels.js --generate`: all 15 valid/solvable/in-band; asset written.
- `node tool/gen_levels.js --validate-only`: passes on the shipped JSON, writes nothing (byte-identical), exit 0.
- `flutter analyze`: no issues. `flutter test`: 95 passed (added density-band, density-increasing, and reset-view/tap tests; switched the Dart solvability test to greedy).
- Manual emulator validation still pending — confirm dense hard levels are playable with pinch-zoom/drag/reset and that exit/collision animations and lives still behave.

## Phase 11 — Varied Arrow Shape Rendering

Phase 11 added an ordered node path to `ArrowPath` and switched the painter to a smooth polyline, so L/U/zigzag arrows render without joint artifacts. All work is inside `frontend-poc-arrow`; backend and Git remotes were untouched.

### What Changed

- **`lib/features/game/domain/arrow_path.dart`**: Added `orderedNodeIds: List<String>` field — the tail-to-head ordered sequence of node IDs (`[startNodeId, …, endNodeId]`). `copyWith` passes it through unchanged.
- **`lib/features/game/domain/level_definition_validator.dart`**: Added `_deriveOrderedNodeIds` static helper. It does a greedy linked-list walk through `occupiedEdgeIds` starting at `startNodeId`, following whichever edge connects to the current node at each step. Called when building each `ArrowPath` during `validate()`. The `ArrowPathDefinition` model and `LevelDefinitionMapper` are unchanged.
- **`lib/features/game/presentation/widgets/graph_board_painter.dart`**: `_paintArrowShape` now builds a single `Path` with `moveTo`/`lineTo` through `arrow.orderedNodeIds` instead of individual `drawLine` calls per edge. Added `..strokeJoin = StrokeJoin.round` to eliminate thickened joint artifacts at bends.
- **`lib/features/game/presentation/widgets/graph_board_hit_tester.dart`**: Body hit-test now iterates consecutive node pairs from `arrow.orderedNodeIds` instead of looking up edge `fromNodeId`/`toNodeId`. Functionally equivalent; order is now guaranteed.
- **`test/features/game/presentation/playable_game_ui_test.dart`**: Two direct `ArrowPath(...)` constructions updated to supply `orderedNodeIds: ['a']`.

### New Tests (`test/features/game/application/bent_arrow_test.dart`)

- `orderedNodeIds_for_L_arrow_is_tail_bend_head`: derivation for `ab+bd` (reversed-order and forward-order edge lists).
- `orderedNodeIds_when_edges_supplied_in_reverse_order`: derivation is order-independent.
- `orderedNodeIds_for_single_edge_arrow_is_start_end`.
- `bent_arrow_escapes_when_path_below_head_is_clear`: L-shaped arrow on basic board exits correctly.
- `bent_arrow_collides_when_body_sweep_hits_another_arrow`: L-shaped arrow whose tail-side sweep hits another arrow's node returns `collision`.

### Phase 11 Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 107 tests passed (102 pre-existing + 5 new).
- Backend repository and Git remotes were not modified.

### Phase 11 Limitations

- `_deriveOrderedNodeIds` assumes arrows are simple paths (no branches). Branching arrow shapes are not supported by the game model and would produce a truncated node list (safe fallback, not a crash).
- Manual emulator validation (Phases 9, 10, 11) is still pending.

### Phase 11 Part 2 — Random Level Generator Rewrite

`tool/gen_levels.js` was rewritten from scratch. All previous level builders (`rowStack`, `buildCombLevel` as primary) were replaced with a random partition algorithm. The comb pattern is kept only as an emergency fallback (it was not triggered for any of the 15 levels).

**Algorithm (sparse graph + DFS partition):**
1. Build a W×H node set (coordinate grid). Hard levels remove boundary nodes randomly with BFS connectivity verification to create irregular silhouettes.
2. Partition all nodes into node-disjoint simple paths via most-constrained-first DFS walk (fewest unvisited neighbours first), capped at `maxPathLen`. Singletons are merged into adjacent path tails/heads.
3. Convert each path to an arrow via `Builder.arrowOverCells` — only the body edges of that arrow are added to the graph (sparse, no inter-arrow horizontal edges). `direction` = direction of last DFS step (always satisfies head-orientation invariant by construction).
4. `Builder.weave()` adds vertical edges for graph connectivity. Weave edges are perpendicular to horizontal arrows and never extend a horizontal sweep.
5. **Solvability guarantee**: With no inter-arrow horizontal edges in the graph, every horizontal arrow's sweep uses only its own body edges → exits immediately → trivially greedy-solvable. Horizontal-end bias in the DFS (prefer horizontal last step) keeps most arrows pointing right/left.
6. Connectivity check (sparse graph can be disconnected after boundary removal even when node-set is coordinate-connected), density band check [10-15 easy / 15-30 medium / 20-50 hard], `hasBent` check (≥1 arrow with 3+ nodes), and greedy solvability check are all applied. Retry up to 200 times per level.

**Grid sizes**: easy 6-7×6-7 (~42-49 nodes), medium 8-9×8-9 (~64-81 nodes), hard 9-12×9-12 with 12-25% removal (~95-112 nodes). `maxPathLen` = 4 (easy/medium), 5 (hard).

**Files changed:**
- `tool/gen_levels.js`: complete rewrite; `buildCombLevel` kept as fallback only.
- `assets/levels/manual_levels.json`: regenerated — all 15 levels are new random layouts.
- `test/features/game/infrastructure/manual_levels_test.dart`: removed hardcoded `hasLength(11)` for level 2 (replaced with `greaterThanOrEqualTo(10)`); updated semantics label check in `playable_game_ui_test.dart` (level 1 now has 42 nodes, 11 arrows).

**Validation output:**
- easy=11.0 < medium=17.4 < hard=22.0 (strictly increasing tier averages ✓)
- 0 hard full-rectangle levels ✓
- All 15: comp=1, free=-, solvable=true ✓
- No fallbacks triggered.

**Test results:** `flutter analyze` — no issues. `flutter test` — 108/108 passed.

**Limitations:**
- Hard levels have 21-24 arrows (well within [20,50] band but toward the lower end). The sparse-graph approach limits how many arrows fit in a given grid because paths can't cross. Increasing `maxPathLen` or using larger hard grids would raise the count.
- All easy/medium levels are rectangular (bbox = W×H, rect=Y). Only hard levels have irregular silhouettes (boundary removal). This is valid per the spec ("hard levels must not ALL be full rectangles"); no constraint on easy/medium shape.
- The JS self-test (deadlock detection) and Dart `should_have_bent_arrows_in_every_difficulty_tier` test both pass, confirming bent arrows are present in all difficulty tiers.

---

### Phase 11b — Level Regeneration with Bent Arrows

Regenerated `assets/levels/manual_levels.json` so each difficulty tier contains visually-bent arrows. Levels 3, 8, and 13 were replaced with a "comb" pattern. All other levels remain as before.

**Design (comb pattern)**: Each comb level stacks N triplets of (sparse-tooth row → full-base row → full-connector row). Tooth rows contain isolated nodes connected down to the base row. L-shaped arrows cover one tooth node + two adjacent base nodes, exiting right. A single connector-row arrow covers the full width exiting left. `weave()` adds vertical edges that link all rows into one connected component without crossing any rightward sweep path — guaranteeing no-free-nodes, solvability, and comp=1.

**Files changed**:
- `tool/gen_levels.js`: added `buildCombLevel()` helper; replaced levels 3, 8, 13 in `buildLevels()`.
- `assets/levels/manual_levels.json`: regenerated.
- `test/features/game/infrastructure/manual_levels_test.dart`: added `should_have_bent_arrows_in_every_difficulty_tier`.

**Validation output** (all pass):
- #3 L-Corridor: easy, 12 arrows, comp=1, free=-, solvable=true
- #8 Comb Grid: medium, 21 arrows, comp=1, free=-, solvable=true
- #13 Comb Maze: hard, 35 arrows, comp=1, free=-, solvable=true
- Tier averages: easy=12.2 < medium=21.4 < hard=34.8 ✓

**Test results**: `flutter analyze` — no issues. `flutter test` — 108/108 passed.

**Limitations**: Level 2 name='L-Turn' and arrow count=11 are now a test contract in `manual_levels_test.dart`. Do not change level 2's name or arrow count without updating that test.

## Known Limitations

- No random level generation yet.
- No final APK build yet.
- No production deployment config.
- No full account/profile management.
- Token storage uses SharedPreferences for academic/demo scope; secure storage is future work.
- Remote levels do not replace local gameplay.
- No final music/background audio assets yet.
- No real gameplay timer yet (intentional; score is mistake/move based).
- Stuck/deadlock detection was treated as optional and is not implemented; lives/game-over remains the failure path.
- Dense hard levels may require pinch-zoom/drag to play comfortably on small screens.
- Manual emulator validation (Phase 9 + Phase 10) is still pending.

## Next Recommended Phase

Recommended next phase: final release preparation and a manual backend/emulator smoke test (auth, sync, leaderboard against the Docker backend), plus the pending manual emulator validation for the dense Phase 10 boards. Optionally, random graph-based level generation afterward.
