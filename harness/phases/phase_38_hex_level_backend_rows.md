# PHASE 38 — Backend Level Rows for Hex Levels 31–40

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `backend-poc-arrow/README.md` (Seed Data section — the "Known gap" blockquote is the problem this phase closes)
- `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Problem

The Flutter client ships hexagonal levels with internal numbers 31–40 (Phase 37). The backend has `Level` rows for numbers 1–30 only — real definitions for 1–15, generated placeholder rows for 16–30. Because `GET /levels` cannot resolve a `levelId` for 31–40, leaderboard submission and progress sync for every hex level silently no-op. Local gameplay, unlocking, and progress are unaffected.

---

## Task

1. Audit `backend-poc-arrow/prisma/levels/manual-levels.ts` and `prisma/seed.ts`. Confirm exactly how the 16–30 placeholder block is generated and how seeding upserts by `number`.
2. Extend the seed so numbers 31–40 produce `Level` rows, mirroring the existing 16–30 placeholder pattern. Decide and state up front whether to:
   - reuse the existing square `LevelSpec` placeholder shape (minimal change, no schema/type churn), or
   - carry real hex geometry (requires `ManualLevelDefinition` to admit hex topology and six directions).

   Default to the **placeholder** approach unless the audit shows the client rejects rows whose definition topology disagrees with its local asset. The client is offline-first and plays from local assets; the backend row exists to provide a stable `levelId`. Justify the choice in the pre-implementation report.
3. Set `difficulty` per row consistently with the client's hex tiering, not blindly `'hard'`.
4. Verify seeding is idempotent — re-running must not duplicate or renumber rows 1–30.
5. Confirm end-to-end that a hex level now resolves a `levelId`: leaderboard submission and progress sync stop no-opping.
6. Update `backend-poc-arrow/README.md`: remove the "Known gap" blockquote and correct the Seed Data + Backend-Driven Dynamic Levels ranges.
7. Add a cross-reference in `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md` noting that board topology is read from `metadata.topology`, never inferred from graph shape (deferred follow-up from Phase 37.4).

---

## Constraints

- **This phase explicitly authorizes backend changes** — it supersedes the standing "do not modify `backend-poc-arrow`" constraint for this phase only.
- Do not change internal level numbers 1–30, or their existing rows' definitions.
- Do not change the remote-level band (`>= 1000`) or its routing.
- Do not modify `manual_levels_2d.json`, `manual_levels_3d.json`, or `manual_levels_hex.json`.
- Frontend changes are out of scope unless the audit proves a client-side change is required to consume the new rows. If so, report it before implementing.
- Do not modify Git remotes.
- Do not commit or push automatically.
- Feature branch only. Never `main`.

---

## Validation

Run these after implementation. All must pass.

```bash
# backend-poc-arrow
npm run lint
npm test
npx prisma migrate reset --force   # or the project's documented seed command; confirm 40 rows
npm run seed                       # run twice — must be idempotent

# frontend-poc-arrow
flutter analyze
flutter test
```

Also confirm manually: `GET /levels` returns numbers 1–40, and a hex level submission persists a leaderboard entry.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
