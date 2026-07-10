# PHASE 23 — Bug Fixes & Polish (Save-Race Hardening + Leaderboard Picker Coverage)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Git Context

- Current branch: `feat/phase-23-bug-fixes-and-polish` — **already created and checked out. Stay here.**
- Do **not** switch or create branches after this point.
- Do **not** commit or push automatically. Stage only if ≥ 95% confident.

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task (lists below).
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Background

The Phase 21.2 audit confirmed progress-save-on-victory is architecturally sound and fires independently of the "Next Level" button. It surfaced exactly two follow-up items — one hardening fix and one coverage gap. This phase closes both. **No new features. No gameplay, rendering, level-data, audio, auth, sync, or API changes.**

---

## Task A — Close the Save/Reload Race on Back-Button Exit

**Symptom (theoretical, negligible probability, but fixable):** The completion save is fire-and-forget (`unawaited(_saveCompletionOnce(...))` in `GameScreenController.activateArrow`). It performs a read-modify-write against `SharedPreferences` via `SaveLevelCompletionUseCase` (`getProgress()` → `saveProgress()`). Separately, `LevelSelectionScreen._openLevel` awaits the pushed game route and, on any pop, reloads progress (`_loadScreenData` → `getProgress()`). If the player pops **extremely** fast (system back / app-bar back) the reload's read can win the race against the save's write, so the level-selection screen shows the just-completed level as not-completed **for that one return**. It self-corrects on the next visit; no data is ever lost or corrupted (the reload is read-only, the save still completes).

**Goal:** Guarantee the level-selection screen reflects the completed level on the **first** return, regardless of how fast the player exits.

**Files to audit:**
- `lib/features/game/presentation/game_screen_controller.dart` (`activateArrow`, `_saveCompletionOnce`, `_completionSaved`, `dispose`, `_safeNotify`)
- `lib/features/game/presentation/game_screen.dart` (`_backToLevels`, `_openNextLevel`, dispose, `Scaffold`/`AppBar` — no explicit `leading`, so pop uses the default back button; no `PopScope` currently)
- `lib/features/levels/presentation/level_selection_screen.dart` (`_openLevel`, `_loadScreenData`)
- `lib/features/progress/application/save_level_completion_use_case.dart`

**Required approach (pick one and justify in your pre-implementation report; Option 1 preferred):**

- **Option 1 (preferred): Make the pending save awaitable and await it before the route pops.**
  - In `GameScreenController`, retain the in-flight completion save as a field (e.g. `Future<void>? _pendingCompletionSave`), assigned when `_saveCompletionOnce` starts, and expose a read-only accessor (e.g. `Future<void> get completionSettled` that returns the pending future or an already-completed future when there is none). Keep the existing `_completionSaved` idempotency guard and fire-and-forget call site behavior otherwise unchanged.
  - Wrap the `GameScreen` body in a `PopScope` (or equivalent) that, before allowing the pop to complete, awaits `controller.completionSettled`. This covers the app-bar back arrow **and** the Android system back button (both trigger the same pop) as well as the in-app "Back to Levels" and "Next Level" paths. Guard against `!mounted` after the await.
  - Ensure `_openNextLevel` still navigates identically and that awaiting a settled/no-op future adds no perceptible delay when there was no victory.

- **Option 2 (alternative): Await the pending save inside the exit handlers only.** Have `_backToLevels` await the controller's pending save before navigating. Rejected-by-default because it does **not** cover the raw system/app-bar back pop (which bypasses `_backToLevels`); only choose this if your audit shows those pops are already intercepted.

**Requirements:**
- The save must still fire on the `GameStatus.victory` transition (not on any button), fire **exactly once** (preserve `_completionSaved`), and remain non-blocking for gameplay.
- Awaiting the pending save must be a **no-op when no victory occurred** (do not stall normal back-navigation from an in-progress or failed level).
- Do **not** await from within `dispose()` (the controller/future must outlive the widget; `_safeNotify` already guards post-dispose notifications).
- Remote sync / leaderboard notify (`_notifyRemoteCompletionBestEffort`) stays best-effort and **must not** be awaited on the exit path — only the **local** `SaveLevelCompletionUseCase` write needs to settle before reload.

**Test coverage (Task A):**
- Add a widget/controller test proving that after a victory, when the player pops via the app-bar back button, the level-selection screen's post-return progress read observes the completed level (i.e. the local save has settled before the reload runs). Use the existing `_TestManualLevelsApp` harness / injectable `saveLevelCompletion` seams; a fake save that completes on a delayed future is the clean way to force and then assert the ordering.
- Keep the three existing Phase 21.2 regression tests green (`should_save_completion_on_victory_before_next_level_is_tapped`, `should_not_duplicate_completion_save_when_victory_overlay_is_tapped_repeatedly`, `should_persist_completion_save_when_player_backs_out_immediately_after_victory`).

---

## Task B — Widget Test Coverage for `LeaderboardLevelPickerScreen`

**Gap:** `lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart` (added in Phase 21.2) has **no dedicated widget test**. It is only exercised transitively.

**Files to audit:**
- `lib/features/leaderboard/presentation/leaderboard_level_picker_screen.dart` (injectable `loadLevels`, `_levelsFuture`, `GameUiKeys.levelCard(number)`, tap → `Navigator.pushNamed(AppRoutes.leaderboard, arguments: number)`)
- `lib/features/game/presentation/game_ui_keys.dart` (`levelCard`)
- `lib/core/routing/app_routes.dart`
- An existing leaderboard/level-selection widget test for harness/localization setup patterns (e.g. `test/features/game/presentation/playable_game_ui_test.dart` and any existing leaderboard test) to mirror `MaterialApp`/l10n wiring and route observation.

**Required test file:** `test/features/leaderboard/presentation/leaderboard_level_picker_screen_test.dart`

**Requirements (assert real behavior, do not mock the widget under test):**
- Inject `loadLevels` with a small deterministic fake level list. Assert the picker renders one tappable card per level (`GameUiKeys.levelCard(n)`) with the level name/number.
- Assert tapping a level card navigates to `AppRoutes.leaderboard` **with that level's number as the argument** (use a route observer or a fake route table / `onGenerateRoute` capturing `settings.arguments`). This is the core regression the Phase 21.2 fix depends on — an empty/`null` argument was the original leaderboard-empty bug.
- Assert the empty/error branch: when `loadLevels` returns an empty list (and/or throws), the screen shows the `leaderboardUnavailable` message and no cards.
- Assert the loading branch shows a `CircularProgressIndicator` before the future completes (pump without settling).
- Wrap in `MaterialApp` with the app's `localizationsDelegates`/`supportedLocales` so `AppLocalizations.of(context)` resolves.

---

## Constraints

- Work only in `frontend-poc-arrow/`.
- Do **not** modify `backend-poc-arrow`, any backend code, or any API contract.
- Do **not** modify game board rendering, arrow shapes/colors, level data, gameplay logic, `MovementResolver`, or the audio system.
- Do **not** modify auth, sync, or leaderboard **fetch/submit** logic. Task A touches only the save-settle plumbing in the game controller/screen; Task B is test-only plus, if strictly required, non-behavioral test seams.
- Do **not** regenerate `assets/levels/manual_levels.json`.
- Do **not** change "Next Level", "Retry", or leaderboard-submission-on-victory behavior — all three were verified correct in the Phase 21.2 audit and must stay green.
- Screens/controllers must not call `http.Client` or `SharedPreferences` directly (use existing use-case / DI factories).
- Graph-based runtime only — no grid/matrix/tile logic.
- Stay on branch `feat/phase-23-bug-fixes-and-polish`. Do not commit or push. Stage only if ≥ 95% confident.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze          # must report 0 issues
flutter test             # all existing tests (132+) plus the new tests must pass
```

Do not run `gen_levels.js` — no level files are touched.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md` (add a Phase 23 section: root cause recap for each item, files touched, what changed, verification results, and any limitations).
2. Update `harness/context/phase_registry.md` — add Phase 23 and set it to COMPLETE.
3. Update `harness/metrics/improvement_log.md`.
4. Report:
   - Files changed / created.
   - Task A: chosen option and why; confirmation the pending-save await is a no-op when no victory occurred and is not awaited in `dispose()`.
   - Task B: the four assertions covered (render, tap-argument, empty/error, loading).
   - Verification results (`flutter analyze`, `flutter test` counts).
5. Await Technical Lead approval before any commit.

---

Do not be verbose. Be direct.
