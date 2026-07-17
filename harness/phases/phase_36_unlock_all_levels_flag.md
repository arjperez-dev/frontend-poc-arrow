# PHASE 36 — Unlock-All-Levels Testing Flag

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

Add a compile-time `UNLOCK_ALL_LEVELS` dart-define flag that unlocks every level in the level-selection list for manual testing. OFF by default: when the define is absent, behavior must be byte-for-byte identical to today.

Files to modify:

1. `lib/core/config/app_config.dart`
   - Add `static const bool unlockAllLevels = bool.fromEnvironment('UNLOCK_ALL_LEVELS');`
   - Document it as a testing-only flag, mirroring the existing `enableRemoteLevels` comment style.

2. `lib/features/levels/presentation/level_selection_screen.dart`
   - At the single unlock gate (~line 154), bypass the lock:
     `final isUnlocked = AppConfig.unlockAllLevels || progress.isUnlockedAfter(...);`
   - This is the ONLY gate change. Do not touch `LocalProgress`, `LevelProgression`, `IsLevelUnlockedUseCase`, or `SaveLevelCompletionUseCase`.

3. `README.md`
   - Document the flag next to the existing `ENABLE_REMOTE_LEVELS` section: off by default, testing only, does not alter saved progress.
   - Add both run commands:
     ```powershell
     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=UNLOCK_ALL_LEVELS=true
     flutter run --dart-define=ENABLE_REMOTE_LEVELS=true --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=UNLOCK_ALL_LEVELS=true
     ```

Explicitly out of scope:
- Do NOT skip or alter completion-save logic. Completing a level under the flag must still save progress normally — the flag is a display/entry gate only, so a tester's real progress is preserved and the app behaves identically once the flag is removed.
- Do NOT touch the leaderboard picker (it has no unlock gate).
- Do NOT touch the game screen (it has no unlock guard; entry is already gated solely by the selection screen).

---

## Constraints

- Do not modify `backend-poc-arrow` or any backend code.
- Do not modify auth, sync, leaderboard, or API code.
- Do not modify Git remotes.
- Do not commit or push automatically.
- Do not work on `main` — branch from the current working branch.
- The domain layer must remain pure Dart: `AppConfig` must NOT be imported into `lib/features/progress/domain/`. The flag is read in presentation only.
- The flag must be OFF by default; absent define ⇒ zero behavior change.

---

## Validation

Run these after implementation. All must pass.

```bash
flutter analyze
flutter test
```

`flutter test` runs with the flag absent, so `level_selection_unlock_test.dart` and all other unlock assertions must pass unchanged. Do not modify any test to accommodate the flag.

Manual check (both run commands from the Task section):
1. Fresh install, flag ON: every card in 2D and in 3D shows a chevron and opens.
2. Complete a level with the flag ON, then relaunch WITHOUT the flag: only the normally-earned levels are unlocked, and the completed level's progress and best score are intact.

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
