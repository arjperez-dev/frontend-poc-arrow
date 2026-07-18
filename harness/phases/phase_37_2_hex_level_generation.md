# PHASE 37.2 — Hexagonal Boards: Level Generation & Asset

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/harness/phases/phase_37_audit_findings.md`

**Depends on:** 37.1 (merged). The Dart validator must already accept
`metadata.topology: "hex"` — this phase's output is validated against it.
**Blocks:** 37.3.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task — in particular the whole of `tool/gen_levels.js`, and how `--generate-3d` was added in Phase 27/28 as the closest precedent for adding a generation mode without disturbing existing ones.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Task

Add a hex generation mode to the build-time level tool and produce a validated
hex level asset. Ten levels, internal numbers **31–40**.

### 1. `tool/gen_levels.js` — hex support

Follow the existing `--generate-3d` precedent: **add a parallel path, do not
generalise the existing 2D/figure/3D builders in place.** The audit's
constraint that the shipped 2D/3D assets stay byte-identical is much easier to
guarantee if their code path is untouched.

- `HEX_DELTA` table matching 37.1's `HexDirection` exactly (`east (+1,0)`,
  `northEast (+1,-1)`, `northWest (0,-1)`, `west (-1,0)`, `southWest (-1,+1)`,
  `southEast (0,+1)`). A drift between the JS table and the Dart enum is the
  single most likely source of "validates in JS, throws in Dart" bugs — mirror
  it literally and comment the cross-reference.
- `hexNeighbors(coord)` returning the 6 axial neighbours.
- `partitionNodesHex()` — the same most-constrained-first DFS as
  `partitionNodes`, over 6-neighbourhoods.
- `BuilderHex` with `arrowOverCells` and a hex `weave()` that adds connectivity
  edges **perpendicular to arrow sweeps** where possible. In hex geometry there
  is no true perpendicular; use the two axes not shared by the arrow's own
  direction, and verify the solvability guarantee empirically via the greedy
  solver rather than by construction.
- `hexRingMask(radius)` producing a regular hexagonal silhouette (all axial
  cells with cube-distance ≤ radius), plus at least two irregular masks for
  variety in the hard tier.
- Re-run every existing invariant against hex adjacency: `noSharedNodes`,
  no-free-nodes, `comp === 1` connectivity, greedy solvability,
  `hasSelfIntersectingArrow`, `hasInteriorGapExit`, density bands.
  Parameterise these by a neighbour function rather than duplicating them.
- New CLI mode `--generate-hex`: reads the on-disk hex asset (if any),
  regenerates 31–40, validates, and **writes only if every check passes** —
  same write-only-if-valid contract as the existing modes.
- `--validate-only` must additionally validate `manual_levels_hex.json` when
  present, and must keep passing on the 2D and 3D sets unchanged.

### 2. `assets/levels/manual_levels_hex.json` (new)

Ten levels, numbers 31–40, schema identical to the existing files, with:

```json
"metadata": { "topology": "hex", "difficulty": "...", "generationType": "hex" }
```

Node coordinates are axial `(q, r)` in the existing `x`/`y` fields; omit `z`.
Arrow `direction` values are the `HexDirection` names from 37.1.

Difficulty spread: 31–33 easy, 34–37 medium, 38–40 hard. Use the existing
density bands as a starting point but **expect to retune them** — a hex node
has 6 neighbours rather than 4, so a hex board of the same node count supports
denser, more interlocking arrow packing and the same arrow count plays harder.
Record the chosen bands and the reasoning in the handoff.

### 3. `pubspec.yaml`

Register the new asset file.

### 4. `docs/LEVEL_AUTHORING.md`

New section: hex topology, axial coordinates, the 6 direction names, the
`metadata.topology` flag, the `--generate-hex` command, and — following the
precedent of the spade/crown notes from Phase 16 — a concrete record of which
hex layouts fought the solvability checker and why.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes. Do not commit or push automatically.
- Feature branch only. Never `main`.
- **`manual_levels_2d.json` and `manual_levels_3d.json` must be byte-identical after this phase.** Prove it with `git diff --stat` on those two paths. Never run `--generate`, `--generate-2d`, `--generate-figures`, or `--generate-3d`.
- Do not modify any Dart source in this phase. If a hex level cannot be made to validate without a Dart change, **stop and report** — that means 37.1 was incomplete, and patching it from here would hide the gap.
- Graph-based only. No matrix/grid/tile model in the emitted JSON.

---

## Validation

```bash
node tool/gen_levels.js --generate-hex     # must report ALL VALID and write
node tool/gen_levels.js --validate-only    # all three sets valid, exit 0
flutter analyze
flutter test
git diff --stat -- assets/levels/manual_levels_2d.json assets/levels/manual_levels_3d.json   # must be empty
```

### New tests required

`test/features/game/infrastructure/manual_levels_hex_test.dart` — mirroring the
existing `manual_levels_test.dart` invariants against the hex set:

- `should_load_ten_hex_levels_numbered_31_to_40`
- `should_declare_hex_topology_in_metadata`
- `should_have_no_free_nodes_at_level_start`
- `should_be_greedy_solvable` (via the real Dart `MovementResolver`, not a mirror)
- `should_have_a_single_connected_component`
- `should_use_all_six_hex_directions_across_the_set`
- `should_have_no_interior_gap_exits`
- `should_have_bent_arrows_in_every_difficulty_tier`

The greedy-solvability test driving the **real** `MovementResolver` is the
important one — it is what proves the JS physics mirror and the Dart physics
actually agree. A JS-only check would not.

---

## Definition of Done

- Ten hex levels ship, all validating under the real Dart validator and
  solvable under the real Dart resolver.
- Existing 2D/3D assets provably untouched.
- The tool can regenerate the hex set deterministically from seeds.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report the final density bands chosen for hex and how they differ from the square bands, with the reasoning.

---

Do not be verbose. Be direct.
