# PHASE 37.4 — Hexagonal Boards: Mode Routing, Progression & UI

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/harness/phases/phase_37_audit_findings.md` **(§1.8 and §5 — mode routing is currently binary; this is the last blocking assumption)**

**Depends on:** 37.1, 37.2, 37.3 (all merged).
**Blocks:** nothing. Final slice of Phase 37.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit `game_mode.dart`, `level_mode_filter.dart`, `local_level_data_source.dart`, `level_selection_screen.dart`, `leaderboard_level_picker_screen.dart`, `level_progression.dart`, `level_complexity.dart`, `game_screen.dart`, `player_settings.dart`, and the SharedPreferences settings adapter.
2. Explain your understanding of the current state — in particular, enumerate every place that treats board type as a **boolean** rather than an enum. The audit lists the ones found; confirm the list is complete rather than trusting it.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Task

Make hexagonal a first-class third mode, end to end.

### 1. `lib/features/settings/domain/game_mode.dart`

Add `hex('HEX')`. `fromStorageKey` already falls back to `twoD` for unknown
keys, so existing persisted settings stay valid — verify this rather than
assuming, and keep the fallback.

### 2. `lib/features/game/presentation/level_mode_filter.dart`

This file is the crux. Replace boolean board-type logic with a mode-returning
function:

- `GameMode modeOfLevel(Level level)` — read `boardGraph.topology == hex` → `GameMode.hex`; else the existing `isThreeDLevel` logic.
- `filterLevelsByGameMode(levels, {required GameMode mode})` replacing the `wantThreeD: bool` signature.
- Reserve internal numbers **31–50** for hex. Update `twoDLevelCount`-based arithmetic (`displayNumberFor`, `maxInternalLevelFor`, `firstInternalLevelFor`, `hasNextLevelFor`) to be range-driven per mode rather than a single split point.
- Keep `isThreeDLevel` if other call sites still need it, but it must not be the routing authority any more.

**Important and non-obvious:** topology is read from **metadata**, not inferred
from graph shape. This is a deliberate departure from the "graph shape is the
source of truth" rule Phase 34.1 established for 2D/3D, and it is unavoidable —
a hex graph and a square graph are indistinguishable by node coordinates alone,
because axial coordinates reuse the same integer lattice. Document this
explicitly in the file's doc comment and in `DYNAMIC_LEVELS_CONTRACT.md`'s
frontend-facing notes, so a future reader doesn't "fix" it back.

### 3. `lib/features/game/infrastructure/local_level_data_source.dart`

Load and append `assets/levels/manual_levels_hex.json` after the 3D set.
Update the doc comment describing the file split.

### 4. Level selection & leaderboard picker

`level_selection_screen.dart` and `leaderboard_level_picker_screen.dart`:
build the progression from the hex-filtered list when the mode is hex. Both
already build a per-mode `LevelProgression` (Phase 29), so this is a filter
argument change, not new machinery. The three modes must never share a sorting
pipeline.

### 5. Main menu / mode selector

Add the hex option wherever 2D/3D is currently chosen. Add ARB keys to
`app_en.arb` and `app_es.arb` and regenerate localizations. Do not hardcode
user-facing strings.

### 6. Complexity analyzer

`level_complexity.dart` computes tiers from structure. Check whether its
weights produce sane hex tiers — a 6-neighbour board changes the
"initially blocked arrows" metric's meaning. If the shipped hex levels band
implausibly, **report it and propose a calibration** rather than silently
retuning thresholds, since the existing thresholds are pinned by
`level_complexity_test.dart` against the 30 shipped square levels.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify Git remotes. Do not commit or push automatically.
- Feature branch only. Never `main`.
- Do not touch `manual_levels_2d.json` or `manual_levels_3d.json`.
- **Internal level numbers for existing levels 1–30 must not change.** Storage, routing, leaderboard submission, and backend mapping all key off them; renumbering would silently invalidate every user's saved progress.
- Do not change the remote-level band (`>= 1000`) or its routing.
- Leaderboard/progress/sync behaviour for 2D and 3D must be unchanged.

---

## Validation

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only
```

### New tests required

- `test/features/game/presentation/level_mode_filter_test.dart` (extend)
  - `should_route_hex_topology_level_to_hex_mode`
  - `should_still_route_square_and_3d_levels_unchanged`
  - `should_not_route_a_single_layer_hex_level_as_2d` ← the regression this phase most plausibly introduces
- `test/features/levels/presentation/` — hex levels appear in hex mode only; 2D and 3D lists are unchanged in content and order.
- `test/features/progress/` — unlock progression works within hex independently of the other two modes.
- A test asserting levels 1–30 keep their internal numbers and their existing 2D/3D mode assignment.

Any widget test mounting `GameScreen` must inject a deterministic
`loadLevels`/`loadLevelByNumber` — see the Phase 29 test-infrastructure note in
`CODEX_HANDOFF.md`. Do not mount it without one.

---

## Definition of Done

- Hex is selectable from the main menu; hex levels list, unlock, and play.
- 2D and 3D progressions, display numbers, unlock state, and leaderboard
  behaviour are byte-for-byte unchanged.
- The full Phase 37 stack works end to end: a player picks hex mode, opens a
  hex level, taps an arrow, and it exits along one of six directions on a
  visibly hexagonal board.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report the state of the manual-validation backlog for Phase 37 as a whole — consistent with prior phases, on-device validation is expected to remain pending unless a device is actually available.

---

Do not be verbose. Be direct.
