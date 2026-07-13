# Codex Handoff

## Current Repository

- Repository: `frontend-poc-arrow`
- Branch: `feat/frontend-backend-integration`
- Do not modify Git remotes automatically.
- Do not modify `backend-poc-arrow` unless a blocking API contract issue is found and reported first.

## Completed Phase

- Phase 23: Bug Fixes & Polish (Save-Race Hardening + Leaderboard Picker Coverage).

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

- The arrow is a **rigid piece**: the head (`endNodeId`) leads; body nodes follow. Only the **head** collides against other arrows (corrected in Phase 12.1 — see below).
- `MovementResolver.resolve` sweeps forward **from the head only** using coordinate-based stepping (`direction.applyTo(coordinate)` → `nodeByCoordinate`). If the head encounters a node occupied by another active arrow, or a blocked edge, the attempt is a `collision`. Otherwise it is `escaped`.
- Body nodes do not have independent collision detection; they occupy the path the head already traversed.
- `coveredNodeIds` is still used to build the blocker set for other arrows (unchanged).
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

**Limitations**: Level 2's name and arrow count are a test contract in `manual_levels_test.dart`. Do not change them without updating that test. (As of Phase 13.2 the name is `'Level 2'` — see that section.)

## Phase 12 — Collision Fix for Bent Arrows

Phase 12 fixed collision detection so every node a bent arrow traverses — start, intermediate, and exit nodes — is checked against blockers, even in sparse graphs where no direct graph edge connects adjacent nodes.

### Root Cause

`MovementResolver.resolve` swept forward from each covered node using `graph.getEdgeInDirection` and `graph.getNeighbor` — both of which follow graph edges. In sparse-graph levels (built by Phase 11b's generator), inter-arrow edges are absent. If node A and blocker node C are at adjacent coordinates with no edge between them, the old sweep returned null (no edge → assumed A exits the board) and never detected C as a blocker. The same bug existed in the JS `canExit` function in `tool/gen_levels.js`.

### What Changed

- **`lib/features/game/domain/board_graph.dart`**: Added `_nodesByCoordinate` map (built at construction) and `nodeByCoordinate(BoardCoordinate)` lookup method.
- **`lib/features/game/application/movement_resolver.dart`**: Inner sweep loop replaced: instead of `getEdgeInDirection`/`getNeighbor`, steps by coordinate (`direction.applyTo(currentNode.coordinate)` → `graph.nodeByCoordinate`). Blocked-edge check retained via `getEdgeBetween` when a graph edge exists. Collision is now detected whenever a node exists at the next coordinate and is occupied by a blocker, regardless of graph connectivity.
- **`tool/gen_levels.js`**: `indexDj` extended with a `byCoord` map. Added `nodeAtCoord` and `edgeBetween` helpers. `canExit` updated to use coordinate-based stepping, matching the Dart fix. Comb fallback density parameter tables corrected so all option combinations fall within the required density bands (easy [10,15], medium [15,30], hard [20,60]).
- **`assets/levels/manual_levels.json`**: Regenerated — all 15 levels are new layouts valid under correct coordinate-based physics.
- **`test/features/game/application/bent_arrow_test.dart`**: Added `bent_arrow_blocked_at_intermediate_node_without_graph_edge_is_collision` — proves the bug (no edge between moving node and blocker, but they ARE coordinate-adjacent → collision) and the fix.
- **`test/features/game/presentation/playable_game_ui_test.dart`**: Updated semantics label for Level 1 (36 nodes / 10 arrows after regeneration).

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 109/109 passed.
- `node tool/gen_levels.js --validate-only`: all 15 levels valid, all solvable, 0 hard rectangles, exit 0.

### New Tests

- `bent_arrow_blocked_at_intermediate_node_without_graph_edge_is_collision`

### Limitations

- Medium levels 9–10 and hard levels 11–14 now use the comb fallback pattern (random partition fails solvability under correct physics within 200 retries). Comb levels are valid and playable but may look more uniform than random-partition levels.
- Level 2 test contract updated: name='L-Turn', arrow count is now ≥ 10 (the `greaterThanOrEqualTo(10)` check was already in place; current level 2 has 12 arrows).
- Manual emulator validation (Phases 9, 10, 11, 12) remains pending.

## Phase 12.1 — Head-Only Collision for Bent Arrows

Phase 12.1 is a scope correction on Phase 12. The coordinate-based sweep introduced in P12 was applied to every covered node of the moving arrow (start, body, head). Body nodes now run independent collision checks, causing a bent arrow whose head path is clear to incorrectly report a collision because a body node is adjacent to another arrow. The fix narrows the sweep to the head only.

### What Changed

- **`lib/features/game/application/movement_resolver.dart`**: Removed the per-covered-node loop. The sweep now starts exclusively from `arrow.endNodeId` (the head). The coordinate-based stepping mechanism (`direction.applyTo(coordinate)` → `nodeByCoordinate`) is retained and unchanged; only its scope was narrowed. `coveredNodeIds` is still used to build `blockerNodes` for other arrows.
- **`test/features/game/application/bent_arrow_test.dart`**: Updated two tests:
  - `bent_arrow_collides_when_body_sweep_hits_another_arrow` → renamed to `bent_arrow_escapes_when_head_clear_but_body_node_adjacent_to_another_arrow`, expectation changed to `escaped`. Documents the regression case: body adjacency is not a collision.
  - `bent_arrow_blocked_at_intermediate_node_without_graph_edge_is_collision` → replaced with `bent_arrow_head_blocked_at_adjacent_coordinate_without_graph_edge_is_collision`. Board rearranged so the blocker (`f`) is directly below the **head** (`e`), with no graph edge between them. Expectation remains `collision`. Preserves coverage of coordinate-based sparse-graph detection, now correctly applied to the head.
- **`test/features/game/application/exit_attempt_resolver_test.dart`**: `should_collide_when_arrow_body_sweep_overlaps_another_arrow` → renamed to `should_escape_when_head_clear_and_body_sweep_would_overlap_another_arrow`, expectation changed to `escaped`. This test was asserting the incorrect full-body-sweep behavior.

### Rigid-Piece Rule (canonical)

The arrow is a **rigid piece**: the head leads, the body follows the head's path. Only the head (`endNodeId`) collides against other arrows. If the head is blocked, the whole arrow rolls back atomically (P9 behavior unchanged). Body nodes occupy the path the head already traversed — they have no independent collision detection.

### No Level or JS Changes

`tool/gen_levels.js` `canExit` already sweeps from `endNodeId` only (it mirrors the head-leads model). No level files or JS changes were required; `--validate-only` passes unchanged.

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 109/109 passed.
- `node tool/gen_levels.js --validate-only`: not run (no level files touched).

### New / Updated Tests

- `bent_arrow_escapes_when_head_clear_but_body_node_adjacent_to_another_arrow` (regression: body adjacency must not block)
- `bent_arrow_head_blocked_at_adjacent_coordinate_without_graph_edge_is_collision` (coordinate sweep from head, sparse graph)
- `should_escape_when_head_clear_and_body_sweep_would_overlap_another_arrow` (updated from body-sweep-blocks expectation)

## Phase 13 — Path-Following Exit Animation (Train on Tracks)

Phase 13 implements the exit animation so bent arrows slide along their own path off the board. The head leaves first; each body node follows the exact sequence of pixel positions the nodes ahead of it occupied, rounding corners, then continues in the exit direction past the head. All changes are presentation-only; no domain or test files were modified.

### What Changed

- **`lib/features/game/presentation/widgets/graph_board_painter.dart`**: `_drawExitingArrow` rewritten with arc-length track sampling.
  - Builds cumulative pixel arc lengths (`arcs[]`) along the `orderedNodeIds` polyline (tail→head).
  - For each node at "from-head index" `i` (0=head, n-1=tail), starts moving after `i * effectiveDelay` (same 10%-per-segment stagger, capped at 50%, as before).
  - `advance = totalDistance * localT`. If `advance ≤ arcToHead`: walks forward along the node polyline by `advance` pixels from the node's starting position, with linear interpolation within each segment — the node rounds the bend. If `advance > arcToHead`: continues straight past the head in the exit direction.
  - Opacity driven by the head's `localT` (head leads the fade). Arrowhead drawn at the displaced head position.
  - The existing 360 ms controller, stagger constants, direction vector, and collision shake are untouched.
  - Previous bug: each node translated `pos + dir * totalDistance * localT` — a straight slide from its own position that preserved the bent shape and moved it in a straight line off the board.

### Files Touched

- `lib/features/game/presentation/widgets/graph_board_painter.dart`

### Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: 109/109 passed.
- `node tool/gen_levels.js --validate-only`: not applicable (no level files touched).

### New Tests

- None (presentation-only change; existing suite fully covers the affected code path).

### Limitations

- Manual emulator validation (Phases 9, 10, 11, 12, 13) is still pending. Trigger an exit on a bent (L/U/zigzag) arrow and confirm it rounds its own corner on the way out, the head leads, and the collision shake is unaffected.

## Phase 13.1 — Level Direction Variety

Phase 13.1 is a generator-only change. All 15 levels now contain a meaningful mix of up/down/left/right arrows; no level is all-horizontal. No engine, collision, rendering, or Dart test files were modified.

### Root Cause

`partitionNodes()` in `tool/gen_levels.js` had two explicit horizontal biases:
1. The last DFS step of each path preferred horizontal neighbours so `direction` would be `right` or `left`.
2. Any path whose final direction was vertical was reversed to produce a horizontal end.

Additionally, `canExit` swept from **all** covered nodes rather than from `endNodeId` only — contradicting the Dart Phase 12.1 head-only resolver. This over-rejected valid vertical configurations, causing ~200-retry failures and comb fallback on most levels.

### What Changed

- **`tool/gen_levels.js`**:
  - `canExit`: now sweeps from `endNodeId` only, matching the Dart Phase 12.1 `MovementResolver` (head-leads model). This was a pre-existing mismatch documented as fixed in P12.1 but not yet applied to the JS tool.
  - `partitionNodes`: removed the last-step horizontal preference and the post-hoc vertical-to-horizontal reversal. Candidates are already shuffled by the seeded PRNG; direction is now determined by whichever step the DFS naturally takes last.
  - `generateLevel`: added a direction-variety check — a level is retried if it has no vertical arrow (`up` or `down`) or if any single direction exceeds 60% of arrows.
  - `Builder`: added `weaveH()` — adds horizontal edges between all horizontally-adjacent node pairs. Used by the mixed fallback for graph connectivity.
  - `buildCombFallback`: replaced the old horizontal-only comb with a **mixed-lane builder** — alternating right/left horizontal rows (H-section) stacked above down-pointing vertical columns (V-section). The two sections are provably non-cross-blocking: H arrows sweep within their rows, V arrows sweep below the H-section. Connectivity ensured by `weaveH()` + `weave()`. Guarantees `hasVertical=true` and `maxDirFrac ≤ 60%`.
- **`assets/levels/manual_levels.json`**: regenerated — 13/15 levels generated by the random partition algorithm; 2 hard levels (14 and 15) use the new mixed fallback.

### Direction Variety (all 15 levels)

```
#1  First Exit   (10): down:60% right:30% left:10%
#2  L-Turn       (11): right:55% down:36% left:9%
#3  Zigzag       (12): down:50% right:33% left:8% up:8%
#4  Two Lanes    (12): right:42% left:25% down:17% up:17%
#5  Queue Up     (11): right:45% left:27% up:18% down:9%
#6  Cross Roads  (16): down:38% left:31% right:31%
#7  T-Junction   (18): right:50% down:39% left:11%
#8  Comb Grid    (21): down:48% left:24% right:24% up:5%
#9  Offset Pair  (17): down:53% right:29% left:18%
#10 Three Way    (16): right:56% down:31% left:13%
#11 Deadlock Intro (23): down:52% left:35% right:13%
#12 Chain Block  (23): down:57% right:26% left:9% up:9%
#13 Comb Maze    (26): left:38% down:35% right:27%
#14 Four Locks   (41): down:39% right:37% left:24%
#15 Final Maze   (41): down:39% right:37% left:24%
```

All 15: `hasVertical=true`, single-direction cap ≤ 60%.

### Files Touched

- `tool/gen_levels.js`
- `assets/levels/manual_levels.json`

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 109/109 passed (no Dart files changed; level 1 layout unchanged — 36 nodes, 10 arrows — so semantics label test unchanged).
- `node tool/gen_levels.js --validate-only`: all 15 levels valid, all solvable, 0 hard rectangles, exit 0.

### New Tests

- None (generator-only change; existing suite fully covers the affected code path).

### Limitations (Phase 13.1 first pass — now resolved)

- Levels 14 and 15 used the deterministic mixed-lane fallback. Fixed in Phase 13.1 refactor below.
- Manual emulator validation (Phases 9, 10, 11, 12, 13, 13.1) is still pending. Confirm up/down-pointing arrows render correctly and exit in the correct direction.

## Phase 13.1 Refactor — All Levels From Random Partition

Generator-only follow-up to Phase 13.1. All 15 levels now originate from the random partition algorithm; the deterministic `buildCombFallback` is no longer a source of shipped levels.

### Root Cause

Hard levels 14 and 15 (seeds 14014 / 15015) exhausted the 200-attempt retry budget without satisfying the variety check. The variety success rate for hard levels is roughly 0.5–1% per attempt — levels 14 and 15 happened to find valid layouts at attempts 209 and 208 respectively, just beyond the old budget.

### What Changed

- **`tool/gen_levels.js`**:
  - `MAX_RETRIES` changed from a flat `200` to a per-tier object: `{ easy: 200, medium: 200, hard: 3000 }`. Hard tier now has a 3000-attempt budget; the PRNG-based loop completes in well under a second per attempt.
  - `generateLevel` computes `const maxRetries = MAX_RETRIES[difficulty] || 200` and uses it for the retry loop.
  - Removed the `buildCombFallback` call at the end of `generateLevel`. On retry exhaustion the function now throws, surfacing generation failures loudly rather than silently shipping a deterministic layout.
  - `buildCombFallback` marked as dead code with a header comment. The function body is retained for reference but is unreachable during generation.
- **`assets/levels/manual_levels.json`**: regenerated — all 15 levels are random-partition outputs. Levels 14 and 15 found at attempts 209 and 208.

### Generation Output

```
#14 Four Locks  hard  nodes=114 arrows=23 bbox=12x10 rect=n comp=1 free=- solvable=true
#15 Final Maze  hard  nodes=104 arrows=22 bbox=12x9  rect=n comp=1 free=- solvable=true
tier avg: easy=11.2 < medium=17.6 < hard=23.4 ✓  hard rects=0 ✓  ALL VALID: true
```

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 109/109 passed.
- `node tool/gen_levels.js --validate-only`: all 15 levels valid, all solvable, 0 hard rectangles, exit 0.
- Confirmed: no level uses `buildCombFallback` (generation log shows attempt numbers; no FALLBACK warning printed).

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

## Phase 13.2 — Level Name Simplification

**Scope**: Generator-only (plus dependent test assertions). No gameplay, domain, or rendering changes.

**What changed**:
- `tool/gen_levels.js`: all 15 `LEVEL_DEFS` names changed from descriptive labels ("First Exit", "L-Turn", …, "Final Maze") to generic `'Level N'`. Difficulty, seeds, meta, and the generation algorithm are unchanged.
- `assets/levels/manual_levels.json` regenerated. Level structure is identical to Phase 13.1 (same seeds → same layouts); only the `name` fields differ.
- Test assertions updated to the new names:
  - `test/features/game/infrastructure/manual_levels_test.dart`: level 2 name `'L-Turn'` → `'Level 2'`.
  - `test/features/game/presentation/playable_game_ui_test.dart`: `'First Exit'` → `'Level 1'` (×2), `'Final Maze'` → `'Level 15'`.
  - `test/widget_test.dart`: `'First Exit'` → `'Level 1'`.

**Test results**: `flutter analyze` — no issues. `flutter test` — 109/109 passed. `node tool/gen_levels.js --validate-only` — ALL VALID: true; tier avgs easy=11.2 < medium=17.6 < hard=23.4; 0 hard full-rectangle levels.

**Note**: Level 2's test contract is now name=`'Level 2'`, arrows ≥ 10.

## Phase 14 — Audio/Music/Localization Audit + Collision Validator

### Task A — Audit Result

All audio/music/localization code is **fully Clean Architecture compliant**. No refactor was needed.

- `AudioPort` and `MusicPort` are pure Dart abstract interfaces in `lib/features/audio/application/`.
- `GameAudioController` and `BackgroundMusicController` depend only on port abstractions — no concrete adapter imports in application or presentation layers.
- `AudioPlayersAudioPort`, `AudioPlayersMusicPort`, `SystemSoundAudioPort` are correctly in infrastructure.
- `l10n.yaml`, `pubspec.yaml`, ARB files, `MaterialApp` setup all correct.

All Task A gaps listed in the phase prompt were already implemented before Phase 14:

- `PlayerSettings.languageCode` (`String?`, null = system default) — present.
- `SharedPreferencesSettingsRepository` — persists/reads `settings.languageCode`.
- `SettingsScreenController.setLanguage()` — implemented.
- `_LanguageSelectorCard` — interactive `DropdownButton<String?>` with English/Spanish/System options.
- `MaterialApp` locale — reactive via `AppSettingsController`/`AppSettingsScope`; seeded from saved prefs in `app_bootstrap.dart`.

Language switching is fully functional. No code changes were needed for Task A.

### Task B — Collision Validator

Added explicit node/edge disjointness enforcement so levels where two arrows share a node or edge are caught at parse time.

**What Changed:**

- **`tool/gen_levels.js`**: Added `noSharedNodes(dj)` function. Iterates all arrows, builds `ownerByNode` and `ownerByEdge` maps, returns conflict descriptions if any node or edge is claimed by more than one arrow. Called from `validateAll`; result shown in the `shared=` column of the per-level report. Failures set `bad=true` and cause exit code 1.
- **`lib/features/game/domain/level_definition_validator.dart`**: Added node and edge disjointness check during arrow validation. Throws `LevelDefinitionException` if any node (startNodeId, endNodeId, or edge endpoint) or occupied edge is already claimed by a prior arrow.
- **`test/features/game/game_test_fixtures.dart`**: Added `collisionDefinition()` helper — a 4-node horizontal graph (a→b→c→d) where `arrow-1` covers `[a,b]` and `arrow-2` covers `[c,d]` with no shared nodes. Arrow-1's head at b(1,0) sweeps right to c(2,0) which is in arrow-2's covered set → collision via coordinate sweep, not node-sharing.
- **`test/features/game/domain/level_definition_validator_test.dart`**: Added `no_opposite_arrows_on_same_path` and `no_shared_nodes_between_arrows` — both assert `throwsA(isA<LevelDefinitionException>())` for levels with shared nodes.
- **5 existing collision-test fixtures updated** (`exit_attempt_resolver_test.dart`, `move_arrow_use_case_test.dart` ×3, `game_screen_controller_test.dart`) to use `collisionDefinition()` instead of `basicDefinition()` with sharing arrows.

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 117/117 passed (108 pre-existing + 2 new validator tests + 7 updated fixture tests).
- `node tool/gen_levels.js --validate-only`: all 15 levels valid, `shared=-` for every level, exit 0.

### New Tests

- `no_opposite_arrows_on_same_path`
- `no_shared_nodes_between_arrows`

### Limitations

- Manual emulator validation (Phases 9–14) is still pending.
- The `noSharedNodes` check is a validator enforcement, not a generator change — the generator already produces node-disjoint arrows by construction (DFS partition), so no levels were regenerated.

### Phase 14 Task B — Runtime Escape Bug Fix (2026-06-22)

**Root cause found and fixed.** The prior audit ("no live defect") was incomplete — it audited the resolver logic but did not scan the actual level data.

**Root cause:** Hard-level boundary node removal (for irregular silhouettes) created interior coordinate **gaps** — coordinates inside the board's bounding box that have no node. When an arrow's head sweep hit such a gap, `nodeByCoordinate` returned `null`, the resolver treated it as the board boundary, and returned `escaped`. A visually adjacent arrow just past the gap was never reached. All 5 hard levels (11–15) had 3–9 arrows with this defect.

**Fix:**
- `tool/gen_levels.js`: added `hasInteriorGapExit(dj)` (checks all arrows for null-node exits within the bbox) and `flipInteriorGapArrows(dj)` (reverses arrows whose head sweep exits through a gap). Reversal uses `OPP[dirBetween(startNode, secondNode)]` — not `OPP[direction]` — to correctly compute the new exit direction for bent arrows (the first-step direction reversed, not the last-step direction reversed). Added `gapExit=` column to `validateAll`. `MAX_RETRIES.hard` raised 3000 → 8000.
- `assets/levels/manual_levels.json`: regenerated — all 15 levels have `gapExit=-`. Hard levels use non-rectangular silhouettes with no interior gaps.
- `test/features/game/infrastructure/manual_levels_test.dart`: added `should_have_no_interior_gap_exits` — sweeps every arrow's head path and asserts no null node inside the level's bounding box.

**No runtime code changed.** `MovementResolver`, `BoardGraph`, and `LevelDefinitionValidator` are correct and untouched.

**Verification:** `flutter analyze` — no issues. `flutter test` — 119/119 passed. `node tool/gen_levels.js --validate-only` — ALL VALID: true, `gapExit=-` for all 15 levels.

## Phase 14.1 — Arrow Shape Fix: Self-Intersection (2026-06-22)

### Problem (clarified)

A visual defect: a pink arrow in Level 12 appeared to form a **closed rectangular loop**. The root cause was **self-intersection** — not a mathematical graph cycle. Arrow `a15` was a U-spiral path:

- Path: `n3_3`(3,3) → `n3_4`(3,4) → `n2_4`(2,4) → `n1_4`(1,4) → `n1_3`(1,3) → `n2_3`(2,3) [head]
- `direction: right`
- Head sweep from `n2_3`(2,3) going right → hits `n3_3`(3,3) = the arrow's own `startNodeId`

The arrow was a valid simple path (5 edges, 6 distinct nodes — not a graph cycle), but the head pointed directly back into its own tail. When tapped it would "exit" by sweeping through its own body — visually nonsensical and player-confusing.

### Audit Findings

- **Level 12 a15 confirmed.** Coordinate-scan script over all 15 levels found exactly 1 self-intersecting arrow: a15 in Level 12. All other 14 levels were clean.
- **Generator mechanism.** The random DFS in `partitionNodes` can legally produce U-spiral paths where the last DFS step points back toward an earlier part of the path **in board space** (through empty coordinates). No graph edge connects them, but the coordinate sweep crosses the body. This is not caught by the DFS's `unvisited` set (which prevents graph-cycle revisits, not coordinate-sweep self-intersection).
- **Validator gap.** The existing per-arrow checks (cycle, branching-head, head-direction) did not include a coordinate sweep simulation of the head's exit path against the arrow's own covered nodes.

### Changes

**`tool/gen_levels.js`:**
- Added `hasSelfIntersectingArrow(dj)`: iterates all arrows; for each, builds the body node set (covered minus head), sweeps from the head by `DELTA[direction]` using `nodeAtCoord`, returns `true` if any swept coordinate hits an own-body node.
- Wired into `generateLevel` after `hasInteriorGapExit` check: `if (hasSelfIntersectingArrow(dj)) continue;` — rejects and retries the level.
- Added equivalent check in `structureErrors` arrow loop for `--validate-only` coverage: pushes `'arrow head sweep self-intersects own body at <nodeId> <arrowId>'`.

**`lib/features/game/domain/level_definition_validator.dart`:**
- Builds `coordToNodeId = Map<BoardCoordinate, String>` before the arrow loop (from `nodesById`).
- Inside the arrow loop (after existing shape checks), sweeps from `headNode.coordinate + dir` by `(dir.dx, dir.dy)`; throws `LevelDefinitionException('Arrow X head sweep in direction D self-intersects own body at node Y.')` on first hit.

**`test/features/game/domain/level_definition_validator_test.dart`:**
- Added `should_reject_arrow_with_self_intersecting_sweep` — mirrors a15's topology: 6 nodes, 5-edge U-spiral, head at (1,0) direction=right sweeps into startNodeId at (2,0). Expects `LevelDefinitionException`.

**`assets/levels/manual_levels.json`:** regenerated — all 15 levels free of self-intersecting arrows. Level 12 now has 26 arrows (was 20); hard tier average 22.8 (was 21.6).

### Verification

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (121 pre-existing + 1 new).
- `node tool/gen_levels.js --validate-only`: ALL VALID: true; self-intersection column clean for all 15 levels.
- Coordinate-scan script confirms 0 self-intersecting arrows across all 15 levels.

## Phase 15 — Audio Playback Stability Fix (2026-06-22/23)

### Context

User-reported, real-device bugs (not covered by the Phase 14 Task A audit, which
checked Clean Architecture compliance only — not runtime audio behavior):
intermittent crashes, music and SFX silencing each other, crackling/distorted
playback, and victory/defeat SFX playing back sped up. **This corrects the
Phase 14 Task A conclusion** ("fully compliant, no changes needed") — the code
was architecturally clean but had live runtime defects the audit didn't check
for.

### Root Causes Found

1. **Crash (resource leak):** `AudioDependencies` constructed a brand-new
   `AudioPlayer` pair every time `GameScreen` mounted (every level/retry/next
   level); nothing ever called the existing `dispose()` methods on
   `AudioPlayersAudioPort`/`AudioPlayersMusicPort`. Native players accumulated
   across a session.
2. **Music/SFX silencing each other:** the SFX port set an explicit Android
   `AudioContext` (`gainTransientMayDuck`) on every `play()` call; the music
   port never set any `AudioContext` at all, leaving it on undocumented
   platform defaults that don't reliably negotiate ducking with the SFX
   stream's transient focus request.
3. **Crackling/distortion:** `AudioPlayersMusicPort._musicVolume` was `1.1` —
   above the `0.0–1.0` range the underlying `audioplayers` plugin passes
   straight into Android's native `MediaPlayer.setVolume()` unclamped.
4. **Victory/defeat sped up:** all four SFX events shared one `AudioPlayer`
   instance with `stop()` immediately followed by `play()` on every call, no
   debounce — concurrent/rapid events raced each other. Byte-level MP3 header
   inspection also found `victory.mp3` encoded at 48000 Hz while
   `move.mp3`/`blocked.mp3`/`defeat.mp3` were at 44100 Hz, compounding the race
   when the shared player switched between mismatched-rate assets.
5. **(Found after the first fix round) Next Level button stops music:**
   `_openNextLevel()` uses `Navigator.pushReplacementNamed`, which disposes the
   old `GameScreen` while mounting a new one. Once music ownership moved to a
   singleton (fix for #1), the old screen's `stopMusic()` and the new screen's
   `startMusic()` raced on the same singleton — whichever ran last won, and
   the old screen's stop tended to land after the new screen's start.

### What Changed

- **`lib/features/audio/infrastructure/audio_manager.dart` (new):** app-lifetime
  `AudioManager` singleton. Created once; `GameAudioController` and
  `BackgroundMusicController` are built lazily and cached, never recreated per
  screen. `startMusic()`/`stopMusic()` are reference-counted (`_musicClaims`)
  so overlapping claims from an old screen disposing and a new screen starting
  (the `pushReplacementNamed` race) don't kill music a still-active screen
  wants playing — only the first claim starts playback and only the last
  release stops it.
- **`lib/features/audio/infrastructure/audio_dependencies.dart` (deleted):** the
  per-screen factory that caused the leak; superseded by `AudioManager`.
- **`lib/features/audio/infrastructure/audio_players_audio_port.dart`:** SFX
  now uses a small pool of 3 `AudioPlayer`s (round-robin) instead of one
  shared instance, so concurrent/rapid SFX events no longer race a single
  player's `stop()`/`play()`. `AudioContext`/volume are set once per pooled
  player at construction instead of on every `play()` call. `usageType`
  corrected from `notification` to `game`.
- **`lib/features/audio/infrastructure/audio_players_music_port.dart`:**
  `_musicVolume` clamped `1.1` → `1.0`, then tuned to `0.6` per user request
  (music should sit quieter than SFX). Added an explicit `AudioContext`
  (`contentType: music`, `usageType: media`, `audioFocus: gain`) so the OS
  properly ducks (not kills) this stream against the SFX port's
  `gainTransientMayDuck` request.
- **`lib/features/game/presentation/game_screen.dart`:** wired to
  `AudioManager.instance` instead of `AudioDependencies`. Test injection seams
  (`widget.playGameAudio`, `widget.backgroundMusicController`) preserved
  unchanged — no test files needed modification.
- **`assets/audio/victory.mp3`:** re-encoded 48000 Hz → 44100 Hz (`ffmpeg
  -ar 44100 -codec:a libmp3lame -q:a 2`) to match the other three SFX assets;
  duration unchanged (4.203s). `ffmpeg` was installed via `scoop` (user-level,
  no admin) after `choco install ffmpeg` failed on a lock-file permission error
  — `choco` requires an elevated shell this environment doesn't have.

### Files Touched

- `lib/features/audio/infrastructure/audio_manager.dart` (new)
- `lib/features/audio/infrastructure/audio_dependencies.dart` (deleted)
- `lib/features/audio/infrastructure/audio_players_audio_port.dart`
- `lib/features/audio/infrastructure/audio_players_music_port.dart`
- `lib/features/game/presentation/game_screen.dart`
- `assets/audio/victory.mp3` (binary re-encode)
- `lib/features/audio/application/{background_music_controller,game_audio_event,music_port}.dart` (formatting only, via `dart format`)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (no new tests; same count as Phase 14.1 — see Limitations).
- `node tool/gen_levels.js --validate-only`: not applicable (no level files touched); re-ran anyway — ALL VALID: true, unaffected.

### New Tests

- None. See Limitations.

### Limitations

- **No automated regression test was added.** All five root causes are
  real-device/native-plugin behaviors (focus negotiation, native volume
  clamping, player resource lifecycle, sample-rate handling) that the
  existing fake-based unit tests (`_FakeAudioPort`, `_FakeSettingsRepository`)
  cannot exercise. Manual on-device verification is required to confirm the
  crash, ducking, distortion, and playback-rate fixes actually hold under real
  Android/iOS audio focus behavior.
- Manual emulator/device validation for this phase, and the still-pending
  manual validation for Phases 9–14.1, has not been performed.
- The SFX pool size (3) and music volume (0.6) are reasonable starting values,
  not tuned against a real device by ear; expect follow-up adjustment requests.

## Phase 16 — Figure Levels 16–20 (2026-06-23)

### Context

This branch (`feat/figure-levels`) extends the game from 15 to 20 levels.
Levels 16–20 are **fixed shape silhouettes** (heart, diamond, club, spade,
crown) instead of the random-rectangle boards used for 1–15, and gradually
increase in difficulty within that new sub-tier. `AppConfig.manualLevelCount
= 20` and its three call sites (`game_screen.dart`'s `hasNextLevel`,
`MergeProgressUseCase`, `SaveLevelCompletionUseCase`) were already wired in
by a prior session before this phase started; this phase supplied the actual
level content those call sites needed, plus a leftover generic-maze draft
"Level 16" in the working tree (not a figure, not from this tool) was
replaced outright.

### What Changed

**`tool/gen_levels.js`:**
- Added `keepLargestComponent(nodes)` and `rasterMask(W, H, predicate)` —
  rasterize a continuous formula onto an integer grid, keep only the largest
  4-connected component as a safety net against a thin extremity (e.g. a
  spike tip) pinching off at low resolution.
- Added five shape-mask functions: `heartNodeSet` (implicit heart curve),
  `diamondNodeSet` (Manhattan-distance rhombus), `clubNodeSet` (3-circle
  trefoil + stem), `spadeNodeSet` (anisotropically-widened heart curve +
  stem + flared foot), `crownNodeSet` (5 individually-tapered triangular
  spikes + jewel + rim band + flared base).
- Added `generateFigureLevel(...)`, a sibling to the existing `generateLevel`
  reusing `partitionNodes`/`Builder`/`flipInteriorGapArrows`'s neighbors, but:
  - calls **both** `weave()` and `weaveH()` (an irregular blob needs
    grid-adjacency in both axes; the random tiers only need `weave()` because
    they're row-aligned rectangles);
  - enforces **all four directions present** (each ≥ `max(2, 10%)` of the
    arrow count, capped at 45% for any one direction) — stricter than the
    random tiers' "at least one vertical, ≤60%", which is why several of
    levels 1–15 are missing a direction entirely;
  - **does not** call `hasInteriorGapExit`/`flipInteriorGapArrows`. That
    check exists to catch an accidental hole in an otherwise-rectangular
    board (the Phase 14 bug). A deliberate figure silhouette is concave by
    design and mathematically simply connected (no enclosed holes) — every
    "missing" cell inside its bounding box is part of the shape's own visible
    edge. Applying the bbox-relative check rejected ~100% of valid partitions
    in testing, so it's a false-positive generator for this shape class, not
    a real defect check.
- Added `FIGURE_LEVEL_DEFS` (16–20) and `buildFigureLevels()`.
- Added CLI mode `--generate-figures`: reads the on-disk JSON, keeps only
  `number <= 15` verbatim, regenerates 16–20, validates the full 20-level set,
  writes only if valid (same write-only-if-valid contract as `--generate`).
- Generalized two hardcoded-`15` spots so future expansion doesn't need a
  code change: `--validate-only`'s count gate now checks the level numbers
  form a contiguous `1..N` sequence (not `=== 15`); the hard-tier difficulty
  check now asserts "every number ≥ 11 present is `hard`" instead of
  "11–15 are hard".
- `validateAll`'s `gapExit=` column reports `Y(figure-ok)` for levels with
  `metadata.generationType === 'figure'` instead of failing them; `hardRects`
  threshold is now `< hardLevels.length` (was hardcoded `< 5`) so it scales
  with the now-10-level hard tier.

**`assets/levels/manual_levels.json`:** levels 1–15 byte-identical (verified —
`git diff` against the last commit shows pure insertions, zero deletions, for
the 1–15 region); 16–20 replaced with the generated figure levels.

**`test/features/game/infrastructure/manual_levels_test.dart`:** updated the
handful of assertions with literal counts (`hasLength(15)` → `20`,
`levels.last.number` → `20`, `List.generate(15,...)` → `20`, added
`manual-020` id check). Scoped `should_have_no_interior_gap_exits` to exclude
`generationType == 'figure'` levels, mirroring the JS-side reasoning above.
Every other test already iterates generically over all loaded levels or uses
open-ended `>= 11` range checks, so 16–20 are covered with zero edits.

**`docs/LEVEL_AUTHORING.md`:** level count 15→20; new §15 documenting the
figure-level generation model, the `--generate-figures` flag, and — as a
concrete record for the next person tuning a shape — the spade/crown
solvability lessons below.

### Iteration History (what didn't work, and why)

Three rounds of user feedback shaped the final shapes/densities:

1. **"Arrows are too little [small], hard to play."** Initial club/spade/star
   used `maxPathLen: 3` (2-edge arrows), giving 49/52/52 arrows respectively —
   visually cluttered. Fix: raised `maxPathLen` to 4–5 for levels 18–20 (and
   `FIGURE_MAX_RETRIES` 8000→20000, since longer arrows have a much lower
   valid-partition rate). Result: fewer, longer, more readable arrows
   (high-30s instead of low-50s).
2. **"That spade doesn't look like one" / "the crown is not a crown."** Two
   separate shape redesigns, same underlying lesson:
   - A wide-ellipse spade body looked more distinctly spade-shaped in
     isolation but was a near-total solvability dead end (0 solved in 300+
     sampled partitions — a round, densely-packed body leaves almost no
     resolvable lane structure for the greedy solver). Replaced with a
     narrower, proven-solvable heart-curve body (anisotropically widened for
     better shoulders) plus a narrow stem that flares to a small triangular
     foot — the flared foot is what actually reads as "spade".
   - A first crown used one shared linear-taper formula for all 5 spikes,
     packed too close together — rendered as illegible noise rather than 5
     points. Fixed by defining each spike's triangle explicitly with
     consistent gaps (clearly separated points, center spike tallest, single
     jewel on the center tip). That shape was then *still* unsolvable (0/1500
     across maxPathLen 3–5) until the solid rim band — a large, dense,
     near-rectangular region — was shrunk; a large near-rectangle has the
     same low-solvability problem as the wide ellipse, just less obviously.
   - **General lesson recorded in §15:** when tuning a figure mask, check the
     actual greedy-solved rate over a few hundred/thousand sampled partitions
     before fixing a density band — coverage-success and connectivity can
     both be 100% while solvability is silently ~0%, and that only shows up
     by exhausting the retry budget (or, faster, by testing the rate
     directly rather than waiting on the real generator's retry loop).
3. **"Delete the star, replace it with something in a similar context but not
   that one."** Level 20 changed from a 5-pointed star to a crown (same
   "card/game symbol" family as heart/diamond/club/spade, user's pick from a
   short list of options).

A visual experiment to address node-dot prominence (shrinking/dimming the
board's node dots so arrows read more clearly) was tried and reverted at the
user's request after testing; a different, better fix for the same underlying
concern (covered nodes rendered near-invisible, only lighting up once the
arrow covering them escapes) landed independently in
`graph_board_painter.dart` during this session.

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (same count as Phase 15 — no tests added or
  removed, only literal-count assertions updated).
- `node tool/gen_levels.js --validate-only`: ALL VALID: true for all 20
  levels; `comp=1`, `free=-`, `shared=-`, `solvable=true` throughout;
  `gapExit=Y(figure-ok)` for 16–20 (expected — see above), `-` for 1–15.

### New Tests

- None (existing tests generalized/updated; see manual_levels_test.dart notes
  above).

### Limitations

- Manual emulator/device validation of levels 16–20 (does the figure
  silhouette read correctly on a real screen size, is pan/zoom comfortable
  for these larger boards) has not been performed — this phase's iteration
  was guided by ASCII-raster inspection and the validator's structural
  checks, not an on-device screenshot.
- Crown's arrow count (28) ended up below club/spade/diamond (37 each)
  because every denser variant that was tried had a near-zero solvable rate;
  this breaks strict "more arrows every level" progression within the figure
  sub-tier, though the hard tier's overall average is still far above medium.
- The five figure-mask functions hardcode their grid constants (no shared
  "scale" parameter) — intentional per `docs/LEVEL_AUTHORING.md` §15
  guidance to tune each shape's actual solved rate individually rather than
  deriving sizes from a formula.

### Next Recommended Phase

Manual on-device validation of levels 16–20 (figure readability, pan/zoom
comfort, that all-four-direction arrows feel natural to play), alongside the
still-pending Phase 15 audio on-device validation and the long-pending manual
backend/emulator smoke test (auth, sync, leaderboard against the Docker
backend) for Phases 9–14.1.

## Phase 15.1 — Pause/Resume Music on App Background (2026-06-24)

### Context

Follow-up to Phase 15. User reported that backgrounding the app during a
level (pressing home / switching to another app on the phone) left the
background music playing — nothing in `AudioManager` observed app
visibility, so the music kept running on the OS audio session even though
the app itself was no longer in the foreground.

### What Changed

- **`lib/features/audio/infrastructure/audio_manager.dart`:** `AudioManager`
  now `extends WidgetsBindingObserver` and registers itself
  (`WidgetsBinding.instance.addObserver(this)`) once, in the singleton's
  private constructor. Overrides `didChangeAppLifecycleState`:
  - `AppLifecycleState.paused` (app backgrounded) → stops the music, via a
    new `_musicPausedForBackground` flag guard (idempotent; only acts once
    per background transition, and only if a screen currently holds a music
    claim).
  - `AppLifecycleState.resumed` (app foregrounded again) → restarts the
    music automatically, but only if `_musicPausedForBackground` was set
    *and* `_musicClaims > 0` — so it doesn't start music out of nowhere if
    the user backgrounded from a screen that wasn't playing music (e.g. the
    level-selection screen).
  - `_musicPausedForBackground` is intentionally separate from the existing
    `_musicClaims` reference count (Phase 15's Next Level fix): claims track
    *which screen wants music*; the new flag tracks *whether the OS, not a
    screen, silenced it*. Keeping them independent means the still-active
    `GameScreen` doesn't need to do anything on resume — `AudioManager`
    restores playback on its own.

### Files Touched

- `lib/features/audio/infrastructure/audio_manager.dart`

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (no new tests — see Limitations).
- `node tool/gen_levels.js --validate-only`: not applicable, no level files touched.

### New Tests

- None. `AppLifecycleState` transitions are not simulated by this project's
  widget tests; see Limitations.

### Limitations

- No automated test covers this — same class of gap as the rest of Phase 15
  (native/OS-level behavior that fake-based unit tests can't exercise).
  Manual on-device check needed: start a level, background the app, confirm
  the music stops; foreground it again, confirm the music resumes on its
  own without navigating away from the screen.
- Only `paused`/`resumed` are handled. `inactive` (brief OS transitions, e.g.
  notification shade, incoming call) and `detached`/`hidden` are
  intentionally not treated as "background" — reacting to `inactive` would
  likely cause audible stutter on transient state changes that aren't a
  real backgrounding.

### Next Recommended Phase

Same as above (Phase 16's recommendation) plus: fold this on-device check
into the same manual validation pass as the rest of Phase 15 (crash-free
across many level transitions, ducking, no crackling, normal-speed SFX,
music survives Next Level, and now also survives background/foreground).

## Phase 17 — Game Board Rendering Polish (2026-06-23/24)

### Context

User-reported visual/usability issues on the game board, distinct from the
gameplay-rules work in Phases 9–14.1: nodes always rendered as solid opaque
white circles regardless of game state, the arrow color palette was muted
pastel, and on dense boards (hard tier, the new figure levels) arrowhead
tips visually drew over neighbouring arrows and taps near a cluster of
arrows could register the wrong one. Branch `feat/frontend-rendering`,
merged via two PRs (#4, #5) onto `develop`.

### What Changed

- **`lib/core/theme/app_theme.dart`:** added a 5-color neon palette —
  `neonBlue`, `neonGreen`, `neonYellow`, `neonPink`, `neonPurple`.
- **`lib/features/game/presentation/widgets/graph_board_painter.dart`:**
  - `_colorForArrow` switched from the old 4-color pastel palette
    (`neonMint`, two hardcoded hex pinks/blues, `pastelAmber`) to the new
    5-color neon palette.
  - Node rendering now depends on coverage: a node still occupied by an
    active arrow (`coveredNodeIds`, built from `session.activeArrows`'
    `orderedNodeIds`) is drawn almost invisible (alpha 0.08, radius 3). A
    node not covered by any active arrow — i.e. freed once the arrow over
    it escapes — gets a lighter/translucent halo+dot (alpha 0.16 / 0.5)
    instead of the previous fully-opaque white circle. Net effect: at level
    start, every node is covered (per the no-free-nodes rule), so only
    arrows are visible; nodes light up progressively as arrows escape.
  - Stroke width and arrowhead length/width are now capped relative to the
    board's pixel cell size (`layout.step`) instead of fixed constants:
    `_arrowStrokeWidth` and the length/width calc inside `_drawArrowHead`
    use `math.min(originalConstant, cellSize * factor)`, floored so they
    never disappear. On boards spacious enough (cell ≳ 43px — true for most
    of levels 1–15) this is a no-op (same fixed 12px stroke / 18px head as
    before); on dense boards it shrinks proportionally so the arrowhead tip
    never reaches far enough to draw over a neighbouring arrow.
- **`lib/features/game/presentation/widgets/graph_board_layout.dart`:**
  added a `step` field (pixel distance between adjacent grid coordinates),
  computed in `fromGraph` and exposed for the painter and hit-tester to
  scale against.
- **`lib/features/game/presentation/widgets/graph_board_hit_tester.dart`:**
  `hitSlop` (tap tolerance) is no longer a fixed 28px radius — it now scales
  with `layout.step`, capped at 45% of cell spacing (so the tolerance radius
  around one node never reaches halfway to its neighbour) and floored at
  12px. Unaffected for any board with cell size ≥ ~62px (cap stays at the
  old 28px); on dense boards this prevents a single tap from matching
  multiple adjacent arrows depending on iteration order.
- **`lib/features/game/presentation/widgets/graph_board.dart`:** the
  board's `AspectRatio` now matches the level's own node-bounding-box
  aspect ratio (`_boardAspectRatio`, clamped to `[0.6, 1.6]`) instead of
  always forcing a square. Square-ish levels (most of 1–15) are unaffected;
  a level that's notably taller or wider than the other axis gets real
  extra pixels on its longer dimension instead of that space going unused.

### Files Touched

- `lib/core/theme/app_theme.dart`
- `lib/features/game/presentation/widgets/graph_board_painter.dart`
- `lib/features/game/presentation/widgets/graph_board_layout.dart`
- `lib/features/game/presentation/widgets/graph_board_hit_tester.dart`
- `lib/features/game/presentation/widgets/graph_board.dart`

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (no new tests — see Limitations).
- `node tool/gen_levels.js --validate-only`: not applicable, no level files
  touched.

### New Tests

- None. Presentation-only visual/interaction tuning; no test file asserts
  exact pixel colors, node alpha, or hit-slop radius values.

### Limitations

- No automated regression test for the visual change (node alpha, neon
  colors) or the hit-slop/aspect-ratio tuning — these are exactly the kind
  of presentation-layer behavior this project's fake-based widget tests
  don't assert pixel-level detail on. Manual on-device/emulator check still
  recommended: confirm nodes are nearly invisible at level start and light
  up as arrows escape, confirm dense levels (hard tier, figure levels
  16–20) no longer show arrowhead tips overlapping neighbouring arrows, and
  confirm taps register the intended arrow on a dense board.

## Phase 18 — Pinch-to-Zoom Reliability Fix (2026-06-24)

### Context

Follow-up to Phase 17. User reported that pinch-to-zoom on the board is
hard to "grab" — the gesture frequently fails to start cleanly, requiring
multiple attempts.

### Root Cause

`GraphBoard`'s `InteractiveViewer` is nested inside the page-level
`ListView` in `game_screen.dart`'s `_GameReadyView` (the whole screen —
HUD, board, buttons — scrolls as one list). This is a known Flutter gotcha:
when a pinch gesture starts, the first finger's initial contact can be
claimed by the ancestor `ListView`'s vertical-drag recognizer (via Flutter's
gesture arena) before the second finger lands and `InteractiveViewer`'s own
`ScaleGestureRecognizer` can claim both pointers. Once the ancestor has
"won" one of the two pointers, the scale recognizer never gets a clean
two-finger gesture, so the pinch doesn't register reliably — the user has
to land both fingers almost perfectly simultaneously to avoid the race.

### What Changed

- **`lib/features/game/presentation/widgets/graph_board.dart`:**
  - Added `onInteractionActiveChanged: ValueChanged<bool>?` to `GraphBoard`.
  - `_GraphBoardState` now wraps the board's `Stack` (the `InteractiveViewer`
    + reset-view button) in a `Listener` that tracks `_activePointers` via
    `onPointerDown`/`onPointerUp`/`onPointerCancel`. `_onPointerCountChanged`
    calls `widget.onInteractionActiveChanged` only on the 0→1 and 1→0
    transitions (not on every pointer event), reporting `true` while at
    least one finger touches the board.
- **`lib/features/game/presentation/game_screen.dart`:**
  - `_GameScreenState` gained `bool _lockPageScroll`, flipped by a callback
    passed as `GraphBoard.onInteractionActiveChanged` (via `_GameReadyView`).
  - `_GameReadyView`'s `ListView` now sets
    `physics: lockPageScroll ? NeverScrollableScrollPhysics() : ClampingScrollPhysics()`.
  - Net effect: as soon as any finger touches the board, the page-level
    `ListView` stops being scrollable, so it can never claim a pointer that
    started on the board — `InteractiveViewer`'s scale recognizer gets
    uncontested control of the gesture. The lock releases the instant all
    fingers lift, so normal page scrolling (e.g. on level-complete, to reach
    the buttons) is unaffected.

### Files Touched

- `lib/features/game/presentation/widgets/graph_board.dart`
- `lib/features/game/presentation/game_screen.dart`

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 122/122 passed (no new tests — see Limitations).
- `node tool/gen_levels.js --validate-only`: not applicable, no level files
  touched.

### New Tests

- None. Multi-touch gesture-arena races between a `Listener`/`InteractiveViewer`
  and an ancestor `Scrollable` are not reproducible through this project's
  widget-test harness (synthetic `tester.tap`/`tester.drag` calls inject a
  single synthetic pointer sequence, not the real two-finger race condition
  being fixed). Same category of gap as Phase 15/15.1's native-behavior
  fixes.

### Limitations

- Manual on-device/emulator verification still needed: confirm a pinch
  gesture started anywhere on the board reliably scales on the first
  attempt, and confirm the page still scrolls normally via touches that
  start outside the board (HUD, buttons, whitespace).
- This commit was pending at write time — see `harness/context/phase_registry.md`
  for status once merged.

### Next Recommended Phase

Manual on-device validation pass covering Phases 15/15.1/17/18 together
(audio crash/ducking/crackling/playback-rate/background-pause, board node
visibility and neon colors, dense-level tap accuracy, and pinch-to-zoom
reliability) — this is now the largest block of "implemented but only
verified by automated tests" work in the project. After that: the
long-pending manual backend/emulator smoke test (auth, sync, leaderboard
against the Docker backend) for Phases 9–14.1.

## Phase 19 — Level Audit & Validation (figure-aware gap-exit fix) (2026-07-09)

### What Changed

- Audited levels 1–15 (no regression — all still `gapExit=-`, clean structure)
  and deep-audited figure levels 16–20 against the exact Phase 14 gap-exit bug
  class, Phase 14.1 self-intersection, shape validity, disjointness,
  no-free-nodes, solvability, density, and direction variety.
- Found 5 real interior-gap-exit defects in the shipped figure levels (18×1,
  19×1, 20×3) — `generateFigureLevel`'s blanket exemption from
  `hasInteriorGapExit` hid genuine hidden-blocker escapes, not just harmless
  shape concavities.
- Added `hasRealInteriorGapExit(dj)` to `tool/gen_levels.js`: a figure-aware
  gap check that only flags a gap as defective when the head sweep, after
  passing through it, reaches another arrow's node (a real hidden blocker) —
  a harmless silhouette concavity (gap leading only to the true boundary) is
  no longer rejected.
- Wired the new check into both `generateFigureLevel` (reject-and-retry) and
  `validateAll` (figures now validated for real gap-exits instead of being
  fully exempted).
- Raised `FIGURE_MAX_RETRIES` from 20,000 to 100,000: quantified exhaustion
  risk under the stricter check was as high as ~5% for spade (19) and ~1.8%
  for crown (20) at 20,000 retries; 100,000 drives this to negligible
  (<1e-6) for all five figures. Regeneration only needed 1,026–4,518 attempts
  per figure in practice.
- Regenerated `assets/levels/manual_levels.json` via `--generate-figures`
  (levels 16–20 only); levels 1–15 verified byte-identical.
- Fixed a compounding rendering defect found during the audit: `hitSlop`'s
  `minHitSlop` floor (12px) exceeded `cellSize * 0.45` on every figure level
  (steps ~15.3–20.3px), silently overriding the documented "never reach
  halfway to neighbour" invariant — worst on crown (56% over cap). Lowered
  `minHitSlop` to 6px in `graph_board_hit_tester.dart`, which clears the cap
  with margin on all five figures.
- Confirmed via independent simulation (not reusing generator code): 0
  self-intersecting arrows across all 166 arrows in levels 16–20; arrowhead
  length/width coefficients (0.42/0.26 of step) stay under half-step at all
  measured figure steps, so no arrowhead-overlap risk; the board `AspectRatio`
  clamp `[0.6, 1.6]` works correctly (only crown's 1.8 raw ratio is clamped).

### Files Touched

- `tool/gen_levels.js`
- `lib/features/game/presentation/widgets/graph_board_hit_tester.dart`
- `assets/levels/manual_levels.json` (levels 16–20 only; 1–15 unchanged)
- `test/features/game/infrastructure/manual_levels_test.dart`
- `test/features/game/presentation/graph_board_hit_tester_test.dart` (new)

### Verification Results

- `flutter analyze`: passed, 0 issues.
- `flutter test`: 124/124 passed (122 baseline + 2 new).
- `node tool/gen_levels.js --validate-only`: `ALL VALID: true` (previously
  `false` — levels 18/19/20 showed `gapExit=Y` under the corrected check
  before regeneration).

### New Tests

- `should_have_no_real_interior_gap_exits_in_figure_levels` — figure-aware
  gap-exit regression test mirroring `hasRealInteriorGapExit`.
- `should_keep_hit_slop_floor_below_half_cell_on_dense_figure_boards` — new
  file `graph_board_hit_tester_test.dart`, regression-tests the `minHitSlop`
  invariant against the real shipped figure-level layouts.

### Limitations

- Rendering audit (arrowhead overlap, `AspectRatio` clamp, `hitSlop`) was
  static/analytical against the painter/hit-tester formulas and real level
  geometry, not a live emulator/on-device pass — still recommended as part
  of the standing Phase 15/15.1/17/18 manual-verification backlog.
- Crown (20) and spade (19) remain the tightest figures by raw solvable-
  partition rate (~0.02%/0.015% post-fix); if a future geometry change makes
  them tighter still, revisit mask tuning per `LEVEL_AUTHORING.md §15` rather
  than raising `FIGURE_MAX_RETRIES` further.

### Next Recommended Phase

Manual on-device validation pass covering Phases 15/15.1/17/18/19 together
(audio, board rendering/neon colors, dense-level tap accuracy including the
new figure-level `hitSlop` fix, pinch-to-zoom, and the regenerated crown/
spade/club figure levels) — then the long-pending backend/emulator smoke test
for Phases 9–14.1.

## Phase 20 — Main Menu Redesign & Game Rebrand (2026-07-09)

### What Changed

- **Rebrand:** "Arrow POC" → **Nodus** (Latin for "knot"/"node" — the core
  mechanic is untangling a graph of nodes, so the name is on-theme without
  reusing generic words like "Puzzle"/"Arrow"/"Game"). Changed only in
  `appTitle` in both ARB files; `MaterialApp.onGenerateTitle` in
  `arrow_poc_app.dart` already reads that key, so the OS-level app title
  updates automatically — no separate `title:` constant existed to edit.
  `homeSubtitle` replaced with a short tagline ("Untangle the knot. One exit
  at a time." / Spanish equivalent) in both locales.
- **`HomeScreen` rewritten** (`lib/features/home/presentation/home_screen.dart`)
  from a plain `Column` to a `StatefulWidget` with:
  - `_MenuBackgroundPainter` (`CustomPainter`) — 4 soft, blurred, neon-tinted
    glows drifting in slow circular orbits over `AppTheme.background`, driven
    by one looping `AnimationController` (18s). Pure geometry (`Canvas.drawCircle`
    + `MaskFilter.blur`), no images/video/shaders/physics — cheap on low-end
    Android.
  - Large display title, gradient-masked (`neonMint`→`neonBlue`) via
    `ShaderMask`.
  - `_MenuButton` — shared tactile button widget (Play=filled/`neonMint`,
    Settings=outlined/`neonPurple`) with `AnimatedScale` press-down feedback
    (0.97x) and a glow `BoxShadow` that softens on press. Reuses the existing
    neon palette; no new colors introduced.
  - `_DebugRow` — backend URL demoted to 50%-opacity, 11px text near the
    bottom, replacing the old prominent `Card`.
- **Android app label**: `android:label` in `AndroidManifest.xml` changed
  `frontend_poc_arrow` → `Nodus`.
- **iOS**: no `ios/` platform directory exists in this project — confirmed via
  glob before starting; nothing to change, no manual step needed.

### Files Touched

- `lib/features/home/presentation/home_screen.dart`
- `lib/core/localization/l10n/app_en.arb`
- `lib/core/localization/l10n/app_es.arb`
- `android/app/src/main/AndroidManifest.xml`

### Verification Results

- `flutter analyze`: passed with 0 issues.
- `flutter test`: 124/124 passed (0 new — existing tests locate Play/Settings
  by localized text via `find.text`, not widget type, so they were unaffected
  by the `FilledButton`/`OutlinedButton` → `_MenuButton` swap).
- `node tool/gen_levels.js --validate-only`: not applicable (no level files
  touched).

### New Tests

- None. Presentation-only visual redesign; existing navigation/localization
  tests already cover the preserved behavior (Play → levels, Settings →
  settings, backend URL still rendered).

### Assets

- None added. The redesign uses only existing theme colors, system fonts, and
  procedural (`CustomPainter`) graphics — no images, SVGs, fonts, or Lottie
  files were needed to hit "premium" visual quality, so `assets/menu/` was not
  created and `pubspec.yaml` was not touched.

### Before / After

- **Before:** static dark `Column` — "Arrow POC" plain text title, one-line
  grey subtitle, a prominent bordered `Card` showing the backend URL in neon
  mint, then a solid `FilledButton` "Play" and bordered `OutlinedButton`
  "Settings".
- **After:** full-bleed animated background of slowly drifting neon glows
  behind a large gradient-text "Nodus" wordmark and tagline; Play/Settings are
  now glowing, press-responsive pill buttons; the backend URL is a small,
  half-opacity debug line tucked near the bottom instead of a prominent card.

### Limitations

- Manual on-device verification of animation smoothness on a genuinely
  low-end Android device is still pending (analytical review: single
  `AnimationController`, 4 blurred circles, no per-frame allocations in
  `paint()` — expected to be cheap, not device-measured).
- No app-icon regeneration was performed or required by this phase (task item
  5's "icon regen" is N/A — the task only asked for the app *label*, not a new
  icon asset).

### Next Recommended Phase

Manual on-device validation pass covering the still-pending Phases
15/15.1/17/18/19/20 items together (audio, board rendering, dense-level tap
accuracy, pinch-to-zoom, and the new animated main menu) — then the
long-pending backend/emulator smoke test for Phases 9–14.1.

## Phase 21 — Backend Progress Reset

### What Changed

- Backend: added an authenticated `DELETE /progress` endpoint (204 No
  Content, `JwtAuthGuard`, 401 if unauthenticated) that clears every progress
  row for the calling user. New `ResetProgressUseCase` calls a new
  `ProgressRepository.deleteByUserId`, implemented in
  `PrismaProgressRepository` via `prisma.playerProgress.deleteMany`.
- Frontend network layer: `ApiClient`/`HttpApiClient` gained a `delete()`
  method (mirrors `get`/`post`/`put`, same auth-header/error-decoding path).
- Frontend progress feature: `RemoteProgressRepository` gained
  `resetProgress()`; `ApiRemoteProgressRepository` implements it via
  `_apiClient.delete('/progress', authenticated: true)`. New
  `ResetRemoteProgressUseCase` (application layer) calls the remote reset
  first, then the existing `LocalProgressRepository.resetProgress()` — so a
  thrown exception from the remote call leaves local progress untouched with
  no extra guard needed.
- Settings presentation: `SettingsScreenController.resetRemoteProgress()`
  returns a `RemoteResetResult` enum (`success` / `offline` /
  `unauthenticated` / `failed`), distinguishing an `ApiException` with
  `statusCode == null` (network-level failure — offline; also clears local
  progress as a fallback) from `statusCode == 401` (not authenticated — local
  progress is *not* cleared) from any other status (generic failure — local
  progress is *not* cleared). `SettingsScreen` renders a new "Reset remote
  progress" card (same `Card`/padding/typography as the existing controls),
  with its own confirm dialog and a result-specific snackbar; when logged
  out, the card is replaced with a "Log in to reset remote progress." message
  instead of a disabled button.
- Localization: added `resetRemoteProgress`, `resetRemoteProgressConfirmation`,
  `remoteProgressReset`, `resetRemoteProgressLoginRequired`,
  `remoteResetOfflineMessage`, `remoteResetFailedMessage` to both
  `app_en.arb`/`app_es.arb`; regenerated `app_localizations*.dart` via
  `flutter gen-l10n`.

### Files Touched

Frontend (`frontend-poc-arrow`):
- `lib/core/network/api_client.dart`
- `lib/core/network/http_api_client.dart`
- `lib/features/progress/application/remote_progress_repository.dart`
- `lib/features/progress/application/reset_remote_progress_use_case.dart` (new)
- `lib/features/progress/infrastructure/api_remote_progress_repository.dart`
- `lib/features/progress/infrastructure/local_progress_dependencies.dart`
- `lib/features/settings/presentation/settings_screen_controller.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/game/presentation/game_ui_keys.dart`
- `lib/core/localization/l10n/app_en.arb`, `app_es.arb`,
  `app_localizations.dart`, `app_localizations_en.dart`,
  `app_localizations_es.dart`
- `test/features/auth/auth_integration_test.dart` (fake `ApiClient` needed
  the new `delete` method)
- `test/features/settings/settings_test.dart` (5 new tests)

Backend (`backend-poc-arrow`):
- `src/application/ports/progress.repository.ts`
- `src/application/progress/reset-progress.use-case.ts` (new)
- `src/infrastructure/repositories/prisma-progress.repository.ts`
- `src/interfaces/http/progress/progress.controller.ts`
- `src/modules/progress.module.ts`
- `test/api-core.e2e-spec.ts` (in-memory fake needed `deleteByUserId`; 2 new
  e2e tests)

### Backend Endpoint

`DELETE /progress` — authenticated (`JwtAuthGuard`, same as the other
`/progress` routes) — clears all `PlayerProgress` rows for
`request.user.id`. Returns `204 No Content` on success, `401` if
unauthenticated. This endpoint did not previously exist; it was newly
implemented (only `POST /progress/sync` and `GET /progress/me` existed
before this phase).

### Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: 129/129 passed (124 pre-existing + 5 new).
- `node tool/gen_levels.js --validate-only`: ALL VALID: true (no level files
  touched).
- Backend `tsc --noEmit`: clean.
- Backend `npm run test:e2e`: 10/10 passed (8 pre-existing + 2 new).
- Backend `npm test`: 9/9 passed (unaffected).

### New Tests

- `should_reset_remote_and_local_progress_when_remote_succeeds`
- `should_clear_local_progress_only_when_backend_is_unreachable`
- `should_report_unauthenticated_without_clearing_local_progress_on_401`
- `should_report_unauthenticated_and_disable_action_when_logged_out`
- `should_report_generic_failure_without_clearing_local_progress`
- `should_delete_progress_when_user_is_authenticated` (backend e2e)
- `should_reject_progress_reset_when_unauthenticated` (backend e2e)

### Limitations

- Manual on-device/live-backend verification of the four UI paths (button
  render, live reset, offline snackbar, 401 message) was not performed in
  this pass — covered by unit tests against fakes only.
- Still stacked on the same still-pending manual on-device validation queue
  as Phases 9–20.

### Next Recommended Phase

Manual on-device/emulator validation pass — ideally combined with the
already-queued Phase 9–20 manual checklist — including this phase's live
backend up/down and login/logout reset-button behavior.

## Phase 21.1 — Main Menu Bottom Navigation & Login Progress Sync (2026-07-09)

Extends Phase 21, same branch (`feat/phase-21-backend-progress-reset`),
uncommitted. Two independent tasks, both frontend-only; no backend changes
needed.

### What Changed

**Task A — Login progress sync:**
- `LocalProgressRepository` gained `getLastSyncedUserId()` /
  `setLastSyncedUserId(String?)`, backed by a new
  `progress.lastSyncedUserId` SharedPreferences key.
- New `SyncProgressOnLoginUseCase` (application layer): if the stored
  last-synced user id is non-null and differs from the newly logged-in
  user's id, local progress is cleared before syncing (prevents user A's
  local unlocks leaking into user B's account on a shared device); if it
  matches or is null (anonymous/guest session), the existing
  `SyncProgressUseCase`/`MergeProgressUseCase` merge policy runs
  unchanged, preserving the "guest progress merges into new account" path.
- `LocalProgressDependencies.createSyncProgressOnLoginUseCase()` wires it
  through the existing DI factory pattern.
- `AuthScreenController` takes an optional `syncProgressOnLogin` callback,
  invoked with `session.user.id` after a successful login/register,
  wrapped in try/catch so a sync failure never blocks login (matches the
  existing non-fatal settings-screen sync UX).
- `AuthScreen._createController()` injects it via
  `LocalProgressDependencies.createSyncProgressOnLoginUseCase()`.

**Task B — Main menu bottom navigation:**
- `HomeScreen`'s two stacked Play/Settings buttons replaced with a 4-item
  bottom row (new `_MenuNavButton`, icon + label, same neon glow styling
  as the removed `_MenuButton`): Levels, Leaderboard (pushes with no level
  argument → global board), Settings, and a disabled "Game Mode"
  placeholder (`onPressed: null`, reserved for a future 3D mode).
- Nodus wordmark, animated `_MenuBackgroundPainter` background, and the
  de-emphasized backend-URL `_DebugRow` all kept in their Phase 20
  positions.
- Only `gameMode` was a genuinely new localization key — `levels`,
  `leaderboard`, `play`, `settings` already existed. Added to both
  `app_en.arb`/`app_es.arb`, regenerated via `flutter gen-l10n`.

### Files Touched

- `lib/features/progress/application/local_progress_repository.dart`
- `lib/features/progress/application/sync_progress_on_login_use_case.dart` (new)
- `lib/features/progress/infrastructure/shared_preferences_local_progress_repository.dart`
- `lib/features/progress/infrastructure/local_progress_dependencies.dart`
- `lib/features/auth/presentation/auth_screen_controller.dart`
- `lib/features/auth/presentation/auth_screen.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/core/localization/l10n/app_en.arb`, `app_es.arb`
- `test/widget_test.dart` (updated for new bottom-nav labels)
- `test/features/settings/settings_test.dart`,
  `test/features/progress/local_progress_test.dart` (fake repositories
  needed the 2 new interface methods)

### Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: 129/129 passed (no net change in count — 2 tests updated
  for new UI, no new dedicated tests added; see Limitations).
- `node tool/gen_levels.js --validate-only`: ALL VALID: true (no level
  files touched).

### Backend Changes Required

None. Task A is achieved entirely with the existing `GET /progress/me` +
local/remote merge machinery; no new/changed endpoint, response shape, or
auth behavior was needed.

### Limitations

- No dedicated automated test was added for the login-identity-switch
  logic (`SyncProgressOnLoginUseCase`'s clear-before-sync branch) or for
  `AuthScreenController`'s new sync-on-login wiring — `AuthScreenController`
  has no existing test file to extend. This is a coverage gap, not a
  known defect; flagged for a follow-up phase rather than added here to
  stay within this phase's stated scope.
- Manual on-device validation of both tasks — 4-item bottom nav layout,
  user-A/user-B login-switch progress isolation, and offline-login
  graceful degradation — was not performed in this pass; stacked on the
  same pending manual-validation queue as Phases 9–21.

### Next Recommended Phase (superseded — see Phase 21.2 below for the
identity-switch test coverage that was originally deferred here)

## Phase 21.2 — Leaderboard Display Fix & Progress Save Regression Coverage (2026-07-09)

Extends Phase 21/21.1, same branch (`feat/phase-21-backend-progress-reset`),
uncommitted. Two independent tasks; no backend changes needed for either.

### Task A — Root Cause & Fix

**Symptom:** tapping "Leaderboard" from the main menu opened the leaderboard
screen but it always rendered empty.

**Root cause:** the Phase 21.1 main-menu button pushed `AppRoutes.leaderboard`
with **no argument**, so `LeaderboardScreen.levelNumber` was `null`.
`LeaderboardScreen._loadEntries()` hard-returns `const <LeaderboardEntry>[]`
whenever `levelNumber == null`, so the fetch never even reached the API. The
backend only exposes `GET /leaderboard/:levelId` — there is no
global/all-levels endpoint — so a true aggregate leaderboard is not
achievable without a backend change.

**Fix (frontend-only):** new `LeaderboardLevelPickerScreen`
(`lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart`,
route `AppRoutes.leaderboardLevelPicker`) lists all levels (via the existing
`LocalLevelDependencies.createGetLocalLevelsUseCase()`) and navigates to the
existing, unmodified `LeaderboardScreen(levelNumber: n)` on tap. `HomeScreen`'s
Leaderboard button now pushes the picker route instead of `AppRoutes.leaderboard`
directly. `LeaderboardScreen`, `GetLeaderboardUseCase`, `ApiLeaderboardRepository`
were audited and are unchanged — they already worked correctly once given a
valid level number.

### Task B — Root Cause & Verification

**Symptom (as reported):** completing a level and backing out (instead of
tapping "Next Level") does not save progress.

**Root cause: did not reproduce.** `GameScreenController.activateArrow`
already calls `unawaited(_saveCompletionOnce(result.session))` synchronously
on the `GameStatus.victory` transition, guarded by the existing
`_completionSaved` flag for idempotency — independent of the "Next Level"
button, which only navigates (`_openNextLevel` in `game_screen.dart`
performs no save of its own). The save is a fire-and-forget
`SharedPreferences` write not tied to widget lifecycle, so it completes even
if the screen is popped immediately after. No production code was changed
for Task B.

**Delivered instead: regression test coverage** proving the above holds, so
a future regression is caught automatically:
- `should_save_completion_on_victory_before_next_level_is_tapped` — save and
  remote-notify both fire exactly once on the victory transition itself,
  before any victory-overlay button is ever tapped.
- `should_not_duplicate_completion_save_when_victory_overlay_is_tapped_repeatedly`
  — tapping "Retry" on the victory overlay does not re-trigger the save.
- `should_persist_completion_save_when_player_backs_out_immediately_after_victory`
  — the save is already recorded before the player backs out via the
  app-bar back button, without ever tapping "Next Level"; level-selection
  reflects it on return.

### Files Touched

- `lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart` (new)
- `lib/core/routing/app_routes.dart`
- `lib/features/home/presentation/home_screen.dart`
- `test/features/game/presentation/playable_game_ui_test.dart` (3 new tests;
  `_TestGameApp`/`_TestManualLevelsApp` test harnesses extended with
  injectable `saveLevelCompletion`/`onSaveLevelCompletion` and a
  `level1Override` for deterministic single-tap victories)

### Verification Results

- `flutter analyze`: passed with no issues.
- `flutter test`: 132/132 passed (129 + 3 new).
- `node tool/gen_levels.js --validate-only`: not run — no level files touched.

### Backend Changes Required

None. Task A is solved entirely with a frontend navigation change (level
picker) using the existing per-level `GET /leaderboard/:levelId` endpoint. A
true global/aggregate leaderboard across all levels would require a new
backend endpoint (e.g. `GET /leaderboard` returning top scores across all
levels) — this was **not** implemented; if a genuine global board is wanted
later, that's the endpoint contract to design and build on a dedicated
backend branch.

### Limitations

- `LeaderboardLevelPickerScreen` has no dedicated widget test of its own
  (only exercised transitively — none of this session's changes to it are
  covered by a targeted test asserting the level list renders and tapping
  navigates correctly). Flagged as a coverage gap for a follow-up phase.
- Manual on-device validation of the leaderboard picker flow and the
  login-identity-switch coverage flagged in Phase 21.1 remain pending,
  stacked on the same manual-validation queue open since Phase 9.

### Next Recommended Phase

Add a dedicated widget test for `LeaderboardLevelPickerScreen`, then add the
`AuthScreenController`/`SyncProgressOnLoginUseCase` unit test coverage
deferred from Phase 21.1, then perform the combined manual on-device
validation pass.


## Phase 22 — 3D Graph Extension, Rotatable Perspective Board, 3D Levels 21–22 (2026-07-09)

(Numbered Phase 22: Phase 19 is PR #18's level audit; Phases 20–21 are the upstream main-menu redesign and backend progress work, developed in parallel on arjperez-dev/frontend-poc-arrow.)

### Context

The graph model was extended from 2D to 3D per the "extend, don't modify"
architectural plan: the theoretical graph design always supported 3D; this
phase made it concrete, added a true-3D rendering surface, and shipped the
first two multi-layer levels. All 2D gameplay, rendering, and levels 1–20
are behavior-identical (levels 1–20 byte-identical in the asset).

### Domain extension (Phases A–C of the plan)

- **`board_coordinate.dart`**: `BoardCoordinate` gained `z` (default `0`) in
  equality/hash — 2D coordinates are the z=0 embedding, not a separate type
  (value-object subclass equality would break map-key symmetry in
  `BoardGraph._nodesByCoordinate`).
- **`move_direction.dart` (new)**: `MoveDirection` interface (`dx/dy/dz`,
  `applyTo`, `opposite`, static `all`/`between`/`parse`). `Direction`
  (planar enum, untouched values) now implements it; new `layer_direction.dart`
  adds `LayerDirection.above/below` (z∓1). Code typed `Direction` stays
  provably planar; dimension-aware code takes `MoveDirection`.
- Type widening only (source-compatible): `ArrowPath.direction`,
  `ArrowPathDefinition.direction`, `BoardGraph.getNeighbor/getEdgeInDirection/
  isExitMove`. `GraphNodeDefinition`/`ManualGraphNodeDto` gained optional
  `z` (absent in JSON = 0 — all existing level JSON valid unchanged).
- **`MovementResolver` unchanged** — its coordinate sweep
  (`direction.applyTo` → `nodeByCoordinate`) was already dimension-agnostic.
- `LevelDefinitionValidator`: orthogonality via `MoveDirection.between`
  (unit step on exactly one axis, any dimension); head-direction and
  self-intersection checks now step via `applyTo` (behavior-preserving
  refactor that made them 3D-correct for free).
- `BoardGraph` additive helpers: `layers`, `isMultiLayer`, `layerSubgraph(z)`.
- 2D painter's `_drawArrowHead` angle now `atan2(dy, dx)` over a
  `MoveDirection` (identical output for all four planar directions).

### 3D presentation (new files, 2D board untouched)

- **`graph_3d_projector.dart`**: pure-math perspective camera — yaw orbit +
  pitch tilt around the board center, layer spacing 2.2 world units,
  perspective divide (focal 14 / camera distance 14), two-pass fit-to-
  viewport × user zoom. Emits per-node `ProjectedPoint {screen, depth,
  pixelScale}`; `directionOnScreen()` projects world-direction steps for
  arrowheads/animation. At yaw=pitch=0 it looks straight down the layer axis.
- **`graph_3d_board_painter.dart`**: painter's algorithm (depth-sorted
  drawables, far→near), z-edges as slanted inter-layer lines, arrow strokes/
  heads scaled by `pixelScale` (real foreshortening), arrowhead angle from
  the projected direction vector (vertical arrows render as real arrows
  pointing between layers), depth-fade cue, covered/free node rule reused,
  exit = whole-shape slide along projected direction + fade, collision
  shake along projected direction.
- **`graph_3d_hit_tester.dart`**: screen-space head/segment hit test through
  the same projector; nearest-depth arrow wins on overlap; slop capped at
  45% of projected cell size.
- **`graph_3d_board.dart`**: `Graph3DBoard` — one-finger drag orbits
  (pitch clamped ±78°), pinch zooms (0.5–3×), tap activates, reset-view
  button restores the initial camera (yaw 25°, pitch 30° so the level reads
  as 3D at first paint), `animate` test flag, `onInteractionActiveChanged`
  page-scroll-lock contract identical to `GraphBoard`.
- **`game_screen.dart`**: `level.boardGraph.isMultiLayer ? Graph3DBoard :
  GraphBoard` — the only selection point.

### 3D levels 21–22

- `AppConfig.manualLevelCount` 20 → 22. Home screen gained a dev shortcut
  button (`AppRoutes.demo3d` → `GameScreen(levelNumber: 21)`) to play the 3D
  levels without completing 1–20.
- **Level 21** (hard, two 5×4 layers, 20 arrows): 16 planar row arrows +
  4 single-node vertical arrows at column x=2 (two `below` on the top layer,
  two `above` on the bottom), each blocked by the row arrow covering the
  cell it sweeps into on the other layer.
- **Level 22** (hard, three 5×4 layers, 28 arrows): 24 planar + 2
  body-spanning vertical arrows (occupying a z-edge, sweeping through the
  third layer) + 2 single-node verticals with two-layer-deep chains; two
  planar arrows are themselves blocked by verticals in their sweep path
  (dependencies cross layers in both directions). Greedy-solvable.
- `tool/gen_levels.js`: z-aware core (`byCoord` keyed `x,y,z`, `DELTA`
  3-vectors + `above`/`below`, `dirBetween` handles z-edges, `canExit`
  sweeps in 3D); zero-edge arrows and cycle-check exemption allowed only for
  `generationType: '3d'`; planar interior-gap check skips vertical arrows
  and 3D levels (`gapExit=n/a(3d)`); new deterministic `build3DLevel21/22()`
  builders and `--generate-3d` mode (keeps 1–20 byte-identical, mirror of
  `--generate-figures`).

### Test updates

- `manual_levels_test.dart`: literals 20→22 (+`manual-022`); arrowhead-
  orientation check scoped to arrows with ≥1 body edge (single-node arrows
  have no body to orient) and made z-aware; interior-gap test now steps
  `(dx, dy, dz)` with a 3-axis bounding box.
- New: `board_coordinate_test.dart`, `move_direction_test.dart`,
  `level_definition_validator_3d_test.dart`,
  `layer_direction_movement_test.dart` (resolver escapes/collides through
  layers, unchanged resolver), `graph_3d_projector_test.dart` (flat-camera
  equivalence, layer separation when tilted, foreshortening, viewport fit,
  projected layer-axis direction, zoom), `graph_3d_board_test.dart`
  (renders, tap-activates via projected position, orbit drag, reset view).

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 158/158 passed.
- `node tool/gen_levels.js --generate-3d`: writes 21–22; levels 1–20
  verified byte-identical (git diff shows pure insertions).
- `node tool/gen_levels.js --validate-only`: ALL VALID for all 22 levels
  (21: comp=1, solvable, 20 arrows, layers=2; 22: comp=1, solvable,
  28 arrows, layers=3); hard tier avg 27.3 > medium 17.6.
- Manual on-device validation pending: level 21/22 open with the tilted 3D
  camera, drag orbit / pinch zoom / tap-to-exit, vertical arrows blocked
  until their covering rows escape, victory → next level flows 20→21→22.

### Limitations

- Exit animation in 3D is the whole-shape slide (Phase 9 style); the
  arc-length "train on tracks" variant from Phase 13 has not been ported to
  the 3D painter.
- The 3D board has no `InteractiveViewer` pan — orbit + zoom substitute for
  it. Dense future 3D levels may want screen-space panning as well.
- `docs/LEVEL_AUTHORING.md` §16 documents the 3D schema and constraints.

## Phase 22.1 — Spanning-Only Vertical Arrows + 3D Figure Levels 23–25 (2026-07-09)

### Context

Post-device feedback on Phase 22: single-node vertical arrows (a lone ⌄ dot
occupying one cell) read badly on the 3D board. The user asked that every
arrow span at least two nodes, like planar arrows, and for three more 3D
levels, more complex than 21–22, shaped as recognizable figures.

### Rule change: no single-node arrows anywhere

- Vertical arrows now always occupy a z-edge between two layers (one cell on
  each). `Builder3D.verticalSingle` was deleted; `tool/gen_levels.js`'s
  `structureErrors` re-enforces "arrow has no edges" strictly for ALL levels
  (the Phase 22 3D exemption was removed), and the cycle/head-behind checks
  are z-aware.
- New Dart asset test `should_have_no_single_node_arrows`; the arrowhead-
  orientation test no longer skips edge-less arrows (none may exist).
- The domain `LevelDefinitionValidator` still permits single-node arrows
  (unit-test fixtures use them); the prohibition is an asset/tool-level
  contract, same tier as no-free-nodes.

### Levels 21–22 redesigned, 23–25 added (all deterministic builders)

- **21** (2 × 5×4 layers, 20 arrows): 4 spanning verticals at column x=2;
  four planar rows point INTO the vertical column and wait for it (verticals
  exit instantly but free a cell on both layers at once).
- **22** (3 × 5×4 layers, 28 arrows): verticals span adjacent layers and
  their sweeps cross the remaining layer; planar arrows on two layers point
  into vertical columns — dependencies cross layers in both directions.
- **23 "Pyramid"** (4 concentric tiers 2×2 / 4×4 / 6×6 / 8×8, 42 arrows,
  120 nodes): tier z1's four center columns are spans down to z2 with heads
  pointing up — each blocked by an apex cell, so the pyramid's core unlocks
  only after the apex is cleared. Rings use column arrows (new
  `Builder3D.colArrow`).
- **24 "Diamond"** (5 tiers 2×2 / 4×4 / 6×6 / 4×4 / 2×2, 34 arrows, 76
  nodes): the center column is a lattice of four span-pairs chaining
  tip → equator → tip in both directions; two equator rows thread through
  the lattice (up to 3-deep chains).
- **25 "Hourglass"** (5 tiers 5×5 / 3×3 / **1×1** / 3×3 / 5×5, 30 arrows,
  69 nodes): a true single-cell waist; the whole x=2 center column is spans
  (W threads the neck and waits on G beneath it), and one row on each outer
  face points into the column.
- First-pass shapes (3 similar-sized tiers each) were rejected by the user
  as unreadable; the figures were rebuilt with more tiers and stronger size
  contrast so the silhouettes read under perspective.
- All five: `comp=1`, no free/shared nodes, greedy-solvable, hard band,
  `gapExit=-`. Hard tier avg 29.0 > medium 17.6. Levels 1–20 byte-identical.

### Validation updates for figure-shaped layers

- Stacked layers of different sizes make the strict "every in-bbox swept
  coordinate has a node" rule false-positive (sweeping past a smaller
  layer's silhouette edge is legitimate). 3D levels now use **real-gap
  semantics** (mirroring PR #18's figure-aware check): only a gap that hides
  a node further along the sweep is a defect. JS: new
  `hasRealInteriorGapExit3D` wired into `validateAll`; Dart:
  `should_have_no_interior_gap_exits` branches on `generationType == '3d'`.
- `Builder3D.weaveLayers` now weaves BOTH in-plane axes (column-arrow layers
  have no row body edges of their own; edges are never gameplay-relevant
  unless blocked).
- Merge note: PR #18 (`feat/phase-19-level-audit-and-validation`) landed on
  `feat/3d-levels` mid-session via a GitHub Desktop stash pop; the resulting
  `gen_levels.js` conflicts were resolved by combining its figure-aware gap
  check with the 3D changes.

### Files Touched

- `tool/gen_levels.js` (3D builder section rewritten; strictness restored;
  `hasRealInteriorGapExit3D`)
- `assets/levels/manual_levels.json` (21–22 regenerated, 23–25 added;
  1–20 byte-identical)
- `lib/core/config/app_config.dart` (`manualLevelCount` 22 → 25)
- `test/features/game/infrastructure/manual_levels_test.dart` (literals → 25,
  no-single-node test, real-gap branch, orientation check unscoped)
- `test/features/game/presentation/graph_3d_board_test.dart` (fixture's
  vertical arrow now spans a z-edge)
- `docs/LEVEL_AUTHORING.md` §16 (spanning-only rule, figures, real-gap)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 161/161 passed.
- `node tool/gen_levels.js --generate-3d`: ALL VALID, wrote 21–25;
  `--validate-only`: ALL VALID for 25 levels; zero `occupiedEdges: []`
  arrows across the entire asset (verified by script).
- Manual on-device validation pending: figures read as pyramid/diamond/
  hourglass under orbit; vertical arrows render as two-node pieces spanning
  layers; chains behave (e.g. 23's core waits for the apex).

## Phase 23 — Bug Fixes & Polish (Save-Race Hardening + Leaderboard Picker Coverage) (2026-07-10)

Closed the two follow-up items from the Phase 21.2 audit: a theoretical
save/reload race on fast back-navigation, and missing widget-test coverage
for `LeaderboardLevelPickerScreen`. Branch
`feat/phase-23-bug-fixes-and-polish`. No gameplay, rendering, level-data,
audio, auth, sync, or API changes; `backend-poc-arrow` untouched.

### Task A — Save/Reload Race on Back-Button Exit

**Root cause recap:** `GameScreenController.activateArrow` fires
`unawaited(_saveCompletionOnce(...))` on the victory transition. The save is
a `SharedPreferences` read-modify-write via `SaveLevelCompletionUseCase`.
`LevelSelectionScreen._openLevel` awaits the pushed route's pop and then
reloads progress. `GameScreen` had no `PopScope`/pop interception, so an
extremely fast pop (system back or app-bar back) could resolve before the
save's write landed, making the reload observe stale (not-yet-completed)
progress for that one return. Self-correcting on the next visit; no data was
ever lost — the save still completed, the reload is read-only.

**Fix (Option 1 — chosen per the phase doc's stated preference):**
`GameScreenController` gained `Future<void>? _pendingCompletionSave`,
assigned inside `_saveCompletionOnce` around only the local
`saveCompletion(...)` call (not the best-effort remote notify, which stays
unawaited/best-effort), and a public `Future<void> get completionSettled =>
_pendingCompletionSave ?? Future<void>.value()` — a no-op resolved future
when no victory has occurred. `GameScreen`'s body is now wrapped in
`PopScope(canPop: false, onPopInvokedWithResult: ...)`: on a pop attempt it
captures `Navigator.of(context)` first (to avoid a
`use_build_context_synchronously` lint after the following await), awaits
`controller.completionSettled`, checks `mounted`, then calls
`navigator.pop(result)`. This intercepts both the app-bar back arrow and the
Android system back button (both route through the same pop). `dispose()`
was not touched — the pending future is never awaited there.
`_backToLevels`/`_openNextLevel` use `pushNamedAndRemoveUntil`/
`pushReplacementNamed` respectively (not `pop`), so `PopScope` does not
intercept them; they were already correct per the Phase 21.2 audit and
remain unchanged.

**Confirmed:** awaiting `completionSettled` is a no-op (immediately-resolved
future) when no victory occurred — normal in-progress/failed-level back
navigation is not stalled. `completionSettled`/`_pendingCompletionSave` are
never awaited or read from `dispose()`.

### Task B — `LeaderboardLevelPickerScreen` Widget Test Coverage

New file `test/features/leaderboard/presentation/leaderboard_level_picker_screen_test.dart`,
mirroring the `MaterialApp`/l10n harness pattern from
`playable_game_ui_test.dart`. Four assertions, five tests:

- **Render:** injects a small deterministic fake level list; asserts one
  `GameUiKeys.levelCard(n)` per level with the level's name text.
- **Tap → argument:** taps a level card; a fake `onGenerateRoute` captures
  `RouteSettings.name`/`.arguments` for `AppRoutes.leaderboard` and asserts
  the argument equals the tapped level's number (the exact regression the
  Phase 21.2 fix depends on — a `null` argument was the original
  leaderboard-empty bug).
- **Empty/error branch:** asserts the localized `leaderboardUnavailable`
  message and no cards, both when `loadLevels` returns an empty list and
  when it throws.
- **Loading branch:** pumps once without settling; asserts a
  `CircularProgressIndicator` and no cards before the future completes.

No production code changed for Task B (test-only, per the phase
constraints); `LeaderboardLevelPickerScreen` itself was not modified.

### Files Changed / Created

- `lib/features/game/presentation/game_screen_controller.dart`
- `lib/features/game/presentation/game_screen.dart`
- `test/features/game/presentation/playable_game_ui_test.dart` (1 new test)
- `test/features/leaderboard/presentation/leaderboard_level_picker_screen_test.dart` (new, 5 tests)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 178/178 passed (132 pre-existing + 6 new: 1 Task A + 5
  Task B).
- `node tool/gen_levels.js --validate-only`: not applicable/not run (no
  level files touched).

### Limitations

- Task A's regression test simulates the race with a 50 ms artificially
  delayed fake save rather than a real timing race against actual
  `SharedPreferences` I/O latency — this proves the await-before-pop
  ordering is correct, not that the original race was ever observable on a
  real device (the phase doc itself describes the original symptom as
  "theoretical, negligible probability").
- Manual on-device validation for this phase (and the long-standing pending
  manual validation from prior phases) was not performed.

## Phase 24 — Game Mode Selector (2D/3D) + "Challenges" Rebrand

Branch `feat/phase-24-game-mode-selector`. Renamed the disabled main-menu "Game Mode" button to "Challenges"/"Retos" (stays disabled — challenge levels don't exist), and added a persisted 2D/3D game-mode selector in Settings that filters the Levels and Leaderboard-picker screens. Presentation-layer filter only, per an explicit decision against splitting `manual_levels.json`.

### What Changed

- **Task A (rebrand):** added a `challenges` ARB key (EN "Challenges" / ES "Retos") to both locales; the disabled fourth `_MenuNavButton` in `home_screen.dart` now reads `localizations.challenges` instead of `localizations.gameMode`. `onPressed` stays `null`. The `gameMode` key is kept and repurposed as the Settings selector's title.
- **Task B1 (domain/persistence):** new `GameMode` enum (`twoD`/`threeD`, pure Dart, no Flutter import) with a stable `storageKey` decoupled from any localized label. `PlayerSettings.gameMode` added, defaulting to `GameMode.twoD` in the constructor and `PlayerSettings.defaults()`. `SharedPreferencesSettingsRepository` persists it under `settings.gameMode`; a missing or unrecognized stored value falls back to 2D via `GameMode.fromStorageKey`.
- **Task B2 (controller):** `SettingsScreenController.setGameMode(GameMode)` mirrors `setLanguage` — `_save(copyWith(gameMode: mode))`.
- **Task B3 (app-level reactivity):** `AppSettingsController` gained a `gameMode` field/getter and `setGameMode()` (notifies only on change), mirroring `locale`/`setLocale`. `app_bootstrap.dart` seeds it from the saved `PlayerSettings.gameMode` alongside the locale seed. The Settings UI calls both `controller.setGameMode(...)` (persist) and `AppSettingsScope.maybeOf(context)?.setGameMode(...)` (drive reactive UI), same two-call pattern as the language dropdown.
- **Task B4 (Settings UI):** new `_GameModeSelectorCard` in `settings_screen.dart` — a `Card` with the `gameMode` title, a `gameModeHint` helper line, and a `SegmentedButton<GameMode>` (2D/3D) keyed `GameUiKeys.gameModeSelector`.
- **Task B5 (filtering — presentation only):** new `lib/features/game/presentation/level_mode_filter.dart` exports `isThreeDLevel(Level)` (`boardGraph.isMultiLayer || (number ?? 0) >= 21`) and `filterLevelsByGameMode(levels, {required wantThreeD})`. `LevelSelectionScreen` and `LeaderboardLevelPickerScreen` both read `AppSettingsScope.maybeOf(context)?.gameMode` (defaulting to 2D when the scope is absent, e.g. in tests without it) and filter the already-loaded level list before building cards. No domain, application, or level-loader code changed; both screens still navigate to the same routes as before (`AppRoutes.levels`, `AppRoutes.leaderboardLevelPicker`) and the pushed screens self-filter from the scope.
- **Task C (localization):** added `challenges`, `gameMode2D`, `gameMode3D`, `gameModeHint` to both ARB files; `gameMode` itself was already present in both locales (EN "Game Mode" / ES "Modo de juego", unchanged). Regenerated via `flutter gen-l10n` (uses the project's `l10n.yaml`, not CLI flags).
- **Architecture decision (recorded, not code):** considered splitting levels 21–25 out of `assets/levels/manual_levels.json` into a separate `manual_levels_3d.json` for a "file-level" mode split. Rejected — all 25 levels load through one `AssetLevelRepository`/`LocalLevelDataSource`/single asset path, and `GameScreen` resolves gameplay by level number through that same single path; a split would touch the repository, dependencies, `GameScreen`'s lookup, `pubspec.yaml`, `tool/gen_levels.js` (two independent validate/generate passes), and `manual_levels_test.dart`, for no correctness gain over the existing `isMultiLayer` structural invariant the 3D board already depends on. Kept the presentation-layer filter as originally scoped.

### Files Touched

- `lib/features/settings/domain/game_mode.dart` (new)
- `lib/features/settings/domain/player_settings.dart`
- `lib/features/settings/infrastructure/shared_preferences_settings_repository.dart`
- `lib/features/settings/presentation/settings_screen_controller.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/core/app/app_settings_controller.dart`
- `lib/core/app/app_bootstrap.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/game/presentation/game_ui_keys.dart`
- `lib/features/game/presentation/level_mode_filter.dart` (new)
- `lib/features/levels/presentation/level_selection_screen.dart`
- `lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart`
- `lib/core/localization/l10n/app_en.arb`, `app_es.arb` (+ regenerated `app_localizations*.dart`)
- `test/widget_test.dart` (label update: "Game Mode" → "Challenges")
- `test/features/settings/settings_test.dart` (game-mode persistence/controller/UI tests)
- `test/features/levels/level_selection_screen_game_mode_filter_test.dart` (new)
- `test/features/leaderboard/presentation/leaderboard_level_picker_screen_test.dart` (added filter test)

### Verification Results

- `flutter gen-l10n`: regenerated cleanly; new getters (`challenges`, `gameMode2D`, `gameMode3D`, `gameModeHint`) confirmed present in `app_localizations.dart`/`_en.dart`/`_es.dart`.
- `flutter analyze`: no issues.
- `flutter test`: 187/187 passed (9 new: 6 in `settings_test.dart`, 2 in `level_selection_screen_game_mode_filter_test.dart`, 1 in `leaderboard_level_picker_screen_test.dart`).
- `node tool/gen_levels.js --validate-only`: not run — no level files touched; `manual_levels.json` was not regenerated or split.
- `backend-poc-arrow`: not touched.

### New Tests

- `should_default_game_mode_to_2d`
- `should_persist_and_read_back_game_mode`
- `should_default_game_mode_to_2d_when_stored_value_is_missing`
- `should_default_game_mode_to_2d_when_stored_value_is_unrecognized`
- `should_persist_game_mode_when_changed_via_controller`
- `should_invoke_controller_and_app_scope_when_3d_is_selected_in_settings_ui`
- `should_show_only_2d_levels_when_game_mode_is_2d`
- `should_show_only_3d_levels_when_game_mode_is_3d`
- `should_filter_levels_by_active_game_mode_from_app_settings_scope`

### Limitations

- Manual emulator/device validation of the selector and menu-driven filtering was not performed in this pass.
- `AppSettingsScope.maybeOf(context)` defaults to 2D when absent (e.g. a screen pushed without the scope in a test harness) — matches the existing locale-scope pattern, not a new gap.
- The `_GameModeSelectorCard` uses `SegmentedButton<GameMode>` rather than a `DropdownButton`, for parity with a toggle-style 2-option control; both were acceptable per the phase prompt.

### Next Recommended Phase

Wire the "Challenges" destination once challenge-level content design begins; until then the button stays intentionally disabled.

## Phase 24 Follow-up — 3D Display-Number Mapping (1-5 instead of 21-25)

Same branch (`feat/phase-24-game-mode-selector`). In 3D mode, internal levels 21-25 were showing as "Level 21"-"Level 25" in `LevelSelectionScreen`/`LeaderboardLevelPickerScreen`, and all 5 appeared locked — confusing now that 2D/3D are user-facing separate modes expected to each start at "Level 1". Added a presentation-only display-number mapping; the internal numbers 21-25 are unchanged everywhere else (domain, application, infrastructure, storage, backend). **Correction (Phase 24.2):** an earlier draft of this note attributed the "all 5 locked" symptom to a separate `progress3d.*` namespace starting empty. That namespace never existed — completions are stored in a single `progress.*` namespace keyed by internal level number (1-25). The real cause was the scalar `lastUnlockedLevel` gate (initial `1`) never reaching internal 21; Phase 24.2 fixes it with a computed per-mode unlock rule.

### What Changed

- **`lib/features/game/presentation/level_mode_filter.dart`**: added `twoDLevelCount = 20` (the source of truth for "where 2D ends and 3D begins", also used to redefine `isThreeDLevel`'s threshold as `> twoDLevelCount` instead of a hardcoded `>= 21`), `displayNumberFor(int internalLevel, GameMode mode)` (`internalLevel - 20` in 3D mode, unchanged in 2D), `maxInternalLevelFor(GameMode mode)` (20 for 2D, `AppConfig.manualLevelCount` for 3D), and `hasNextLevelFor(int internalLevel, GameMode mode)`.
- **`LevelSelectionScreen`**: `_LevelCard` now takes a `displayNumber` (computed by the parent from `AppSettingsScope`'s `gameMode`) and shows it in both the number badge and the `'Level $displayNumber'` title, replacing the previous `level.name`/`level.number` display. The `GameUiKeys.levelCard(...)` key and the unlock check (`progress.isUnlocked(levelNumber)`) still use the **internal** number — only the rendered text changed. Tapping still calls `_openLevel(context, level.number)` (internal).
- **`LeaderboardLevelPickerScreen`**: same mapping — `ListTile` avatar/title show `displayNumberFor(number, gameMode)`; `Navigator.pushNamed(AppRoutes.leaderboard, arguments: number)` still passes the internal number.
- **`GameScreen`**: reads `gameMode` from `AppSettingsScope` in the `AnimatedBuilder` builder (defaults to 2D when absent). AppBar title changed from `controller.level?.name` to a computed `'Level ${displayNumberFor(internalNumber, gameMode)}'` (safe because every shipped level's `name` field is already exactly `'Level <internal number>'` — verified against the shipped `manual_levels.json`, so this is a no-op for 2D). `_GameReadyView`/`_VictoryOverlay` gained a `gameMode`/`nextLevelDisplayNumber` parameter; `hasNextLevel` now calls `hasNextLevelFor(level.number, gameMode)` instead of comparing the internal number against the global `AppConfig.manualLevelCount` (previously a 3D level 24 victory would always show "next level" since `24 < 25`, correctly, but a 2D level 20 victory would also incorrectly read `20 < 25` as true before this fix — now 2D caps at 20, 3D caps at 25 internal). The "Next Level" button label is now `'${localizations.nextLevel}: $nextLevelDisplayNumber'` (e.g. "Next level: 2" when leaving internal level 21 in 3D mode) instead of a bare, unnumbered label. `_openNextLevel`/`_openLeaderboard` navigation logic is unchanged — both still use the internal `level.number`.
- **No domain/application/infrastructure/storage/backend changes.** `LevelDefinition`, `BoardGraph`, `MovementResolver`, `SaveLevelCompletionUseCase`, and the progress repository are untouched. **Correction (Phase 24.2):** there is no separate `progress3d.*` namespace — a single `progress.*` namespace stores completions keyed by internal level number (1-25); mode separation for unlock is computed, not stored.

### Files Touched

- `lib/features/game/presentation/level_mode_filter.dart`
- `lib/features/levels/presentation/level_selection_screen.dart`
- `lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart`
- `lib/features/game/presentation/game_screen.dart`
- `test/features/leaderboard/presentation/leaderboard_level_picker_screen_test.dart`
- `test/features/levels/level_selection_screen_game_mode_filter_test.dart`
- `test/features/game/presentation/game_screen_display_number_test.dart` (new)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 195/195 passed (8 new: 2 name-mapping fixups + 6 net-new display-number tests across the three touched screens).
- `node tool/gen_levels.js --validate-only`: not run — no level files touched.
- `backend-poc-arrow`: not touched. `manual_levels.json`: not regenerated.

### New Tests

- `should_display_2d_level_numbers_unchanged`
- `should_map_3d_internal_level_numbers_21_to_25_as_display_1_to_5` (level selection)
- `should_open_internal_level_21_when_displayed_3d_level_1_is_tapped`
- `should_map_3d_internal_level_numbers_21_to_25_as_display_1_to_5` (leaderboard picker)
- `should_navigate_with_internal_level_number_when_displayed_3d_card_is_tapped`
- `should_display_internal_2d_level_number_unchanged_in_app_bar`
- `should_map_internal_3d_level_21_to_displayed_level_1_in_app_bar`
- `should_show_mapped_next_level_number_on_victory_in_3d_mode`

### Limitations

- The AppBar/HUD "Level N" text is not a localized string (matches the pre-existing behavior of displaying `level.name`, which was already an unlocalized literal baked into the level data) — same convention, not a regression.
- Manual on-device validation of the 3D display mapping was not performed.
- `hasNextLevelFor`'s incidental fix (2D no longer reads `< manualLevelCount` globally) was not called out as a separate bug in the request but is a direct, necessary consequence of "hasNextLevel must check against the mode's level range, not the global count" — flagged here for visibility since it changes prior 2D behavior at the boundary (level 20 in 2D no longer shows a "next level" button, which is correct since level 21 is a different mode's content).

## Phase 24.2 — Mode-Aware Level Unlock (Approach A)

Branch: `feat/phase-24-game-mode-selector` (continuation). Fixed the bug where every 3D level (internal 21–25) was locked for a fresh user. Root cause was **not** a separate progress namespace (see the `progress3d.*` correction below) but the single scalar `LocalProgress.lastUnlockedLevel` (initial `1`): the level-selection gate called `progress.isUnlocked(internalNumber)`, and for internal 21 that scalar never reached 21 unless the user completed 2D level 20 — i.e. the two modes bled through one shared counter. Approach A computes unlock **per mode** from the existing shared `completedLevelNumbers` set (no new storage, no migration): the set is naturally partitioned because 2D (1–20) and 3D (21–25) internal numbers never overlap.

### Unlock Rule

`isUnlockedForMode(n, mode)` := `n == firstInternalLevelFor(mode)` (2D→1, 3D→21; the first level of a mode is always unlocked) **OR** `isCompleted(n - 1)` (previous internal level completed — same mode, since numbering is contiguous per mode). The `firstInternalLevelFor` clause is what prevents cross-mode bleed for internal 21 (whose predecessor 20 is a 2D level).

### What Changed

- **`lib/features/progress/domain/local_progress.dart`**: added `isUnlockedForMode(int levelNumber, GameMode mode)` — the **authoritative** rule. Existing `isUnlocked(int)` (scalar `lastUnlockedLevel`) kept for reset/backward-compat but is no longer used by the level-selection gate. Added a private `_twoDLevelCount = 20` mirroring the presentation constant so the domain rule needs no presentation import (imports pure-domain `game_mode.dart` only).
- **`lib/features/game/presentation/level_mode_filter.dart`**: added `firstInternalLevelFor(GameMode)` and `isLevelUnlockedForMode(LocalProgress, int, GameMode)` — the latter delegates to the domain rule (no duplicated logic). Added a `LocalProgress` import.
- **`lib/features/levels/presentation/level_selection_screen.dart`**: the card gate now calls `isLevelUnlockedForMode(progress, levelNumber, gameMode)` instead of `progress.isUnlocked(levelNumber)`. `gameMode` was already read from `AppSettingsScope`.
- **`lib/features/progress/application/is_level_unlocked_use_case.dart`**: `call(int)` → `call(int, GameMode)`, delegating to the domain rule. It has **zero production callers** (verified by grep — only the factory in `local_progress_dependencies.dart`, itself uncalled, and the test); a doc comment now marks it legacy. Kept for test coverage per phase instruction — not deleted.
- **Documentation `progress3d.*` correction**: the earlier Phase 24 / Phase 24-follow-up notes (and `harness/phases/phase_24_game_mode_selector.md`, `harness/context/phase_registry.md`) claimed 3D completions were stored in a separate `progress3d.*` namespace. That namespace **never existed**. A single `progress.*` namespace (`shared_preferences_local_progress_repository.dart`, keys `progress.completedLevelNumbers` / `progress.bestResultsByLevel` / `progress.lastUnlockedLevel`) stores completions keyed by internal level number (1–25); mode separation for unlock is **computed, not stored**. All occurrences annotated/corrected in place (not rewritten destructively).
- **No changes** to `SaveLevelCompletionUseCase` write logic, the `lastUnlockedLevel` scalar, `hasNextLevelFor`/next-level navigation, leaderboard/API/sync code, or any storage schema. No new `SharedPreferences` key set.

### Files Touched

- `lib/features/progress/domain/local_progress.dart`
- `lib/features/game/presentation/level_mode_filter.dart`
- `lib/features/levels/presentation/level_selection_screen.dart`
- `lib/features/progress/application/is_level_unlocked_use_case.dart`
- `docs/CODEX_HANDOFF.md`, `harness/phases/phase_24_game_mode_selector.md`, `harness/context/phase_registry.md` (progress3d correction)
- `test/features/progress/local_progress_test.dart` (updated: use-case signature + cross-mode isolation)
- `test/features/game/presentation/level_mode_filter_test.dart` (new)
- `test/features/levels/presentation/level_selection_unlock_test.dart` (new)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 207/207 passed.
- `node tool/gen_levels.js --validate-only`: not run — no level files touched.
- `backend-poc-arrow`: not touched.

### New Tests

- `firstInternalLevelFor returns 1 for 2D and 21 for 3D`
- `3D first level (internal 21) is unlocked with empty progress`
- `3D internal 22 locked until 21 completed, unlocked after`
- `completing 2D level 20 does not unlock 3D internal 21`
- `completing 3D internal 21 does not unlock 2D level 2`
- `2D level 1 unlocked by default; level 2 locked until 1 completed`
- `should_unlock_first_3d_level_by_default`
- `should_isolate_unlock_between_modes`
- `in_3d_mode_with_empty_progress_first_3d_card_unlocked_rest_locked`

### Limitations

- Manual on-device validation of the 3D unlock progression was not performed.
- `IsLevelUnlockedUseCase` is retained with zero production callers purely for application-layer test coverage of the rule; its factory in `local_progress_dependencies.dart` is likewise unused.

### Follow-up bug — 3D leaderboard never loaded (backend seed gap)

**Symptom:** in 3D mode, Leaderboard → pick a level → the app issued `GET /levels` but never `GET /leaderboard/:levelId`; entries never loaded.

**Diagnosis:** the frontend navigation/argument passing was already correct — the picker ([leaderboard_level_picker_screen.dart:80](lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart:80)) and the victory screen ([game_screen.dart:211](lib/features/game/presentation/game_screen.dart:211)) both pass the **internal** level number (21–25), the route reads it as `int`, and `GetLeaderboardForLevelNumberUseCase` resolves number→backend `Level.id` via `GET /levels` before calling `GET /leaderboard/:id`. The real cause was upstream: **the backend seed (`backend-poc-arrow/prisma/levels/manual-levels.ts`) defined only levels 1–15**, so `getLevelIdsByNumber()[n]` was `null` for every n > 15 and the use case short-circuited to `[]` before the leaderboard call. This bit all 3D levels (start at 21) and would also have hit 2D figure levels 16–20.

**Fix (backend seed only, with user approval to touch the backend):** added leaderboard/progress **anchor rows** for numbers 16–25 to `levelSpecs` (10 generated `LevelSpec` entries, `'Level 16'…'Level 25'`). `Level.number` is `@unique` and `Level.id` is a generated UUID, so a row per internal number is required for number→id resolution. The seeded `definitionJson` is a minimal valid 2D placeholder and is **never used for gameplay** — the authoritative, playable boards (figures + multi-layer 3D) live in the frontend's local assets. No frontend code changed; no leaderboard API contract changed. Backend `tsc --noEmit` clean. **Deploy step required:** re-run `prisma db seed` (or `prisma migrate reset`) against the target DB for the new rows to exist.

### Next Recommended Phase

Wire the "Challenges" destination once challenge-level content design begins (unchanged from the Phase 24 recommendation).

## Phase 24.1 — 2D/3D Level File Separation (Option 2: File Split, Global Numbering Preserved)

Chosen as Option 2 of a Phase 24.1 audit (P24 had explicitly rejected a file split for "no correctness gain" — this phase revisits that decision at the harness's direction). Splits the single `assets/levels/manual_levels.json` authoring file into two files while keeping internal level numbers **globally unique**: 2D stays 1–20, 3D stays 21–25. No renumber, no display-offset change (`level_mode_filter.dart` untouched). Progress, leaderboard, sync, and backend are untouched — the internal `number` primary key never moved.

### What Changed

- **`assets/levels/manual_levels_2d.json`** (new): levels 1–20, generated via `tool/gen_levels.js --generate-2d` from the same deterministic seeds/builders as before — verified byte-identical union with the deleted `manual_levels.json`.
- **`assets/levels/manual_levels_3d.json`** (new): levels 21–25, generated via `tool/gen_levels.js --generate-3d` (deterministic, no RNG) — same verification.
- **`assets/levels/manual_levels.json`**: deleted, after loading + validation + tests were confirmed green against the two new files.
- **`tool/gen_levels.js`**: `ASSET` constant replaced by `ASSET_2D`/`ASSET_3D`. CLI modes replaced: `--generate-2d` (levels 1–15 random + 16–20 figures, writes `manual_levels_2d.json`), `--generate-3d` (levels 21–25, writes `manual_levels_3d.json`, unchanged builders), `--generate` (shorthand: both), `--validate-only` (reads and validates both files independently, default). `validateAll(levels, fileKind)` now takes a `'2d'`/`'3d'` kind: the 2D path keeps the full existing invariant set (progression, strictly-increasing tier averages, density, hard-not-all-rectangular, figure real-gap); the 3D path skips the progression/increasing-average checks (meaningless over an all-hard 5-level set) and instead asserts every level is `'hard'` and multi-layer (`new Set(nodes.map(z)).size > 1`) — structure/no-free-nodes/no-shared-nodes/greedy-solvability/no-single-node-arrows/`hasRealInteriorGapExit3D` already applied generically per-level regardless of file, so those needed no gating.
- **`lib/features/game/infrastructure/local_level_data_source.dart`**: `LocalLevelDataSource` now takes `assetPath2d`/`assetPath3d` (both injectable, defaulting to the real asset paths via new `manualLevels2dAssetPath`/`manualLevels3dAssetPath` static constants replacing the old single `manualLevelsAssetPath`). `loadManualLevels()` loads and parses both via the unchanged `ManualLevelCollectionDto.fromJsonString`, concatenating 2D-then-3D into one list.
- **`pubspec.yaml`**: asset registration swapped from the single old path to both new paths.
- **`AssetLevelRepository`/`LocalLevelDependencies`**: no changes — the repository already only depends on `LocalLevelDataSource.loadManualLevels()` returning one merged list; the dependency factory already only passed `assetTextLoader`, so it picks up both new default paths automatically.
- **`level_mode_filter.dart`, `level_definition_mapper.dart` id logic, progress/leaderboard/sync code, `backend-poc-arrow`**: all confirmed untouched — internal numbers, ids (`manual-001`…`manual-025`), and the presentation display offset are unaffected by the file split.
- **`test/features/game/infrastructure/manual_levels_test.dart`**: restructured into a `'merged repository (2D + 3D)'` group (the prior top-level 25-level/unique-number/unique-id/progression assertions, now scoped explicitly to the merged repository, since they're integration-level), a new `'2D levels (1-20)'` group, and a new `'3D levels (21-25)'` group (all-hard + multi-layer, plus a new `should_have_spanning_vertical_arrows_in_every_3d_level` check). Existing cross-cutting checks that already loop over all loaded levels (no-free-nodes, solvability, density bands, single-connected-component, arrowhead orientation, no-single-node-arrows, interior-gap/figure-real-gap/3D-real-gap, bent-arrow-per-tier) were left as top-level tests since they naturally span both files with zero changes needed. `should_keep_manual_levels_graph_based_not_matrix_based` updated to read both new asset-path constants instead of the deleted `manualLevelsAssetPath`.
- **`docs/LEVEL_AUTHORING.md`**: documents the dual-file workflow (§ intro, §12 regenerating, §16 3D regenerate/validate commands).
- **`harness/context/current_constraints.md`**: updated the Levels section and "last updated" line to reference the two new files and CLI modes instead of the deleted single file/old flags (not explicitly required by Task E but kept in sync since it documents the exact CLI surface this phase changed).

### Files Touched

- `assets/levels/manual_levels_2d.json` (new), `assets/levels/manual_levels_3d.json` (new), `assets/levels/manual_levels.json` (deleted)
- `tool/gen_levels.js`
- `lib/features/game/infrastructure/local_level_data_source.dart`
- `pubspec.yaml`
- `test/features/game/infrastructure/manual_levels_test.dart`
- `docs/LEVEL_AUTHORING.md`
- `harness/context/current_constraints.md`

### Verification Results

- `node tool/gen_levels.js --generate-2d`: 20 levels valid, written.
- `node tool/gen_levels.js --generate-3d`: 5 levels valid, written.
- `node tool/gen_levels.js --generate`: both, valid, written (used to produce the shipped files).
- `node tool/gen_levels.js --validate-only`: ALL VALID: true for both files.
- Verified programmatically: the union of the two files' levels is byte-identical (after sorting by number) to the deleted `manual_levels.json`'s 25 levels.
- `flutter analyze`: no issues.
- `flutter test`: 198/198 passed (6 new: `should_only_contain_levels_1_to_20`, `should_only_contain_hard_multi_layer_levels`, `should_have_spanning_vertical_arrows_in_every_3d_level`, plus the 3 group-restructure test names carried over unchanged in behavior).
- `grep -r manual_levels.json` (Dart/YAML): no remaining references outside a `tool/gen_levels.js` header comment.
- `backend-poc-arrow`: not modified (no git repo in this workspace to diff, but no file under that directory was opened or written this phase).

### New Tests

- `should_only_contain_levels_1_to_20`
- `should_only_contain_hard_multi_layer_levels`
- `should_have_spanning_vertical_arrows_in_every_3d_level`

### Limitations

- Manual in-app validation (2D level plays, 3D level plays and still displays 1–5 in the app bar) was not performed this pass — recommended before merging.
- `harness/context/current_constraints.md` was updated even though Task E didn't explicitly list it, to keep the documented CLI surface accurate; flagging in case the harness expects only the four listed docs to change.

### Next Recommended Phase

Manual on-device/emulator validation of 2D and 3D gameplay end-to-end now that levels load from two separate assets.

## Phase 25 — 3D Figure Levels 26–30 (Cross, Star, Cat, Helix, Hollow Pyramid) (2026-07-11)

### Context

With Phase 24's game-mode split in place (3D levels live in
`manual_levels_3d.json`, internally 21+, displayed as 3D 1+ via
`displayNumberFor`), the 3D mode grows from 5 to 10 levels. The five new
levels are figure-shaped: 26 "3D Cross", 27 "3D Star", 28 "Abstract Cat",
29 "Double Helix", 30 "Hollow Pyramid" — internally 26–30, displayed as 3D
levels 6–10 with zero display-layer changes (the mapping is arithmetic).

### What Changed

- **`tool/gen_levels.js`**: two new `Builder3D` helpers — `zColArrow`
  (straight vertical arrows spanning ≥2 layers) and `pathArrow` (free-form
  bent arrows stepping across layers, used for staircase rays and the cat's
  tail) — plus five deterministic builders `build3DLevel26..30` wired into
  `build3DLevels()`. Shape/gameplay notes live as comments on each builder.
- **`assets/levels/manual_levels_3d.json`**: regenerated — levels 21–25
  byte-identical (verified against HEAD), 26–30 appended. All 10: hard,
  comp=1, no free/shared nodes, no single-node arrows, greedy-solvable,
  no real-gap exits. Arrow counts 20–42; layer counts 2–8.
- **`lib/core/config/app_config.dart`**: `manualLevelCount` 25 → 30 (the 3D
  ceiling via `maxInternalLevelFor`; 2D stays capped by `twoDLevelCount`).
- **`test/features/game/infrastructure/manual_levels_test.dart`**: merged-set
  literals 25 → 30 (+`manual-030`), 3D group widened to 21–30 (hasLength 10).

### Design notes — shape-first rework (user rejected the first pass)

The first versions of 26-29 were built solver-first and did not read as
their figures on screen (only the hollow pyramid did). All four were
redesigned around the canonical geometry, then the game structure was fit
inside the shape:

- **26 Cross**: was three stacked plus-plates; now ONE true 3D cross — a
  2-thick plus plate at z2 with a 2×2 post punched through its center,
  z0-z4 (three orthogonal bars, one shared intersection).
- **27 Star**: was planar rays + decoration; now a starburst — octahedral
  core (3×3 mid + plus caps) radiating 14 spikes: ±x/±y/±z straight, plus
  4 rising and 4 falling bent spikes.
- **28 Cat**: was a front-facing blob; now the iconic SITTING side profile
  (haunch back-left, head front-top, two upright ear columns, tail hugging
  the back edge with an inward hook), per pixel/voxel-cat conventions
  (ears + tail + silhouette = recognizability).
- **29 Helix**: was rotating square edges (a tunnel); now true DNA — two
  arms orbiting the axis column at 45°/layer over 10 layers, 180° apart;
  axis-aligned layers form straight "base pair" bond lines through the
  axis (one arm inward/blocked, one outward/free), diagonal layers are
  bent elbows.
- **30 Hollow Pyramid**: unchanged (it read correctly).

Validator catches across both passes: disconnected vertical segment groups
(every non-adjacent vertical piece pair needs an explicit connectivity
z-edge — hit three times), head-on pairs across a carved column, and a
ring whose four sides chained in a full circle (a chain loop needs a free
drain). Silhouettes were verified by ASCII-rendering every layer from the
generated JSON before handing over — the step whose absence caused the
first-pass rejection.

### Verification Results

- `node tool/gen_levels.js --generate-3d`: ALL VALID, wrote 21–30
  (21–25 byte-identical); `--validate-only`: both sets ALL VALID.
- Per-layer ASCII silhouette render of 26–29: all four figures read.
- `flutter analyze`: no issues.
- `flutter test`: 207/207 passed.
- Manual on-device validation pending: figures read correctly under orbit
  (cross planes, star rays, cat silhouette from the front at yaw≈0, helix
  strands + corner bonds, pyramid shell), and the display numbering shows
  3D 6–10 in the Challenges/3D list.

### Limitations

- The user-requested "start node / end node / path" framing does not map to
  this game's mechanics; "solvability" is implemented as the established
  greedy-exit model (every arrow can eventually escape).
- The cat reads best from the front (yaw ≈ 0); at extreme yaw it is
  abstract, as 2-layer sculptures are.
- 26–30 average fewer arrows than a dense 2D hard level by design — 3D
  orbiting adds difficulty on its own; tune per playtest feedback.
## Phase 26 — Challenges Mode: Time Attack, Move Limit, Perfect Run (2026-07-12)

### Context

Wires the main menu's "Challenges" placeholder button (Phase 24 rebrand,
`onPressed: null`) into a full challenge system: picker → the existing
level-selection screen (same 2D/3D mode from settings, same unlocks as
campaign) → the existing game screen with a challenge modifier active.
User decisions: v1 ships Time Attack + Move Limit + Perfect Run (Daily
Challenge deferred); challenge results are FULLY SEPARATE from campaign
progress; scoring demonstrates the Strategy design pattern through the
pre-existing `ScoreStrategy` abstraction.

### What Changed

- **New feature `lib/features/challenges/`** (domain / application /
  infrastructure / presentation):
  - `Challenge` enum + `ChallengeContext` with CALCULATED limits: the
    minimal solve is one tap per arrow (guaranteed by greedy solvability),
    so Time Attack gets `max(30s, arrows × 5/4/3s − 20s)` for easy/medium/hard
    and Move Limit gets `arrows + 5/3/2` slack moves by tier. (An earlier
    draft read the dormant `timeLimit`/`maxMoves` metadata; replaced with
    computed limits at user request — metadata stays dormant.)
  - **Strategy pattern showcase**: `TimeAttackScoreStrategy` (+10/remaining
    second), `MoveLimitScoreStrategy` (+25/unused move),
    `PerfectRunScoreStrategy` (1500 − moves·10; mistakes absent because one
    mistake ends the run) — all implementing the untouched `ScoreStrategy`
    interface, selected at exactly one point (`scoreStrategyForChallenge`).
  - `ChallengeRecordsRepository` port + get/save use cases +
    SharedPreferences adapter (`challenges.bestScores` key) + factory.
  - `ChallengePickerScreen` (three challenge cards).
- **Game engine** (challenge rules live in application, not presentation):
  `GameSession` carries an optional `ChallengeContext` (+`remainingSeconds`/
  `remainingMoves`); `MoveArrowUseCase` enforces the move budget (a tap
  beyond it fails the run before resolving) and perfect-run's
  one-mistake-fails; `GameSessionService.tickClock` advances the clock and
  fails an expired Time Attack. Null challenge = byte-identical campaign
  behavior.
- **First real timer in the app**: `GameScreenController` runs a 1s periodic
  ticker for Time Attack (rule in the service; controller only ticks),
  disabled in tests via the `enableBoardAnimations` seam, driven manually
  with `advanceClock()`.
- **UI**: home button wired; levels screen accepts a challenge (banner chip,
  levels open with `GameRouteArgs`); in challenge mode each level card shows
  the CHALLENGE best ("Challenge best: N") or no score at all when that
  level hasn't been played in that specific challenge — campaign bests
  never appear there (and vice versa); game HUD gains one challenge stat chip
  (countdown m:ss / moves left / flawless badge); game-over overlay message
  varies by fail reason (time up / out of moves / broken perfect run);
  victory overlay shows the challenge best + "New record!", hides the
  leaderboard button in challenges, and Next Level keeps the challenge.
  Full EN+ES l10n (14 new keys).
- **On challenge victory**: a challenge record is saved INSTEAD of campaign
  completion — no unlock, no remote sync, no leaderboard submit.

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 226/226 passed (19 new: strategy formulas + factory,
  rule enforcement incl. campaign-unchanged, records round-trip,
  controller clock/fail-reasons, and the separation contract — challenge
  victory saves a record and never calls saveLevelCompletion/remote).
- `node tool/gen_levels.js --validate-only`: n/a (no level files touched).
- Manual on-device validation pending: full flow for each challenge in both
  2D and 3D modes; countdown visible and defeat sound on expiry; campaign
  progress unchanged after challenge wins.

### Limitations

- Daily Challenge (date-seeded level + streak) was researched and deferred
  to a future phase; Marathon and Mirror Mode were catalogued as candidates.
- Challenge records are local-only by design (no backend schema for them).
- The Perfect Run HUD chip is a static flawless badge, not a counter.
- Lives are fully campaign-only: the hearts are hidden in challenge HUDs
  AND the lives mechanic is disabled in challenge sessions (user playtest
  found the hidden six-collision death confusing — a challenge run now
  ends only by its own rule: clock, budget, or the perfect-run mistake).
  Regression-tested with eight collisions under Time Attack.

## Phase 27 — UI Polish: Launcher Icon, Home Menu Layout, Settings Restyle (2026-07-12)

### Context

User-requested visual pass on branch `feat/phase-27-ui-polish`, driven by
three reference images: a rendered heart figure level (new app icon), a
dark UI kit and a settings mockup (both lavender/violet on dark navy).
The settings restyle was explicitly a **trial** for a possible app-wide
re-theme. Mid-phase, after seeing the result, the user kept the new
sectioned layout but rejected the lavender/violet palette — the final
screen uses the mockups' structure with the app's existing mint/neon
colors.

### What Changed

- **Android launcher icon** (no new dependencies — ffmpeg pipeline, not
  `flutter_launcher_icons`): the user-supplied `HeartNodus.jpeg` (864×758,
  the heart level rendered with neon arrows) was padded square on its own
  sampled background color `#121A2D` (probed from the image corner so no
  seam shows), then scaled to the 5 legacy `ic_launcher.png` mipmaps
  (heart at ~80% of canvas). Added a proper adaptive icon for API 26+:
  `mipmap-anydpi-v26/ic_launcher.xml`, `values/ic_launcher_background.xml`
  (color `#121A2D`), and 5 `ic_launcher_foreground.png` mipmaps with the
  heart at ~58% of canvas to fit the 66/108dp safe zone under any mask.
  `AndroidManifest.xml` already pointed at `@mipmap/ic_launcher` — untouched.
- **Home menu layout** (`home_screen.dart`): the 4-button `Row` from P21.1
  (icon-above-label tiles, 11px text that ellipsized "Leaderboard" and the
  Spanish labels) became a `Column` of full-width horizontal bar buttons:
  leading icon, 16px label, trailing chevron — same per-button neon accent,
  glow shadow, and tap-scale feedback. Wordmark, animated background, and
  debug row untouched. Widget tests locate these by localized label text,
  so no test changes were needed for this screen.
- **Settings restyle** (`settings_screen.dart` — new structure, existing
  colors):
  - Mockup-style sectioned order with uppercase mint `_SectionHeader`s:
    **Account** (avatar with initials or person glyph on a mint→blue
    gradient circle; filled login/sync; outlined logout) → **Game
    Preferences** (game mode, language) → **App Settings** (sound + music
    `SwitchListTile`s with rounded mint icon chips) → **Data** (backend URL
    card, both reset buttons).
  - `_SettingsCard` (a `Material` with the same mint-tinted border as the
    global `Card` theme) replaces `Card` within this screen. Using
    `Material` (not a decorated `Container`) matters: `ListTile` asserts if
    wrapped in a color-decorated non-Material ancestor.
  - A lavender/violet variant of this restyle (new `AppTheme` constants,
    scoped `Theme` override for switches/segmented button, gradient primary
    button) was built first and then reverted at the user's direction after
    review — the layout survived, the palette did not. No `AppTheme` color
    constants were ultimately added or changed.
  - All `GameUiKeys`, the language-dropdown key, controller wiring, dialogs,
    and snackbar logic are byte-identical in behavior. The empty placeholder
    subtitles (`soundFoundationDescription`/`musicFutureDescription`, both
    `" "`) are no longer rendered; their ARB keys remain.
  - 4 new ARB keys in both locales (`settingsSectionAccount`,
    `settingsSectionGamePreferences`, `settingsSectionAppSettings`,
    `settingsSectionData`), Spanish kept accent-free matching file style;
    regenerated via `flutter gen-l10n`.
- **Test adjustments** (`settings_test.dart`, both consequences of the
  taller sectioned layout on the 800×600 test viewport): the "settings
  loaded" readiness probe switched from `soundSwitch` (now below the fold —
  `ListView` children are lazily built, so the finder finds nothing) to
  `gameModeSelector` (near the top); and the reset-progress tap now does
  `ensureVisible` after `scrollUntilVisible`, because the latter stops as
  soon as an edge enters the viewport while the tap targets the center.

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 235/235 passed (0 new, 2 adjusted as above).
- `node tool/gen_levels.js --validate-only`: n/a (no level files touched).
- Manual on-device validation pending: launcher icon on a real
  launcher/emulator (legacy + adaptive mask), home layout, settings look.

### Phase 27.1 follow-ups (same session, user-directed)

- **Pixel Game display font** (user-supplied; replaced an Urban Block
  choice from earlier in the same session): `assets/fonts/PixelGame.otf`
  (SuhadiDesign), family `PixelGame` in `pubspec.yaml`. Applied to three
  surfaces per user direction: (1) the Nodus wordmark — the old
  mint→blue gradient `ShaderMask` was replaced by `_PixelWordmark`, two
  stacked `Text`s (a `PaintingStyle.stroke` pass in the new
  `AppTheme.neonBlueDark` `0xFF0B6180` underneath, a `neonBlue` fill on
  top) since Flutter has no single-pass text outline; (2) the home 2D/3D
  toggle labels (no synthetic bold on a bitmap-style face); (3) the
  Victory and Game Over overlay titles (`headlineSmall.copyWith(
  fontFamily)`). Glyph coverage verified via fontTools for the EN+ES
  strings (full lowercase mapped in both shipped variants; only the
  regular face is bundled). ⚠ **License: 1001Fonts FFP — personal use
  only** (embedding in a personal-use app is explicitly allowed); a
  commercial release needs the author's written permission. Noted in
  `pubspec.yaml` next to the declaration.
- **Language moved to App Settings**: the language card now sits below the
  music toggle; the Game Preferences section header no longer precedes it.
- **2D/3D mode selector moved from settings to the home screen**: a
  pill-shaped `_GameModeToggle` sits between the Nodus wordmark and the
  menu buttons (which were shrunk — padding 18/12, 14px labels — so the
  screen doesn't feel saturated). The selected segment is filled with its
  accent color (mint for 2D, blue for 3D) plus a glow shadow and dark
  label; the unselected side stays transparent/muted. Selection uses the
  same two-call shape as the old settings card: `AppSettingsScope.
  setGameMode` for app-wide reactivity plus `SavePlayerSettingsUseCase`
  for persistence (`HomeScreen` builds the use cases via
  `SettingsDependencies`, the same presentation→infrastructure-factory
  pattern `SettingsScreen` uses). `GameUiKeys.gameModeSelector` moved with
  the widget. The settings screen lost its whole Game Preferences section;
  `SettingsScreenController.setGameMode` kept (controller-level test still
  covers it; no production UI caller). `gameMode2D`/`gameMode3D` ARB keys
  remain in use as the toggle labels; `gameMode`/`gameModeHint`/
  `settingsSectionGamePreferences` are now unused but kept.
- **Bug found on device and fixed — toggle appeared stuck on 2D**: the
  home screen never rebuilt on mode change, because `AppSettingsScope.
  updateShouldNotify` compares controller *identity* (stable for the app's
  lifetime) and `ArrowPocApp`'s `AnimatedBuilder` only rebuilds
  `MaterialApp` itself, not already-built routes. The mode DID change
  underneath (persistence and the freshly-pushed levels screen were
  correct — which is why the widget test passed while the device looked
  broken), but the toggle highlight never moved. Fix: the toggle is
  wrapped in a `ListenableBuilder` on the scope's controller. Any future
  widget that displays (not just sets) a scope value on an already-mounted
  screen needs the same treatment.
- **Tests**: the settings 3D-selection UI test became
  `test/features/home/presentation/home_game_mode_switch_test.dart`, an
  end-to-end check: tap 3D on home → toggle highlight actually moves
  (asserted via the segment's fill color — this assertion fails against
  the pre-fix code) → SharedPreferences stores `'3D'` → Levels shows
  internal card 21 and no card 1. It lives in its OWN file deliberately:
  real `rootBundle` asset loads hang forever on the second navigation to
  the levels screen within one test process (even inside `runAsync`) —
  every pre-existing test file only ever visits the levels screen once,
  so this had never surfaced. Also: never `pumpAndSettle` on the home
  screen — the background animation repeats forever; use bounded pumps.
  `settings_test.dart`'s readiness probe returned to `soundSwitch` (back
  above the fold once the game-mode card left) and the now-unused
  `appSettings` harness param was removed.

### Verification Results (after 27.1)

- `flutter analyze`: no issues.
- `flutter test`: 235/235 passed (net zero: −1 settings UI test, +1
  home end-to-end test).
- Manual device validation: user confirmed the stuck-toggle symptom and
  the retest of the fix is pending.

### Limitations

- The lavender/violet trial palette was rejected for this app; any future
  re-theme proposal should start from a different palette direction (the
  sectioned layout itself was approved and kept).
- Icon source is a JPEG screenshot; a vector or direct-render source would
  produce crisper small sizes if ever needed.
- No `ios/` directory exists in this project — nothing to update there.
- The one-levels-visit-per-test-file constraint (rootBundle hang) is
  documented in both affected test files but not root-caused inside
  flutter_test; if a future phase needs multiple real-asset navigations
  in one file, inject a fake level loader instead.

## Phase 28 — 3D Audit and Polish (2026-07-13)

Audit-first phase. Full per-level + interaction findings are saved in
`harness/phases/phase_28_audit_findings.md`. All four approved fix groups
were implemented; the change is **presentation-scoped** — no JSON, no
`MovementResolver`, no projector projection-contract, no `level_mode_filter.dart`,
no 2D board changes. `manual_levels_3d.json` was NOT touched (no level-content
defect found).

### What Changed

- **Exit animation (A1/A2/A3)** — `graph_3d_board_painter.dart`: the 3D exit is
  now arc-length **path-following** (bent arrows round their own corners,
  "train on tracks") mirroring the 2D board, instead of a rigid
  translate-and-fade. The exit slide is now a **depth-sorted drawable** (added
  to the same `_Drawable` list) so a piece leaving away from the camera is
  occluded by nearer geometry instead of always drawing on top. Fly-out
  distance scales with the head's `pixelScale` so it reads the same at every
  zoom.
- **Arrow legibility (A5/A6/A7)** — vertical (`above`/`below`) arrows whose
  projected axis is degenerate (camera looking down the stack) now get a
  filled-disc head fallback so the head is never invisible; active arrows are
  drawn **segment-by-segment** so each segment dims by its own depth
  (near-to-far shading within a spanning arrow); the just-tapped arrow shows a
  white **selection ring** — `lastActivatedArrowId` is now wired from the
  controller (`GameScreenController.lastActivatedArrowId => lastAttemptTrace?.arrowId`)
  to `Graph3DBoard` (was hard-wired `null`).
- **Depth/comfort (B1/B3)** — a faint per-layer **convex-hull floor plate**
  grounds each z-layer so the stack reads as separate floors; a one-time
  **"drag to rotate" hint** pill (auto-hides after 4 s or on first touch) makes
  the board's rotatability discoverable.
- **Camera/aspect (A8/A9/B2)** — `Graph3DBoard` aspect is now derived from the
  level's own footprint (`_boardAspectRatio`) instead of a fixed square, so the
  flat 2-layer cat (28) gets width and deep stacks (≥6 layers, e.g. helix 29)
  get height.
- **l10n** — added `dragToRotate` to `app_en.arb` / `app_es.arb` (regenerated).

### Files Touched

- `lib/features/game/presentation/widgets/graph_3d_board_painter.dart`
- `lib/features/game/presentation/widgets/graph_3d_board.dart`
- `lib/features/game/presentation/game_screen.dart` (pass real `lastActivatedArrowId`)
- `lib/features/game/presentation/game_screen_controller.dart` (add getter)
- `lib/core/localization/l10n/app_en.arb`, `app_es.arb` (+ generated `app_localizations*.dart`)
- `harness/phases/phase_28_audit_findings.md` (new — audit deliverable)

### Verification Results

- `flutter analyze`: no issues.
- `flutter test`: 235/235 passed.
- `node tool/gen_levels.js --validate-only`: ALL VALID: true (no level files
  touched; run as a safety check).

### New Tests

- None. Changes are presentation-only (custom-paint rendering, animation curves,
  camera aspect, an l10n hint); the existing suite covers the widget/controller
  seams. Visual correctness of the new exit path-following, floor plates, head
  fallback, and selection ring requires on-device inspection.

### Limitations

- **Manual emulator/device validation is pending** (as for all prior phases):
  orbit/tilt/zoom each 3D level 21–30; trigger an exit on a straight AND a bent
  arrow (e.g. 27/29/30) and confirm the path-follow + depth-sort read correctly
  through the whole exit; confirm z-arrow head fallback, floor plates, selection
  ring, the rotate hint, and reset-view.
- `_addLayerFloors` uses a per-layer convex hull; for a concave silhouette
  (e.g. the cat) the floor plate is the hull, slightly larger than the true
  footprint. Intentional — it is a faint grounding cue, not an outline.

### Next Recommended Phase

On-device validation pass of the 3D polish, then tune floor-plate/selection-ring
opacities and the exit fly-out constant by eye if needed.

## Phase 28.1 — 3D Level Complexity Redesign (Hard Mode)

### What Changed

- Reworked all ten 3D builders (`build3DLevel21..30`) in `tool/gen_levels.js`
  so every 3D level is significantly denser and deeper than before, while each
  figure still reads as its silhouette (verified by per-layer ASCII render of
  the regenerated JSON before handover). Regenerated
  `assets/levels/manual_levels_3d.json` via `--generate-3d`.
- Added two authoring helpers to `Builder3D`: `queueRow(xs,y,z,dir,size)` and
  `queueCol(ys,x,z,dir,size)` — fill a row/column with a QUEUE of disjoint,
  same-direction arrows (auto-splitting at gaps and into groups of `size`;
  every run must be ≥2 cells). Deep queues raise arrow count and forced-ordering
  depth without hand-listing each arrow, and keep solvability trivial (a
  same-direction queue toward a boundary always drains greedily).
- Design invariants held for all ten: no single-node arrows, node/edge-disjoint,
  no free nodes, `comp=1`, greedy-solvable, real-gap-3D clean, ≥1 spanning
  vertical, multi-layer, hard tier. No renderer/projector/board, resolver,
  backend, auth/sync, or 2D-asset changes.

### Per-level summary (arrows: baseline → new, layers, shape/depth notes)

- **21** 20→**40**, 3 layers (6×5). Row-queued grid; six spanning columns
  parked at row tails (acyclic) with heads landing on covered blockers one layer
  over; two center columns punched through with split y2 rows. Depth-3 chains.
- **22** 28→**50**, 3 layers (6×6). Column-oriented (contrasts 21's rows); six
  spanning columns tail-parked; two bent cross-layer feet for shape variety.
- **23 Pyramid** 42→**48**, 4 tiers 2/4/6/8. Deep 3-cell base queues; inner z2
  rows sweep through the core span tails → three-deep cross-layer chains
  (row → core span → apex).
- **24 Diamond** 34→**42**, 5 tiers 2/4/6/4/2. Full center span lattice
  (tip→equator→tip); deepened equator; four bent faceting nubs.
- **25 Hourglass** 30→**34**, 5 tiers 5/3/1/3/5 (recentred to (3,3)); single-cell
  waist preserved; eight bent corner flares (four per cap) exiting the true
  boundary.
- **26 3D Cross** 24→**32**, 5 layers. Plus-plate arms extended to length 8 with
  deep queues chaining toward the 2×2 post; post chains through the plate.
- **27 3D Star** 23→**31**, 7 layers. Core recentred to (7,7); six axis spikes
  lengthened into deep queues; extra near-cap N/S spikes; cap + corner + z spikes.
- **28 Cat** 43→**50**, 2 layers. Added a deep base/feet queue row per layer and
  a bent front paw; ears, head, hooked tail, spine spans kept.
- **29 Double Helix** 22→**32**, 10 layers. Parallel backbone arrow added at each
  base-pair (axis-aligned) layer so the two strands read as thick at the rungs;
  spiral and inward-bond chains unchanged.
- **30 Hollow Pyramid** 26→**33**, 4 shells. Outer ring rewritten as deep queues
  draining clockwise into the single free SE arrow; three bent corner buttresses.

Arrow-count average rose from ~29 to ~39 (all within the hard band [20,60],
none in the 51–60 warning zone). Compact figures (25/26/27/29/30) received
moderate increases to keep silhouettes legible (legibility-first, per the
approved per-figure judgment); larger footprints (21/22/23/24/28) went higher.

### Files Touched

- `tool/gen_levels.js` (Builder3D helpers + all ten 3D builders)
- `assets/levels/manual_levels_3d.json` (regenerated, levels 21–30)

### Verification Results

- `flutter analyze`: passed, no issues.
- `flutter test`: 235/235 passed (no test changes needed — the 3D group has no
  hardcoded arrow-count literals; all generic invariant tests cover 21–30).
- `node tool/gen_levels.js --generate-3d`: ALL VALID: true; asset written.
- `node tool/gen_levels.js --validate-only`: both sets ALL VALID, exit 0.
- `assets/levels/manual_levels_2d.json`: untouched (`--generate-2d`/`--generate`
  never run; 2D tier averages unchanged at 11.2 / 17.6 / 28.1).
- Per-layer ASCII silhouette render of all ten regenerated levels confirmed each
  figure still reads.

### New Tests

- None (no test literals changed; existing generic invariant suite covers all 10
  regenerated levels).

### Limitations

- **Manual device validation pending**: orbit/tilt/zoom each 3D level 21–30;
  confirm each figure reads under rotation; exit on a straight AND a bent arrow
  reads correctly through the whole animation; the deeper dependency chains are
  solvable by planning.
- Levels 26 and 27 have large sparse bounding boxes (16×16 / 15×15) from their
  long thin arms; they read as cross/star but render small — a candidate for a
  future respace if on-device legibility is poor.

### Next Recommended Phase

On-device validation of the redesigned 3D levels; tune any figure whose density
fights the renderer by respacing geometry (never by changing the painter).
