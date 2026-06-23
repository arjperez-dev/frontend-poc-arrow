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

- `assets/levels/manual_levels.json` is the **authoritative hand-editable source**. Do not run `node tool/gen_levels.js --generate` unless regeneration is explicitly intended by the task.
- `--validate-only` is always safe and reads without writing.
- **Level 2 test contract**: name='Level 2', arrow count ≥ 10. Do not change level 2's name or arrow count below the floor without updating `test/features/game/infrastructure/manual_levels_test.dart`.

## Audio (Phase 15)

- `AudioManager` (`lib/features/audio/infrastructure/audio_manager.dart`) is an app-lifetime singleton. Do not recreate `GameAudioController`/`BackgroundMusicController`/the underlying `AudioPlayer`s per screen — that recreate-per-screen pattern (the deleted `AudioDependencies`) is what caused the original crash/leak. New screens must call `AudioManager.instance`, not build their own ports.
- `startMusic()`/`stopMusic()` are reference-counted (`_musicClaims`). Any new navigation path that can dispose one `GameScreen` while mounting another (e.g. another `pushReplacement*` use) relies on this counting to avoid the old screen's stop killing the new screen's music — do not bypass it with a direct `MusicPort.stop()`/`start()` call.
- SFX (`AudioPlayersAudioPort`) uses a pool of 3 `AudioPlayer`s, not one shared instance. Do not collapse it back to a single player — that caused crackling/sped-up playback when events fired close together.
- Music volume (`AudioPlayersMusicPort._musicVolume`) must stay within `0.0–1.0` — the underlying plugin passes it unclamped into native `MediaPlayer.setVolume`; values above 1.0 cause audible clipping. Current value is `0.6` (SFX volume in `AudioPlayersAudioPort._effectsVolume` is `0.25`); the music multiplier is numerically higher than the SFX multiplier even though music should sound quieter, because perceived loudness depends on each asset's mastering level, not just the multiplier — retune both by ear on a real device, don't assume the numbers alone reflect relative loudness.
- All SFX assets in `assets/audio/` (`move.mp3`, `blocked.mp3`, `victory.mp3`, `defeat.mp3`) must stay at the same sample rate (44100 Hz) — a mismatch (`victory.mp3` was previously 48000 Hz) contributed to playback-rate artifacts when assets share a pooled player.
- A Clean-Architecture-compliance audit of audio/storage/network adapter code is **not** a substitute for a real-device behavior check — Phase 14 Task A audited layering only and missed five live runtime defects in the audio adapters. Don't repeat that mistake for other adapter code.

## Git

- Never work on `main`.
- Never commit or push automatically. Manual audit is required before every commit.
- Never force-push.

## Gameplay Model

- No matrix/grid/tile runtime model may be introduced.
- Arrow shapes are arbitrary paths (defined by `occupiedEdges`). No fixed templates.
- Whole-arrow collision must remain in the resolver (`MovementResolver`), not in presentation.

---

*Last updated: 2026-06-23 (Phase 15 — audio playback stability: AudioManager singleton, SFX pool, music volume/focus, victory.mp3 sample rate)*
