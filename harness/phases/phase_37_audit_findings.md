# Phase 37 — Hexagonal Boards: Pre-Implementation Audit

**Status:** audit only. No implementation code written, no branch created.
**Verdict:** feasible, but **must be split into 4 sub-phases** (37.1–37.4).
**Confidence in the audit:** high for domain/application; medium-high for
presentation (rendering polish is inherently iterative).

---

## 1. Current 2D Board System

### 1.1 Directions — already an open abstraction

`lib/features/game/domain/move_direction.dart` defines
`abstract interface class MoveDirection implements Enum` with `dx/dy/dz`,
`applyTo(BoardCoordinate)`, and `opposite`. Two implementations exist:

- `Direction` (`direction.dart`): `up(0,-1) right(1,0) down(0,1) left(-1,0)`, `dz => 0`
- `LayerDirection` (`layer_direction.dart`): `above(0,0,-1) below(0,0,1)`

Its own doc comment states the intent explicitly: *"New axes are added by
writing a new implementation, never by changing an existing one
(Open/Closed)."* This is the single most important finding — the 3D phase
already paid the cost of generalising away from a hardcoded 4-direction enum,
and hexagonal geometry inherits that work.

Three static members are the extension seam:

- `MoveDirection.all` — a flat `[...Direction.values, ...LayerDirection.values]`
- `MoveDirection.between(from, to)` — linear scan of `all`, first delta match
- `MoveDirection.parse(name)` — linear scan of `all`, first name match

### 1.2 Graph model

`BoardGraph` holds three maps built at construction: `_nodesById`,
`_nodesByCoordinate`, `_edgesById`. `GraphNode` is `{id, coordinate}`;
`GraphEdge` is `{id, fromNodeId, toNodeId, isBlocked}` — **undirected and
geometry-free**. There is no grid, no tile, no cell, no adjacency matrix
anywhere. Edges carry no direction; direction is always *derived* from the two
endpoint coordinates via `MoveDirection.between`.

`getNeighbor(nodeId, direction)` walks incident edges and compares
`MoveDirection.between(node.coord, other.coord) == direction`.
`layers`/`isMultiLayer`/`layerSubgraph(z)` are z-specific but additive and
harmless.

### 1.3 Movement resolver — geometry-agnostic already

`MovementResolver.resolve` (application) does **not** use `getNeighbor`. It
sweeps from the head only:

```dart
final nextCoord = arrow.direction.applyTo(currentNode.coordinate);
final nextNode = graph.nodeByCoordinate(nextCoord);
if (nextNode == null) break;                       // boundary → escaped
if (edge != null && edge.isBlocked) return collision;
if (blockerNodes.contains(nextNode.id)) return collision;
```

This loop contains **zero square-grid assumptions**. It works for any
`MoveDirection` whose `applyTo` lands on a coordinate that `nodeByCoordinate`
can find. Given a correct hex direction set, the resolver needs **no changes
at all**. Same for `MoveArrowUseCase`, lives, score, and victory.

### 1.4 Painter

`GraphBoardPainter.paint` (349 lines) draws: a rounded-rect background, then
`canvas.drawLine(from, to)` per edge, then per-arrow polylines through
`orderedNodeIds` with `StrokeJoin.round`, then an arrowhead rotated by the
arrow's direction, then node dots. **Positions come entirely from
`GraphBoardLayout.positionOf(nodeId)`** — the painter never touches
coordinates itself except through the layout.

`GraphBoardLayout.fromGraph` is the *only* place cartesian geometry is
hardcoded:

```dart
Offset(origin.dx + (coord.x - minX) * step, origin.dy + (coord.y - minY) * step)
```

A single uniform `step` for both axes, derived from bbox extents.

**Consequence:** hexagonal rendering is largely a *layout* change, not a
painter rewrite. Edges as straight lines between hex centres are already
correct for hex geometry. Only the hexagon cell outlines are genuinely new
drawing work.

### 1.5 Hit tester

`GraphBoardHitTester.findArrowAt` is purely metric: euclidean distance to the
head position, then `distanceToSegment` against consecutive `orderedNodeIds`
pairs, with slop `clamp(cellSize*0.45, 6, 28)`. **No cell-shape assumption
whatsoever.** It picks *arrows*, not cells. It works unchanged on a hex layout;
only the `0.45` factor may want retuning because hex centre spacing differs
between the two axes.

### 1.6 Level validator

`LevelDefinitionValidator.validate` (263 lines) performs, in order: duplicate
node/edge ids → edge endpoint existence → **`MoveDirection.between(...) == null`
→ throw "Edge must be orthogonal."** → blocked-edge existence → arrow node/edge
disjointness → cycle check → branching-head check → head-direction check
(`dir.opposite.applyTo(headCoord)` must be a body node) → self-intersection
sweep (`dir.applyTo` walk vs own body).

Every geometric check routes through `applyTo` / `between`. All of them are
therefore automatically correct for hex **provided the direction set resolves
correctly**. The only hardcoded word is the error string "orthogonal".

### 1.7 Level generator

`tool/gen_levels.js` is a build-time Node tool (not runtime). It carries its
own JS mirror of the physics: `DELTA` tables, `nodeAtCoord`, `canExit`,
`partitionNodes` (most-constrained-first DFS over 4-neighbourhoods),
`Builder`/`Builder3D`, `weave()`/`weaveH()`, plus validators
(`noSharedNodes`, `hasInteriorGapExit`, `hasSelfIntersectingArrow`,
greedy solvability, density bands, connectivity). Modes: `--validate-only`
(default, never writes), `--generate`/`--generate-2d`, `--generate-figures`,
`--generate-3d`.

This is the largest single body of square/cube-specific code in the project.

### 1.8 Assets & routing

Two asset files (`manual_levels_2d.json`, `manual_levels_3d.json`) are
concatenated by `LocalLevelDataSource.loadManualLevels()`. Node JSON is
`{id, x, y, z?}` — `z` optional, defaulting 0. **The JSON schema is already
tolerant**: adding hex levels needs no DTO change to nodes/edges/arrows, only
`direction` string values the parser doesn't currently know.

Mode routing is **binary**, and this is the second real problem area:
- `GameMode` enum has exactly two values (`twoD`, `threeD`).
- `isThreeDLevel(level)` returns a `bool`; `filterLevelsByGameMode` takes
  `wantThreeD: bool`.
- `displayNumberFor`, `maxInternalLevelFor`, `firstInternalLevelFor`,
  `hasNextLevelFor` all do arithmetic against the `twoDLevelCount = 20` split.
- `GameScreen` picks `GraphBoard` vs `Graph3DBoard` off that same boolean.

### 1.9 Square-grid assumptions — the actual list

| # | Assumption | Location | Severity |
|---|---|---|---|
| A1 | 4 planar directions with those 4 exact deltas | `direction.dart` | additive fix |
| A2 | Uniform `step` on both axes, `pos = (x,y)*step` | `graph_board_layout.dart` | **blocking** |
| A3 | Global flat direction registry; first delta match wins | `move_direction.dart` | **blocking, subtle** |
| A4 | Nodes are dots, cells are implicit (never drawn) | `graph_board_painter.dart` | new work |
| A5 | 4-neighbour DFS, `DELTA`, `weave` | `tool/gen_levels.js` | large, isolated |
| A6 | Board type is a boolean (2D or 3D) | `level_mode_filter.dart`, `game_mode.dart` | **blocking** |
| A7 | "orthogonal" wording | validator error string | cosmetic |

---

## 2. The One Hard Problem (A3)

This is the finding that determines the whole shape of the phase, and it is
not obvious from a casual read.

Pointy-top hexagons in axial coordinates `(q, r)` mapped onto `(x, y)` have six
neighbour deltas:

```
E  (+1,  0)     W  (-1,  0)
NE (+1, -1)     SW (-1, +1)
NW ( 0, -1)     SE ( 0, +1)
```

Compare against `Direction`: `right(1,0) left(-1,0) up(0,-1) down(0,1)`.

**Four of the six hex deltas are byte-identical to the four square deltas.**

Because `MoveDirection.between` is a linear scan over a flat global `all` list
returning the *first* delta match, a hex "east" step would resolve to
`Direction.right`, not `HexDirection.east`. And `NE`/`SW` are `(+1,-1)`/
`(-1,+1)` — currently unmatched by anything, so `between` returns `null` and
the validator throws **"Edge must be orthogonal"** on every hex diagonal edge.

So the naive "just add a `HexDirection` enum to `MoveDirection.all`" plan
fails in two directions at once: half the hex directions get silently
misidentified as square directions, and the other half get rejected outright.
Worse, adding NE/SW to the global registry would make `between` start
returning non-null for genuine diagonals on *square* boards — a real
regression risk to the 2D validator's orthogonality guarantee.

### Blast radius (measured, not assumed)

`between` / `parse` / `getNeighbor` / `isExitMove` / `getEdgeInDirection`
callers across `lib/`:

- `level_definition_validator.dart:55` — `MoveDirection.between` (edge check)
- `level_definition_mapper.dart:46` — `MoveDirection.parse` (arrow direction)
- `board_graph.dart` — `getNeighbor` internal to `getEdgeInDirection`/`isExitMove`

`getNeighbor`, `isExitMove`, and `getEdgeInDirection` have **no production
callers at all** — only three assertions in
`level_definition_validator_test.dart`. The runtime hot path
(`MovementResolver`) bypasses them entirely via `nodeByCoordinate`.

So the fix surface is genuinely two call sites, not a sprawl.

### Resolution: topology-scoped direction resolution

Introduce a `BoardTopology` (`square` | `hex`) that scopes which direction set
is consulted:

- `MoveDirection.allFor(topology)` replaces the flat `all`
- `MoveDirection.between(from, to, {topology = BoardTopology.square})`
- `MoveDirection.parse(name, {topology = BoardTopology.square})`

Defaulting `topology` to `square` keeps every existing call site and every
existing test behaviourally identical. `HexDirection` names must be distinct
(`east`, `northEast`, `northWest`, `west`, `southWest`, `southEast`) so `parse`
stays unambiguous, and the hex set is *never* merged into the square set.

`BoardGraph` gains a `topology` field (defaulting to `square`) so
`getNeighbor` can resolve within the right set. `LevelDefinitionValidator`
reads the topology from level metadata and threads it through.

**Note:** `LayerDirection` (`above`/`below`, dz-only) does not collide with
either set, and hex + layers are orthogonal concerns — a hex level is simply
single-layer. No 3D/hex interaction needs designing now.

---

## 3. Scope of Change

**New direction set** — `HexDirection` enum, 6 values, implementing the
existing `MoveDirection` interface. ~40 lines, mirrors `LayerDirection`.

**Coordinate system** — **no new type needed.** Axial `(q, r)` stores directly
in the existing `BoardCoordinate.x/y` with `z` unused (0). `BoardCoordinate` is
just an int triple with value equality; it carries no square-grid semantics.
This avoids touching `nodeByCoordinate`, the resolver, `GraphNode`, the DTO,
and the JSON schema. Cube coordinates are not needed — nothing in the codebase
computes hex distance or rotation.

**Edge connectivity** — no model change. `GraphEdge` is already an undirected
id pair. A hex node simply has up to 6 incident edges instead of 4.

**Rendering** — a `HexBoardLayout` (axial → pixel), and hexagon outlines
drawn per node. Pointy-top mapping:
`px = size*√3*(q + r/2)`, `py = size*1.5*r`.
Everything downstream of the layout (edges, arrow polylines, arrowheads,
exit path-following animation, collision shake) works unchanged, because all
of it is expressed in terms of `positionOf(nodeId)`.

**Hit-testing** — no structural change; the metric tester works as-is. Retune
the slop factor for hex spacing.

**Validation** — automatic once topology-scoped directions land. Only the
"orthogonal" error wording generalises to "adjacent along a lattice axis".

**Generator** — a new hex mode in `tool/gen_levels.js`: 6-neighbour `DELTA`
table, hex `partitionNodes`, a hex `weave`, hex silhouette masks, and the
existing invariant checks (greedy solvability, no-free-nodes, connectivity,
disjointness, self-intersection, gap-exit) re-run against hex adjacency. The
checks themselves are topology-parameterisable; the *layout builders* are not.

**Level format** — no schema change. `definitionJson.metadata.topology: "hex"`
as an additive, absent-means-square hint. This matches the precedent set by
Phase 34.1's `metadata.mode` and by `z`-optional nodes. New asset file
`assets/levels/manual_levels_hex.json`.

---

## 4. Single Phase or Split?

**Must be split.** Four sub-phases, strictly ordered.

- **Can the domain layer be extended without breaking 2D?** Yes — `MoveDirection`
  was designed for exactly this, and the topology parameter defaults to
  `square`. But it is *not* a no-op change (A3), so it needs its own phase with
  its own regression proof.
- **Can `MovementResolver` handle 6 directions with minimal changes?** With
  **zero** changes. It is already coordinate-driven. This is the strongest
  signal that the feature is feasible.
- **Is presentation a larger, separable chunk?** Yes — `GraphBoardLayout` +
  hexagon rendering + slop retuning is independent of the generator and
  independently testable against a hand-authored fixture.
- **Is the generator separable?** Yes, and it's the biggest chunk. It's a Node
  build tool with no Dart dependency; it only needs the *format* fixed.
- **Ordering dependencies?** 37.1 → everything (direction parsing gates level
  loading). 37.2 (generator/asset) before 37.3 (presentation) so the renderer
  has real levels to draw. 37.4 (mode routing) last, because it is the only
  user-visible switch and should flip on a fully working stack.

Sequencing 37.2 before 37.3 is a deliberate inversion of the usual
domain→app→UI order: rendering polish is judged by eye, and judging it against
one hand-authored 7-node fixture wastes the pass.

---

## 5. Conclusions

**Minimal safe file set.**

*37.1 (domain):* `hex_direction.dart` (new), `board_topology.dart` (new),
`move_direction.dart`, `board_graph.dart`, `level_definition_validator.dart`,
`level_definition_mapper.dart`.

*37.2 (generator/asset):* `tool/gen_levels.js`, `assets/levels/manual_levels_hex.json`
(new), `pubspec.yaml` (asset registration), `docs/LEVEL_AUTHORING.md`.

*37.3 (presentation):* `hex_board_layout.dart` (new), `hex_board_painter.dart`
(new), `hex_board.dart` (new), `graph_board_hit_tester.dart` (slop only),
`game_screen.dart` (board selection).

*37.4 (routing):* `game_mode.dart`, `level_mode_filter.dart`,
`local_level_data_source.dart`, `level_selection_screen.dart`,
`leaderboard_level_picker_screen.dart`, `app_config.dart`, ARB files.

**Risk of breaking existing 2D levels.** Low, and concentrated in 37.1. The
mitigations are structural rather than aspirational: `topology` defaults to
`square` everywhere; hex directions live in a separate registry and are never
merged into the square one; `manual_levels_2d.json` and `manual_levels_3d.json`
are never regenerated (the constraint forbids it, and 37.2 adds a hex-only
generator mode rather than touching the existing ones); and the existing 275-test
suite plus `--validate-only` on both shipped assets is the regression gate at
every sub-phase boundary.

The one risk worth naming honestly: if `topology` is ever threaded as a
*required* parameter instead of a defaulted one, the compiler will surface every
call site — which is safe — but a hex level whose metadata flag is missing would
silently validate under square rules and produce nonsense adjacency. 37.1 should
make the mapper fail loudly on an unknown direction name rather than fall back,
which the existing `parse` already does (`throw FormatException`).

**Can hex and square levels coexist?** Yes, and the architecture is unusually
well-prepared for it. Levels are independent graph documents; nothing is global
except the direction registry (fixed by 37.1) and the binary mode switch (fixed
by 37.4). Since a hex level is single-layer, `isMultiLayer` correctly reports
false for it — but note this means **topology must be read from metadata, not
inferred from graph shape**, which is a departure from the "graph shape is the
source of truth" rule Phase 34.1 established for 2D/3D. That departure is
unavoidable: a hex graph and a square graph are indistinguishable by node
coordinates alone, since axial coordinates reuse the same integer lattice. This
should be documented explicitly rather than left as a surprise.

**Own asset file?** Yes — `manual_levels_hex.json`, matching the existing
2D/3D file split. Same schema, additive metadata flag, appended by
`LocalLevelDataSource`. Reserve internal numbers **31–50** for hex, keeping the
`< 1000` local band and leaving the remote band untouched.

---

## 6. Deliverables

Generated alongside this audit:

- `harness/phases/phase_37_1_hex_domain_foundation.md`
- `harness/phases/phase_37_2_hex_level_generation.md`
- `harness/phases/phase_37_3_hex_board_rendering.md`
- `harness/phases/phase_37_4_hex_mode_routing.md`

Each carries the template's mandatory ≥95%-confidence gate and explicit
wait-for-approval step. No implementation code was written and no branch was
created as part of this audit.
