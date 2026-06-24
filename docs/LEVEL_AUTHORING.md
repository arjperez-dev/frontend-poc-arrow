# Level Authoring Guide

This guide explains how to author and edit the Arrow game's manual levels.

`assets/levels/manual_levels.json` is the **authoritative source of truth**. You
edit it by hand, then validate with:

```bash
node tool/gen_levels.js --validate-only
flutter test
```

The tool **never overwrites** the JSON unless you explicitly pass `--generate`
(see §12). Hand-edit freely — your changes will not be lost by validation.

---

## 1. Overview

A level is a **graph**: dots (nodes) connected by orthogonal links (edges).
Arrows are multi-segment paths lying on the graph. Tapping an arrow makes it
attempt a full exit, sliding in its head direction until it leaves the board or
hits another arrow's occupied shape (a collision). The runtime is graph-based —
there is no matrix/grid/tile model. Levels are deterministic and hand-authored.

## 2. File structure

```json
{
  "levels": [
    {
      "number": 1,
      "name": "First Exit",
      "difficulty": "easy",
      "definitionJson": {
        "nodes": [],
        "edges": [],
        "arrows": [],
        "blockedEdges": [],
        "metadata": {}
      }
    }
  ]
}
```

- Exactly **20 levels**, `number` 1–20.
- `difficulty`: `easy` (1–5), `medium` (6–10), `hard` (11–20, see §15 for the
  16–20 figure-level sub-tier).
- `definitionJson` holds the graph: `nodes`, `edges`, `arrows`, `blockedEdges`,
  `metadata`.

## 3. Nodes

```json
{ "id": "n2_1", "x": 2, "y": 1 }
```

- Integer grid coordinates; `x` increases right, `y` increases **down**.
- `id` must be unique. Convention: `n<x>_<y>` (e.g. `n2_1` at x=2, y=1).
- Nodes are the persistent visible dots; they remain after arrows escape.

## 4. Edges

```json
{ "id": "n0_0-n1_0", "fromNodeId": "n0_0", "toNodeId": "n1_0", "direction": "right" }
```

- An edge connects two **adjacent** nodes exactly one unit apart (orthogonal).
  Diagonal or longer edges are rejected by the validator.
- `id` must be unique. Convention: `<fromId>-<toId>`.
- `direction` is `right` | `left` | `down` | `up` (from → to). It is descriptive;
  the engine recomputes direction from coordinates.
- Edges are undirected for movement: an arrow can traverse an edge from either
  end. (The mapper also normalizes a reversed `occupiedEdges` reference like
  `n1_0-n0_0` to the canonical `n0_0-n1_0` if that edge exists.)

## 5. Arrows

```json
{
  "id": "a1",
  "occupiedEdges": ["n0_0-n1_0", "n1_0-n2_0"],
  "startNodeId": "n0_0",
  "endNodeId": "n2_0",
  "direction": "right"
}
```

- `endNodeId` is the **head** — it defines the exit direction.
- `occupiedEdges` is the arrow **body**: a contiguous chain of edges from the
  tail (`startNodeId`) to the head (`endNodeId`).
- `direction` is the head/exit direction. The arrow travels strictly in this
  direction and **never auto-turns**.
- `id` must be unique within the level.
- An arrow must have at least one occupied edge (≥ 2 nodes).

## 6. Straight arrows

A 3-node horizontal arrow whose head points right and exits off the right edge:

```json
{ "id": "a1", "occupiedEdges": ["n0_0-n1_0", "n1_0-n2_0"],
  "startNodeId": "n0_0", "endNodeId": "n2_0", "direction": "right" }
```

When tapped it slides right until the whole shape leaves the board (if the path
is clear).

## 7. Arrow shapes are arbitrary paths, **not** fixed templates

There are **no** predefined arrow templates such as "L arrow", "U arrow", or
"zigzag arrow". An arrow's visual shape is simply **the path produced by the
connected graph edges assigned to it** in `occupiedEdges`. Depending on those
edges (and `startNodeId` / `endNodeId` / `direction`) the same engine renders a
straight, L-shaped, U-shaped, zigzag, snake-like, long, short, or irregular
arrow — all are just paths.

- `endNodeId` is the head; `direction` is the exit direction.
- `occupiedEdges` is the connected body path from tail (`startNodeId`) to head.
- The head must be the **exit-facing** end: the body edge touching the head must
  lead *opposite* to `direction` (the body trails behind the head). The
  validator checks this.

To author an arbitrary path, list the body edges in order from tail to head.
Example bent path (right, right, then down; head at the bottom, exits down):

```json
{ "id": "a1",
  "occupiedEdges": ["n0_0-n1_0", "n1_0-n2_0", "n2_0-n2_1"],
  "startNodeId": "n0_0", "endNodeId": "n2_1", "direction": "down" }
```

The whole shape slides out as one rigid piece in the head direction. Collision
is tested against the **entire** shape, not just the head (see §10). Assign arrows
organically across the connected board; do not think in fixed shape templates.

## 8. Connected traversal graph (one board, no islands)

**Each level must be one single connected traversal graph.** A level must not
behave like several separate boards or disconnected islands. The validator
rejects any level whose graph has more than one connected component.

- Connectivity is over **all** nodes and edges (the traversal graph used by
  movement, exit, and collision simulation).
- If you want visual empty space, the gap must **not** split the graph. Bridge
  it so traversal continues across the gap. The current levels do this simply by
  keeping rows left-aligned and adding **vertical connector edges** between
  adjacent rows (perpendicular to the horizontal arrows, so they never change an
  arrow's exit sweep).
- An arrow must not escape early just because it reached a visual gap: if the
  traversal graph continues in the head direction, the arrow continues along it,
  and if another arrow sits on the continuation path, collision still happens.

### Hidden connector nodes (optional)

If a layout truly needs a gap that can't be bridged by edges between visible
nodes, you may add **hidden connector nodes** (`"hidden": true`). They:

- preserve traversal/collision continuity through the gap,
- are **not** drawn as normal board dots,
- are exempt from the visible no-free-nodes rule (§9),
- still participate in movement/exit/collision simulation.

The current levels do **not** use hidden connectors — connectivity is achieved
with connector edges between visible nodes, so every node stays visible and
occupied.

## 9. The no-free-nodes rule (visible nodes)

**Every visible/playable node must be occupied by at least one arrow at level
start.** A node is occupied if it is an arrow's `startNodeId`, `endNodeId`, or an
endpoint of one of its `occupiedEdges`. No visible node may be left bare.

- Hidden connector nodes (§8), if used, **may** be unoccupied — they exist only
  for traversal continuity.
- Two arrows must **not** share a node (their occupied shapes must be disjoint at
  the start).

Validate with `--validate-only`; it lists any free visible nodes.

## 10. Designing solvable levels

Movement model:
- Tapping an arrow attempts a full exit. The arrow's whole shape sweeps forward
  in the head direction. If any swept cell is occupied by **another active
  arrow** (head, body, or any node), the attempt is a collision — the arrow
  snaps back, you lose progress toward a life (every 2 mistakes = −1 life).
- Escaped arrows become inactive and **non-blocking**.

Key fact: because exiting an arrow only ever **frees** nodes (never adds a
blocker), the order among currently-exitable arrows does not matter. A level is
solvable iff a **greedy** strategy — repeatedly exit any arrow that can currently
exit — empties the board. The validator uses exactly this greedy check, so:

- The reliable design pattern is **filled lanes / queues**: a straight run of
  nodes fully covered by a queue of arrows all pointing toward the open end. The
  arrow nearest the boundary exits first; the next then becomes exitable; etc.
- **Disjoint lanes are always solvable.** Cross-blocking (an arrow whose exit
  path passes through another lane) is fine too, as long as the blocking lane can
  itself clear — greedy will find the order.

## 11. Increasing level density

- Add more lanes (rows/columns/arms).
- Make lanes longer and put **more arrows per lane** (deeper queues = more
  forced ordering).
- Use multi-segment (L/U/zigzag) arrows for visual and cognitive variety.
- Keep every node covered (§8) and keep lanes node-disjoint for guaranteed
  solvability.
- Vary lane widths, offsets, gaps, and orientations so boards don't all look
  like plain rectangles.

## 12. Designing difficulty

| Tier | Levels | Arrows | Board | Interactions |
|------|--------|--------|-------|--------------|
| Easy | 1–5 | **10–15** (soft ramp L1→L5) | up to ~6×6 | mostly queues, light blocking, varied shapes |
| Medium | 6–10 | **15–30** | up to ~8×8 | more blocking, more required ordering, more L/U shapes |
| Hard | 11–20 | **20–50** (51–60 allowed as a warning) | large, irregular | heavy blocking, complex shapes, may need zoom/pan |

11–15 are random irregular-rectangle boards; 16–20 are fixed figure
silhouettes (heart/diamond/club/spade/crown) — see §15.

Cross-tier rule: **average arrows must strictly increase** easy < medium < hard.
Hard levels must **not all be full rectangles**. Do not inflate arrow counts at
the cost of a readable board — beyond ~50 arrows the validator warns, and 61+
fails.

## 13. Validating after editing

After editing `manual_levels.json` by hand:

```bash
# Validate the on-disk JSON. Never writes. Exits non-zero on any failure.
node tool/gen_levels.js --validate-only

# Run the Dart guarantees (validator, no-free-nodes, greedy solvability,
# density bands, progression, graph-based runtime).
flutter test
```

The validator reports, per level: node/arrow counts, bounding box, whether the
board is a full rectangle, free nodes (must be none), solvability, and any
density-band violation. It also checks difficulty progression, strictly
increasing tier averages, and that hard levels aren't all rectangles.

The report also shows `comp=` (connected components — must be 1) per level.

Common failures:
- `edge not orthogonal/unit` — an edge connects non-adjacent or diagonal nodes.
- `DISCONNECTED(n)` — the level graph has `n` islands; make it one connected
  traversal graph (§8).
- `free [...]` — a visible node isn't covered by any arrow (§9).
- `solvable=false` — a deadlock; usually two arrows share a node, or an arrow's
  exit path is permanently blocked.
- `density … out of [min,max]` — arrow count is outside the tier band (§12).

### Regenerating (optional, intentional only)

`tool/gen_levels.js` also contains in-script builders that can regenerate the
denser baseline:

```bash
node tool/gen_levels.js --generate          # rebuilds levels 1-15, WRITES manual_levels.json
node tool/gen_levels.js --generate-figures  # rebuilds levels 16-20 only, WRITES manual_levels.json
```

Use either only when you intend to replace the corresponding hand-authored
JSON. `--generate-figures` reads the 15 levels already on disk and carries
them through byte-for-byte (it never touches 1–15); it only regenerates and
replaces 16–20. Day-to-day authoring is hand-editing the JSON +
`--validate-only`.

## 14. blockedEdges

`blockedEdges` is an array of edge ids that act as static walls. It is kept for
schema compatibility and is **empty** in all current levels — the intended
blocker is other active arrows, not static zones. Leave it empty unless you have
a strong, specific reason.

## 15. Figure levels (16–20)

Levels 16–20 are **fixed shape silhouettes** instead of random rectangles:
heart (16), diamond (17), club (18), spade (19), crown (20). Each shape is a
hand-tuned continuous formula (an implicit curve, a union of circles, or a
point-in-polygon test) rasterized onto an integer grid in
`tool/gen_levels.js` (`heartNodeSet`, `diamondNodeSet`, `clubNodeSet`,
`spadeNodeSet`, `crownNodeSet`). Only the *partition into arrows* is randomized
per seed — the silhouette itself is fixed.

### Generation differences from the random tiers (1–15)

- **Both `weave()` and `weaveH()`** are called (not just `weave()`), because an
  irregular blob silhouette needs grid-adjacency in both axes for the
  connected-traversal-graph requirement (§8) — a row-aligned rectangle does
  not.
- **All four directions required.** The random tiers only require "at least
  one vertical arrow, ≤60% in any single direction" — which is why several of
  levels 1–15 are missing a direction entirely. Figure levels require all of
  up/down/left/right present, each with at least `max(2, 10% of arrow count)`
  arrows, capped at 45% for any one direction.
- **`hasInteriorGapExit`/`flipInteriorGapArrows` do not apply.** That check
  exists to catch an accidental hole in an otherwise-rectangular board (the
  bug fixed in Phase 14). A figure silhouette is *deliberately* non-rectangular
  and mathematically simply connected (no enclosed holes) — every "missing"
  cell inside its bounding box is part of the shape's own visible concave
  edge, not an accidental gap. Applying the bbox-relative check here rejects
  almost every valid partition (verified empirically). `validateAll`'s
  `gapExit=` column reports `Y(figure-ok)` for these levels instead of
  treating it as a failure; the matching Dart test
  (`should_have_no_interior_gap_exits`) excludes levels with
  `metadata.generationType == 'figure'` for the same reason.
- **Solvability is the tightest constraint, not density.** A shape with a
  large, dense, nearly-rectangular or nearly-circular region (e.g. a fat
  ellipse body, or a tall solid rim band) can have a near-zero greedy-solvable
  rate — sometimes 0 in several thousand sampled partitions — even though
  density and connectivity are fine. When tuning a shape, check the actual
  solved rate (not just coverage) before fixing a density band, and prefer a
  smaller/thinner silhouette over a denser one if solvability is rare.
  `FIGURE_MAX_RETRIES` (20000) is generous specifically because the
  solvable-partition rate for some shapes is under 0.1%.
- **`metadata.generationType` is `'figure'`**, not `'manual'`, so these levels
  are distinguishable from the random tiers (used by the gapExit exemption
  above; nothing else depends on it).

### Adding or changing a figure level

1. Write a `*NodeSet()` function returning a `Map<id, {x, y}>` (see the
   existing five for the pattern). Use `rasterMask(W, H, predicate)` and wrap
   the result in `keepLargestComponent()` as a safety net.
2. Sanity-check the silhouette by printing its ASCII raster before wiring it
   in — ad hoc, not part of the script. A shape that looks right at a glance
   usually still needs proportion tuning (see the spade/crown history below).
3. Add the entry to `FIGURE_LEVEL_DEFS` with a `maxPathLen` and density
   `band`. Run `node tool/gen_levels.js --generate-figures` and read the
   per-level `attempt N:` line it prints — if it throws after exhausting
   `FIGURE_MAX_RETRIES`, the thrown error includes a rejection-reason
   breakdown (coverage / density / disconnected / selfIntersect /
   directionVariety / unsolvable counts) to tell you which constraint is the
   bottleneck.
4. Re-run `flutter test` — `manual_levels_test.dart` covers all 20 levels
   generically except the few assertions with literal counts.

History worth knowing: an early spade (a wide ellipse body) looked more
distinctly spade-shaped in isolation but was a near-total solvability dead
end (0 solved in 300+ sampled partitions) — replaced with a narrower,
proven-solvable body plus a flared stem/foot, which is what actually reads as
"spade". An early crown used one shared linear taper formula for all 5
spikes and rendered as illegible noise; the fix was defining each spike's
triangle explicitly with consistent gaps, then shrinking the whole shape
(a large solid rim band, like a dense near-rectangle, had a near-zero
solvable rate) until the solved rate became reliable (~1% per attempt).
