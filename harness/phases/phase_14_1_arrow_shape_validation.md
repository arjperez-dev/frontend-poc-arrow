# PHASE 14.1 — Arrow Shape Fix: Generator Cycle Bug

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Context

Phase 14 is complete and merged to `main` (audio/localization audit done;
interior gap exit bug fixed; validator cycle checks added). Work continues on
branch `feat/phase-14-audio-and-collision-fix` — **do not switch branches**.

**This is a re-do. The previous attempt failed.** A prior agent (sonnet)
claimed `partitionNodes` **cannot** produce cycles because it uses DFS with
`unvisited.delete`, and so only added validator-side checks. **That claim was
WRONG.** Validator checks alone are NOT sufficient. The bug is in the
**GENERATOR**.

**Hard evidence — do not dispute it:**
- Visual screenshots show **Level 12** rendering a **pink arrow that forms a
  closed rectangle** — a 4-node loop, head at top-right pointing right, body
  connecting back on itself to form a cycle.
- The level data in `assets/levels/manual_levels.json` confirms it.

The generator **CAN and DID** produce a cyclic arrow. Do **not** open with "it
cannot happen." It happened. Your job is to **prove the mechanism** and **kill
it at the source**.

**Why a cycle is a defect:** `ArrowPath` (P11) models arrows as **simple
paths** — an ordered tail-to-head node sequence `[startNodeId, …, endNodeId]`.
`_deriveOrderedNodeIds` walks occupied edges assuming exactly one continuation
per node. A cycle gives a node two body edges → the walk is ambiguous and the
ordered sequence is ill-defined. `LEVEL_AUTHORING.md §7` also requires the head
to have exactly one incident body edge leading opposite to `direction`; a cycle
violates this.

---

## Task

### A — Locate the exact cyclic arrow (evidence first)
Open `assets/levels/manual_levels.json` and inspect **Level 12 arrow by
arrow**. Find the cyclic arrow. Document its:
- `id`
- `occupiedEdges` (full list)
- `startNodeId`, `endNodeId`
- `direction`
- `orderedNodeIds`

Confirm it is a true cycle (start reachable back to itself, or `edges >= nodes`
over the covered node set), not a legal bent path.

### B — Trace it back to the generator and prove the mechanism
Open `tool/gen_levels.js`. Determine **which function** emitted this arrow. Do
not stop at the first plausible cause — prove it with the actual code path:
- `partitionNodes` — did a DFS path revisit a node? Did **singleton merging**
  splice two segments into a loop?
- `Builder.arrowOverCells` — did it add an edge that closes a loop?
- `flipInteriorGapArrows` — did reversing start/end on a bent path create a cycle?
- `weave()` / `weaveH()` — did a weave edge get wrongly included in `occupiedEdges`?
- `buildCombFallback` or any other fallback path.
- A **seed-specific** edge case where the random partition closes a loop.

Identify the **exact line(s)** responsible. The previous agent's "DFS +
`unvisited.delete` makes cycles impossible" reasoning is incomplete — find the
gap it missed (e.g. merging, weave edges, or post-processing reintroducing an
edge between already-visited nodes).

### C — Fix the generator so cycles are IMPOSSIBLE
The fix must live in `tool/gen_levels.js` and guarantee no cyclic arrow can ever
be emitted, under any seed:
- Add **cycle detection during arrow construction** (e.g. union-find or a
  visited/edge-count check as each occupied edge is added — reject the moment
  `edges >= nodes` over the arrow's node set).
- Ensure every arrow path stays **simple**: no loops, no branches (each interior
  node degree 2, both endpoints degree 1).
- **Reject and retry** any candidate level that contains a cyclic or branching
  arrow, rather than shipping it.

### D — Add the equivalent check to `--validate-only`
Ensure `validateAll` in `tool/gen_levels.js` fails on any cyclic/branching arrow,
so regression is caught at generation time, not just at runtime.

### E — Regenerate level data
Run `node tool/gen_levels.js --generate` to rewrite
`assets/levels/manual_levels.json`.

### F — Verify the data is clean
- Run `node tool/gen_levels.js --validate-only` → must pass with **no cycle errors**.
- Inspect **Level 12** specifically → confirm the cyclic arrow is **gone**.
- Inspect **all 15 levels** → confirm no arrow has `startNodeId == endNodeId`
  or otherwise forms a closed loop or branch.

### G — Harden the Dart validator (defense in depth)
In `lib/features/game/domain/level_definition_validator.dart`, ensure
`validate()` throws `LevelDefinitionException` when a single arrow's
`occupiedEdgeIds`:
- form a **cycle**, or
- give the head (`endNodeId`) **more than one** incident body edge (branching), or
- have a head body edge inconsistent with `direction` (must lead **opposite**).
Messages must include the arrow id and the violated invariant. (Confirm whether
Phase 14 already added these; complete any gap.)

### H — Tests
Add to the validator test suite if not already present:
- `should_reject_arrow_with_cyclic_path` — one arrow whose occupied edges close
  a loop → expect `LevelDefinitionException`.
- `should_reject_arrow_with_branching_head` — one arrow whose head node has two
  incident body edges → expect `LevelDefinitionException`.

Run `flutter test` and confirm **all** tests pass.

---

## Constraints

- Work **only** inside `frontend-poc-arrow/`.
- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code unless explicitly required.
- Do not modify Git remotes.
- Graph-based runtime only — no grid/matrix/tile logic.
- The fix MUST be in the **generator** (`tool/gen_levels.js`). Validator-only
  changes are explicitly insufficient and will be rejected.
- **Stay on branch `feat/phase-14-audio-and-collision-fix`.** Do not switch branches.
- Do not commit or push. Stage only if ≥ 95% confident.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only
```

Manual checks:
- Level 12's pink cyclic arrow is gone.
- No arrow in any of the 15 levels has `startNodeId == endNodeId` or forms a
  closed loop / branch.
- Every arrow head has exactly one body edge, leading opposite its direction.
- The two validator tests fail-fast on cyclic and branching arrows.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md` — add **Phase 14.1 as COMPLETE**.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
