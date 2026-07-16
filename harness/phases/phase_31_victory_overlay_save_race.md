# PHASE 31 — Close the Victory-Overlay Save Race (Back to Levels / Next Level)

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

## Task

### Background

Phase 23 wrapped the game screen in a `PopScope(canPop: false)` whose
`onPopInvokedWithResult` awaits `controller.completionSettled` before calling
`Navigator.pop()`. This closed the race between the async local progress save
and the route pop for the **Android system back button** and the **app-bar back
arrow** — both of which route through the same pop and therefore through
`PopScope`. That part works correctly and must not regress.

The gap: the two **in-app victory-overlay buttons** navigate with methods that
are *not* pops, so they bypass `PopScope` entirely and never await
`completionSettled`:

- **"Back to Levels"** → `_backToLevels()` calls
  `Navigator.pushNamedAndRemoveUntil(...)`.
- **"Next Level"** → `_openNextLevel()` calls
  `Navigator.pushReplacementNamed(...)`.

On these two paths the level-selection screen can read progress before the
`SharedPreferences` write lands, showing stale unlock/best-score state on the
**first** return. The write itself is never lost (it completes in the
background), but the ordering guarantee Phase 23 established is missing here.
This is the exact first-return staleness Phase 23 aimed to eliminate.

### Files to modify

- `lib/features/game/presentation/game_screen.dart`
  - `_backToLevels()`: make it `async`; `await controller.completionSettled`
    before `Navigator.pushNamedAndRemoveUntil(...)`. Capture the `Navigator`
    (and any other `BuildContext`-derived objects) **before** the await, and
    re-check `if (!mounted) return;` **after** the await, mirroring the existing
    `PopScope.onPopInvokedWithResult` guard pattern.
  - `_openNextLevel()`: same treatment before `Navigator.pushReplacementNamed(...)`.
    Preserve the current next-level number computation (progression order with
    internal-number fallback) exactly.
  - When no victory occurred, `completionSettled` returns an
    already-resolved future — navigation must proceed with no perceptible stall.
  - Do **not** change remote-sync behavior: `_notifyRemoteCompletionBestEffort`
    stays `unawaited` / best-effort. `completionSettled` continues to gate on
    the local save only.
  - The `VoidCallback` wiring for `onBackToLevels` / `onNextLevel` may be kept
    (fire-and-forget of the async handler is acceptable) — the button callback
    signatures in `_GameReadyView` / `_VictoryOverlay` / `_GameOverOverlay` do
    not need to change.

### Regression tests to add

- `test/features/game/presentation/playable_game_ui_test.dart` (or the existing
  game-screen widget test file):
  - **Back to Levels awaits the save**: inject a `saveLevelCompletion` fake that
    completes only after an artificial delay (e.g. a `Completer` the test
    controls). Drive a victory, tap the victory-overlay "Back to Levels" button,
    and assert navigation does **not** fire until the save future completes;
    then complete it and assert navigation happens.
  - **Next Level awaits the save**: same construction for the "Next Level"
    button — prove the `pushReplacementNamed` navigation is deferred until the
    local save settles.
  - Use the existing fake-based harness (injectable `saveLevelCompletion`,
    `enableBoardAnimations: false`) already used by the game-screen tests. Assert
    ordering via the controlled `Completer`, not wall-clock timing.

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code unless this task explicitly requires it.
- Do not modify Git remotes.
- Do not commit or push automatically.
- Do not change the existing `PopScope` behavior for the system/app-bar back path.
- Do not change remote-sync semantics: it stays unawaited and best-effort.
- Do not change the `completionSettled` contract (local save only; no-op future when no victory).
- Preserve the existing `!mounted` guard-after-await pattern on every navigation path.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze
flutter test
```

`node tool/gen_levels.js --validate-only` is not applicable (no level files touched).

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report all changes. Do **not** commit or push.

---

Do not be verbose. Be direct.
