# PHASE 34 — Backend-Driven Dynamic Levels (Overview + Sub-Phase 34.1 Start)

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

## Why This Phase Exists (Audit Conclusion)

An audit of `backend-poc-arrow/prisma/levels/manual-levels.ts` versus the frontend
level system established the following current contract:

- The frontend loads **all playable gameplay levels from local bundled assets**:
  `assets/levels/manual_levels_2d.json` (levels 1–20) and
  `assets/levels/manual_levels_3d.json` (levels 21–25), concatenated by
  `LocalLevelDataSource.loadManualLevels()`.
- The frontend **never fetches level *definitions* (nodes/edges/arrows) from the
  backend**. `ApiRemoteLevelRepository.getLevelIdsByNumber()` calls `GET /levels`
  and reads only each level's `number` and `id`, discarding `definitionJson`.
- That `number → id` map is used **only** by `SyncProgressUseCase` and the
  leaderboard use cases to translate a local level number into the backend
  `Level.id` needed by `/progress` and `/leaderboard/:levelId`.
- Editing `manual-levels.ts` (or its seeded `definitionJson`) therefore has **zero
  effect on the boards rendered in the running game**. The seed's own header
  comment confirms rows 16–30 are minimal 2D placeholders that exist purely so a
  backend `Level.id` exists for progress/leaderboard mapping.

**Conclusion:** backend level seeds do **not** drive frontend gameplay levels.
Backend level data is used only for leaderboard/progress id↔number mapping, not
for gameplay level content. Local assets and backend seeds are effectively
independent for gameplay.

This phase adds a **new capability** on top of that: let the backend serve
**dynamic/additional** playable levels the frontend can download and play, while
**keeping every existing offline local level intact**. This is additive, not a
replacement of the local-first model.

---

## High-Level Goal

Enable the backend to serve dynamic/additional levels (real, playable
`definitionJson`, 2D and 3D) that the frontend can download and merge into its
level list, while the existing local levels remain the offline source of truth
and continue to work with the backend unreachable.

Design principles (non-negotiable):
- **Offline-first.** Local bundled levels are always available and always load
  first. Remote fetch is best-effort and non-blocking, exactly like the existing
  sync/leaderboard behavior.
- **Additive.** Remote levels *add* new content (new level numbers) or, at most,
  override by explicit rule; they never remove or break local levels.
- **Local wins on conflict.** If a remote level shares a number with a local
  level, the local definition is used unless a later sub-phase deliberately
  specifies an override policy.
- **2D vs 3D separation preserved.** The existing 2D/3D split and mode-aware
  unlock logic (Phase 24.x) must keep working; remote levels declare their mode.
- **No changes to auth, sync, leaderboard, or existing API contracts** beyond
  what the new feature strictly requires.

---

## Sub-Phase Breakdown

This is a large task delivered as independent, safe slices. Each sub-phase has
its own prompt file in `harness/phases/` and must be completed, validated, and
handed off before the next begins.

- **34.1 — Backend level contract & storage design (2D/3D).**
  `harness/phases/phase_34_1_backend_level_contract.md`
  Confirm/adjust how the backend distinguishes 2D vs 3D levels and exposes real
  playable `definitionJson`, without touching existing 1–15 real rows or the
  16–30 placeholder-mapping story. Design-and-schema slice only.

- **34.2 — Backend seeding/authoring for additional real levels.**
  `harness/phases/phase_34_2_backend_level_seeding.md`
  A mechanism (seed script / admin flow reusing existing CRUD) to store *real*
  playable definitions for **additional** level numbers beyond the local set,
  keeping local levels and existing placeholder rows intact.

- **34.3 — Frontend remote level-definition fetch abstraction.**
  `harness/phases/phase_34_3_frontend_remote_level_fetch.md`
  A read-only `RemoteLevelDefinitionRepository` + DTO mapping backend
  `LevelEntity` → the frontend's existing `ManualLevelDto` shape (incl. `z`).
  No merge, no gameplay wiring yet.

- **34.4 — Frontend offline-first merge strategy.**
  `harness/phases/phase_34_4_frontend_offline_first_merge.md`
  A level source that loads local assets first, merges remote levels (append new
  numbers; local wins on conflict), caches remote definitions for offline replay,
  and degrades to local-only when the backend is unreachable.

- **34.5 — Validation, integration & testing.**
  `harness/phases/phase_34_5_validation_and_testing.md`
  End-to-end tests: fallback when backend down, merge correctness, 2D/3D routing,
  no regression to existing local play, sync, or leaderboard.

Do the slices in order. Do **not** bundle them.

---

## Task (Sub-Phase 34.1 kickoff)

This overview file authorizes starting **34.1 only**. Follow
`phase_34_1_backend_level_contract.md`. Do not begin 34.2+ in the same pass.

---

## Constraints

- Do not modify `backend-poc-arrow` except where a sub-phase (34.1/34.2)
  explicitly scopes a backend change for this feature. Report before any backend
  change to existing endpoints.
- Do not modify auth, sync, leaderboard, or existing API contracts unless the
  active sub-phase explicitly requires it.
- Do not modify Git remotes.
- Do not commit or push automatically.
- Never work on `main`. Use a feature branch for this work.
- Keep all existing local levels (`manual_levels_2d.json`,
  `manual_levels_3d.json`) byte-intact unless a sub-phase explicitly regenerates
  them.

---

## Validation

Run these after each sub-phase's implementation. All must pass.

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only   # only if level files were touched
```

Backend sub-phases additionally:

```bash
# from backend-poc-arrow
npm run lint
npm test
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
