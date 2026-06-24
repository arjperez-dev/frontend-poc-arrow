---
name: current_constraints
type: context
---

# Current Constraints

Check every item on this list before starting any phase. Update this file when constraints change (add a note explaining what changed and why).

---

## Backend

- **Do not modify `backend-poc-arrow` or any backend code.** The frontend is the only scope.
- **Do not modify Git remotes.** Remote URLs are fixed.
- Backend integration is **additive only**. Existing local gameplay must never depend on the backend being available.

## Frontend Code

- **Do not modify auth, sync, leaderboard, or API code** unless the task explicitly requires it.
- Screens and controllers must not call `http.Client` static helpers or `SharedPreferences` directly — use infrastructure adapters only.
- Domain layer must remain pure Dart (no Flutter, HTTP, or storage imports).

## Levels

- `assets/levels/manual_levels.json` is the **authoritative hand-editable source**. Do not run `node tool/gen_levels.js --generate` (levels 1–15) or `--generate-figures` (levels 16–20) unless regeneration is explicitly intended by the task.
- `--validate-only` is always safe and reads without writing.
- **Level 2 test contract**: name='Level 2', arrow count ≥ 10. Do not change level 2's name or arrow count below the floor without updating `test/features/game/infrastructure/manual_levels_test.dart`.
- **20 levels total** (1–15 random rectangle boards, 16–20 figure silhouettes: heart/diamond/club/spade/crown). `AppConfig.manualLevelCount` is the single source of truth for the count — do not hardcode `15` or `20` elsewhere. See `docs/LEVEL_AUTHORING.md` §15 for the figure-level generation model (why `hasInteriorGapExit` doesn't apply to them, why solvability — not density — is the binding constraint when tuning a shape).

## Audio (Phase 15)

- `AudioManager` (`lib/features/audio/infrastructure/audio_manager.dart`) is an app-lifetime singleton. Do not recreate `GameAudioController`/`BackgroundMusicController`/the underlying `AudioPlayer`s per screen — that recreate-per-screen pattern (the deleted `AudioDependencies`) is what caused the original crash/leak. New screens must call `AudioManager.instance`, not build their own ports.
- `startMusic()`/`stopMusic()` are reference-counted (`_musicClaims`). Any new navigation path that can dispose one `GameScreen` while mounting another (e.g. another `pushReplacement*` use) relies on this counting to avoid the old screen's stop killing the new screen's music — do not bypass it with a direct `MusicPort.stop()`/`start()` call.
- SFX (`AudioPlayersAudioPort`) uses a pool of 3 `AudioPlayer`s, not one shared instance. Do not collapse it back to a single player — that caused crackling/sped-up playback when events fired close together.
- Music volume (`AudioPlayersMusicPort._musicVolume`) must stay within `0.0–1.0` — the underlying plugin passes it unclamped into native `MediaPlayer.setVolume`; values above 1.0 cause audible clipping. Current value is `0.6` (SFX volume in `AudioPlayersAudioPort._effectsVolume` is `0.25`); the music multiplier is numerically higher than the SFX multiplier even though music should sound quieter, because perceived loudness depends on each asset's mastering level, not just the multiplier — retune both by ear on a real device, don't assume the numbers alone reflect relative loudness.
- All SFX assets in `assets/audio/` (`move.mp3`, `blocked.mp3`, `victory.mp3`, `defeat.mp3`) must stay at the same sample rate (44100 Hz) — a mismatch (`victory.mp3` was previously 48000 Hz) contributed to playback-rate artifacts when assets share a pooled player.
- A Clean-Architecture-compliance audit of audio/storage/network adapter code is **not** a substitute for a real-device behavior check — Phase 14 Task A audited layering only and missed five live runtime defects in the audio adapters. Don't repeat that mistake for other adapter code.
- `AudioManager` extends `WidgetsBindingObserver` (Phase 15.1) to stop music on `AppLifecycleState.paused` and resume it on `resumed`, via a `_musicPausedForBackground` flag kept separate from `_musicClaims`. Do not merge these two pieces of state — claims track screen ownership, the flag tracks OS visibility; conflating them was exactly the kind of bug both fixes exist to prevent.

## Board Rendering / Interaction (Phase 17/18)

- `GraphBoardLayout.step` (px per grid cell) is the single source of truth for scaling board visuals to density. `GraphBoardPainter`'s stroke width and arrowhead length/width, and `GraphBoardHitTester.hitSlop`, all derive from it (each capped at its pre-Phase-17 fixed value, floored so it never disappears). If you add another size-sensitive visual to the board, scale it from `layout.step` the same way — don't reintroduce a fixed pixel constant that silently overlaps on dense boards (hard tier, figure levels 16–20).
- `GraphBoard`'s `AspectRatio` is computed from the level's own node bounding box (`_boardAspectRatio`, clamped `[0.6, 1.6]`), not hardcoded to 1. Don't revert this to a fixed square without checking how it affects figure-level layouts (15, 19, 20 are notably non-square).
- `GraphBoard.onInteractionActiveChanged` + `GameScreen._lockPageScroll` exist specifically to stop the page-level `ListView` from competing with `InteractiveViewer`'s pinch gesture (a Flutter gesture-arena race: the ancestor `Scrollable` can claim the first finger before the second lands). If you restructure `GameScreen`'s layout or `GraphBoard`'s gesture handling, preserve this pointer-count → scroll-lock coupling, or pinch-to-zoom will regress to being hard to start.

## Git

- Never work on `main`.
- Never commit or push automatically. Manual audit is required before every commit.
- Never force-push.

## Gameplay Model

- No matrix/grid/tile runtime model may be introduced.
- Arrow shapes are arbitrary paths (defined by `occupiedEdges`). No fixed templates.
- Whole-arrow collision must remain in the resolver (`MovementResolver`), not in presentation.

---

*Last updated: 2026-06-24 (Phase 17/18 — board rendering polish: cell-size-relative scaling for stroke/arrowhead/hit-slop, non-square board aspect ratio; pinch-to-zoom reliability fix via pointer-count-driven scroll lock)*
