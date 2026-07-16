# PHASE 34.4 — Frontend Offline-First Merge Strategy

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

- `LocalLevelDataSource.loadManualLevels()` returns local `ManualLevelDto`s
  (2D 1–20 then 3D 21–25), which feed the rest of the level pipeline.
- 34.3 provides `RemoteLevelDefinitionRepository.fetchRemoteLevels()` returning
  `ManualLevelDto`s from the backend, read-only and best-effort.
- 2D/3D separation and mode-aware unlock (Phase 24.x) must keep working.

## Goal

Introduce an offline-first merged level source: local levels always load and are
authoritative; remote levels are appended (new numbers) and cached for offline
replay; the backend being unreachable changes nothing about local play.

## Task

1. Add a level source (e.g. `MergedLevelDataSource`) that:
   - loads local levels first (always),
   - attempts `fetchRemoteLevels()` best-effort (non-blocking; failure ⇒ ignore),
   - merges: **append** remote levels whose `number` is not present locally;
     on number conflict, **local wins** (do not override local). Preserve 2D/3D
     grouping/order expected downstream.
2. Cache the last successfully fetched remote levels (e.g. a
   `SharedPreferences`-backed adapter in infrastructure) so previously downloaded
   remote levels remain playable offline. On fetch failure, fall back to cache;
   if no cache, local-only.
3. Wire the merged source into the level-loading path **behind a feature flag /
   config** (default preserving current behavior unless enabled), so this can
   ship dark. Confirm mode-aware unlock still routes 2D vs 3D correctly using the
   34.1 `metadata.mode`.
4. Ensure sync + leaderboard remain unchanged: they still resolve backend
   `Level.id` via the existing `GET /levels` number→id map; remote-playable
   levels that also have a backend row simply map naturally.
5. Tests: append-new-numbers, local-wins-on-conflict, backend-down ⇒ local-only,
   cache-hit ⇒ remote levels available offline, 2D/3D routing preserved.

## Constraints

- Local levels remain the offline source of truth; never delete/replace them.
- Remote merge is best-effort and non-blocking; a failure must never break level
  selection, gameplay, progress, unlocking, settings, or victory.
- Do not modify auth, sync, leaderboard, or `ApiRemoteLevelRepository` logic.
- `SharedPreferences` access stays in infrastructure adapters only.
- Do not modify Git remotes. Do not commit or push automatically. Never work on `main`.

---

## Validation

```bash
flutter analyze
flutter test
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
