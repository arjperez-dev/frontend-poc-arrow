# PHASE 34.1 — Backend Level Contract & Storage Design (2D/3D)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/phases/phase_34_backend_driven_levels.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Current State (from audit)

- `backend-poc-arrow/prisma/schema.prisma` `Level` model already stores
  `number` (unique), `name`, `difficulty`, `generationType`, `seed`, and
  `definitionJson` (arbitrary JSON), plus `createdAt`/`updatedAt`.
- `LevelsController` already exposes `GET /levels`, `GET /levels/:id`,
  `POST /levels` (ADMIN), `PUT /levels/:id` (ADMIN). `GET /levels` returns full
  `LevelEntity` objects **including `definitionJson`** — the frontend simply
  ignores that field today.
- The frontend gameplay DTO (`ManualLevelDefinitionDto` / `ManualGraphNodeDto`)
  already supports an optional `z` axis (absent ⇒ `z = 0`, a 2D level). So a
  single `definitionJson` shape covers both 2D and 3D; **3D is distinguished by
  the presence of non-zero `z` on nodes**, not by a separate schema.
- Backend `Level` rows 16–30 currently hold placeholder 2D `definitionJson`
  used only for id↔number mapping (documented in `manual-levels.ts`).

## Goal (this slice — design + minimal backend surface only)

Define and document the exact contract the frontend will consume to download
real, playable 2D and 3D levels, and confirm the backend can express it, with the
**smallest** schema/API change (ideally none to existing endpoints).

## Task

1. **Decide the 2D/3D discriminator** and document it:
   - Recommended: keep a single `definitionJson` graph shape; 3D is any level
     whose nodes carry a non-zero `z`. Add a machine-readable hint in
     `definitionJson.metadata` (e.g. `"mode": "2d" | "3d"`) so the frontend can
     route without scanning every node. Confirm this matches the frontend
     `ManualLevelDto`/metadata expectations and Phase 24.x mode-aware unlock.
2. **Decide the level-number namespace** for additional remote levels so they do
   not collide with local levels 1–25. Document the chosen range/rule (e.g.
   remote-only levels start at a reserved number band). Do **not** repurpose the
   existing 16–30 placeholder rows for gameplay in this slice.
3. **Confirm the read contract** the frontend will use: whether the frontend
   fetches all definitions from `GET /levels` (already returns `definitionJson`)
   or from `GET /levels/:id`. Document field names, types, and the shape that
   maps 1:1 to `ManualLevelDto`.
4. If (and only if) a schema field is genuinely required (e.g. an explicit
   `mode`/`isRemotePlayable` column), write the Prisma migration; otherwise
   record that metadata-in-JSON is sufficient and make **no** schema change.
5. Produce a short design note at
   `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md` (create) capturing the
   decisions above. This is the contract 34.2–34.4 implement against.

## Constraints

- Do not modify auth, sync, leaderboard, or existing API request/response shapes
  in a breaking way. Additive JSON fields only.
- Do not change existing `Level` rows 1–15 (real) or the 16–30 placeholder
  mapping behavior.
- Do not modify Git remotes. Do not commit or push automatically. Never work on `main`.
- Prefer **no** schema migration; justify any migration in the design note.

---

## Validation

```bash
# from backend-poc-arrow (if backend code/schema touched)
npm run lint
npm test
npx prisma validate   # only if schema.prisma was touched
```

Frontend is not modified in this slice; no Flutter changes expected.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
