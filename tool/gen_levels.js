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
const MAX_RETRIES = 200;

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

      let next;
      if (path.length === maxPathLen - 1) {
        // Last step: prefer horizontal neighbours so direction=right/left.
        const hCands = allCands.filter(nb => nodes.get(nb).y === nodes.get(cur).y);
        next = hCands.length ? hCands[0] : allCands[0];
      } else {
        next = allCands[0];
      }
      path.push(next);
      unvisited.delete(next);
      cur = next;
    }

    // Try to reverse path if direction is vertical, to get a horizontal end.
    const dir = finalDir(path, nodes);
    if (!H_DIRS.includes(dir) && path.length >= 2) {
      const revDir = finalDir([...path].reverse(), nodes);
      if (H_DIRS.includes(revDir)) path.reverse();
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

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
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

    // Greedy solvability (should almost always pass with sparse graph + horizontal bias).
    if (!solvableGreedy(dj)) continue;

    console.log(`  #${number} attempt ${attempt + 1}: ${n} arrows, ${totalNodes} nodes, ${W}x${H}`);
    return level;
  }

  // Fallback: deterministic comb (guaranteed valid, always used as last resort).
  console.warn(`  #${number} FALLBACK after ${MAX_RETRIES} retries`);
  return buildCombFallback(number, name, difficulty, meta, baseSeed);
}

// ---------------------------------------------------------------------------
// Comb fallback (randomised parameters so each fallback looks different)
// ---------------------------------------------------------------------------
function buildCombFallback(number, name, difficulty, meta, seed) {
  const rng = makePRNG(seed);
  const nTeeth = { easy: [3,4,5], medium: [4,5,6], hard: [5,6,7] }[difficulty];
  const nCombs = { easy: [2,2,3], medium: [2,3,3], hard: [3,4,5] }[difficulty];
  const ti = rng.int(nTeeth.length);
  return buildCombLevel(number, name, difficulty, meta, nTeeth[ti], nCombs[ti]);
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
  { number:  1, name: 'First Exit',     difficulty: 'easy',   meta: { t: 120, m: 30  }, seed: 10001 },
  { number:  2, name: 'L-Turn',         difficulty: 'easy',   meta: { t: 120, m: 33  }, seed: 20002 },
  { number:  3, name: 'Zigzag',         difficulty: 'easy',   meta: { t: 120, m: 36  }, seed: 30003 },
  { number:  4, name: 'Two Lanes',      difficulty: 'easy',   meta: { t: 120, m: 39  }, seed: 40004 },
  { number:  5, name: 'Queue Up',       difficulty: 'easy',   meta: { t: 120, m: 45  }, seed: 50005 },
  { number:  6, name: 'Cross Roads',    difficulty: 'medium', meta: { t: 100, m: 48  }, seed: 60006 },
  { number:  7, name: 'T-Junction',     difficulty: 'medium', meta: { t: 100, m: 54  }, seed: 70007 },
  { number:  8, name: 'Comb Grid',      difficulty: 'medium', meta: { t: 100, m: 63  }, seed: 80008 },
  { number:  9, name: 'Offset Pair',    difficulty: 'medium', meta: { t: 100, m: 72  }, seed: 90009 },
  { number: 10, name: 'Three Way',      difficulty: 'medium', meta: { t: 100, m: 84  }, seed: 10010 },
  { number: 11, name: 'Deadlock Intro', difficulty: 'hard',   meta: { t: 90,  m: 66  }, seed: 11011 },
  { number: 12, name: 'Chain Block',    difficulty: 'hard',   meta: { t: 90,  m: 84  }, seed: 12012 },
  { number: 13, name: 'Comb Maze',      difficulty: 'hard',   meta: { t: 90,  m: 105 }, seed: 13013 },
  { number: 14, name: 'Four Locks',     difficulty: 'hard',   meta: { t: 80,  m: 126 }, seed: 14014 },
  { number: 15, name: 'Final Maze',     difficulty: 'hard',   meta: { t: 80,  m: 150 }, seed: 15015 },
];

function buildLevels() {
  return LEVEL_DEFS.map(d => generateLevel(d.number, d.name, d.difficulty, d.meta, d.seed));
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
  const nodes = {}, edges = {};
  for (const n of dj.nodes) nodes[n.id] = n;
  for (const e of dj.edges) edges[e.id] = e;
  return { nodes, edges };
}
function edgeInDir(dj, byId, nodeId, dir) {
  const node = byId.nodes[nodeId]; const [dx, dy] = DELTA[dir];
  for (const e of dj.edges) {
    let other = null;
    if (e.fromNodeId === nodeId) other = e.toNodeId;
    else if (e.toNodeId === nodeId) other = e.fromNodeId;
    else continue;
    const o = byId.nodes[other];
    if (o && o.x === node.x + dx && o.y === node.y + dy) return e;
  }
  return null;
}
function neighborInDir(dj, byId, nodeId, dir) {
  const e = edgeInDir(dj, byId, nodeId, dir); if (!e) return null;
  return e.fromNodeId === nodeId ? e.toNodeId : e.fromNodeId;
}
function canExit(dj, byId, arrow, activeById, blockedSet) {
  const blocker = new Set();
  for (const id in activeById) {
    if (id === arrow.id) continue;
    for (const n of coveredNodes(dj, activeById[id], byId)) blocker.add(n);
  }
  for (const start of coveredNodes(dj, arrow, byId)) {
    let cur = start;
    while (true) {
      const e = edgeInDir(dj, byId, cur, arrow.direction);
      if (!e) break;
      if (blockedSet.has(e.id)) return false;
      const nb = neighborInDir(dj, byId, cur, arrow.direction);
      if (nb === null) break;
      if (blocker.has(nb)) return false;
      cur = nb;
    }
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
  }
  return errs;
}
function shapeOf(dj) {
  const xs = dj.nodes.map(n => n.x), ys = dj.nodes.map(n => n.y);
  const w = Math.max(...xs) - Math.min(...xs) + 1, h = Math.max(...ys) - Math.min(...ys) + 1;
  return { w, h, rect: dj.nodes.length === w * h };
}

function validateAll(levels) {
  let ok = true; const warnings = [];
  const diffByNum = {}, arrowsByTier = { easy: [], medium: [], hard: [] };
  for (const lvl of levels) {
    const dj = lvl.definitionJson, diff = lvl.difficulty;
    diffByNum[lvl.number] = diff;
    const se = structureErrors(dj), free = noFreeNodes(dj);
    const sv = solvableGreedy(dj), sh = shapeOf(dj);
    const components = connectedComponents(dj), n = dj.arrows.length;
    if (arrowsByTier[diff]) arrowsByTier[diff].push(n);
    const band = DENSITY[diff]; let densityErr = '';
    if (band) {
      if (n < band.min || n > band.max) densityErr = `density ${n} out of [${band.min},${band.max}]`;
      else if (band.warn && n > band.warn) warnings.push(`#${lvl.number} dense (${n} arrows, >${band.warn})`);
    }
    const bad = se.length || free || !sv || densityErr || components !== 1;
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
      ' solvable=' + sv +
      (components !== 1 ? ' DISCONNECTED(' + components + ')' : '') +
      (densityErr ? ' ' + densityErr.toUpperCase() : '') +
      (se.length ? ' STRUCT_ERR=' + JSON.stringify(se) : '')
    );
  }
  const prog = [1,2,3,4,5].every(k => diffByNum[k] === 'easy') &&
    [6,7,8,9,10].every(k => diffByNum[k] === 'medium') &&
    [11,12,13,14,15].every(k => diffByNum[k] === 'hard');
  const avg = t => arrowsByTier[t].reduce((a, b) => a + b, 0) / (arrowsByTier[t].length || 1);
  const increasing = avg('easy') < avg('medium') && avg('medium') < avg('hard');
  const hardRects = levels.filter(l => l.number >= 11).filter(l => shapeOf(l.definitionJson).rect).length;
  console.log();
  console.log('difficulty progression ok:', prog);
  console.log('tier avg arrows: easy=' + avg('easy').toFixed(1) + ' medium=' + avg('medium').toFixed(1) +
    ' hard=' + avg('hard').toFixed(1) + ' (must strictly increase:', increasing + ')');
  console.log('hard full-rectangle levels:', hardRects, '(must be < 5)');
  if (warnings.length) console.log('WARNINGS:', warnings.join('; '));
  const allOk = ok && prog && increasing && hardRects < 5;
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
  const validateOnly = args.includes('--validate-only') || !generate;
  if (generate && args.includes('--validate-only')) {
    console.error('Pass either --generate or --validate-only, not both.');
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
  console.log('MODE: --validate-only (reads manual_levels.json, never writes)\n');
  const parsed = JSON.parse(fs.readFileSync(ASSET, 'utf8'));
  const levels = parsed.levels || [];
  if (levels.length !== 15) {
    console.log(`Expected 15 levels, found ${levels.length}`); process.exitCode = 1; return;
  }
  const allOk = validateAll(levels);
  if (!allOk) process.exitCode = 1;
}

main();
