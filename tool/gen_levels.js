// Level tool for the Arrow game (Phase 11 — random bent-arrow generator).
//
//   node tool/gen_levels.js --validate-only   (default, no args)
//       Reads assets/levels/manual_levels.json, runs all checks. Never writes.
//
//   node tool/gen_levels.js --generate
//       Generates 15 random levels, validates, writes manual_levels.json.
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

const ASSET = path.join(__dirname, '..', 'assets', 'levels', 'manual_levels.json');
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

function dirBetween(a, b) {
  if (b.x === a.x + 1 && b.y === a.y) return 'right';
  if (b.x === a.x - 1 && b.y === a.y) return 'left';
  if (b.x === a.x && b.y === a.y + 1) return 'down';
  if (b.x === a.x && b.y === a.y - 1) return 'up';
  return null;
}
const DELTA = { right: [1, 0], left: [-1, 0], down: [0, 1], up: [0, -1] };
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
  for (const n of dj.nodes) { nodes[n.id] = n; byCoord[`${n.x},${n.y}`] = n.id; }
  for (const e of dj.edges) edges[e.id] = e;
  return { nodes, edges, byCoord };
}
function nodeAtCoord(byId, x, y) { return byId.byCoord[`${x},${y}`] || null; }
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
  const [dx, dy] = DELTA[arrow.direction];
  // Sweep from the head only (mirrors the Dart Phase 12.1 head-only resolver).
  let cur = arrow.endNodeId;
  while (true) {
    const cn = byId.nodes[cur];
    const nextId = nodeAtCoord(byId, cn.x + dx, cn.y + dy);
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
    if (!a.occupiedEdges || a.occupiedEdges.length < 1) errs.push('arrow has no edges ' + a.id);
    const head = byId.nodes[a.endNodeId]; const [dx, dy] = DELTA[a.direction] || [0, 0];
    if (head) {
      let behind = false;
      for (const eId of a.occupiedEdges) {
        const e = byId.edges[eId]; if (!e) continue;
        const otherId = e.fromNodeId === a.endNodeId ? e.toNodeId : e.toNodeId === a.endNodeId ? e.fromNodeId : null;
        if (!otherId) continue;
        const o = byId.nodes[otherId];
        if (o && o.x === head.x - dx && o.y === head.y - dy) behind = true;
      }
      if (!behind) errs.push('arrow head not at exit end ' + a.id);
    }
    // Cycle check: N edges over a simple path span N+1 distinct nodes.
    const bodyNodes = new Set();
    for (const eId of a.occupiedEdges) {
      const e = byId.edges[eId]; if (!e) continue;
      bodyNodes.add(e.fromNodeId); bodyNodes.add(e.toNodeId);
    }
    if (a.occupiedEdges.length >= bodyNodes.size) errs.push('arrow body forms a cycle ' + a.id);
    // Self-intersection check: head sweep must not hit own body.
    const head2 = byId.nodes[a.endNodeId];
    if (head2) {
      const body2 = new Set([a.startNodeId]);
      for (const eId of a.occupiedEdges) {
        const e = byId.edges[eId]; if (!e) continue;
        body2.add(e.fromNodeId); body2.add(e.toNodeId);
      }
      body2.delete(a.endNodeId);
      const [dx2, dy2] = DELTA[a.direction] || [0, 0];
      let cx2 = head2.x + dx2, cy2 = head2.y + dy2;
      while (true) {
        const nId2 = nodeAtCoord(byId, cx2, cy2);
        if (!nId2) break;
        if (body2.has(nId2)) { errs.push('arrow head sweep self-intersects own body at ' + nId2 + ' ' + a.id); break; }
        cx2 += dx2; cy2 += dy2;
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
    const [dx, dy] = DELTA[a.direction] || [0, 0];
    let cx = head.x + dx, cy = head.y + dy;
    while (true) {
      const nId = nodeAtCoord(byId, cx, cy);
      if (!nId) break;
      if (body.has(nId)) return true;
      cx += dx; cy += dy;
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
    const [dx, dy] = DELTA[arrow.direction];
    let cx = head.x, cy = head.y;
    while (true) {
      cx += dx; cy += dy;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) break; // true boundary
      if (!nodeAtCoord(byId, cx, cy)) return true; // interior gap
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
    const [dx, dy] = DELTA[arrow.direction];
    let cx = head.x, cy = head.y, gap = false;
    while (true) {
      cx += dx; cy += dy;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) break;
      if (!nodeAtCoord(byId, cx, cy)) { gap = true; break; }
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

function validateAll(levels) {
  let ok = true; const warnings = [];
  const diffByNum = {}, arrowsByTier = { easy: [], medium: [], hard: [] };
  for (const lvl of levels) {
    const dj = lvl.definitionJson, diff = lvl.difficulty;
    diffByNum[lvl.number] = diff;
    const se = structureErrors(dj), free = noFreeNodes(dj);
    const sv = solvableGreedy(dj), sh = shapeOf(dj);
    const shared = noSharedNodes(dj);
    // Figure levels (16-20) are deliberately concave silhouettes: a bbox-
    // interior "gap" can be a legitimate part of the shape's own visible
    // outer edge, not an accidental hole. Random tiers (1-15) use the
    // blanket bbox check; figures use the figure-aware check (Phase 19) that
    // only flags a gap when it hides a real blocker past it.
    const isFigure = dj.metadata && dj.metadata.generationType === 'figure';
    const gapExit = isFigure ? hasRealInteriorGapExit(dj) : hasInteriorGapExit(dj);
    const components = connectedComponents(dj), n = dj.arrows.length;
    if (arrowsByTier[diff]) arrowsByTier[diff].push(n);
    const band = DENSITY[diff]; let densityErr = '';
    if (band) {
      if (n < band.min || n > band.max) densityErr = `density ${n} out of [${band.min},${band.max}]`;
      else if (band.warn && n > band.warn) warnings.push(`#${lvl.number} dense (${n} arrows, >${band.warn})`);
    }
    const bad = se.length || free || !sv || densityErr || components !== 1 || shared || gapExit;
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
      (components !== 1 ? ' DISCONNECTED(' + components + ')' : '') +
      (densityErr ? ' ' + densityErr.toUpperCase() : '') +
      (se.length ? ' STRUCT_ERR=' + JSON.stringify(se) : '')
    );
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
function main() {
  const args = process.argv.slice(2);
  const generate = args.includes('--generate');
  const generateFigures = args.includes('--generate-figures');
  const modeCount = [generate, generateFigures, args.includes('--validate-only')].filter(Boolean).length;
  if (modeCount > 1) {
    console.error('Pass exactly one of --generate, --generate-figures, --validate-only.');
    process.exitCode = 2; return;
  }
  if (!selfTest()) return;
  console.log();
  if (generate) {
    console.log('MODE: --generate (will write manual_levels.json if valid)\n');
    const levels = buildLevels();
    console.log();
    const allOk = validateAll(levels);
    if (allOk) {
      fs.writeFileSync(ASSET, JSON.stringify({ levels }, null, 2) + '\n');
      console.log('\nWROTE', ASSET);
    } else {
      console.log('\nNOT WRITTEN — fix issues first'); process.exitCode = 1;
    }
    return;
  }
  if (generateFigures) {
    console.log('MODE: --generate-figures (regenerates levels 16-20 only; 1-15 left byte-identical)\n');
    const parsed = JSON.parse(fs.readFileSync(ASSET, 'utf8'));
    const base = (parsed.levels || []).filter(l => l.number <= 15);
    if (base.length !== 15) {
      console.log(`Expected 15 base levels (1-15) on disk, found ${base.length}`); process.exitCode = 1; return;
    }
    const figures = buildFigureLevels();
    console.log();
    const levels = [...base, ...figures];
    const allOk = validateAll(levels);
    if (allOk) {
      fs.writeFileSync(ASSET, JSON.stringify({ levels }, null, 2) + '\n');
      console.log('\nWROTE', ASSET);
    } else {
      console.log('\nNOT WRITTEN — fix issues first'); process.exitCode = 1;
    }
    return;
  }
  console.log('MODE: --validate-only (reads manual_levels.json, never writes)\n');
  const parsed = JSON.parse(fs.readFileSync(ASSET, 'utf8'));
  const levels = parsed.levels || [];
  const numbers = levels.map(l => l.number).sort((a, b) => a - b);
  const contiguous = numbers.length > 0 && numbers.every((n, i) => n === i + 1);
  if (!contiguous) {
    console.log(`Expected a contiguous 1..N level numbering, found: ${JSON.stringify(numbers)}`);
    process.exitCode = 1; return;
  }
  const allOk = validateAll(levels);
  if (!allOk) process.exitCode = 1;
}

main();
