# PHASE 21 — Backend Progress Reset

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
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

Phase 20 is complete and merged to `main`. The game is feature-complete and
polished: 20 levels, gameplay, collision resolution, audio, neon rendering,
level selection, the redesigned main menu, settings, auth, sync, and
leaderboard.

The `SettingsScreen` currently exposes a **"Reset local progress"** button that
clears only the local `SharedPreferences` progress store.

**The problem:** when the backend is running and the user resets local
progress, returning to the level selection screen re-syncs remote progress from
the backend, restoring previously unlocked levels. Local reset alone is
therefore ineffective for any signed-in user with a live backend.

The user needs a way to reset progress stored **in the backend**, not just
locally.

Relevant surfaces (audit and confirm exact paths before editing):
- Presentation: `SettingsScreen` + `SettingsScreenController`.
- Domain: existing progress use cases / progress domain model.
- Infrastructure: the remote progress repository, `ApiClient` interface, and
  `HttpApiClient` implementation.
- Backend: `backend-poc-arrow` progress routes + auth middleware.
- Localization: `lib/core/localization/l10n/app_en.arb` and `app_es.arb`.

**Stay on branch `feat/phase-21-backend-progress-reset`** (already created and
checked out from latest `main`). Do **not** switch branches.

---

## Task

### 1 — Add the "Reset remote progress" button
- Add a **"Reset remote progress"** button to `SettingsScreen`, adjacent to the
  existing "Reset local progress" button.
- Visual styling must match the existing settings UI (cards, padding,
  typography). Do not restyle the existing controls.

### 2 — Implement the full Clean Architecture flow
- **Domain:** add a `ResetRemoteProgressUseCase` (or extend the existing
  progress domain model if that is the more appropriate fit).
- **Application:** the use case calls a remote progress repository method to
  reset backend progress.
- **Infrastructure:** add `resetRemoteProgress()` to the remote progress
  repository. It must call the backend via `ApiClient` / `HttpApiClient`.
- **Presentation:** `SettingsScreenController` exposes the reset action;
  `SettingsScreen` renders the button and handles loading / error states.

### 3 — Backend endpoint audit and implementation
- Audit `backend-poc-arrow` to determine whether an endpoint already exists for
  deleting/resetting user progress (e.g. `DELETE /progress`,
  `POST /progress/reset`).
- **If it exists:** use it directly.
- **If it does not exist:** this is a blocking API contract issue. Implement it
  in `backend-poc-arrow`:
  - Add an authenticated endpoint that clears the user's progress records for
    all levels.
  - Require a valid auth token (same middleware as existing progress endpoints).
  - Return `204 No Content` or `200 OK` on success.
  - Return `401` if unauthenticated.
- Update the frontend `ApiClient` interface and `HttpApiClient` implementation
  to include the new call.

### 4 — Keep both stores in sync
- After a successful remote reset, **also clear local progress automatically**
  so both stores stay in sync.
- The user must see **only level 1 unlocked** once the operation completes.

### 5 — Error handling
- **Backend offline:** show a snackbar/toast "Backend unavailable. Local
  progress reset only." and still clear local progress.
- **User not authenticated:** show "Log in to reset remote progress." and
  disable or hide the button.
- **Generic failure:** show an error message; do **not** clear local progress
  unless the remote reset succeeded.

### 6 — Localization
- If new keys are needed (button labels, snackbar messages), add them to
  **both** ARB files (`app_en.arb` and `app_es.arb`).

---

## Constraints

- Work in `frontend-poc-arrow/` and `backend-poc-arrow/` **only as needed** for
  the progress-reset API contract.
- Do not modify auth, sync, leaderboard, or API code unrelated to progress
  reset.
- Do not modify game board rendering, arrow shapes/colors, level data, gameplay
  logic, `MovementResolver`, or the audio system.
- Graph-based runtime only — no grid/matrix/tile logic introduced.
- Preserve all existing settings functionality — the local reset button must
  remain working.
- Screens/controllers must **not** directly call `http.Client` or
  `SharedPreferences`; go through the repository/use-case layers.
- Do not modify Git remotes. Do not regenerate
  `assets/levels/manual_levels.json`.
- **Stay on branch `feat/phase-21-backend-progress-reset`.** Do not switch
  branches.
- Do not commit or push. Stage only if ≥ 95% confident. Await Technical Lead
  approval before any commit.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze                          # 0 issues
flutter test                             # all 124 existing tests pass
node tool/gen_levels.js --validate-only  # passes (do not regenerate levels)
```

Manual checks:
- "Reset remote progress" button renders adjacent to "Reset local progress",
  matching the existing settings styling.
- With backend live + signed in: reset clears remote **and** local progress;
  returning to level selection shows only level 1 unlocked (no re-sync
  restores levels).
- Backend offline: snackbar "Backend unavailable. Local progress reset only.";
  local progress still cleared.
- Not authenticated: button disabled/hidden with "Log in to reset remote
  progress."
- Generic failure: error shown; local progress untouched.
- Local reset button still works as before.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md` — mark **Phase 21 as COMPLETE**.
3. Update `harness/metrics/improvement_log.md`.

Report:
- List of files changed / created in **both** repos.
- The backend endpoint path and method used (existing or newly implemented).
- Confirmation that `flutter analyze` (0 issues), `flutter test` (124 tests),
  and `node tool/gen_levels.js --validate-only` all pass.

---

Do not be verbose. Be direct.
