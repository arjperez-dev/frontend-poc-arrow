# PHASE 34.2 — Backend Seeding/Authoring for Additional Real Levels

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/phases/phase_34_backend_driven_levels.md`
- `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md` *(created in 34.1)*
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Current State

- Backend already has `CreateLevelUseCase` / `UpdateLevelUseCase` and ADMIN-gated
  `POST /levels` / `PUT /levels/:id` that persist `definitionJson`.
- `backend-poc-arrow/prisma/levels/manual-levels.ts` seeds levels 1–30; 1–15 are
  real 2D boards, 16–30 are placeholder rows for id↔number mapping only.
- Level graph validation exists at `backend-poc-arrow/src/domain/levels/graph-level-definition.ts`.

## Goal

Provide a mechanism to store **real, playable** `definitionJson` for **additional**
level numbers (the reserved remote-only band defined in 34.1), covering both 2D
and 3D, without disturbing local levels or the existing placeholder mapping rows.

## Task

1. Add a seed/authoring source for the additional real levels, e.g.
   `backend-poc-arrow/prisma/levels/remote-levels.ts` (or extend the seed runner),
   containing real 2D and 3D definitions with `metadata.mode` per the 34.1
   contract. Keep them in the reserved number band; do not overwrite 1–30.
2. Wire the seed into the existing seeding entrypoint idempotently (upsert by
   `number`), so re-running the seed does not duplicate rows and does not mutate
   local levels 1–15 or the 16–30 placeholder rows.
3. Ensure each new level's `definitionJson` passes the backend graph validator
   (`graph-level-definition.ts`). Add validation coverage if a 3D case is not
   currently exercised.
4. Confirm `POST/PUT /levels` (ADMIN) accept and round-trip a 3D definition
   (non-zero `z`) unchanged. Add a focused test if missing.
5. Document the seed workflow in `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md`.

## Constraints

- Do not modify auth, sync, leaderboard code, or existing endpoint shapes.
- Do not change or reorder local levels 1–25 or placeholder rows 16–30.
- Additive only; upserts keyed by `number`.
- Do not modify Git remotes. Do not commit or push automatically. Never work on `main`.

---

## Validation

```bash
# from backend-poc-arrow
npm run lint
npm test
npx prisma validate            # if schema touched (should not be)
# run the seed against a disposable DB and confirm idempotency + no changes to 1-30 real/placeholder rows
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
