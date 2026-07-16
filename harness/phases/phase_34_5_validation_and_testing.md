# PHASE 34.5 — Validation, Integration & Testing

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/phases/phase_34_backend_driven_levels.md`
- `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md`
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

34.1–34.4 delivered: backend contract + seeding for additional real levels, a
frontend remote-definition fetch abstraction, and an offline-first merged level
source (feature-flagged) with caching.

## Goal

Prove the whole feature end-to-end and prove it does not regress the existing
local-first game, sync, or leaderboard. Then enable the feature by default if all
checks pass.

## Task

1. Add integration-level tests exercising the full path: backend serves an extra
   2D and an extra 3D level → frontend fetches, merges, and both are selectable
   and playable under the real resolver.
2. Regression tests / assertions:
   - Backend unreachable ⇒ local levels 1–25 all load and play; no crash.
   - Local levels remain byte/semantically unchanged; existing level tests pass.
   - Sync and leaderboard behavior unchanged (id↔number mapping intact).
   - 2D/3D mode-aware unlock still correct with merged remote levels.
3. If a manual harness check is warranted, document steps in the handoff
   (backend up: download + play a remote 2D and 3D level; toggle backend off:
   confirm cached remote levels still play and local play is intact).
4. Flip the feature flag to enabled-by-default **only** if every automated check
   passes; otherwise leave dark and document what blocks it.
5. Update `docs/LEVEL_AUTHORING.md` with a short "remote/dynamic levels" section
   describing how new backend levels reach players.

## Constraints

- No new gameplay rules; this slice is validation, wiring confirmation, and docs.
- Do not modify auth, sync, or leaderboard logic.
- Do not modify Git remotes. Do not commit or push automatically. Never work on `main`.

---

## Validation

```bash
flutter analyze
flutter test
node tool/gen_levels.js --validate-only   # only if any local level file was touched (it should not be)
```

Backend, if touched:

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
