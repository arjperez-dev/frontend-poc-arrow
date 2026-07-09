# PHASE 21.1 — Main Menu Bottom Navigation & Login Progress Sync

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to both tasks.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask
   clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Context

Phase 21 (backend progress reset) is implemented but **not yet committed** — its
changes are live in the working tree. Phase 21.1 is an extension and will be
committed together with Phase 21 (single PR) or separately, at the Technical
Lead's discretion. For now, everything stays in the working tree.

**Stay on branch `feat/phase-21-backend-progress-reset`.** Do **not** create a
new branch. Do **not** commit.

### Current state (audited)

- **Main menu** (`lib/features/home/presentation/home_screen.dart`) was
  redesigned in Phase 20 with the "Nodus" wordmark (`localizations.appTitle`), a
  subtitle, a `CustomPainter` animated background (`_MenuBackgroundPainter`), a
  de-emphasized backend-URL debug row (`_DebugRow`), and only **two**
  vertically-stacked `_MenuButton`s: **Play** → `AppRoutes.levels` and
  **Settings** → `AppRoutes.settings`.
- **Routes** (`lib/core/routing/app_routes.dart`) already define `levels`,
  `settings`, `leaderboard` (takes an optional `int?` level number argument via
  `_readLevelNumber`), `auth`, and `game`. All are wired in `onGenerateRoute`.
- **Leaderboard** (`lib/features/leaderboard/...`) exists with its own
  dependencies factory, repository, use cases, and screen. `LeaderboardScreen`
  accepts an optional `levelNumber`.
- **Auth** (`lib/features/auth/...`): `AuthScreenController.submit()` performs
  login/register via `LoginUseCase` / `RegisterUseCase`, then sets status
  `success`; `AuthScreen` reacts by `Navigator.pop(true)`. **No progress sync is
  triggered after login.**
- **Progress sync** (`lib/features/progress/application/sync_progress_use_case.dart`):
  `SyncProgressUseCase.call()` reads local progress, fetches remote via
  `RemoteProgressRepository.getMyProgress()`, merges with `MergeProgressUseCase`
  (higher score wins, fewer moves breaks ties), saves merged locally, then
  pushes merged results back to remote. It is currently invoked **only** from
  `SettingsScreen` (manual "Sync progress" button), constructed via
  `LocalProgressDependencies.createSyncProgressUseCase()`.
- **DI factories**: `LocalProgressDependencies` (progress), `AuthDependencies`
  (auth), `LeaderboardDependencies` (leaderboard) are the static factory
  classes. Screens/controllers build use cases through these — they never touch
  `http.Client` or `SharedPreferences` directly.

---

## Task A — Login Progress Sync

**Problem:** progress is not synced for the user who just logged in. If user A
played locally and unlocked levels, then user B logs in on the same device, user
B sees user A's local progress. After a successful login, the app must fetch and
reconcile the **logged-in user's** remote progress into local state.

1. Audit the login flow. Identify the correct seam to trigger post-login sync —
   the recommended seam is `AuthScreenController` (inject an optional sync
   callback / `SyncProgressUseCase`, invoked after `AuthScreenStatus.success`),
   mirroring how `SettingsScreen` already injects
   `LocalProgressDependencies.createSyncProgressUseCase().call`. Do **not** make
   the controller call `http.Client` / `SharedPreferences` directly.
2. After a successful login (and register, if a fresh remote profile applies),
   trigger progress sync so the newly logged-in user's remote progress is
   fetched and merged into local state via the existing
   `SyncProgressUseCase` / `MergeProgressUseCase` policy.
3. **Resolve the user-A/user-B identity tension explicitly.** The existing merge
   policy is additive (local ∪ remote, best-wins). A naive merge would leak
   user A's local unlocks into user B's account. Decide and implement the
   correct behavior:
   - Preferred: track the last-synced user id locally; if the user logging in
     **differs** from the last-synced user, clear local progress **before**
     syncing so user B starts from their own remote progress (or level 1 if
     none), rather than inheriting user A's unlocks.
   - If the user was previously **logged out / anonymous** and playing locally,
     merge local progress into the new user's remote progress using the existing
     policy (this is the intended "carry my guest progress into my account" path).
   - If **no remote progress** exists for the new user, keep local progress as
     the fallback only when it belongs to that same user or an anonymous session.
4. Ensure the level selection screen reflects the correct user's progress after
   login (the sync must complete / persist before navigation returns to levels).
5. Handle sync failure gracefully (backend offline): login still succeeds; do
   not block or crash. Surface a non-fatal message if appropriate.

**If Task A requires ANY backend change (new/changed endpoint, response shape,
or auth behavior): STOP and report the required contract first.** Do **not**
modify `backend-poc-arrow` without explicit Technical Lead approval and a
dedicated backend branch. The expectation is that Task A is achievable entirely
in the frontend using the existing `GET /progress/me` + sync/merge machinery.

---

## Task B — Main Menu Bottom Navigation

Redesign `home_screen.dart` to a bottom-oriented layout with **4** items,
rendered as an icon + label button row (or bottom navigation bar) anchored at
the bottom of the screen:

1. **Levels** (Play) → `Navigator.pushNamed(AppRoutes.levels)`.
2. **Leaderboard** → `Navigator.pushNamed(AppRoutes.leaderboard)` (existing
   route; pass no level argument for the global board).
3. **Settings** → `Navigator.pushNamed(AppRoutes.settings)`.
4. **Game Mode** (Type) → placeholder, `onPressed: null` (visibly disabled).
   Reserved for a future 3D game-mode phase. Do not wire any navigation.

Requirements:
- The **"Nodus"** wordmark (`localizations.appTitle`), subtitle, and the
  `_MenuBackgroundPainter` animated background from Phase 20 must remain visible
  **above** the buttons.
- Keep the backend-URL debug row (`_DebugRow`) de-emphasized, in its Phase 20
  placement.
- Preserve all existing navigation routes and controllers.
- Use existing localization keys where possible (`play`/`settings` already
  exist). Add new keys **only** for the new labels (e.g. `levels`,
  `leaderboard`, `gameMode`) to **both** `app_en.arb` and `app_es.arb`, then
  regenerate localizations (`flutter gen-l10n`).
- Match existing neon theming (`AppTheme` colors, `_MenuButton` styling idiom).

---

## Constraints

- Work in `frontend-poc-arrow/` **only**.
- Do **not** modify `backend-poc-arrow`. If Task A appears to need a backend
  change, STOP and report it for a separate approved backend branch.
- Do not modify auth, sync, or leaderboard **API contracts** unless required for
  Task A and explicitly approved.
- Do not modify game board rendering, arrow shapes/colors, level data, gameplay
  logic, `MovementResolver`, or the audio system.
- Graph-based runtime only — no grid/matrix/tile logic introduced.
- Preserve all existing settings functionality (including Phase 21's local and
  remote reset buttons).
- Screens/controllers must **not** directly call `http.Client` or
  `SharedPreferences`; go through repository / use-case / DI-factory layers.
- Do not modify Git remotes. Do not regenerate
  `assets/levels/manual_levels.json`.
- **Stay on branch `feat/phase-21-backend-progress-reset`.** Do not switch or
  create branches.
- Do not commit or push. Stage only if ≥ 95% confident. Await Technical Lead
  approval before any commit.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze                          # 0 issues
flutter test                             # all existing tests pass (124+)
node tool/gen_levels.js --validate-only  # passes (do not regenerate levels)
```

Manual checks:
- Main menu shows 4 bottom items (Levels, Leaderboard, Settings, Game Mode) with
  icons + labels; "Nodus" wordmark and animated background remain above.
- "Game Mode" is visibly disabled and does nothing when tapped.
- Levels / Leaderboard / Settings each navigate to their existing screens.
- Log in as user B on a device holding user A's local progress: level selection
  reflects user B's remote progress, **not** user A's unlocked levels.
- Log in from an anonymous local session with progress: local progress merges
  into the account per the existing best-wins policy.
- Backend offline during login: login still completes; no crash.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using
   `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md` — mark **Phase 21.1 as COMPLETE**.
3. Update `harness/metrics/improvement_log.md`.

Report:
- List of files changed / created.
- Any backend changes required (if any) — these are **deferred** to a separate
  approved backend branch and must not be implemented in `backend-poc-arrow`
  during this phase.
- Confirmation that `flutter analyze` (0 issues), `flutter test` (124+), and
  `node tool/gen_levels.js --validate-only` all pass.

---

Do not be verbose. Be direct.
