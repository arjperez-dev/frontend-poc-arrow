// Level tool for the Arrow game (Phase 11 — random bent-arrow generator).
//
// Phase 24.1: the single manual_levels.json asset was split into two files,
// with internal level numbers kept globally unique (no renumber): 2D levels
// 1-20 live in manual_levels_2d.json, 3D levels 21-25 in manual_levels_3d.json.
//
//   node tool/gen_levels.js --validate-only   (default, no args)
//       Reads both asset files, runs all checks on each independently. Never writes.
//
//   node tool/gen_levels.js --generate-2d
//       Generates levels 1-15 (random) + 16-20 (figures), validates as the 2D
//       set, writes manual_levels_2d.json.
//
//   node tool/gen_levels.js --generate-3d
//       Generates levels 21-25 (hand-designed), validates as the 3D set,
//       writes manual_levels_3d.json.
//
//   node tool/gen_levels.js --generate
//       Shorthand: runs --generate-2d then --generate-3d.
//
// Generation algorithm (sparse graph + DFS partition):
//   1. Define a W×H node grid (coordinate-based adjacency, NO edges upfront).
//   2. Partition ALL nodes into node-disjoint simple paths via most-constrained-
//      first DFS walk (fewest unvisited neighbours first), capped at maxPathLen.
//      Singletons are merged into adjacent path tails/heads.
//   3. Convert paths to arrows via Builder.arrowOverCells (adds ONLY the body
//      edges of each arrow — sparse horizontal edges, no inter-arrow edges).
//   4. Builder.weave() adds vertical edges between all vertically-adjacent nodes
//      for graph connectivity (weave edges are perpendicular to all horizontal
//      arrows, so they never affect horizontal sweeps).
//   5. Because no inter-arrow horizontal edges exist in the graph, every
//      horizontal arrow's sweep uses only its own body edges → exits immediately
//      → trivially greedy-solvable with ~100% success rate.
//   6. Arrows whose last DFS step is vertical (direction=up/down) are reversed
//      or retried; they're unusual and the greedy check catches any edge cases.
//   7. Retry up to MAX_RETRIES per level with different seeds. Fallback: comb
//      pattern (kept as safety net; should not trigger in normal operation).
//
// Checks: structure, no-free-nodes, greedy solvability, difficulty progression,
// density bands, strictly increasing tier averages, hard-not-all-rectangular,
// single connected component.

'use strict';
const fs = require('fs');
const path = require('path');

const ASSET_2D = path.join(__dirname, '..', 'assets', 'levels', 'manual_levels_2d.json');
const ASSET_3D = path.join(__dirname, '..', 'assets', 'levels', 'manual_levels_3d.json');
// Per-tier retry budgets. Hard gets a large budget so the random partition
// algorithm finds a valid varied level without falling back to a deterministic
// layout. This is a build-time tool — spending a few seconds per hard level
// is acceptable.
const MAX_RETRIES = { easy: 200, medium: 200, hard: 8000 };

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------
const nid = (x, y) => `n${x}_${y}`;
const eid = (a, b) => `${a}-${b}`;

// z is optional on nodes (absent = 0, i.e. an ordinary 2D level).
const zOf = n => n.z || 0;

function dirBetween(a, b) {
  const za = zOf(a), zb = zOf(b);
  if (za === zb) {
    if (b.x === a.x + 1 && b.y === a.y) return 'right';
    if (b.x === a.x - 1 && b.y === a.y) return 'left';
    if (b.x === a.x && b.y === a.y + 1) return 'down';
    if (b.x === a.x && b.y === a.y - 1) return 'up';
    return null;
  }
  if (b.x === a.x && b.y === a.y) {
    if (zb === za + 1) return 'below';
    if (zb === za - 1) return 'above';
  }
  return null;
}
// Unit steps as [dx, dy, dz]. above/below are the z-layer axis (3D levels).
const DELTA = {
  right: [1, 0, 0], left: [-1, 0, 0], down: [0, 1, 0], up: [0, -1, 0],
  above: [0, 0, -1], below: [0, 0, 1],
};
const H_DIRS = ['right', 'left']; // horizontal directions

function parseCoord(id) {
  const m = id.match(/^n(-?\d+)_(-?\d+)$/);
  return { x: parseInt(m[1], 10), y: parseInt(m[2], 10) };
}

// ---------------------------------------------------------------------------
// Seeded PRNG (Park-Miller LCG)
// ---------------------------------------------------------------------------
function makePRNG(seed) {
  let s = ((seed >>> 0) || 1) & 0x7fffffff;
  return {
    next() { s = Math.imul(s, 48271) & 0x7fffffff; if (s === 0) s = 1; return s / 0x80000000; },
    int(n)  { return Math.floor(this.next() * n); },
    bool(p) { return this.next() < p; },
    shuffle(arr) {
      const a = arr.slice();
      for (let i = a.length - 1; i > 0; i--) { const j = this.int(i + 1); [a[i], a[j]] = [a[j], a[i]]; }
      return a;
    },
  };
}

// ---------------------------------------------------------------------------
// Builder (sparse graph — only adds edges that are explicitly requested)
// ---------------------------------------------------------------------------
function Builder(number, name, difficulty) {
  return {
    number, name, difficulty,
    _nodes: new Map(), _edges: new Map(), _arrows: [], _seq: 0,
    addNode(x, y) {
      const id = nid(x, y);
      if (!this._nodes.has(id)) this._nodes.set(id, { x, y });
      return id;
    },
    addEdge(a, b) {
      if (!this._edges.has(eid(a, b)) && !this._edges.has(eid(b, a)))
        this._edges.set(eid(a, b), { from: a, to: b });
    },
    edgeBetween(a, b) {
      if (this._edges.has(eid(a, b))) return eid(a, b);
      if (this._edges.has(eid(b, a))) return eid(b, a);
      return null;
    },
    // Add a node-list as a single arrow. `cells` is [[x,y],...] tail→head.
    arrowOverCells(cells, direction) {
      const ids = cells.map(([x, y]) => this.addNode(x, y));
      for (let i = 0; i < ids.length - 1; i++) this.addEdge(ids[i], ids[i + 1]);
      const occ = [];
      for (let i = 0; i < ids.length - 1; i++) occ.push(this.edgeBetween(ids[i], ids[i + 1]));
      this._arrows.push({
        id: 'a' + (++this._seq),
        occupiedEdges: occ,
        startNodeId: ids[0],
        endNodeId:   ids[ids.length - 1],
        direction,
      });
    },
    // Add vertical edges between every vertically-adjacent node pair for
    // graph connectivity. These edges are perpendicular to horizontal arrows
    // and never extend a horizontal sweep. They are NOT added between nodes
    // that don't already exist (no phantom nodes are created).
    weave() {
      for (const [id, p] of this._nodes) {
        const below = nid(p.x, p.y + 1);
        if (this._nodes.has(below)) this.addEdge(id, below);
      }
    },
    // Add horizontal edges between every horizontally-adjacent node pair for
    // graph connectivity. Used by mixed layouts where vertical sections would
    // otherwise be disconnected from each other.
    weaveH() {
      for (const [id, p] of this._nodes) {
        const right = nid(p.x + 1, p.y);
        if (this._nodes.has(right)) this.addEdge(id, right);
      }
    },
    build(meta) {
      const nm = this._nodes;
      return {
        number, name, difficulty,
        definitionJson: {
          nodes: [...nm.entries()].map(([id, p]) => ({ id, x: p.x, y: p.y })),
          edges: [...this._edges.entries()].map(([id, e]) => ({
            id, fromNodeId: e.from, toNodeId: e.to,
            direction: dirBetween(nm.get(e.from), nm.get(e.to)),
          })),
          arrows: this._arrows.map(a => ({ ...a })),
          blockedEdges: [],
          metadata: { difficulty, timeLimit: meta.t, maxMoves: meta.m,
            generationType: 'manual', seed: null },
        },
      };
    },
  };
}

// ---------------------------------------------------------------------------
// Grid node set (coordinates only — no edges added here)
// ---------------------------------------------------------------------------
function makeNodeSet(W, H, rng, removalFraction) {
  const nodes = new Map();
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      nodes.set(nid(x, y), { x, y });

  if (removalFraction > 0) {
    const boundary = rng.shuffle(
      [...nodes.keys()].filter(id => {
        const p = nodes.get(id); return p.x === 0 || p.x === W-1 || p.y === 0 || p.y === H-1;
      })
    );
    const target = Math.floor(boundary.length * removalFraction);
    let removed = 0;
    for (const id of boundary) {
      if (removed >= target) break;
      nodes.delete(id);
      if (coordBfsComponents(nodes) !== 1) nodes.set(id, parseCoord(id));
      else removed++;
    }
  }
  return nodes;
}

// BFS connectivity using coordinate adjacency (no edgeMap needed).
function coordBfsComponents(nodes) {
  if (nodes.size === 0) return 0;
  const seen = new Set();
  let comps = 0;
  for (const start of nodes.keys()) {
    if (seen.has(start)) continue;
    comps++;
    const stack = [start];
    seen.add(start);
    while (stack.length) {
      const { x, y } = nodes.get(stack.pop());
      for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
        const nb = nid(x+dx, y+dy);
        if (nodes.has(nb) && !seen.has(nb)) { seen.add(nb); stack.push(nb); }
      }
    }
  }
  return comps;
}

// Coordinate-based adjacency (used by DFS partition; ignores edges).
function coordAdj(id, nodes) {
  const { x, y } = nodes.get(id);
  const nbs = [];
  for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
    const nb = nid(x+dx, y+dy);
    if (nodes.has(nb)) nbs.push(nb);
  }
  return nbs;
}

// ---------------------------------------------------------------------------
// Shape masks (figure levels 16-20) — rasterize a continuous silhouette
// formula onto an integer grid, then keep only the largest 4-connected
// component as a safety net against thin extremities (e.g. a star tip)
// pinching off into an isolated cell at the chosen resolution.
// ---------------------------------------------------------------------------
function keepLargestComponent(nodes) {
  const seen = new Set();
  let best = [];
  for (const startId of nodes.keys()) {
    if (seen.has(startId)) continue;
    const comp = [startId];
    seen.add(startId);
    const stack = [startId];
    while (stack.length) {
      const curId = stack.pop();
      const { x, y } = nodes.get(curId);
      for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
        const nb = nid(x + dx, y + dy);
        if (nodes.has(nb) && !seen.has(nb)) { seen.add(nb); stack.push(nb); comp.push(nb); }
      }
    }
    if (comp.length > best.length) best = comp;
  }
  const result = new Map();
  for (const id of best) result.set(id, nodes.get(id));
  return result;
}

function rasterMask(W, H, predicate) {
  const nodes = new Map();
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      if (predicate(x, y)) nodes.set(nid(x, y), { x, y });
  return keepLargestComponent(nodes);
}

// Classic implicit heart curve (u²+v²−1)³ − u²v³ ≤ ε. v is flipped so the
// cusp/notch (two lobes) sits at the top and the point tapers at the bottom.
function heartNodeSet() {
  const W = 29, H = 27, cx = 14, cy = 10, s = 6.2, eps = 0.02;
  return rasterMask(W, H, (x, y) => {
    const u = (x - cx) / s, v = -(y - cy) / s;
    const t = u * u + v * v - 1;
    return (t * t * t - u * u * v * v * v) <= eps;
  });
}

// Rhombus: Manhattan distance <= 1 from center. Always single-component.
function diamondNodeSet() {
  const W = 15, H = 15, cx = 7, cy = 7, sx = 7, sy = 7;
  return rasterMask(W, H, (x, y) => {
    const u = (x - cx) / sx, v = (y - cy) / sy;
    return Math.abs(u) + Math.abs(v) <= 1;
  });
}

// Trefoil (top + left + right circles) over a stem column. The stem starts
// well inside the top circle's footprint so it bridges into the body with no
// gap (a gap here would otherwise split the stem into its own component).
function clubNodeSet() {
  const W = 21, H = 21;
  const cx = (W - 1) / 2, r = 3.525, sep = 4.725;
  const topC = [cx, 5.25];
  const leftC = [cx - sep, 5.25 + sep * 0.85];
  const rightC = [cx + sep, 5.25 + sep * 0.85];
  const inCircle = (x, y, [ccx, ccy]) => {
    const dx = x - ccx, dy = y - ccy; return dx * dx + dy * dy <= r * r;
  };
  return rasterMask(W, H, (x, y) => {
    if (inCircle(x, y, topC) || inCircle(x, y, leftC) || inCircle(x, y, rightC)) return true;
    return Math.abs(x - cx) <= 1.8 && y >= 8.25 && y <= 18;
  });
}

// Heart curve, unflipped (point at the top, rounded body below — the same
// proven-solvable silhouette family as the original spade), widened
// anisotropically (sx > sy) for fuller "shoulders", plus a narrow stem that
// flares gradually to a wide triangular foot at the very bottom. The flared
// foot is what reads as "spade" rather than a generic point-up teardrop; an
// earlier wide-ellipse-bodied version with a plain stem looked more
// distinctly spade-shaped but was a near-total solvability dead end (0/300
// in testing) — the round, densely-packed body left almost no resolvable
// lane structure for the greedy solver.
function spadeNodeSet() {
  const W = 29, H = 31, cx = 14, cy = 16, sx = 6.4, sy = 5.6, eps = 0.02;
  const stemHalf = 1.6, stemFrom = 22, footFrom = 26, footTo = 30, footHalf = 4.2;
  return rasterMask(W, H, (x, y) => {
    const u = (x - cx) / sx, v = (y - cy) / sy;
    const t = u * u + v * v - 1;
    if ((t * t * t - u * u * v * v * v) <= eps) return true;
    if (Math.abs(x - cx) <= stemHalf && y >= stemFrom && y <= footFrom) return true;
    if (y > footFrom && y <= footTo) {
      const frac = (y - footFrom) / (footTo - footFrom);
      const half = stemHalf + frac * (footHalf - stemHalf);
      if (Math.abs(x - cx) <= half) return true;
    }
    return false;
  });
}

// A royal crown: 5 individually-tapered triangular spikes (the center one
// tallest, like a real crown) sitting on a solid rim band with a small
// flared base, plus a jewel orb on the center spike's tip. Each spike is
// defined explicitly (not a generic repeating step) so there is a clear,
// consistent gap between adjacent spikes at every row — a first attempt
// using one shared linear taper for all spikes rendered as illegible noise
// at this resolution instead of 5 distinct points.
function crownNodeSet() {
  const W = 21, H = 11, cx = 10, halfW = 8;
  const bandTop = 7, bandBot = 9, baseY = 10, flareMult = 1.2;
  const spikeBaseHalf = 1.5, tipHalf = 0.4, jewelR = 0.9;
  const spikeTops = [
    { dx: -7, topY: 4 }, { dx: -3.5, topY: 2 }, { dx: 0, topY: 0, jewel: true },
    { dx: 3.5, topY: 2 }, { dx: 7, topY: 4 },
  ];
  return rasterMask(W, H, (x, y) => {
    if (y >= bandTop && y <= bandBot && Math.abs(x - cx) <= halfW) return true;
    if (y > bandBot && y <= baseY) {
      const half = halfW + (y - bandBot) * flareMult;
      if (Math.abs(x - cx) <= half) return true;
    }
    for (const { dx, topY, jewel } of spikeTops) {
      const spikeX = cx + dx;
      if (y >= topY && y <= bandTop) {
        const frac = (y - topY) / (bandTop - topY);
        const half = tipHalf + frac * (spikeBaseHalf - tipHalf);
        if (Math.abs(x - spikeX) <= half) return true;
      }
      if (jewel) {
        const jdx = x - spikeX, jdy = y - topY;
        if (jdx * jdx + jdy * jdy <= jewelR * jewelR) return true;
      }
    }
    return false;
  });
}

// ---------------------------------------------------------------------------
// Path partition (most-constrained-first DFS, horizontal-end bias)
//
// After partitioning, paths satisfy:
//   • Every node belongs to exactly one path (complete coverage).
//   • Consecutive nodes are coordinate-adjacent (a body edge will exist).
//   • Last step is preferably horizontal; the arrow direction from the last
//     step is stored in the path's `dir` field.
// ---------------------------------------------------------------------------
function partitionNodes(nodes, rng, maxPathLen) {
  const unvisited = new Set(nodes.keys());
  const paths = []; // each entry: { nodeIds: [...], dir }

  while (unvisited.size > 0) {
    // Most-constrained first: fewest unvisited neighbours.
    let startId = null, bestDeg = Infinity;
    for (const id of unvisited) {
      const deg = coordAdj(id, nodes).filter(nb => unvisited.has(nb)).length;
      if (deg < bestDeg) { bestDeg = deg; startId = id; }
    }

    unvisited.delete(startId);
    const path = [startId];
    let cur = startId;

    while (path.length < maxPathLen) {
      const allCands = rng.shuffle(coordAdj(cur, nodes).filter(nb => unvisited.has(nb)));
      if (!allCands.length) break;
      path.push(allCands[0]);
      unvisited.delete(allCands[0]);
      cur = allCands[0];
    }

    if (path.length >= 2) {
      paths.push({ nodeIds: path, dir: finalDir(path, nodes) });
    } else {
      // Singleton: merge into adjacent path.
      mergeSingleton(path[0], paths, nodes);
    }
  }

  return paths;
}

function finalDir(path, nodes) {
  if (path.length < 2) return null;
  return dirBetween(nodes.get(path[path.length - 2]), nodes.get(path[path.length - 1]));
}

function mergeSingleton(id, paths, nodes) {
  // Try prepend to tail (safest: doesn't change head direction).
  for (const nb of coordAdj(id, nodes)) {
    for (const p of paths) {
      if (p.nodeIds[0] === nb) { p.nodeIds.unshift(id); return; }
    }
  }
  // Try append to head (changes head node; last step still valid).
  for (const nb of coordAdj(id, nodes)) {
    for (const p of paths) {
      if (p.nodeIds[p.nodeIds.length - 1] === nb) {
        p.nodeIds.push(id);
        p.dir = finalDir(p.nodeIds, nodes);
        return;
      }
    }
  }
  // Worst case: keep as singleton (coverage check will fail → retry).
  paths.push({ nodeIds: [id], dir: null });
}

// ---------------------------------------------------------------------------
// Level generator
// ---------------------------------------------------------------------------
// Grid sizes and maxPathLen are tuned so expected arrow counts hit the density
// bands without excess retries:
//   Easy   6×6=36 nodes, pathLen≤4  → E[arrows] ≈ 10–13  band [10,15]
//   Medium 8×8=64 nodes, pathLen≤4  → E[arrows] ≈ 18–22  band [15,30]
//   Hard   9–12×9–12 with removal, pathLen≤5 → E[arrows] ≈ 22–40  band [20,50]
const LEVEL_CONFIGS = {
  easy:   { W: 6, Wvar: 1, H: 6, Hvar: 1, maxPathLen: 4, removalFrac: 0    },
  medium: { W: 8, Wvar: 1, H: 8, Hvar: 1, maxPathLen: 4, removalFrac: 0    },
  hard:   { W: 9, Wvar: 3, H: 9, Hvar: 3, maxPathLen: 5, removalFrac: 0.12 },
};

const DENSITY = {
  easy:   { min: 10, max: 15 },
  medium: { min: 15, max: 30 },
  hard:   { min: 20, max: 60, warn: 50 },
};

function generateLevel(number, name, difficulty, meta, baseSeed) {
  const cfg = LEVEL_CONFIGS[difficulty];
  const band = DENSITY[difficulty];
  const maxRetries = MAX_RETRIES[difficulty] || 200;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const rng = makePRNG(baseSeed + attempt * 97);

    const W = cfg.W + rng.int(cfg.Wvar + 1);
    const H = cfg.H + rng.int(cfg.Hvar + 1);
    const remFrac = difficulty === 'hard' ? cfg.removalFrac + rng.next() * 0.10 : 0;

    const nodeSet = makeNodeSet(W, H, rng, remFrac);
    const totalNodes = nodeSet.size;

    const paths = partitionNodes(nodeSet, rng, cfg.maxPathLen);

    // Validate: all nodes covered, no singletons.
    const covered = new Set(paths.flatMap(p => p.nodeIds));
    if (covered.size !== totalNodes) continue;
    if (paths.some(p => p.nodeIds.length < 2)) continue;

    // Build via Builder (sparse graph: only body edges + weave).
    const b = Builder(number, name, difficulty);
    for (const { nodeIds, dir } of paths) {
      b.arrowOverCells(nodeIds.map(id => {
        const { x, y } = nodeSet.get(id); return [x, y];
      }), dir);
    }
    b.weave();
    const level = b.build(meta);
    const dj = level.definitionJson;

    // Density check.
    const n = dj.arrows.length;
    if (n < band.min || n > band.max) continue;

    // Must have at least one bent arrow (≥3 nodes) per level.
    if (!dj.arrows.some(a => a.occupiedEdges.length >= 2)) continue;

    // Graph must be one connected component (sparse graph can be disconnected
    // when the removal leaves parts joined only through removed horizontal edges).
    if (connectedComponents(dj) !== 1) continue;

    // Fix interior gap exits by reversing affected arrows before checking
    // direction variety. An interior gap exit occurs when an arrow's head sweep
    // hits a removed boundary node inside the bounding box. Reversing the arrow
    // makes it exit from the opposite end, which is typically an interior node
    // with no gap in the opposite direction. After reversal the body-behind-head
    // invariant still holds (verified algebraically).
    flipInteriorGapArrows(dj);

    // Verify no gaps remain after flipping (both ends near removed nodes).
    if (hasInteriorGapExit(dj)) continue;

    // Reject any arrow whose head sweep hits its own body (self-intersection).
    // This catches U/spiral paths where the exit direction points back into the
    // arrow's own tail — visually a "closed loop" defect.
    if (hasSelfIntersectingArrow(dj)) continue;

    // Direction variety check (after flip since directions may have changed):
    // require at least one vertical arrow; cap any single direction at 60%.
    const dirCounts = {};
    for (const a of dj.arrows) dirCounts[a.direction] = (dirCounts[a.direction] || 0) + 1;
    const hasVertical = (dirCounts['up'] || 0) + (dirCounts['down'] || 0) > 0;
    const maxDirFrac = Math.max(...Object.values(dirCounts)) / dj.arrows.length;
    if (!hasVertical || maxDirFrac > 0.60) continue;

    // Greedy solvability (after flip, directions changed — re-evaluate).
    if (!solvableGreedy(dj)) continue;

    console.log(`  #${number} attempt ${attempt + 1}: ${n} arrows, ${totalNodes} nodes, ${W}x${H}`);
    return level;
  }

  // All retries exhausted — fail loudly. No shipped level may come from a
  // deterministic fallback. Increase MAX_RETRIES or tune LEVEL_CONFIGS.
  throw new Error(
    `Level #${number} '${name}' (${difficulty}): exhausted all ${maxRetries} retries ` +
    `without finding a valid varied level. Increase MAX_RETRIES.hard or tune LEVEL_CONFIGS.hard.`
  );
}

// ---------------------------------------------------------------------------
// Figure levels (16-20): fixed shape silhouette (heart/diamond/club/spade/
// star) instead of a random rectangle. Only the partition into arrows is
// retried per seed — the node set itself is deterministic per shape.
//
// Direction-variety is stricter here than the random tiers: the random
// generator only requires "at least one vertical arrow, cap 60%", which is
// why several of levels 1-15 are missing a direction entirely. Figure levels
// must use all four directions so every escape has arrows leaving every way.
// ---------------------------------------------------------------------------
const FIGURE_MAX_RETRIES = 100000;

function generateFigureLevel(number, name, meta, seed, nodeSetFactory, maxPathLen, band) {
  const reject = { coverage: 0, density: 0, noBent: 0, disconnected: 0,
    gapExit: 0, selfIntersect: 0, directionVariety: 0, unsolvable: 0 };
  for (let attempt = 0; attempt < FIGURE_MAX_RETRIES; attempt++) {
    const rng = makePRNG(seed + attempt * 97);
    const nodeSet = nodeSetFactory();
    const totalNodes = nodeSet.size;

    const paths = partitionNodes(nodeSet, rng, maxPathLen);

    const covered = new Set(paths.flatMap(p => p.nodeIds));
    if (covered.size !== totalNodes) { reject.coverage++; continue; }
    if (paths.some(p => p.nodeIds.length < 2)) { reject.coverage++; continue; }

    const b = Builder(number, name, 'hard');
    for (const { nodeIds, dir } of paths) {
      b.arrowOverCells(nodeIds.map(id => {
        const { x, y } = nodeSet.get(id); return [x, y];
      }), dir);
    }
    b.weave();
    b.weaveH(); // irregular blob shapes need both axes woven for connectivity
    const level = b.build(meta);
    const dj = level.definitionJson;
    dj.metadata.generationType = 'figure';

    const n = dj.arrows.length;
    if (n < band.min || n > band.max) { reject.density++; continue; }
    if (!dj.arrows.some(a => a.occupiedEdges.length >= 2)) { reject.noBent++; continue; }
    if (connectedComponents(dj) !== 1) { reject.disconnected++; continue; }

    // The blanket hasInteriorGapExit is deliberately NOT applied here — it
    // false-positives on every concave dent in a figure silhouette (100% of
    // coverage-passing attempts failed it, per Phase 16 notes). Instead use
    // the figure-aware hasRealInteriorGapExit (Phase 19), which only rejects
    // a gap that hides a real blocker (another arrow's node past the gap) —
    // the actual P14-class defect — while allowing harmless shape concavities.
    if (hasRealInteriorGapExit(dj)) { reject.gapExit++; continue; }

    if (hasSelfIntersectingArrow(dj)) { reject.selfIntersect++; continue; }

    // All four directions required, each with a meaningful share — not just
    // "has a vertical arrow". This is what makes arrows exit every way.
    const dirCounts = {};
    for (const a of dj.arrows) dirCounts[a.direction] = (dirCounts[a.direction] || 0) + 1;
    const minPerDir = Math.max(2, Math.floor(n * 0.10));
    const allFour = ['up', 'down', 'left', 'right'].every(d => (dirCounts[d] || 0) >= minPerDir);
    const maxDirFrac = Math.max(...['up', 'down', 'left', 'right'].map(d => dirCounts[d] || 0)) / n;
    if (!allFour || maxDirFrac > 0.45) { reject.directionVariety++; continue; }

    if (!solvableGreedy(dj)) { reject.unsolvable++; continue; }

    console.log(`  #${number} attempt ${attempt + 1}: ${n} arrows, ${totalNodes} nodes, dirs=${JSON.stringify(dirCounts)}`);
    return level;
  }

  throw new Error(
    `Figure level #${number} '${name}': exhausted all ${FIGURE_MAX_RETRIES} retries ` +
    `without finding a valid level. Rejection breakdown: ${JSON.stringify(reject)}. ` +
    `Tune the shape mask or band.`
  );
}

// ---------------------------------------------------------------------------
// DEAD CODE — buildCombFallback is no longer called. generateLevel throws
// instead of falling back to this deterministic layout. Retained for reference.
// ---------------------------------------------------------------------------
function buildCombFallback(number, name, difficulty, meta, seed) { // eslint-disable-line no-unused-vars
  // Parameters tuned to hit density bands: easy [10,15], medium [15,30], hard [20,60].
  // H-section: nHRows rows each with W/2 two-node arrows, alternating right/left.
  // V-section: nVCols columns each with nVPC two-node down-pointing arrows.
  // Total arrows = nHRows*(W/2) + nVCols*nVPC
  const CFG = {
    easy:   { W: 6, nHRows: 3, nVCols: 2, nVPC: 2 }, // 9 + 4 = 13
    medium: { W: 8, nHRows: 4, nVCols: 3, nVPC: 3 }, // 16 + 9 = 25
    hard:   { W:10, nHRows: 5, nVCols: 4, nVPC: 4 }, // 25 + 16 = 41
  };
  const { W, nHRows, nVCols, nVPC } = CFG[difficulty];
  const b = Builder(number, name, difficulty);

  // H-section: rows 0..nHRows-1, full width W.
  // Even rows point right (head at right end), odd rows point left (head at left end).
  for (let y = 0; y < nHRows; y++) {
    const nArrows = W / 2;
    for (let ai = 0; ai < nArrows; ai++) {
      if (y % 2 === 0) {
        // Right: tail at x=ai*2, head at x=ai*2+1
        b.arrowOverCells([[ai*2, y], [ai*2+1, y]], 'right');
      } else {
        // Left: tail at x=ai*2+1, head at x=ai*2
        b.arrowOverCells([[ai*2+1, y], [ai*2, y]], 'left');
      }
    }
  }

  // V-section: nVCols columns evenly spaced across x=0..W-1, rows nHRows..nHRows+nVPC*2-1.
  // Each column gets nVPC two-node down-pointing arrows.
  // V-column x-positions: spread evenly so they connect to H-section via weave().
  const vStep = Math.floor(W / (nVCols + 1));
  for (let ci = 0; ci < nVCols; ci++) {
    const cx = vStep * (ci + 1);
    for (let ai = 0; ai < nVPC; ai++) {
      const ty = nHRows + ai * 2;
      b.arrowOverCells([[cx, ty], [cx, ty + 1]], 'down');
    }
  }

  b.weaveH(); // connect H-section rows and bridge H→V sections horizontally
  b.weave();  // connect nodes vertically within each column
  return b.build(meta);
}

function buildCombLevel(number, name, difficulty, meta, nTeeth, nCombs) {
  const b = Builder(number, name, difficulty);
  const baseW = nTeeth * 2;
  for (let ci = 0; ci < nCombs; ci++) {
    const ty = ci * 3, by = ci * 3 + 1, ry = ci * 3 + 2;
    for (let ti = 0; ti < nTeeth; ti++) {
      const tx = ti * 2;
      b.arrowOverCells([[tx, ty], [tx, by], [tx + 1, by]], 'right');
    }
    const conn = [];
    for (let x = baseW - 1; x >= 0; x--) conn.push([x, ry]);
    b.arrowOverCells(conn, 'left');
  }
  b.weave();
  return b.build(meta);
}

// ---------------------------------------------------------------------------
// Level definitions
// ---------------------------------------------------------------------------
const LEVEL_DEFS = [
  { number:  1, name: 'Level 1',  difficulty: 'easy',   meta: { t: 120, m: 30  }, seed: 10001 },
  { number:  2, name: 'Level 2',  difficulty: 'easy',   meta: { t: 120, m: 33  }, seed: 20002 },
  { number:  3, name: 'Level 3',  difficulty: 'easy',   meta: { t: 120, m: 36  }, seed: 30003 },
  { number:  4, name: 'Level 4',  difficulty: 'easy',   meta: { t: 120, m: 39  }, seed: 40004 },
  { number:  5, name: 'Level 5',  difficulty: 'easy',   meta: { t: 120, m: 45  }, seed: 50005 },
  { number:  6, name: 'Level 6',  difficulty: 'medium', meta: { t: 100, m: 48  }, seed: 60006 },
  { number:  7, name: 'Level 7',  difficulty: 'medium', meta: { t: 100, m: 54  }, seed: 70007 },
  { number:  8, name: 'Level 8',  difficulty: 'medium', meta: { t: 100, m: 63  }, seed: 80008 },
  { number:  9, name: 'Level 9',  difficulty: 'medium', meta: { t: 100, m: 72  }, seed: 90009 },
  { number: 10, name: 'Level 10', difficulty: 'medium', meta: { t: 100, m: 84  }, seed: 10010 },
  { number: 11, name: 'Level 11', difficulty: 'hard',   meta: { t: 90,  m: 66  }, seed: 11011 },
  { number: 12, name: 'Level 12', difficulty: 'hard',   meta: { t: 90,  m: 84  }, seed: 12012 },
  { number: 13, name: 'Level 13', difficulty: 'hard',   meta: { t: 90,  m: 105 }, seed: 13013 },
  { number: 14, name: 'Level 14', difficulty: 'hard',   meta: { t: 80,  m: 126 }, seed: 14014 },
  { number: 15, name: 'Level 15', difficulty: 'hard',   meta: { t: 80,  m: 150 }, seed: 15015 },
];

function buildLevels() {
  return LEVEL_DEFS.map(d => generateLevel(d.number, d.name, d.difficulty, d.meta, d.seed));
}

// Figure levels 16-20: heart, diamond, club, spade, star. Arrow-count bands
// step up from level 15's 22 arrows, staying inside the hard tier's overall
// [20,60] density band (51-60 is an allowed warning, per LEVEL_AUTHORING.md).
const FIGURE_LEVEL_DEFS = [
  { number: 16, name: 'Level 16', meta: { t: 75, m: 168 }, seed: 160016,
    nodeSetFactory: heartNodeSet,   maxPathLen: 6, band: { min: 24, max: 32 } },
  { number: 17, name: 'Level 17', meta: { t: 70, m: 186 }, seed: 170017,
    nodeSetFactory: diamondNodeSet, maxPathLen: 3, band: { min: 34, max: 40 } },
  { number: 18, name: 'Level 18', meta: { t: 65, m: 204 }, seed: 180018,
    nodeSetFactory: clubNodeSet,    maxPathLen: 4, band: { min: 33, max: 40 } },
  { number: 19, name: 'Level 19', meta: { t: 60, m: 222 }, seed: 190019,
    nodeSetFactory: spadeNodeSet,   maxPathLen: 5, band: { min: 34, max: 41 } },
  { number: 20, name: 'Level 20', meta: { t: 55, m: 240 }, seed: 200020,
    nodeSetFactory: crownNodeSet,   maxPathLen: 4, band: { min: 25, max: 32 } },
];

function buildFigureLevels() {
  return FIGURE_LEVEL_DEFS.map(d => generateFigureLevel(
    d.number, d.name, d.meta, d.seed, d.nodeSetFactory, d.maxPathLen, d.band
  ));
}

// ---------------------------------------------------------------------------
// 3D levels 21-25 (deterministic hand-designed builders — no RNG)
//
// Multi-layer levels: nodes carry a z coordinate; arrows may point 'above'/
// 'below'. EVERY arrow occupies at least 2 nodes — vertical arrows always
// span a z-edge between two layers (single-node arrows looked like floating
// dots and are forbidden everywhere). Cross-layer gameplay comes from two
// mechanisms:
//   1. a vertical arrow's head sweep passes through cells of the layers
//      beyond it — blocked until the arrows covering those cells escape;
//   2. a planar arrow's sweep passes through a vertical arrow's cell on its
//      own layer — blocked until the vertical escapes.
//
// 23-25 are figure levels: layer silhouettes of different sizes stack into a
// recognizable 3D form (pyramid / diamond / hourglass).
//
// Design invariants (same as every other tier, verified by validateAll and
// the Dart asset tests): every node covered at start, node/edge-disjoint
// arrows, single connected component, greedy-solvable, hard density band.
// ---------------------------------------------------------------------------
const nid3 = (x, y, z) => `n${x}_${y}_${z}`;

function Builder3D(number, name, difficulty) {
  return {
    number, name, difficulty,
    _nodes: new Map(), _edges: new Map(), _arrows: [], _seq: 0,
    addNode(x, y, z) {
      const id = nid3(x, y, z);
      if (!this._nodes.has(id)) this._nodes.set(id, { x, y, z });
      return id;
    },
    addEdge(a, b) {
      if (!this._edges.has(eid(a, b)) && !this._edges.has(eid(b, a)))
        this._edges.set(eid(a, b), { from: a, to: b });
    },
    edgeBetween(a, b) {
      if (this._edges.has(eid(a, b))) return eid(a, b);
      if (this._edges.has(eid(b, a))) return eid(b, a);
      return null;
    },
    _pushArrow(ids, direction) {
      for (let i = 0; i < ids.length - 1; i++) this.addEdge(ids[i], ids[i + 1]);
      const occ = [];
      for (let i = 0; i < ids.length - 1; i++) occ.push(this.edgeBetween(ids[i], ids[i + 1]));
      this._arrows.push({
        id: 'a' + (++this._seq), occupiedEdges: occ,
        startNodeId: ids[0], endNodeId: ids[ids.length - 1], direction,
      });
    },
    // Horizontal arrow over consecutive x cells at (y, z). Tail→head order:
    // for 'left' the head is the lowest x, for 'right' the highest.
    rowArrow(xs, y, z, direction) {
      const ordered = direction === 'left' ? [...xs].sort((a, b) => b - a) : [...xs].sort((a, b) => a - b);
      this._pushArrow(ordered.map(x => this.addNode(x, y, z)), direction);
    },
    // Vertical-in-plane arrow over consecutive y cells at (x, z). Tail→head:
    // for 'up' the head is the lowest y, for 'down' the highest.
    colArrow(ys, x, z, direction) {
      const ordered = direction === 'up' ? [...ys].sort((a, b) => b - a) : [...ys].sort((a, b) => a - b);
      this._pushArrow(ordered.map(y => this.addNode(x, y, z)), direction);
    },
    // Layer-axis arrow occupying the z-edge (x,y,zTail)-(x,y,zHead).
    verticalSpan(x, y, zTail, zHead, direction) {
      this._pushArrow([this.addNode(x, y, zTail), this.addNode(x, y, zHead)], direction);
    },
    // Layer-axis arrow over consecutive z cells at (x, y) — the multi-layer
    // generalization of verticalSpan. Tail→head: for 'above' the head is the
    // lowest z, for 'below' the highest.
    zColArrow(zs, x, y, direction) {
      const ordered = direction === 'above' ? [...zs].sort((a, b) => b - a) : [...zs].sort((a, b) => a - b);
      this._pushArrow(ordered.map(z => this.addNode(x, y, z)), direction);
    },
    // Free-form arrow over an explicit tail→head cell path [[x,y,z], ...].
    // Used by figure levels for bent arrows that step across layers
    // (staircase rays, tails). Caller must order cells tail→head and pass
    // the direction of the LAST step (head must be the exit-facing end).
    pathArrow(cells, direction) {
      this._pushArrow(cells.map(([x, y, z]) => this.addNode(x, y, z)), direction);
    },
    // In-plane connectivity: x- and y-edges between adjacent nodes of the
    // same layer. Never gameplay-relevant (edges only matter when blocked),
    // exactly like the 2D tiers' weave(); both axes are woven because 3D
    // layers may consist of column arrows with no row edges of their own.
    weaveLayers() {
      for (const [id, p] of this._nodes) {
        const below = nid3(p.x, p.y + 1, p.z);
        if (this._nodes.has(below)) this.addEdge(id, below);
        const right = nid3(p.x + 1, p.y, p.z);
        if (this._nodes.has(right)) this.addEdge(id, right);
      }
    },
    // Split a sorted run of ints into contiguous groups of `size` (a trailing
    // singleton is merged back so no group is length 1).
    _chunk(run, size) {
      const out = [];
      for (let i = 0; i < run.length; i += size) out.push(run.slice(i, i + size));
      if (out.length > 1 && out[out.length - 1].length === 1) {
        const last = out.pop(); out[out.length - 1].push(...last);
      }
      return out;
    },
    _runs(vals) {
      const s = [...new Set(vals)].sort((a, b) => a - b);
      const runs = []; let run = [s[0]];
      for (let k = 1; k < s.length; k++) {
        if (s[k] === s[k - 1] + 1) run.push(s[k]);
        else { runs.push(run); run = [s[k]]; }
      }
      runs.push(run); return runs;
    },
    // Fill a row (fixed y,z) over x cells with a QUEUE of disjoint same-direction
    // arrows (deeper queue = more forced ordering). Splits automatically at gaps
    // and into groups of `size` (default 2). Every run must be length >= 2.
    queueRow(xs, y, z, direction, size = 2) {
      for (const run of this._runs(xs)) {
        if (run.length < 2) throw new Error(`queueRow run <2 at y${y} z${z}: ${run}`);
        for (const c of this._chunk(run, size)) this.rowArrow(c, y, z, direction);
      }
    },
    // Fill a column (fixed x,z) over y cells with a queue of disjoint arrows.
    queueCol(ys, x, z, direction, size = 2) {
      for (const run of this._runs(ys)) {
        if (run.length < 2) throw new Error(`queueCol run <2 at x${x} z${z}: ${run}`);
        for (const c of this._chunk(run, size)) this.colArrow(c, x, z, direction);
      }
    },
    build(meta) {
      const nm = this._nodes;
      return {
        number: this.number, name: this.name, difficulty: this.difficulty,
        definitionJson: {
          nodes: [...nm.entries()].map(([id, p]) => ({ id, x: p.x, y: p.y, z: p.z })),
          edges: [...this._edges.entries()].map(([id, e]) => ({
            id, fromNodeId: e.from, toNodeId: e.to,
            direction: dirBetween(nm.get(e.from), nm.get(e.to)),
          })),
          arrows: this._arrows.map(a => ({ ...a })),
          blockedEdges: [],
          metadata: { difficulty: this.difficulty, timeLimit: meta.t, maxMoves: meta.m,
            generationType: '3d', seed: null },
        },
      };
    },
  };
}

// Level 21 — three full 6×5 layers, ~40 arrows. Hardened intro: six spanning
// columns thread all three layers, each parked at the tail end of its row so
// no planar queue ever sweeps into it (keeps the board acyclic and solvable),
// while every vertical's head sweep lands on a covered blocker cell one layer
// away (depth-2), and those blockers sit mid-queue (depth-3). Two center
// columns (2,2)/(3,2) are punched through the middle with the y2 rows split to
// sweep outward around them.
function build3DLevel21() {
  const b = Builder3D(21, 'Level 21', 'hard');
  // Spanning columns (all heads land on a planar blocker one layer over).
  b.verticalSpan(0, 0, 0, 1, 'below');  // V1: head z1 → (0,0,z2)
  b.verticalSpan(5, 1, 2, 1, 'above');  // V2: head z1 → (5,1,z0)
  b.verticalSpan(2, 2, 0, 1, 'below');  // V3: head z1 → (2,2,z2)
  b.verticalSpan(3, 2, 2, 1, 'above');  // V4: head z1 → (3,2,z0)
  b.verticalSpan(5, 3, 0, 1, 'below');  // V5: head z1 → (5,3,z2)
  b.verticalSpan(0, 4, 2, 1, 'above');  // V6: head z1 → (0,4,z0)
  // z0 (carved (0,0),(2,2),(5,3)).
  b.queueRow([1, 2, 3, 4, 5], 0, 0, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5], 1, 0, 'left');
  b.queueRow([0, 1], 2, 0, 'left'); b.queueRow([3, 4, 5], 2, 0, 'right');
  b.queueRow([0, 1, 2, 3, 4], 3, 0, 'left');
  b.queueRow([0, 1, 2, 3, 4, 5], 4, 0, 'right');
  // z1 (carved (0,0),(5,1),(2,2),(3,2),(5,3),(0,4)).
  b.queueRow([1, 2, 3, 4, 5], 0, 1, 'right');
  b.queueRow([0, 1, 2, 3, 4], 1, 1, 'left');
  b.queueRow([0, 1], 2, 1, 'left'); b.queueRow([4, 5], 2, 1, 'right');
  b.queueRow([0, 1, 2, 3, 4], 3, 1, 'left');
  b.queueRow([1, 2, 3, 4, 5], 4, 1, 'right');
  // z2 (carved (5,1),(3,2),(0,4)).
  b.queueRow([0, 1, 2, 3, 4, 5], 0, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4], 1, 2, 'left');
  b.queueRow([0, 1, 2], 2, 2, 'left'); b.queueRow([4, 5], 2, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5], 3, 2, 'left');
  b.queueRow([1, 2, 3, 4, 5], 4, 2, 'right');
  b.weaveLayers();
  return b.build({ t: 50, m: 300 });
}

// Level 22 — three full 6×6 layers, ~44 arrows, COLUMN-oriented (contrasting
// 21's rows): every layer is filled with vertical-in-plane queues (even x
// down, odd x up). Six spanning columns thread the layers, each parked at the
// tail (top for down-columns, bottom for up-columns) so no planar queue sweeps
// into it — acyclic and solvable — while each vertical head lands on a covered
// blocker one layer away. Two bent cross-layer feet protrude at the base for
// arrow-shape variety (they exit through empty air, so they stay free).
function build3DLevel22() {
  const b = Builder3D(22, 'Level 22', 'hard');
  // Spanning columns (heads land on a planar blocker one layer over).
  b.verticalSpan(0, 0, 0, 1, 'below');  // V1: head z1 → (0,0,z2)
  b.verticalSpan(2, 0, 0, 1, 'below');  // V2: head z1 → (2,0,z2)
  b.verticalSpan(4, 0, 2, 1, 'above');  // V3: head z1 → (4,0,z0)
  b.verticalSpan(1, 5, 0, 1, 'below');  // V4: head z1 → (1,5,z2)
  b.verticalSpan(3, 5, 2, 1, 'above');  // V5: head z1 → (3,5,z0)
  b.verticalSpan(5, 5, 2, 1, 'above');  // V6: head z1 → (5,5,z0)
  // z0 (carved (0,0),(2,0),(1,5)).
  b.queueCol([1, 2, 3, 4, 5], 0, 0, 'down'); b.queueCol([0, 1, 2, 3, 4], 1, 0, 'up');
  b.queueCol([1, 2, 3, 4, 5], 2, 0, 'down'); b.queueCol([0, 1, 2, 3, 4, 5], 3, 0, 'up');
  b.queueCol([0, 1, 2, 3, 4, 5], 4, 0, 'down'); b.queueCol([0, 1, 2, 3, 4, 5], 5, 0, 'up');
  // z1 (carved (0,0),(2,0),(4,0),(1,5),(3,5),(5,5)).
  b.queueCol([1, 2, 3, 4, 5], 0, 1, 'down'); b.queueCol([0, 1, 2, 3, 4], 1, 1, 'up');
  b.queueCol([1, 2, 3, 4, 5], 2, 1, 'down'); b.queueCol([0, 1, 2, 3, 4], 3, 1, 'up');
  b.queueCol([1, 2, 3, 4, 5], 4, 1, 'down'); b.queueCol([0, 1, 2, 3, 4], 5, 1, 'up');
  // z2 (carved (4,0),(3,5),(5,5)).
  b.queueCol([0, 1, 2, 3, 4, 5], 0, 2, 'down'); b.queueCol([0, 1, 2, 3, 4, 5], 1, 2, 'up');
  b.queueCol([0, 1, 2, 3, 4, 5], 2, 2, 'down'); b.queueCol([0, 1, 2, 3, 4], 3, 2, 'up');
  b.queueCol([1, 2, 3, 4, 5], 4, 2, 'down'); b.queueCol([0, 1, 2, 3, 4], 5, 2, 'up');
  // Bent cross-layer feet: rise a layer then hook out the bottom edge (head
  // 'above' sweeps to z=-1 → off the board, so both are free).
  b.pathArrow([[2, 6, 1], [2, 6, 0]], 'above'); // simple protruding vertical foot
  b.pathArrow([[4, 6, 0], [4, 6, 1], [3, 6, 1]], 'left'); // bent foot, exits left
  b.weaveLayers();
  return b.build({ t: 45, m: 300 });
}

// Level 23 — "Pyramid": four concentric stepped tiers, 2×2 (z0) / 4×4 (z1)
// / 6×6 (z2) / 8×8 (z3), all centered on (3.5, 3.5) so the silhouette reads
// as a ziggurat from any camera angle. The four center columns of tier z1
// are spans down to tier z2 with heads pointing up — each blocked by an
// apex cell, so the pyramid's core unlocks only after the apex is cleared.
function build3DLevel23() {
  const b = Builder3D(23, 'Level 23', 'hard');
  // Apex (2×2 at x3-4, y3-4).
  b.rowArrow([3, 4], 3, 0, 'right');
  b.rowArrow([3, 4], 4, 0, 'left');
  // Core spans (z1↔z2), heads at z1 pointing above → blocked by the apex.
  b.verticalSpan(3, 3, 2, 1, 'above');
  b.verticalSpan(4, 3, 2, 1, 'above');
  b.verticalSpan(3, 4, 2, 1, 'above');
  b.verticalSpan(4, 4, 2, 1, 'above');
  // Tier z1 ring (4×4 at x2-5, y2-5, minus the 4 core cells). Rows diverge
  // outward; the side columns chain into the rows.
  b.rowArrow([2, 3], 2, 1, 'left'); b.rowArrow([4, 5], 2, 1, 'right');
  b.rowArrow([2, 3], 5, 1, 'left'); b.rowArrow([4, 5], 5, 1, 'right');
  b.colArrow([3, 4], 2, 1, 'up');    // waits on row y2 (2,2)
  b.colArrow([3, 4], 5, 1, 'down');  // waits on row y5 (5,5)
  // Tier z2 (6×6 at x1-6, y1-6, minus 4 core span tails and 2 z2↔z3 spans).
  // Edge rows diverge outward; the two inner rows (y3,y4) sweep unidirectionally
  // THROUGH the core span tails — so their inner arrow must wait for a core span
  // (which itself waits for the apex): a three-deep cross-layer chain.
  b.rowArrow([1, 2], 1, 2, 'left'); b.rowArrow([4, 5, 6], 1, 2, 'right');
  b.rowArrow([1, 2, 3], 2, 2, 'left'); b.rowArrow([4, 5, 6], 2, 2, 'right');
  b.rowArrow([1, 2], 3, 2, 'right'); b.rowArrow([5, 6], 3, 2, 'right');  // [1,2]→ waits cores + [5,6]
  b.rowArrow([1, 2], 4, 2, 'left'); b.rowArrow([5, 6], 4, 2, 'left');    // [5,6]← waits cores + [1,2]
  b.rowArrow([1, 2, 3], 5, 2, 'left'); b.rowArrow([4, 5, 6], 5, 2, 'right');
  b.rowArrow([1, 2, 3], 6, 2, 'left'); b.rowArrow([5, 6], 6, 2, 'right');
  // Base tier z3 (8×8, minus 2 z2↔z3 span cells) — deep 3-cell queues, one
  // direction per row (alternating), so the base itself is a forced ordering.
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 0, 3, 'right', 3);
  b.queueRow([0, 1, 2, 4, 5, 6, 7], 1, 3, 'left', 3);   // (3,1) carved (z2↔z3 span)
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 2, 3, 'right', 3);
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 3, 3, 'left', 3);
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 4, 3, 'right', 3);
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 5, 3, 'left', 3);
  b.queueRow([0, 1, 2, 3, 5, 6, 7], 6, 3, 'right', 3);  // (4,6) carved (z2↔z3 span)
  b.queueRow([0, 1, 2, 3, 4, 5, 6, 7], 7, 3, 'left', 3);
  // Tier-linking spans z2↔z3 (heads at z2 pointing above exit through the
  // empty air beside the smaller tiers — free, they exist for the shape's
  // vertical silhouette and connectivity).
  b.verticalSpan(3, 1, 3, 2, 'above');
  b.verticalSpan(4, 6, 3, 2, 'above');
  // Apex↔z1 connectivity (unclaimed z-edges).
  b.addEdge(nid3(3, 3, 0), nid3(3, 3, 1));
  b.addEdge(nid3(4, 4, 0), nid3(4, 4, 1));
  b.weaveLayers();
  return b.build({ t: 45, m: 300 });
}

// Level 24 — "Diamond" (octahedron): five concentric tiers, 2×2 (z0) /
// 4×4 (z1) / 6×6 (z2) / 4×4 (z3) / 2×2 (z4), tapering out then back in so
// the stack reads as a gem. The center column x2-3/y2-3 is a lattice of
// spans: the left column chains top-tip → equator, the right column chains
// bottom-tip → equator, and two equator rows point into them.
function build3DLevel24() {
  const b = Builder3D(24, 'Level 24', 'hard');
  // Top tip (2×2 at x2-3, y2-3): left column planar, right column span tails.
  b.colArrow([2, 3], 2, 0, 'up');
  b.verticalSpan(3, 2, 0, 1, 'below');  // waits on the z2↔z3 span below it
  b.verticalSpan(3, 3, 0, 1, 'below');
  // Bottom tip: right column planar, left column span tails.
  b.colArrow([2, 3], 3, 4, 'down');
  b.verticalSpan(2, 2, 4, 3, 'above');  // waits on the z1↔z2 span above it
  b.verticalSpan(2, 3, 4, 3, 'above');
  // Full center span lattice (the octahedron's core): every center-column cell
  // across all five tiers is a span, chained tip→equator→tip.
  b.verticalSpan(2, 2, 2, 1, 'above');  // blocked by top tip (2,2,0)
  b.verticalSpan(2, 3, 2, 1, 'above');  // blocked by top tip (2,3,0)
  b.verticalSpan(3, 2, 2, 3, 'below');  // blocked by bottom tip (3,2,4)
  b.verticalSpan(3, 3, 2, 3, 'below');  // blocked by bottom tip (3,3,4)
  // Upper-mid tier z1 (4×4 at x1-4, minus center): ring rows diverge, side
  // columns chain into them.
  b.rowArrow([1, 2], 1, 1, 'left'); b.rowArrow([3, 4], 1, 1, 'right');
  b.rowArrow([1, 2], 4, 1, 'left'); b.rowArrow([3, 4], 4, 1, 'right');
  b.colArrow([2, 3], 1, 1, 'up');    // waits on row y1
  b.colArrow([2, 3], 4, 1, 'down');  // waits on row y4
  // Lower-mid tier z3: mirror.
  b.rowArrow([1, 2], 1, 3, 'left'); b.rowArrow([3, 4], 1, 3, 'right');
  b.rowArrow([1, 2], 4, 3, 'left'); b.rowArrow([3, 4], 4, 3, 'right');
  b.colArrow([2, 3], 1, 3, 'up');
  b.colArrow([2, 3], 4, 3, 'down');
  // Equator z2 (6×6 at x0-5, minus the 4 center span cells) — deeper 2-cell
  // queues; outer rows are deep one-way queues, the two inner rows diverge
  // around the center lattice.
  b.queueRow([0, 1, 2, 3, 4, 5], 0, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5], 1, 2, 'left');
  b.queueRow([0, 1], 2, 2, 'left'); b.queueRow([4, 5], 2, 2, 'right');
  b.queueRow([0, 1], 3, 2, 'left'); b.queueRow([4, 5], 3, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5], 4, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5], 5, 2, 'left');
  // Bent faceting nubs protruding off the equator (arrow-shape variety; they
  // exit through empty air, so they stay free).
  b.pathArrow([[6, 1, 2], [6, 2, 2], [7, 2, 2]], 'right');
  b.pathArrow([[6, 4, 2], [6, 3, 2], [7, 3, 2]], 'right');
  b.pathArrow([[1, 6, 2], [2, 6, 2], [2, 7, 2]], 'down');
  b.pathArrow([[4, 6, 2], [3, 6, 2], [3, 7, 2]], 'down');
  // Center-column connectivity between the disjoint span pieces.
  b.addEdge(nid3(2, 2, 2), nid3(2, 2, 3)); b.addEdge(nid3(2, 3, 2), nid3(2, 3, 3));
  b.addEdge(nid3(3, 2, 1), nid3(3, 2, 2)); b.addEdge(nid3(3, 3, 1), nid3(3, 3, 2));
  b.weaveLayers();
  return b.build({ t: 45, m: 320 });
}

// Level 25 — "Hourglass": five tiers 5×5 (z0) / 3×3 (z1) / 1×1 (z2) /
// 3×3 (z3) / 5×5 (z4) — a true single-cell waist at the center. The whole
// x=2 center column is spans: A/E rise out of the top cone, W threads the
// one-cell neck (blocked by G beneath it), F/B drop out of the bottom cone,
// and one row on each outer face points into the column and must wait.
function build3DLevel25() {
  const b = Builder3D(25, 'Level 25', 'hard');
  // Center-column spans (waist recentred at (3,3)).
  b.verticalSpan(3, 2, 1, 0, 'above');  // A: exits up out of the top cone
  b.verticalSpan(3, 4, 1, 0, 'above');  // E: exits up out of the top cone
  b.verticalSpan(3, 3, 1, 2, 'below');  // W: threads the waist, waits on G
  b.verticalSpan(3, 3, 3, 4, 'below');  // G: exits down, frees the neck
  b.verticalSpan(3, 2, 3, 4, 'below');  // F: exits down out of the bottom cone
  b.verticalSpan(3, 4, 3, 4, 'below');  // B: exits down out of the bottom cone
  // Top 5×5 cap (x1-5, y1-5; carves (3,2)/(3,4)=A/E tops and the 4 corners
  // taken by the bent flares) — deep queues.
  b.queueRow([2, 3, 4], 1, 0, 'right');
  b.queueRow([1, 2, 4, 5], 2, 0, 'left');
  b.queueRow([1, 2, 3, 4, 5], 3, 0, 'right');
  b.queueRow([1, 2, 4, 5], 4, 0, 'left');
  b.queueRow([2, 3, 4], 5, 0, 'right');
  // Bottom 5×5 cap (carves (3,2)/(3,4)=F/B, (3,3)=G exit cell, and 4 corners).
  b.queueRow([2, 3, 4], 1, 4, 'right');
  b.queueRow([1, 2, 4, 5], 2, 4, 'left');
  b.queueRow([1, 2, 4, 5], 3, 4, 'right');
  b.queueRow([1, 2, 4, 5], 4, 4, 'left');
  b.queueRow([2, 3, 4], 5, 4, 'right');
  // Waist cones (3×3 at x2-4, y2-4; the x=3 column is all span cells).
  b.colArrow([2, 3, 4], 2, 1, 'down'); b.colArrow([2, 3, 4], 4, 1, 'up');
  b.colArrow([2, 3, 4], 2, 3, 'up'); b.colArrow([2, 3, 4], 4, 3, 'down');
  // Bent corner flares off both caps (arrow-shape variety): each hooks around a
  // cap corner and exits straight off the true outer boundary, so all eight
  // stay free with no gap-sweep.
  for (const z of [0, 4]) {
    b.pathArrow([[1, 1, z], [1, 0, z], [0, 0, z]], 'left');   // NW
    b.pathArrow([[5, 1, z], [5, 0, z], [6, 0, z]], 'right');  // NE
    b.pathArrow([[1, 5, z], [1, 6, z], [0, 6, z]], 'left');   // SW
    b.pathArrow([[5, 5, z], [5, 6, z], [6, 6, z]], 'right');  // SE
  }
  // Neck connectivity: the waist cell links down to G's top (unclaimed).
  b.addEdge(nid3(3, 3, 2), nid3(3, 3, 3));
  b.weaveLayers();
  return b.build({ t: 40, m: 340 });
}

// Level 26 — "3D Cross" (displayed as 3D level 6). One TRUE 3D cross: a
// flat plus-sign plate at the middle layer (X-bar and Y-bar, each 2 cells
// thick and 10 long) with a 2×2 vertical post punched through its shared
// center from z0 to z4 — three orthogonal bars meeting at a single
// intersection, like a jack. The center 2×2 belongs to the post columns, so
// every inward plate arrow chains THROUGH the intersection; each line uses
// one direction only (no head-on pairs) and drains at a free outer arrow.
function build3DLevel26() {
  const b = Builder3D(26, 'Level 26', 'hard');
  // Post: 2×2 columns (x7-8, y7-8) spanning z0-z4; their z2 cells ARE the
  // plate's center. Each column pairs a free exit with a chained half.
  for (const [x, y, freeTop] of [[7, 7, true], [8, 7, false], [7, 8, false], [8, 8, true]]) {
    if (freeTop) {
      b.zColArrow([0, 1], x, y, 'above');      // exits up
      b.zColArrow([2, 3, 4], x, y, 'above');   // chains through it
    } else {
      b.zColArrow([2, 3, 4], x, y, 'below');   // exits down
      b.zColArrow([0, 1], x, y, 'below');      // chains through it
    }
  }
  // Plate at z2: a 2-thick plus, each arm 8 long. X-bar rows y7 (east) and
  // y8 (west); Y-bar cols x7 (south) and x8 (north). Deep queues on each arm
  // half chain toward the post: the innermost arrow of every arm can only
  // leave once the whole arm ahead of it and the post have cleared.
  b.queueRow([0, 1, 2, 3, 4, 5, 6], 7, 2, 'right');
  b.queueRow([9, 10, 11, 12, 13, 14, 15], 7, 2, 'right');
  b.queueRow([0, 1, 2, 3, 4, 5, 6], 8, 2, 'left');
  b.queueRow([9, 10, 11, 12, 13, 14, 15], 8, 2, 'left');
  b.queueCol([0, 1, 2, 3, 4, 5, 6], 7, 2, 'down');
  b.queueCol([9, 10, 11, 12, 13, 14, 15], 7, 2, 'down');
  b.queueCol([0, 1, 2, 3, 4, 5, 6], 8, 2, 'up');
  b.queueCol([9, 10, 11, 12, 13, 14, 15], 8, 2, 'up');
  // Post continuity: each column's two arrow pieces meet at z1/z2 with no
  // shared body edge — join them (unclaimed z-edges, like weave edges).
  for (const [x, y] of [[7, 7], [8, 7], [7, 8], [8, 8]]) {
    b.addEdge(nid3(x, y, 1), nid3(x, y, 2));
  }
  b.weaveLayers();
  return b.build({ t: 40, m: 300 });
}

// Level 27 — "3D Star" (displayed as 7). A starburst: a compact octahedral
// core (3×3 mid layer with plus-shaped caps above and below) radiating
// FOURTEEN spikes — six straight ones along ±x/±y/±z, four rising and four
// falling bent spikes off the caps' tips and the core's corners. Axis
// spikes are contiguous lines through the core, so inward spikes chain
// through the middle; every diagonal spike sweeps out into empty air.
function build3DLevel27() {
  const b = Builder3D(27, 'Level 27', 'hard');
  // Core mid layer z3: 3×3 at x6-8, y6-8 (center 7,7). Rows chain into the
  // axis spikes on each side.
  b.rowArrow([6, 7, 8], 6, 3, 'right');   // chains east
  b.rowArrow([6, 7, 8], 7, 3, 'left');    // chains west
  b.rowArrow([6, 7, 8], 8, 3, 'right');   // chains east
  // Six long straight axis spikes (length 6 each = deep 3-arrow queues) along
  // ±x/±y, radiating out to the board edge.
  b.queueRow([0, 1, 2, 3, 4, 5], 7, 3, 'left');       // west
  b.queueRow([9, 10, 11, 12, 13, 14], 7, 3, 'right');  // east
  b.queueCol([0, 1, 2, 3, 4, 5], 7, 3, 'up');          // north
  b.queueCol([9, 10, 11, 12, 13, 14], 7, 3, 'down');   // south
  // Caps z2/z4: a plus of 5 cells — a 3-cell column plus two tips owned by
  // the rising/falling cap spikes.
  b.colArrow([6, 7, 8], 7, 2, 'up');
  b.colArrow([6, 7, 8], 7, 4, 'down');
  b.pathArrow([[6, 7, 2], [6, 7, 1], [5, 7, 1], [5, 7, 0]], 'above');  // W rising
  b.pathArrow([[8, 7, 2], [8, 7, 1], [9, 7, 1], [9, 7, 0]], 'above');  // E rising
  b.pathArrow([[6, 7, 4], [6, 7, 5], [5, 7, 5], [5, 7, 6]], 'below');  // W falling
  b.pathArrow([[8, 7, 4], [8, 7, 5], [9, 7, 5], [9, 7, 6]], 'below');  // E falling
  // Extra near-cap spikes on the N/S faces of the vertical column (more rays,
  // denser starburst; each exits into empty air).
  b.pathArrow([[7, 6, 1], [7, 5, 1], [7, 5, 0]], 'above');  // N near-top
  b.pathArrow([[7, 8, 1], [7, 9, 1], [7, 9, 0]], 'above');  // S near-top
  b.pathArrow([[7, 6, 5], [7, 5, 5], [7, 5, 6]], 'below');  // N near-bottom
  b.pathArrow([[7, 8, 5], [7, 9, 5], [7, 9, 6]], 'below');  // S near-bottom
  // Vertical spikes through the core column (7,7): top exits, bottom chains
  // all the way up through cap-core-cap and out.
  b.zColArrow([0, 1], 7, 7, 'above');
  b.zColArrow([5, 6], 7, 7, 'above');
  // Corner spikes at the mid layer: bent, pointing away diagonally.
  b.pathArrow([[9, 6, 3], [9, 5, 3], [10, 5, 3], [10, 4, 3]], 'up');     // NE
  b.pathArrow([[5, 6, 3], [5, 5, 3], [4, 5, 3], [4, 4, 3]], 'up');       // NW
  b.pathArrow([[9, 8, 3], [9, 9, 3], [10, 9, 3], [10, 10, 3]], 'down');  // SE
  b.pathArrow([[5, 8, 3], [5, 9, 3], [4, 9, 3], [4, 10, 3]], 'down');    // SW
  // Core column continuity (unclaimed z-edges between EVERY vertical piece:
  // z-spike → cap → core → cap → z-spike; caps otherwise float, since weave
  // only joins nodes within a layer).
  b.addEdge(nid3(7, 7, 1), nid3(7, 7, 2));
  b.addEdge(nid3(7, 7, 2), nid3(7, 7, 3));
  b.addEdge(nid3(7, 7, 3), nid3(7, 7, 4));
  b.addEdge(nid3(7, 7, 4), nid3(7, 7, 5));
  b.weaveLayers();
  return b.build({ t: 40, m: 300 });
}

// Level 28 — "Abstract Cat" (displayed as 8). The iconic SITTING cat in
// side profile (facing right), two layers deep: a tall rounded haunch at
// the back, a smaller head up front with two pointed ear columns, a chest
// tucked under the chin, and a tail hugging the back edge that rises and
// hooks inward at the top. Ears are upward columns; the tail is one long
// bent arrow on the back layer only.
//
//   y0  ........E.E.     E = ear columns (x8, x10)
//   y1  ........E.E.
//   y2  .......HHHHH     H = head x7-11
//   y3  .......HHHHH
//   y4  T.BBBBBBBB..     B = body/back x2-9 (chest tucks under the chin)
//   y5  TBBBBBBBBB..     body x1-9
//   y6  TBBBBBBBBBB.     body + front leg x1-10
//   y7  TBBBBBBBBBB.     base x1-10        T = tail column x0 (back layer)
function build3DLevel28() {
  const b = Builder3D(28, 'Level 28', 'hard');
  for (const z of [0, 1]) {
    // Ears (pointed, upright — they exit straight up past the head).
    b.colArrow([0, 1], 8, z, 'up');
    b.colArrow([0, 1], 10, z, 'up');
    // Head (x7-11, y2-3).
    b.rowArrow([7, 8, 9], 2, z, 'right'); b.rowArrow([10, 11], 2, z, 'right');
    b.rowArrow([10, 11], 3, z, 'left'); b.rowArrow([7, 8, 9], 3, z, 'left');
    // Back/body. The spine spans carve (5,4) and (5,6); each carved row has
    // exactly one side chaining into the spine.
    b.rowArrow([2, 3, 4], 4, z, 'right');            // chains into the spine
    b.rowArrow([6, 7, 8, 9], 4, z, 'right');         // exits east under the chin
    b.rowArrow([1, 2], 5, z, 'left'); b.rowArrow([3, 4], 5, z, 'left');
    b.rowArrow([5, 6], 5, z, 'left'); b.rowArrow([7, 8, 9], 5, z, 'left');
    b.rowArrow([1, 2, 3, 4], 6, z, 'right');         // chains into the spine
    b.rowArrow([6, 7], 6, z, 'right'); b.rowArrow([8, 9, 10], 6, z, 'right');
    b.rowArrow([1, 2], 7, z, 'right'); b.rowArrow([3, 4], 7, z, 'right');
    b.rowArrow([5, 6], 7, z, 'right'); b.rowArrow([7, 8], 7, z, 'right');
    b.rowArrow([9, 10], 7, z, 'right');
    // Base/feet row (deep queue) — gives the sitting cat a fuller haunch.
    b.queueRow([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 8, z, 'right', 3);
  }
  // Spine: front↔back spans in the carved column.
  b.verticalSpan(5, 4, 0, 1, 'below');
  b.verticalSpan(5, 6, 1, 0, 'above');
  // Tail: back layer only — hugs the haunch, rises along x0, hooks inward
  // at the top. Its head waits for the y4 body row, so the tail is one of
  // the last pieces to leave (it uncurls at the end).
  b.pathArrow([[0, 7, 1], [0, 6, 1], [0, 5, 1], [0, 4, 1], [1, 4, 1]], 'right');
  // Bent front paw poking down ahead of the chest (front layer), for shape
  // variety — new cells beyond the body, exits south off the board.
  b.pathArrow([[10, 5, 0], [11, 5, 0], [11, 6, 0]], 'down');
  b.weaveLayers();
  return b.build({ t: 40, m: 320 });
}

// Level 29 — "Double Helix" (displayed as 9). DNA: two strand arms orbit a
// central axis column, rotating 45° per layer over ten layers (1.25 turns),
// always 180° apart. On axis-aligned layers the arms lie on one straight
// line through the axis — one arm points INWARD (the base-pair bond,
// blocked through the axis and the far strand), the other exits outward.
// On diagonal layers the arms are bent elbows sweeping out into empty air.
// The axis is the only full-height column; strand cells never stack, which
// is exactly what makes the spiral read when orbited.
function build3DLevel29() {
  const b = Builder3D(29, 'Level 29', 'hard');
  // Axis (3,3), z0-9: top half chains through the bottom half.
  b.zColArrow([0, 1, 2, 3, 4], 3, 3, 'below');
  b.zColArrow([5, 6, 7, 8, 9], 3, 3, 'below');
  b.addEdge(nid3(3, 3, 4), nid3(3, 3, 5));
  // One strand arm. dir8: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW.
  // Axis-aligned arms are straight 3-cell lines from the board edge to the
  // cell beside the axis; `inward` points them at the axis. Diagonal arms
  // are bent elbows starting beside the axis and stepping outward.
  // Axis-aligned (base-pair) layers carry a parallel BACKBONE arrow one cell
  // out from the bond, so the double helix reads as two thick strands at the
  // rungs; the backbone always points outward and exits free.
  const arm = (dir8, z, inward) => {
    switch (dir8) {
      case 0: b.colArrow([0, 1, 2], 3, z, inward ? 'down' : 'up');
        b.colArrow([0, 1, 2], 2, z, 'up'); break;
      case 2: b.rowArrow([4, 5, 6], 3, z, inward ? 'left' : 'right');
        b.rowArrow([4, 5, 6], 2, z, 'right'); break;
      case 4: b.colArrow([4, 5, 6], 3, z, inward ? 'up' : 'down');
        b.colArrow([4, 5, 6], 2, z, 'down'); break;
      case 6: b.rowArrow([0, 1, 2], 3, z, inward ? 'right' : 'left');
        b.rowArrow([0, 1, 2], 2, z, 'left'); break;
      case 1: b.pathArrow([[3, 2, z], [4, 2, z], [4, 1, z], [5, 1, z]], 'right'); break;
      case 3: b.pathArrow([[4, 3, z], [4, 4, z], [5, 4, z], [5, 5, z]], 'down'); break;
      case 5: b.pathArrow([[3, 4, z], [2, 4, z], [2, 5, z], [1, 5, z]], 'left'); break;
      case 7: b.pathArrow([[2, 3, z], [2, 2, z], [1, 2, z], [1, 1, z]], 'up'); break;
    }
  };
  for (let z = 0; z < 10; z++) {
    const a = z % 8;              // strand A rotates 45 degrees per layer
    const bDir = (a + 4) % 8;     // strand B is always 180 degrees opposite
    // On straight layers, alternate which strand carries the inward bond.
    const aInward = z % 4 === 0;
    arm(a, z, aInward);
    arm(bDir, z, !aInward);
  }
  b.weaveLayers();
  return b.build({ t: 40, m: 340 });
}

// Level 30 — "Hollow Pyramid" (displayed as 10). Four shells: a 2×2 apex
// over three concentric hollow rings (4×4, 6×6, 8×8 perimeters). Every ring
// arrow runs ALONG its edge — never across the hollow interior — so no
// sweep ever crosses the void (real-gap safe). Corner spans step down
// through the shells (the pyramid's inner staircase: their lower cell sits
// one step inside the ring below), and each ring's sides chain into its
// corner spans, so the shell drains corner by corner.
function build3DLevel30() {
  const b = Builder3D(30, 'Level 30', 'hard');
  // Apex z0 (x3-4, y3-4): corner (3,3) is the staircase top; the other
  // three cells form one bent arrow that exits west.
  b.pathArrow([[4, 3, 0], [4, 4, 0], [3, 4, 0]], 'left');
  // Staircase spans. Lower cells sit inside the next ring's hollow and
  // sweep out through empty air below the pyramid (or beside it), so all
  // spans are free once tapped; the rings chain INTO them.
  b.verticalSpan(3, 3, 0, 1, 'below');   // S1: apex → ring-1 hole
  b.verticalSpan(2, 2, 1, 2, 'below');   // S2: ring-1 corner → ring-2 hole
  b.verticalSpan(5, 5, 1, 2, 'below');   // S3: ring-1 corner → ring-2 hole
  b.verticalSpan(1, 1, 2, 3, 'below');   // S4: ring-2 corner → ring-3 hole
  b.verticalSpan(6, 6, 2, 3, 'below');   // S5: ring-2 corner → ring-3 hole
  // Ring 1 (z1, perimeter of x2-5 / y2-5; corners (2,2) and (5,5) belong to
  // S2/S3). Every side chains into a staircase corner.
  b.rowArrow([3, 4, 5], 2, 1, 'left');   // north → S2
  b.colArrow([3, 4], 5, 1, 'down');      // east → S3
  b.rowArrow([2, 3, 4], 5, 1, 'right');  // south → S3
  b.colArrow([3, 4], 2, 1, 'up');        // west → S2
  // Ring 2 (z2, perimeter of x1-6 / y1-6; corners (1,1) and (6,6) belong to
  // S4/S5).
  b.rowArrow([2, 3], 1, 2, 'left');      // north-west → S4
  b.rowArrow([4, 5, 6], 1, 2, 'right');  // north-east → exits
  b.colArrow([2, 3], 6, 2, 'down');      // east upper → chains into lower
  b.colArrow([4, 5], 6, 2, 'down');      // east lower → S5
  b.rowArrow([1, 2], 6, 2, 'right');     // south-west → chains east into S5
  b.rowArrow([3, 4, 5], 6, 2, 'right');  // south-east → S5
  b.colArrow([2, 3], 1, 2, 'up');        // west upper → S4
  b.colArrow([4, 5], 1, 2, 'up');        // west lower → chains through upper
  // Ring 3 (z3, perimeter of x0-7 / y0-7; corners assigned rotationally).
  // Chains run clockwise (W→N→E→S) and drain at the free south-east arrow —
  // the south side must NOT chain onward into the west, or the ring's
  // dependencies close into a circle and deadlock.
  // Deep queues along each edge, all chaining clockwise toward the single free
  // south-east arrow (which exits past x8) — the drain order is now several
  // arrows deep per side.
  b.queueRow([0, 1, 2, 3, 4, 5, 6], 0, 3, 'right');   // north, chains east
  b.queueCol([0, 1, 2, 3, 4, 5, 6], 7, 3, 'down');    // east, chains south
  b.queueRow([1, 2, 3, 4, 5, 6, 7], 7, 3, 'right');   // south, SE arrow drains free
  b.queueCol([1, 2, 3, 4, 5, 6, 7], 0, 3, 'up');      // west, chains north
  // Bent corner buttresses protruding off the base ring (arrow-shape variety;
  // each exits into empty air, so they stay free).
  b.pathArrow([[9, 1, 3], [8, 1, 3], [8, 0, 3]], 'up');    // NE
  b.pathArrow([[7, 9, 3], [7, 8, 3], [8, 8, 3]], 'right'); // SE
  b.pathArrow([[1, 9, 3], [1, 8, 3], [0, 8, 3]], 'left');  // SW
  b.weaveLayers();
  return b.build({ t: 35, m: 360 });
}

function build3DLevels() {
  return [
    build3DLevel21(), build3DLevel22(), build3DLevel23(),
    build3DLevel24(), build3DLevel25(), build3DLevel26(),
    build3DLevel27(), build3DLevel28(), build3DLevel29(),
    build3DLevel30(),
  ];
}

// ---------------------------------------------------------------------------
// Validation (unchanged logic)
// ---------------------------------------------------------------------------
function coveredNodes(dj, arrow, byId) {
  const s = new Set([arrow.startNodeId, arrow.endNodeId]);
  for (const eId of arrow.occupiedEdges) {
    const e = byId.edges[eId]; if (e) { s.add(e.fromNodeId); s.add(e.toNodeId); }
  }
  return s;
}
function indexDj(dj) {
  const nodes = {}, edges = {}, byCoord = {};
  for (const n of dj.nodes) { nodes[n.id] = n; byCoord[`${n.x},${n.y},${zOf(n)}`] = n.id; }
  for (const e of dj.edges) edges[e.id] = e;
  return { nodes, edges, byCoord };
}
function nodeAtCoord(byId, x, y, z = 0) { return byId.byCoord[`${x},${y},${z}`] || null; }
function edgeBetween(byId, a, b) {
  for (const e of Object.values(byId.edges)) {
    if ((e.fromNodeId === a && e.toNodeId === b) || (e.fromNodeId === b && e.toNodeId === a)) return e;
  }
  return null;
}
function canExit(dj, byId, arrow, activeById, blockedSet) {
  const blocker = new Set();
  for (const id in activeById) {
    if (id === arrow.id) continue;
    for (const n of coveredNodes(dj, activeById[id], byId)) blocker.add(n);
  }
  const [dx, dy, dz = 0] = DELTA[arrow.direction];
  // Sweep from the head only (mirrors the Dart Phase 12.1 head-only resolver).
  let cur = arrow.endNodeId;
  while (true) {
    const cn = byId.nodes[cur];
    const nextId = nodeAtCoord(byId, cn.x + dx, cn.y + dy, zOf(cn) + dz);
    if (nextId === null) break; // board boundary
    const e = edgeBetween(byId, cur, nextId);
    if (e && blockedSet.has(e.id)) return false;
    if (blocker.has(nextId)) return false;
    cur = nextId;
  }
  return true;
}
function solvableGreedy(dj) {
  const byId = indexDj(dj); const blockedSet = new Set(dj.blockedEdges || []);
  const active = {}; for (const a of dj.arrows) active[a.id] = a;
  let remaining = dj.arrows.length, progress = true;
  while (remaining > 0 && progress) {
    progress = false;
    for (const id of Object.keys(active)) {
      if (canExit(dj, byId, active[id], active, blockedSet)) {
        delete active[id]; remaining--; progress = true;
      }
    }
  }
  return remaining === 0;
}
function noFreeNodes(dj) {
  const byId = indexDj(dj); const covered = new Set();
  for (const a of dj.arrows) for (const n of coveredNodes(dj, a, byId)) covered.add(n);
  const free = dj.nodes.filter(n => !n.hidden && !covered.has(n.id)).map(n => n.id);
  return free.length ? free : null;
}
function connectedComponents(dj) {
  if (dj.nodes.length === 0) return 0;
  const adj = {}; for (const n of dj.nodes) adj[n.id] = [];
  for (const e of dj.edges) {
    if (adj[e.fromNodeId]) adj[e.fromNodeId].push(e.toNodeId);
    if (adj[e.toNodeId])   adj[e.toNodeId].push(e.fromNodeId);
  }
  const seen = new Set(); let components = 0;
  for (const start of dj.nodes.map(n => n.id)) {
    if (seen.has(start)) continue; components++;
    const stack = [start]; seen.add(start);
    while (stack.length) {
      const cur = stack.pop();
      for (const nb of adj[cur] || []) if (!seen.has(nb)) { seen.add(nb); stack.push(nb); }
    }
  }
  return components;
}
function structureErrors(dj) {
  const errs = []; const nodeIds = new Set();
  for (const n of dj.nodes) { if (nodeIds.has(n.id)) errs.push('dup node ' + n.id); nodeIds.add(n.id); }
  const byId = indexDj(dj); const edgeIds = new Set();
  for (const e of dj.edges) {
    if (edgeIds.has(e.id)) errs.push('dup edge ' + e.id); edgeIds.add(e.id);
    if (!nodeIds.has(e.fromNodeId) || !nodeIds.has(e.toNodeId)) errs.push('edge endpoint missing ' + e.id);
    else if (dirBetween(byId.nodes[e.fromNodeId], byId.nodes[e.toNodeId]) === null)
      errs.push('edge not orthogonal/unit ' + e.id);
  }
  const arrowIds = new Set();
  for (const a of dj.arrows) {
    if (arrowIds.has(a.id)) errs.push('dup arrow ' + a.id); arrowIds.add(a.id);
    if (!nodeIds.has(a.startNodeId) || !nodeIds.has(a.endNodeId)) errs.push('arrow node missing ' + a.id);
    for (const eId of a.occupiedEdges) if (!edgeIds.has(eId)) errs.push('arrow edge missing ' + a.id + ' ' + eId);
    // Every arrow (planar or vertical) must occupy at least one edge — i.e.
    // at least two nodes. A one-node arrow renders as a floating dot.
    const hasEdges = a.occupiedEdges && a.occupiedEdges.length >= 1;
    if (!hasEdges) errs.push('arrow has no edges ' + a.id);
    const head = byId.nodes[a.endNodeId]; const [dx, dy, dz = 0] = DELTA[a.direction] || [0, 0, 0];
    if (head && hasEdges) {
      let behind = false;
      for (const eId of a.occupiedEdges) {
        const e = byId.edges[eId]; if (!e) continue;
        const otherId = e.fromNodeId === a.endNodeId ? e.toNodeId : e.toNodeId === a.endNodeId ? e.fromNodeId : null;
        if (!otherId) continue;
        const o = byId.nodes[otherId];
        if (o && o.x === head.x - dx && o.y === head.y - dy && zOf(o) === zOf(head) - dz) behind = true;
      }
      if (!behind) errs.push('arrow head not at exit end ' + a.id);
    }
    // Cycle check: N edges over a simple path span N+1 distinct nodes.
    // (Only meaningful for arrows with a body; a single-node arrow has none.)
    const bodyNodes = new Set();
    for (const eId of a.occupiedEdges) {
      const e = byId.edges[eId]; if (!e) continue;
      bodyNodes.add(e.fromNodeId); bodyNodes.add(e.toNodeId);
    }
    if (hasEdges && a.occupiedEdges.length >= bodyNodes.size) errs.push('arrow body forms a cycle ' + a.id);
    // Self-intersection check: head sweep must not hit own body.
    const head2 = byId.nodes[a.endNodeId];
    if (head2) {
      const body2 = new Set([a.startNodeId]);
      for (const eId of a.occupiedEdges) {
        const e = byId.edges[eId]; if (!e) continue;
        body2.add(e.fromNodeId); body2.add(e.toNodeId);
      }
      body2.delete(a.endNodeId);
      const [dx2, dy2, dz2 = 0] = DELTA[a.direction] || [0, 0, 0];
      let cx2 = head2.x + dx2, cy2 = head2.y + dy2, cz2 = zOf(head2) + dz2;
      while (true) {
        const nId2 = nodeAtCoord(byId, cx2, cy2, cz2);
        if (!nId2) break;
        if (body2.has(nId2)) { errs.push('arrow head sweep self-intersects own body at ' + nId2 + ' ' + a.id); break; }
        cx2 += dx2; cy2 += dy2; cz2 += dz2;
      }
    }
  }
  return errs;
}
function shapeOf(dj) {
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y);
  const w = Math.max(...xs) - Math.min(...xs) + 1, h = Math.max(...ys) - Math.min(...ys) + 1;
  return { w, h, rect: dj.nodes.length === w * h };
}
// Returns true if any arrow's head sweep hits a node that belongs to the same
// arrow's own body (self-intersection). Such arrows look like closed loops and
// would confusingly "exit" by passing through their own tail/body nodes.
function hasSelfIntersectingArrow(dj) {
  const byId = indexDj(dj);
  for (const a of dj.arrows) {
    const head = byId.nodes[a.endNodeId];
    if (!head) continue;
    // Covered body nodes excluding the head itself.
    const body = new Set([a.startNodeId]);
    for (const eId of a.occupiedEdges) {
      const e = byId.edges[eId]; if (!e) continue;
      body.add(e.fromNodeId); body.add(e.toNodeId);
    }
    body.delete(a.endNodeId);
    const [dx, dy, dz = 0] = DELTA[a.direction] || [0, 0, 0];
    let cx = head.x + dx, cy = head.y + dy, cz = zOf(head) + dz;
    while (true) {
      const nId = nodeAtCoord(byId, cx, cy, cz);
      if (!nId) break;
      if (body.has(nId)) return true;
      cx += dx; cy += dy; cz += dz;
    }
  }
  return false;
}

// Returns true if any arrow's head sweep exits through a coordinate that is
// INSIDE the level's bounding box but has no node (a boundary-removal gap).
// Such gaps create invisible "escape holes" that confuse players: another arrow
// visually ahead of the escaping arrow appears to block it, but the resolver
// exits at the gap before reaching the blocker.
function hasInteriorGapExit(dj) {
  const byId = indexDj(dj);
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  for (const arrow of dj.arrows) {
    const head = byId.nodes[arrow.endNodeId];
    if (!head) continue;
    const [dx, dy, dz = 0] = DELTA[arrow.direction];
    if (dz !== 0) continue; // vertical arrows sweep the z axis, not this plane
    let cx = head.x, cy = head.y;
    while (true) {
      cx += dx; cy += dy;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) break; // true boundary
      if (!nodeAtCoord(byId, cx, cy, zOf(head))) return true; // interior gap
    }
  }
  return false;
}

// Figure-aware interior gap-exit check (Phase 19). hasInteriorGapExit flags
// EVERY bbox-interior empty coordinate, which false-positives on concave
// figure silhouettes (a dent in a heart/crown outline is a legitimate part of
// the shape, not a defect). This version only flags a gap as a real P14-class
// defect when the head sweep, after passing through the gap, reaches an
// ACTUAL node belonging to another arrow — i.e. a hidden blocker the resolver
// would skip over. A gap that leads only to the true bbox boundary (or to no
// further node at all) is a harmless concavity.
function hasRealInteriorGapExit(dj) {
  const byId = indexDj(dj);
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  for (const arrow of dj.arrows) {
    const head = byId.nodes[arrow.endNodeId];
    if (!head) continue;
    const [dx, dy] = DELTA[arrow.direction];
    let cx = head.x, cy = head.y, sawGap = false;
    while (true) {
      cx += dx; cy += dy;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) break; // true boundary
      const nId = nodeAtCoord(byId, cx, cy);
      if (!nId) { sawGap = true; continue; } // concavity cell, keep scanning
      if (sawGap) return true; // hidden blocker past a gap: real P14-class defect
      break; // node reached with no prior gap: normal collision, not a defect
    }
  }
  return false;
}

// 3D-aware real-gap check for multi-layer levels. Sweeps in full (dx,dy,dz)
// with a 3-axis bounding box, and — like hasRealInteriorGapExit — only flags
// a defect when the sweep crosses at least one empty in-bbox coordinate and
// THEN reaches an actual node (a hidden blocker the resolver would skip).
// Empty space past a smaller layer's silhouette (pyramid/diamond/hourglass
// shapes) is a legitimate part of the figure, not a defect.
function hasRealInteriorGapExit3D(dj) {
  const byId = indexDj(dj);
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y), zs = dj.nodes.map(zOf);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  const minZ = Math.min(...zs), maxZ = Math.max(...zs);
  for (const arrow of dj.arrows) {
    const head = byId.nodes[arrow.endNodeId];
    if (!head) continue;
    const [dx, dy, dz = 0] = DELTA[arrow.direction];
    let cx = head.x, cy = head.y, cz = zOf(head), sawGap = false;
    while (true) {
      cx += dx; cy += dy; cz += dz;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY || cz < minZ || cz > maxZ) break;
      const nId = nodeAtCoord(byId, cx, cy, cz);
      if (!nId) { sawGap = true; continue; }
      if (sawGap) return true;
      break;
    }
  }
  return false;
}

// Reverse any arrow whose head sweep exits through an interior gap so that its
// head exits from the OTHER end instead. The body-behind-head invariant is
// preserved by computing the new exit direction from the FIRST step of the
// original path (not OPP[originalDirection], which would be wrong for bent
// arrows). Example: bent path A(0,0)→B(1,0)→C(1,1)→D(1,2) direction=down.
// After reversal: head=A, new direction=OPP[dirBetween(A,B)]="left". The body
// edge A-B leads from A to B(1,0), which is at A + (1,0) = A - delta(left) ✓.
// Mutates dj.arrows in place. Returns true if any arrow was reversed.
function flipInteriorGapArrows(dj) {
  const OPP = { right: 'left', left: 'right', up: 'down', down: 'up' };
  const byId = indexDj(dj);
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  let flipped = false;
  for (const arrow of dj.arrows) {
    const head = byId.nodes[arrow.endNodeId];
    if (!head) continue;
    const [dx, dy, dz = 0] = DELTA[arrow.direction];
    if (dz !== 0) continue; // vertical arrows sweep the z axis, not this plane
    let cx = head.x, cy = head.y, gap = false;
    while (true) {
      cx += dx; cy += dy;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) break;
      if (!nodeAtCoord(byId, cx, cy, zOf(head))) { gap = true; break; }
    }
    if (!gap) continue;
    // Compute new direction from the FIRST step of the original path.
    // The first occupiedEdge connects startNodeId to its adjacent node;
    // the new exit direction is opposite the first step's direction.
    const firstEdge = byId.edges[arrow.occupiedEdges[0]];
    if (!firstEdge) continue;
    const secondNodeId = firstEdge.fromNodeId === arrow.startNodeId
      ? firstEdge.toNodeId : firstEdge.fromNodeId;
    const startNode = byId.nodes[arrow.startNodeId];
    const secondNode = byId.nodes[secondNodeId];
    if (!startNode || !secondNode) continue;
    const firstStepDir = dirBetween(startNode, secondNode);
    if (!firstStepDir) continue;
    const newDir = OPP[firstStepDir];
    const tmp = arrow.startNodeId;
    arrow.startNodeId = arrow.endNodeId;
    arrow.endNodeId = tmp;
    arrow.direction = newDir;
    flipped = true;
  }
  return flipped;
}

// Returns an array of conflict descriptions if any two arrows share a node or
// edge, otherwise null. Two arrows sharing a node means their occupied shapes
// (startNodeId + endNodeId + edge endpoints) overlap.
function noSharedNodes(dj) {
  const byId = indexDj(dj);
  const ownerByNode = {}, ownerByEdge = {};
  const conflicts = [];
  for (const a of dj.arrows) {
    const nodes = coveredNodes(dj, a, byId);
    for (const n of nodes) {
      if (ownerByNode[n]) conflicts.push(`node ${n} shared by ${ownerByNode[n]} and ${a.id}`);
      else ownerByNode[n] = a.id;
    }
    for (const eId of a.occupiedEdges) {
      if (ownerByEdge[eId]) conflicts.push(`edge ${eId} shared by ${ownerByEdge[eId]} and ${a.id}`);
      else ownerByEdge[eId] = a.id;
    }
  }
  return conflicts.length ? conflicts : null;
}

// [fileKind] is '2d' (default) or '3d'. The 2D set (1-20) keeps the full
// invariant set: difficulty progression (1-5 easy/6-10 medium/11-20 hard),
// strictly-increasing tier averages, density bands, figure-level real-gap
// check, contiguous numbering. The 3D set (21-25) is all-hard by design, so
// the easy/medium progression and increasing-tier-average checks do not
// apply to it (there is nothing to compare); instead every 3D level must be
// multi-layer (>1 distinct z), on top of the invariants that already apply
// generically (structure/no-single-node-arrows, no-free-nodes, greedy
// solvability, disjoint arrows, real-gap-3D).
function validateAll(levels, fileKind = '2d') {
  const is3DFile = fileKind === '3d';
  let ok = true; const warnings = [];
  const diffByNum = {}, arrowsByTier = { easy: [], medium: [], hard: [] };
  for (const lvl of levels) {
    const dj = lvl.definitionJson, diff = lvl.difficulty;
    diffByNum[lvl.number] = diff;
    const se = structureErrors(dj), free = noFreeNodes(dj);
    const sv = solvableGreedy(dj), sh = shapeOf(dj);
    const shared = noSharedNodes(dj);
    const isMultiLayer = new Set(dj.nodes.map(zOf)).size > 1;
    const layerErr = is3DFile && !isMultiLayer;
    if (layerErr) ok = false;
    // Figure levels (16-20) are deliberately concave silhouettes: a bbox-
    // interior "gap" can be a legitimate part of the shape's own visible
    // outer edge, not an accidental hole. Random tiers (1-15) use the
    // blanket bbox check; figures use the figure-aware check (Phase 19) that
    // only flags a gap when it hides a real blocker past it; 3D levels (21+)
    // use the z-aware equivalent of the same real-gap semantics.
    const isFigure = dj.metadata && dj.metadata.generationType === 'figure';
    const is3D = dj.metadata && dj.metadata.generationType === '3d';
    const gapExit =
      is3D ? hasRealInteriorGapExit3D(dj)
        : isFigure ? hasRealInteriorGapExit(dj) : hasInteriorGapExit(dj);
    const components = connectedComponents(dj), n = dj.arrows.length;
    if (arrowsByTier[diff]) arrowsByTier[diff].push(n);
    const band = DENSITY[diff]; let densityErr = '';
    if (band) {
      if (n < band.min || n > band.max) densityErr = `density ${n} out of [${band.min},${band.max}]`;
      else if (band.warn && n > band.warn) warnings.push(`#${lvl.number} dense (${n} arrows, >${band.warn})`);
    }
    const bad = se.length || free || !sv || densityErr || components !== 1 || shared || gapExit || layerErr;
    if (bad) ok = false;
    console.log(
      '#' + String(lvl.number).padStart(2) + ' ' + (lvl.name || '').padEnd(15) +
      ' ' + diff.padEnd(6) +
      ' nodes=' + String(dj.nodes.length).padStart(3) +
      ' arrows=' + String(n).padStart(2) +
      ' bbox=' + sh.w + 'x' + sh.h +
      ' rect=' + (sh.rect ? 'Y' : 'n') +
      ' comp=' + components +
      ' free=' + (free ? JSON.stringify(free) : '-') +
      ' shared=' + (shared ? JSON.stringify(shared) : '-') +
      ' gapExit=' + (gapExit ? 'Y' : '-') +
      ' solvable=' + sv +
      (is3D ? ' layers=' + new Set(dj.nodes.map(zOf)).size + (layerErr ? ' NOT_MULTI_LAYER' : '') : '') +
      (components !== 1 ? ' DISCONNECTED(' + components + ')' : '') +
      (densityErr ? ' ' + densityErr.toUpperCase() : '') +
      (se.length ? ' STRUCT_ERR=' + JSON.stringify(se) : '')
    );
  }
  if (is3DFile) {
    // 3D set is all-hard by construction; the easy/medium progression and
    // strictly-increasing tier-average checks don't apply (nothing to
    // compare against). All-hard is still asserted directly.
    const allHard = Object.values(diffByNum).every(d => d === 'hard');
    if (!allHard) ok = false;
    console.log();
    console.log('all levels hard (3D set):', allHard);
    if (warnings.length) console.log('WARNINGS:', warnings.join('; '));
    const allOk = ok && allHard;
    console.log('ALL VALID:', allOk);
    return allOk;
  }
  // Generalized so any count >= 15 (figure levels 16+) works without a code
  // change: 1-5 easy, 6-10 medium, every number >= 11 present must be hard.
  const prog = [1,2,3,4,5].every(k => diffByNum[k] === 'easy') &&
    [6,7,8,9,10].every(k => diffByNum[k] === 'medium') &&
    Object.keys(diffByNum).map(Number).filter(k => k >= 11).every(k => diffByNum[k] === 'hard');
  const avg = t => arrowsByTier[t].reduce((a, b) => a + b, 0) / (arrowsByTier[t].length || 1);
  const increasing = avg('easy') < avg('medium') && avg('medium') < avg('hard');
  const hardLevels = levels.filter(l => l.number >= 11);
  const hardRects = hardLevels.filter(l => shapeOf(l.definitionJson).rect).length;
  console.log();
  console.log('difficulty progression ok:', prog);
  console.log('tier avg arrows: easy=' + avg('easy').toFixed(1) + ' medium=' + avg('medium').toFixed(1) +
    ' hard=' + avg('hard').toFixed(1) + ' (must strictly increase:', increasing + ')');
  console.log('hard full-rectangle levels:', hardRects, '(must be <', hardLevels.length, ')');
  if (warnings.length) console.log('WARNINGS:', warnings.join('; '));
  const allOk = ok && prog && increasing && hardRects < hardLevels.length;
  console.log('ALL VALID:', allOk);
  return allOk;
}

// ---------------------------------------------------------------------------
// Self-test: greedy solver must reject a known deadlock.
//
// Grid A(0,0)–B(1,0)–C(2,0)–D(3,0):
//   Arrow1: head=B dir=right — from A, sweep right → B(own) → C ∈ Arrow2 → BLOCKED
//   Arrow2: head=C dir=left  — from D, sweep left  → C(own) → B ∈ Arrow1 → BLOCKED
//   Neither can exit → solvableGreedy must return false.
// ---------------------------------------------------------------------------
function selfTest() {
  const dj = {
    nodes: [{ id:'A',x:0,y:0},{id:'B',x:1,y:0},{id:'C',x:2,y:0},{id:'D',x:3,y:0}],
    edges: [
      {id:'A-B',fromNodeId:'A',toNodeId:'B',direction:'right'},
      {id:'B-C',fromNodeId:'B',toNodeId:'C',direction:'right'},
      {id:'C-D',fromNodeId:'C',toNodeId:'D',direction:'right'},
    ],
    arrows: [
      {id:'arrow1',occupiedEdges:['A-B'],startNodeId:'A',endNodeId:'B',direction:'right'},
      {id:'arrow2',occupiedEdges:['C-D'],startNodeId:'D',endNodeId:'C',direction:'left'},
    ],
    blockedEdges: [],
  };
  if (solvableGreedy(dj) !== false) {
    console.error('SELF-TEST FAILED: deadlock incorrectly reported as solvable');
    process.exitCode = 1; return false;
  }
  console.log('Self-test passed: deadlock correctly detected.');
  return true;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
function writeLevels(assetPath, levels) {
  fs.writeFileSync(assetPath, JSON.stringify({ levels }, null, 2) + '\n');
  console.log('\nWROTE', assetPath);
}

function runGenerate2D() {
  console.log('MODE: --generate-2d (levels 1-15 random + 16-20 figures; writes manual_levels_2d.json)\n');
  const levels = [...buildLevels(), ...buildFigureLevels()];
  console.log();
  const allOk = validateAll(levels, '2d');
  if (allOk) {
    writeLevels(ASSET_2D, levels);
  } else {
    console.log('\nNOT WRITTEN — fix issues first'); process.exitCode = 1;
  }
  return allOk;
}

function runGenerate3D() {
  console.log('MODE: --generate-3d (levels 21-30; writes manual_levels_3d.json)\n');
  const levels = build3DLevels();
  console.log();
  const allOk = validateAll(levels, '3d');
  if (allOk) {
    writeLevels(ASSET_3D, levels);
  } else {
    console.log('\nNOT WRITTEN — fix issues first'); process.exitCode = 1;
  }
  return allOk;
}

function readContiguous(assetPath, expectedStart) {
  const parsed = JSON.parse(fs.readFileSync(assetPath, 'utf8'));
  const levels = parsed.levels || [];
  const numbers = levels.map(l => l.number).sort((a, b) => a - b);
  const contiguous = numbers.length > 0 &&
    numbers.every((n, i) => n === expectedStart + i);
  if (!contiguous) {
    console.log(`${assetPath}: expected contiguous numbering from ${expectedStart}, found: ${JSON.stringify(numbers)}`);
    return null;
  }
  return levels;
}

function main() {
  const args = process.argv.slice(2);
  const generate = args.includes('--generate');
  const generate2D = args.includes('--generate-2d');
  const generate3D = args.includes('--generate-3d');
  const modeCount = [generate, generate2D, generate3D, args.includes('--validate-only')].filter(Boolean).length;
  if (modeCount > 1) {
    console.error('Pass exactly one of --generate, --generate-2d, --generate-3d, --validate-only.');
    process.exitCode = 2; return;
  }
  if (!selfTest()) return;
  console.log();
  if (generate) {
    console.log('MODE: --generate (shorthand: --generate-2d + --generate-3d)\n');
    const ok2d = runGenerate2D();
    console.log();
    const ok3d = runGenerate3D();
    if (!ok2d || !ok3d) process.exitCode = 1;
    return;
  }
  if (generate2D) {
    const ok = runGenerate2D();
    if (!ok) process.exitCode = 1;
    return;
  }
  if (generate3D) {
    const ok = runGenerate3D();
    if (!ok) process.exitCode = 1;
    return;
  }
  console.log('MODE: --validate-only (reads manual_levels_2d.json + manual_levels_3d.json, never writes)\n');
  const levels2d = readContiguous(ASSET_2D, 1);
  const levels3d = readContiguous(ASSET_3D, 21);
  if (!levels2d || !levels3d) { process.exitCode = 1; return; }
  console.log('--- 2D set (manual_levels_2d.json) ---');
  const ok2d = validateAll(levels2d, '2d');
  console.log('\n--- 3D set (manual_levels_3d.json) ---');
  const ok3d = validateAll(levels3d, '3d');
  if (!ok2d || !ok3d) process.exitCode = 1;
}

main();
