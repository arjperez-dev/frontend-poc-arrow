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

- `assets/levels/manual_levels_2d.json` (levels 1–20) and `assets/levels/manual_levels_3d.json` (levels 21–30) are the **authoritative hand-editable sources** (Phase 24.1 split the former single `manual_levels.json`; internal numbers stayed globally unique, no renumber). Do not run `node tool/gen_levels.js --generate-2d`, `--generate-3d`, or `--generate` unless regeneration is explicitly intended by the task.
- `--validate-only` is always safe and reads without writing.
- **Level 2 test contract**: name='Level 2', arrow count ≥ 10. Do not change level 2's name or arrow count below the floor without updating `test/features/game/infrastructure/manual_levels_test.dart`.
- **30 levels total** (1–15 random rectangle boards, 16–20 figure silhouettes: heart/diamond/club/spade/crown, 21–30 multi-layer 3D levels: 23 pyramid / 24 diamond / 25 hourglass / 26 cross / 27 starburst / 28 cat / 29 helix / 30 hollow pyramid). `AppConfig.manualLevelCount` is the single source of truth for the count — do not hardcode a level count elsewhere. See `docs/LEVEL_AUTHORING.md` §15 (figure-level model) and §16 (3D-level model).
- **No single-node arrows** (Phase 22.1): every arrow — planar or vertical — must occupy ≥ 1 edge (≥ 2 nodes). Vertical arrows always span a z-edge between two layers. Enforced by `gen_levels.js` `structureErrors` and the Dart asset test `should_have_no_single_node_arrows`; the domain validator stays permissive (unit fixtures use single-node arrows).
- 3D levels use `generationType: '3d'` and real-gap semantics for the interior-gap check (empty space past a smaller tier's silhouette is legitimate; only a gap hiding a node further along the sweep is a defect) — mirrored in JS (`hasRealInteriorGapExit3D`) and the Dart test.

## 3D Board (Phase 22)

- Multi-layer levels (`boardGraph.isMultiLayer`) render via `Graph3DBoard` (rotatable perspective camera); 2D levels keep the flat `GraphBoard`. The selection point is the single conditional in `game_screen.dart` — do not modify the 2D board stack for 3D concerns.
- `Graph3DProjector` is the single source of truth for 3D screen positions: the painter draws through it and `Graph3DHitTester` hit-tests through the same instance/parameters — never compute a 3D screen position by another path or taps will disagree with pixels.
- `MovementResolver` is dimension-agnostic (coordinate sweep). Do not add z-special-casing to it; extend via `MoveDirection` implementations instead (Open/Closed — `Direction` stays planar-only, dimension-aware code accepts `MoveDirection`).

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

## Challenges (Phase 26)

- Challenge results are FULLY SEPARATE from campaign progress: a challenge
  victory saves to `challenges.bestScores` (SharedPreferences) and must
  never call `SaveLevelCompletionUseCase`, remote sync, or the leaderboard.
  The separation is asserted by a dedicated test — keep it green.
- Challenge rules (move budget, perfect-run fail, clock expiry) live in the
  application layer (`MoveArrowUseCase` / `GameSessionService.tickClock`).
  The controller's Timer only calls `tickClock`; do not put rules in it.
- Scoring for challenges goes through `scoreStrategyForChallenge` — add new
  challenge types by adding a `ScoreStrategy` implementation and a factory
  arm, never by branching inside score computation.
- Challenge limits are CALCULATED (`ChallengeContext.forLevel`): time =
  max(30s, arrows × 5/4/3s − 20s by tier), moves = arrows + 5/3/2 slack by tier.
  The `timeLimit`/`maxMoves` level metadata remain dormant — do not read
  them for gameplay without updating this note.
- Lives (hearts AND the six-collision game-over) are campaign-only. In
  challenge sessions `MoveArrowUseCase` skips the lives check entirely —
  a challenge fails only via its own rule. Do not re-couple them.

## Git

- Never work on `main`.
- Never commit or push automatically. Manual audit is required before every commit.
- Never force-push.

## Gameplay Model

- No matrix/grid/tile runtime model may be introduced.
- Arrow shapes are arbitrary paths (defined by `occupiedEdges`). No fixed templates.
- Whole-arrow collision must remain in the resolver (`MovementResolver`), not in presentation.

---

*Last updated: 2026-07-12 (Phase 27 — no new constraints; corrected the stale level count 25→30 and the 3D file range 21–25→21–30, which Phase 25 shipped but did not sync into this file. Note for future restyles: the lavender/violet palette trial was rejected by the user — the app keeps its mint/neon identity.)*
