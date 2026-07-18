# PHASE 37.1 — Hexagonal Boards: Domain Foundation (6 Directions + Topology Scoping)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/harness/phases/phase_37_audit_findings.md` **(required — §2 explains the delta-collision problem this phase exists to solve)**

**Depends on:** nothing. First slice of Phase 37.
**Blocks:** 37.2, 37.3, 37.4.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

Specifically confirm you understand, in your own words, why simply adding a
`HexDirection` enum to `MoveDirection.all` does **not** work. If that
explanation does not mention that four of the six axial hex deltas are
identical to the four `Direction` deltas, stop and re-read the audit §2.

---

## Task

Extend the domain so a board can declare hexagonal topology and resolve 6
directions, **without altering any behaviour for existing square levels**.

### 1. `lib/features/game/domain/board_topology.dart` (new)

```dart
enum BoardTopology { square, hex }
```

Document that `square` covers both the 2D plane and the 3D layer lattice
(`Direction` + `LayerDirection`), and that `hex` is planar-only.

### 2. `lib/features/game/domain/hex_direction.dart` (new)

`enum HexDirection implements MoveDirection` — pointy-top axial `(q, r)`
stored in `BoardCoordinate.x/y`, `dz` always 0:

| value | dx | dy |
|---|---|---|
| `east` | +1 | 0 |
| `northEast` | +1 | -1 |
| `northWest` | 0 | -1 |
| `west` | -1 | 0 |
| `southWest` | -1 | +1 |
| `southEast` | 0 | +1 |

`opposite` pairs east↔west, northEast↔southWest, northWest↔southEast.
`applyTo` mirrors `Direction.applyTo` (preserves `z`).

Names must not collide with any `Direction` or `LayerDirection` name — they
don't, but assert it in a test.

### 3. `lib/features/game/domain/move_direction.dart`

Replace the flat global registry with topology-scoped resolution:

- `static List<MoveDirection> allFor(BoardTopology topology)` —
  `square` → `[...Direction.values, ...LayerDirection.values]` (exactly today's
  `all`); `hex` → `[...HexDirection.values, ...LayerDirection.values]`.
- `static MoveDirection? between(BoardCoordinate from, BoardCoordinate to, {BoardTopology topology = BoardTopology.square})`
- `static MoveDirection? parse(String value, {BoardTopology topology = BoardTopology.square})` — keep throwing `FormatException` on unknown names. **Do not add a fallback that searches the other topology's set.**

Keep `static List<MoveDirection> get all` only if something still needs it;
prefer deleting it so no caller can accidentally get cross-topology matching.
Update its doc comment to explain the scoping rule and why the sets must stay
disjoint.

### 4. `lib/features/game/domain/board_graph.dart`

Add `final BoardTopology topology;` to the constructor, **defaulting to
`BoardTopology.square`**. Pass it to `MoveDirection.between` inside
`getNeighbor`. Propagate it in `layerSubgraph(z)`.

Do not change `nodeByCoordinate`, `_nodesByCoordinate`, or any map structure.

### 5. `lib/features/game/domain/level_definition_validator.dart`

- Read topology from `definition.metadata['topology']`: `'hex'` → `BoardTopology.hex`, absent/`'square'` → `BoardTopology.square`, anything else → throw `LevelDefinitionException`.
- Thread it into `MoveDirection.between` for the edge check, and into the constructed `BoardGraph`.
- Generalise the error string `'Edge ${edge.id} must be orthogonal.'` → `'Edge ${edge.id} must connect lattice-adjacent nodes.'` and update the one test asserting it.
- The head-direction check, self-intersection sweep, cycle check, branching-head check, and disjointness checks need **no logic change** — they already route through `applyTo`/coordinate equality. Verify this rather than assuming it.

### 6. `lib/features/game/infrastructure/level_definition_mapper.dart`

Thread the same metadata-derived topology into `MoveDirection.parse` at
line ~46. An arrow direction name unknown for the level's topology must still
throw — a hex level naming `"right"` is an authoring error, not a fallback.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes. Do not commit or push automatically.
- Work on a feature branch (e.g. `feat/phase-37-hex-boards`). Never `main`.
- **`MovementResolver` must not be modified.** It is already topology-agnostic (audit §1.3). If you believe it needs a change, stop and report — that finding would invalidate the phase plan.
- Do not touch `manual_levels_2d.json` or `manual_levels_3d.json`.
- Do not touch presentation (`lib/features/game/presentation/**`) or `tool/gen_levels.js` in this phase.
- No matrix/grid/tile runtime model. Graph-only.
- Every new parameter must default to `square` so existing call sites compile and behave identically.

---

## Validation

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only   # no level files touched; run as regression proof
```

All 275 existing tests must still pass. `--validate-only` must report
ALL VALID for both the 2D and 3D sets, exit 0.

### New tests required

In `test/features/game/domain/`:

- `hex_direction_test.dart`
  - `should_step_to_all_six_axial_neighbours`
  - `should_pair_opposites_correctly`
  - `should_preserve_z_when_applied`
  - `should_not_share_any_name_with_square_or_layer_directions`
- `move_direction_test.dart` (extend)
  - `should_resolve_east_not_right_when_topology_is_hex` ← **the regression proof for audit §2**
  - `should_resolve_right_not_east_when_topology_is_square`
  - `should_return_null_for_hex_diagonal_delta_when_topology_is_square`
  - `should_resolve_north_east_when_topology_is_hex`
  - `should_reject_hex_direction_name_when_topology_is_square`
- `level_definition_validator_test.dart` (extend)
  - `should_accept_hex_level_with_six_direction_adjacency`
  - `should_reject_hex_edge_between_non_adjacent_axial_nodes`
  - `should_reject_unknown_topology_metadata_value`
  - `should_still_reject_diagonal_edge_on_square_level` ← guards against the hex diagonals leaking into the square registry

Add a minimal hand-authored hex fixture (7 nodes: one centre + its 6
neighbours) to `test/features/game/game_test_fixtures.dart` as
`hexDefinition()`. 37.3 will reuse it.

---

## Definition of Done

- A hex level definition validates and produces a `BoardGraph` with
  `topology == hex` and correct 6-neighbour adjacency.
- `MovementResolver.resolve` correctly escapes/collides on that hex fixture
  **with zero resolver changes** — assert this in an application-layer test
  (`test/features/game/application/hex_movement_test.dart`), covering: clear
  sweep to boundary → escaped; blocker on the head's axial ray → collision;
  a bent hex arrow escaping.
- Zero behavioural change for square levels, proven by the untouched suite.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report whether `MovementResolver` truly needed no change. If it did, that is a finding worth surfacing prominently — it changes 37.3's risk profile.

---

Do not be verbose. Be direct.
