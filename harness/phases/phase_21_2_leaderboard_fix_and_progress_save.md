# PHASE 21.2 — Leaderboard Display Fix & Progress Save on Completion

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Git Context

- Current branch: `feat/phase-21-backend-progress-reset` — **stay here.**
- Phases 21 and 21.1 are implemented but **not committed**; their changes are in the working tree. Phase 21.2 extends the same working tree.
- Do **not** create a new branch. Do **not** commit or push. Do **not** stage unless ≥ 95% confident.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task (list below).
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Task A — Leaderboard Not Displaying

**Symptom:** Tapping "Leaderboard" from the main menu opens the screen but shows no entries (only the "leaderboard unavailable" empty state).

**Root cause (already located during phase authoring — verify during your audit):**
`HomeScreen` pushes `AppRoutes.leaderboard` with **no argument**, so `LeaderboardScreen.levelNumber` is `null`. `LeaderboardScreen._loadEntries()` short-circuits and returns an empty list whenever `levelNumber == null`:

```dart
// leaderboard_screen.dart
Future<List<LeaderboardEntry>> _loadEntries() async {
  final levelNumber = widget.levelNumber;
  if (levelNumber == null) {
    return const <LeaderboardEntry>[];   // <-- always empty from main menu
  }
  ...
}
```

The backend exposes only `GET /leaderboard/:levelId` (see `ApiLeaderboardRepository.getForLevel`). There is **no global / all-levels leaderboard endpoint**. A true "global leaderboard" from the main menu would therefore require a backend change.

**Files to audit:**
- `lib/features/home/presentation/home_screen.dart` (the `leaderboard` nav button)
- `lib/features/leaderboard/presentation/leaderboard_screen.dart`
- `lib/features/leaderboard/application/get_leaderboard_use_case.dart`
- `lib/features/leaderboard/application/leaderboard_repository.dart`
- `lib/features/leaderboard/infrastructure/api_leaderboard_repository.dart`
- `lib/features/leaderboard/infrastructure/leaderboard_dependencies.dart`
- `lib/features/leaderboard/domain/leaderboard_entry.dart`
- `lib/features/progress/infrastructure/api_remote_level_repository.dart` (`getLevelIdsByNumber`)
- `lib/core/routing/app_routes.dart`

**Required approach — frontend-only, no backend change:**
Because there is no global endpoint, the main-menu "Leaderboard" entry point must resolve to a concrete level. Implement **one** of the following (pick and justify in your pre-implementation report; a level picker is preferred as it needs no backend and exposes all levels):

- **Option 1 (preferred): Level picker → per-level leaderboard.** From the main menu, navigate to a lightweight level-selection list (reuse existing level listing) whose tap opens `LeaderboardScreen(levelNumber: n)`. Keep the existing per-level leaderboard screen unchanged.
- **Option 2: Default to Level 1.** Main-menu button pushes `AppRoutes.leaderboard` with `arguments: 1`. Simplest, but only ever shows one level's board.

Also handle these correctness points found in the audit:
- Confirm `LeaderboardScreen` still renders correctly for a valid `levelNumber` (fetch fires on init via `_entriesFuture`, `_entryFromJson` parses the `user.displayName` nested shape). Verify a non-empty backend response actually renders — do not assume.
- Ensure the empty-state vs. error-state distinction is preserved (both currently show `leaderboardUnavailable`; leave as-is unless your option requires a change).

**If, and only if, you conclude a backend change is unavoidable to satisfy the requirement:** STOP and report the exact endpoint contract needed (method, path, response shape). Do **not** modify `backend-poc-arrow`. The preferred frontend-only option above should make this unnecessary.

---

## Task B — Progress Save on Level Completion

**Symptom (as reported):** Completing a level and then pressing back (system or app-bar) does not save progress; only "Next Level" saves.

**Root cause (verify during audit — current code may already save on victory):**
`GameScreenController.activateArrow` already calls `unawaited(_saveCompletionOnce(result.session))` when `result.session.status == GameStatus.victory`, and `_saveCompletionOnce` is idempotent via the `_completionSaved` guard. Your audit must confirm whether the reported symptom still reproduces. Two things to verify precisely:

1. **Save fires on victory, not on "Next Level" tap.** Confirm `_saveLevelCompletion` and `_notifyRemoteLevelCompletion` are invoked from the victory transition in `activateArrow` (they appear to be) — and that the "Next Level" button (`_openNextLevel`) does **not** itself perform the save (it only navigates). If the save is in fact only reached via "Next Level" in some path, move it to the victory transition.
2. **Save completes despite immediate pop.** `_saveCompletionOnce` is fire-and-forget (`unawaited`). Because `SaveLevelCompletionUseCase` writes to `SharedPreferences` independent of widget lifecycle, the write should complete even after the screen is disposed. Verify this holds — the controller's `_safeNotify()` already guards against notifying after dispose. Confirm the level-selection screen reflects saved progress on return (local progress read on that screen's load).

**Files to audit:**
- `lib/features/game/presentation/game_screen_controller.dart`
- `lib/features/game/presentation/game_screen.dart` (`_openNextLevel`, `_backToLevels`, `_VictoryOverlay`)
- `lib/features/progress/application/save_level_completion_use_case.dart`
- `lib/features/progress/infrastructure/local_progress_dependencies.dart`
- The level-selection screen and controller (progress read on load)

**Requirements:**
- `SaveLevelCompletionUseCase` must be invoked **exactly once** on `GameStatus.victory`, regardless of how the player subsequently exits (system back, app-bar back, "Back to Levels", or "Next Level"). Preserve the existing `_completionSaved` idempotency guard.
- Remote sync / leaderboard submission (`NotifyRemoteLevelCompletion`) must also fire at completion time (best-effort, already wrapped in try/catch), not deferred to "Next Level".
- **Do not** change "Next Level" behavior — it must still navigate to the next level as before.
- **Do not** trigger the save more than once from repeated taps on victory-screen elements.
- If the audit shows the current code already satisfies all of the above, the deliverable for Task B is **regression test coverage** proving save-on-victory and single-invocation, plus a short written confirmation — not speculative code churn.

---

## Constraints

- Work only in `frontend-poc-arrow/`.
- Do **not** modify `backend-poc-arrow` or any backend/API contract. If Task A requires it, STOP and report.
- Do not modify game board rendering, arrow shapes/colors, level data, gameplay logic, `MovementResolver`, or the audio system.
- Do not modify auth, sync, or API contracts unrelated to these two fixes.
- Do not regenerate `assets/levels/manual_levels.json`.
- Preserve all existing settings functionality and the bottom navigation.
- Screens/controllers must not call `http.Client` or `SharedPreferences` directly (use existing use-case/DI factories).
- Graph-based runtime only — no grid/matrix/tile logic.
- Stay on branch `feat/phase-21-backend-progress-reset`. Do not commit or push. Stage only if ≥ 95% confident.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze          # must report 0 issues
flutter test             # all existing tests (124+) must pass
```

Do not run `gen_levels.js` — no level files are touched.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md` — set Phase 21.2 to COMPLETE.
3. Update `harness/metrics/improvement_log.md`.
4. Report:
   - Files changed / created.
   - Root cause found for each bug (Task A and Task B).
   - Any backend changes required (deferred to a separate backend branch — none should be needed if Option 1 is chosen for Task A).
   - Verification results (`flutter analyze`, `flutter test`).
5. Await Technical Lead approval before any commit.

---

Do not be verbose. Be direct.
