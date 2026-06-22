# PHASE 14 — Audio/Music/Localization Audit + Collision Runtime Escape Fix

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

Phases 13, 13.1, and 13.2 are complete and merged to `main`. The `develop`
branch has already been merged into `main` via PR, so the **audio, music, and
localization code is now present in `main`**. A partial Phase 14 implementation
is also present. The game has working collision (head-only sweep), varied arrow
shapes, random directions, and a path-following exit animation.

**Do NOT fetch or merge `develop`.** The code under audit is already integrated.

This phase has two tasks. Work on branch
`feat/phase-14-audio-and-collision-fix` (already created and checked out).
**Do not switch branches.**

---

## Task A — Audio, Music & Localization — COMPLETED

**No action needed.** This task is already implemented, audited, and Clean
Architecture compliant. Language switching (English / Spanish / System default)
is fully functional and persists across restarts. Do not re-do this work.

If — and only if — the Task B work forces you to touch shared files and you
notice a regression in audio/music/localization, report it. Otherwise leave
this area untouched.

---

## Task B — Collision Bug: Runtime Escape Bug

**Status: CRITICAL BUG CONFIRMED — this is a live runtime defect, not a
hypothetical.**

**Observable bug:** Tapping an arrow causes it to escape (slide off the board)
**even when another arrow is visually directly in its exit path.** Visual
evidence (two attached screenshots) shows a green arrow exiting the board
despite another arrow blocking its path.

**Prior partial fix (by a previous agent):** Added `noSharedNodes` validation
in `tool/gen_levels.js` and `level_definition_validator.dart`, plus two Dart
tests for shared-node rejection. **This was generation-side validation only and
did NOT change the runtime behavior. The bug still reproduces.** Do not assume
it is fixed.

**Hypothesis:** The defect is in how `MovementResolver` sweeps for blockers when
arrows sit on parallel/adjacent paths, **OR** in how the generator assigns arrow
paths relative to board boundaries. Investigate both; do not stop at the first
plausible cause.

This is an **audit-first investigation that must end in a real fix.**

### B.1 — Read the visual evidence

Study the two attached screenshots carefully. Identify:
- Which level is shown.
- Which arrow escaped (color, approximate board position).
- Which arrow should have blocked it.
- The nodes and directions involved.

Use this visual evidence to drive the investigation.

### B.2 — Reproduce the bug

Find the exact level in `assets/levels/manual_levels.json` that matches the
screenshot. Identify the escaping arrow and the arrow that should have blocked
it. Document **exact arrow IDs, node coordinates, and directions**.

If the screenshot level cannot be conclusively identified, construct a **minimal
test fixture** that reproduces the visual scenario: two arrows where one is
visually "in front" of the other, but the resolver returns `escaped`.

### B.3 — Audit `MovementResolver.resolve()` line by line

- How does it build `blockerNodes`?
- How does it step from the head coordinate?
- Does it check **only node occupancy**, or also **edge adjacency**?
- Is there a case where a blocker arrow is visually in front but **not** in the
  coordinate sweep path?

### B.4 — Audit `BoardGraph` and `nodeByCoordinate`

- Does `nodeByCoordinate` return the correct node for every coordinate?
- Are there "hidden" nodes or coordinate gaps that cause the sweep to miss
  blockers?

### B.5 — Audit the generator's board construction

- Does the generator place arrows too close to boundaries?
- Are board `width`/`height` correctly calculated so arrows near edges have room
  to sweep?
- Is there a case where an arrow's head is at `(x,y)`, the next coordinate in its
  direction is **off** the board, but visually another arrow sits "just outside"
  that should block it?

### B.6 — Decide where the real bug is, then fix it precisely

- **Runtime bug (`MovementResolver`):** fix the sweep logic so blockers are
  detected in all visual configurations. Add a runtime test reproducing B.2.
- **Generator bug:** fix board sizing / arrow-placement logic. Regenerate with
  `node tool/gen_levels.js --generate`.
- **Level-data bug:** identify the broken levels and regenerate.
- **Multiple causes:** fix all of them.

Fixes must be precise and minimal. Graph-based runtime only — no grid/matrix/tile
logic.

---

## Constraints

- Work **only** inside `frontend-poc-arrow/`.
- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code unless explicitly required.
- Do not modify Git remotes.
- Do **not** fetch or merge `develop` — the code is already in `main`.
- Graph-based runtime only — no grid/matrix/tile logic.
- **Stay on branch `feat/phase-14-audio-and-collision-fix`.** Do not switch branches.
- Do not commit or push. Stage only if ≥ 95% confident.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only   # only if level/generator files were touched
```

Manual checks:
- Confirm the screenshot scenario no longer escapes: an arrow with another arrow
  directly in its exit path collides instead of sliding off the board.
- Confirm no level spawns two arrows sharing a node or edge.
- Confirm a runtime test exists that reproduces the original escape and now
  asserts `collision`.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md` — mark **Phase 14 as COMPLETE**.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
