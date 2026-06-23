# AI Usage

This file documents AI-assisted work for the Flutter frontend repository.

## Entry Template

- Date:
- AI tool/model:
- Role of the tool:
- Task or problem addressed:
- Prompt or faithful paraphrase:
- Result obtained:
- Modifications made by the team:
- Lessons learned:
- Limitations found:
- Approximate percentage of AI-assisted code:
- Critical reflection:

## Initial Planning Entry

- Date: 2026-05-23
- AI tool/model: Codex coding agent
- Role of the tool: Planning support only for the frontend during Phase 1.
- Task or problem addressed: Record the AI usage stub early, while avoiding Flutter app bootstrap or other frontend modifications.
- Prompt or faithful paraphrase: Create only the frontend `AI_USAGE.md` stub during Phase 1; do not bootstrap or modify the frontend app.
- Result obtained: Pending team review.
- Modifications made by the team: Pending.
- Lessons learned: Pending.
- Limitations found: Pending.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: Pending.

## Phase 3 Frontend Bootstrap Entry

- Date: 2026-05-23
- AI tool/model: Codex coding agent
- Role of the tool: Flutter bootstrap implementation support.
- Task or problem addressed: Initialize the Flutter frontend foundation with Clean Architecture folders, routing, localization, theme, API configuration, placeholder screens, tests, CI, README, and handoff documentation.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; preserve `AI_USAGE.md`; add explicit localization with English and Spanish ARB files; keep `DottedBoardPlaceholder` presentation-only; do not implement game engine, graph domain classes, manual levels, random levels, or backend integration.
- Result obtained: Pending team review after Phase 3 verification.
- Modifications made by the team: Pending.
- Lessons learned: Phase 3 should establish boundaries and tooling without pulling real gameplay into the bootstrap.
- Limitations found: Pending.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: Pending.

## Phase 3 Handoff Validation Update

- Date: 2026-05-23
- AI tool/model: Codex coding agent
- Role of the tool: Documentation and continuity support.
- Task or problem addressed: Update `docs/CODEX_HANDOFF.md` after Phase 3 validation so future Codex sessions can continue safely from the actual implemented state.
- Prompt or faithful paraphrase: Refresh the handoff with the implemented Flutter bootstrap, constraints, verification results including Android Emulator manual run, notes about Flutter project creation, and the next recommended Phase 4 direction.
- Result obtained: Updated `docs/CODEX_HANDOFF.md` to reflect the validated Phase 3 state.
- Modifications made by the team: Android Emulator manual validation was reported after implementation.
- Lessons learned: Handoff documents should be corrected after validation, not left as original plans.
- Limitations found: The handoff is a snapshot and should be updated again after Phase 4.
- Approximate percentage of AI-assisted code: Documentation update only.
- Critical reflection: The update reinforces that `DottedBoardPlaceholder` is not the game engine and that backend integration remains future work.

## Phase 4 Game Engine Domain Entry

- Date: 2026-05-24
- AI tool/model: Codex coding agent
- Role of the tool: Pure Dart game domain and application implementation support.
- Task or problem addressed: Implement the graph-based game engine foundation without UI gameplay, backend integration, manual levels, random generation, or APK build.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; implement pure Dart graph domain/application classes; ensure undirected edge traversal works from either endpoint; escaped arrows are inactive and non-blocking; keep validation structural only; use `flutter_test`; do not add `mocktail` or Singleton.
- Result obtained: Pending team review after Phase 4 verification.
- Modifications made by the team: Pending.
- Lessons learned: The graph engine boundary is easiest to preserve when movement and validation stay in pure Dart and presentation remains untouched.
- Limitations found: Phase 4 uses small test fixtures only; real manual levels and UI integration remain future phases.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: The implementation demonstrates the required graph model while avoiding premature UI/backend coupling.

## Phase 5 Manual Graph Levels Entry

- Date: 2026-05-23
- AI tool/model: Codex coding agent
- Role of the tool: Flutter level asset and Clean Architecture implementation support.
- Task or problem addressed: Add the 15 required deterministic manual graph-based levels as local Flutter assets, keep them compatible with the backend seed format, load them through infrastructure/application boundaries, and verify them with tests.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; mirror `backend-poc-arrow/prisma/levels/manual-levels.ts` as closely as possible; preserve explicit level numbers; load the actual registered asset; keep validation strict and structural; do not implement gameplay UI, backend integration, random generation, or APK build.
- Result obtained: Added `assets/levels/manual_levels.json`, registered it in `pubspec.yaml`, added local asset data source/repository/use cases, preserved level numbers in the domain model, and added focused tests for loading, validation, progression, uniqueness, graph shape, mapping, reversed edge id normalization, and invalid reversed edge rejection.
- Modifications made by the team: Pending team review.
- Lessons learned: Backend seed compatibility and frontend domain strictness can coexist by mapping backend-style undirected edge references into canonical domain edge ids before validation, while rejecting references that do not have an exact or reversed equivalent edge.
- Limitations found: Phase 5 does not render or play these levels yet; gameplay UI and backend synchronization remain future work.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: The local level pipeline keeps the app playable offline in future phases without letting asset loading leak into pure domain logic.

## Phase 6 Playable Game UI Entry

- Date: 2026-05-23
- AI tool/model: Codex coding agent
- Role of the tool: Flutter gameplay UI implementation support.
- Task or problem addressed: Implement the first playable graph-based UI using real local manual levels, while keeping movement rules in the existing game engine.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; use `assets/levels/manual_levels.json` for the normal flow; render graph nodes, edges, and arrows; centralize presentation-only coordinate mapping; hit-test only to select arrow ids; delegate movement to `GameSessionService`; add tests, localization, README, and handoff updates; do not add dependencies or implement backend/random/APK/persistence work.
- Result obtained: Added playable local level selection, graph board rendering, arrow tap activation, moves/score updates, victory UI, presentation-only coordinate mapping/hit testing, localization keys, tests, README, and handoff documentation.
- Modifications made by the team: Pending.
- Lessons learned: A small presentation controller and coordinate mapper keep the UI playable without contaminating the pure graph engine.
- Limitations found: Phase 6 has no backend progress sync, random levels, advanced persistence, or release APK.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: The implementation keeps the graph persistent visually and uses UI hit testing only as input selection, not as game rule logic.

## Phase 7 Local Progress, Settings, Audio Foundation Entry

- Date: 2026-05-24
- AI tool/model: Codex coding agent
- Role of the tool: Flutter local persistence, settings, audio foundation, test, and documentation implementation support.
- Task or problem addressed: Add local progress persistence, local level unlocking, best score tracking, functional settings, reset progress, and lightweight audio feedback while preserving the graph-based gameplay boundary.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; add only `shared_preferences`; keep persistence behind Clean Architecture ports/adapters; do not implement backend integration, random levels, final APK, final audio/music assets, fake timer, or matrix/cell runtime logic; reset progress must not reset settings; save completion exactly once per completed session.
- Result obtained: Implemented local progress and settings Clean Architecture ports/use cases/adapters, local unlocking UI, victory save-progress flow, best-score display, settings toggles, reset progress confirmation, system-click audio feedback foundation, tests, README updates, and final Phase 7 handoff documentation.
- Modifications made by the team: Phase 7 constraints were clarified by the team before implementation: add only `shared_preferences`, avoid `audioplayers`, keep audio as foundation only, do not reset settings when resetting progress, and avoid fake timer UI.
- Lessons learned: Local persistence stays manageable when screens depend on use cases/controllers instead of storage APIs, and audio can be represented as a replaceable port before real assets exist.
- Limitations found: Phase 7 does not include backend sync, random levels, final audio/music assets, background music playback, a real timer, runtime language switching, or APK release.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: The phase improves demo readiness without weakening the core boundary: Flutter owns gameplay logic, movement remains in the graph engine, and storage/audio concerns are adapters rather than domain dependencies.

## Phase 8 Frontend Backend Integration Entry

- Date: 2026-05-24
- AI tool/model: Codex coding agent
- Role of the tool: Frontend backend integration implementation support.
- Task or problem addressed: Add optional authentication, API client foundation, progress synchronization, remote level-id mapping, and leaderboard integration while preserving local-first gameplay.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; add only `http`; keep auth optional; keep local manual levels as the default playable source; use injectable `http.Client`; keep HTTP and SharedPreferences behind infrastructure adapters; make sync and leaderboard non-blocking; do not modify backend or Git remotes.
- Result obtained: Added `core/network`, auth session/token storage, login/register UI, settings auth/sync actions, remote progress merge/sync, backend level-id mapping, leaderboard fetch/submit support, non-blocking victory sync, tests, README updates, and handoff updates.
- Modifications made by the team: Phase 8 constraints clarified that SharedPreferences token storage is academic/demo scope and production should use secure token storage later.
- Lessons learned: Mapping backend level ids by level number lets backend integration coexist with local graph assets without replacing offline gameplay.
- Limitations found: Backend health and Android emulator launch were verified, but manual in-app register/login/complete-level interaction was not performed; secure token storage, random levels, final APK, and production deployment remain future work.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: The implementation keeps gameplay local and graph-based while making backend features additive rather than mandatory.

## Phase 9 Gameplay Fixes, Lives System, Level Redesign, Stability Entry

- Date: 2026-05-31
- AI tool/model: Claude (Anthropic) coding agent.
- Role of the tool: Phase 9 gameplay-rule correction, lives/game-over system, level redesign, exit/collision animation, stability fixes, and tests.
- Task or problem addressed: Make arrow activation a full atomic exit attempt; make collision detection consider the full arrow shape (head, body, segments, nodes, edges) of every active arrow; roll back failed attempts with no partial movement; add a 3-lives system (1 life lost per 2 mistakes, game-over at 6); animate successful exits (whole shape sliding out) and collisions (shake + flash); fix level-selection refresh after returning from a level via any back path; redesign all 15 manual levels with varied non-rectangular graph shapes; guarantee no free nodes at level start; and add/maintain tests.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; do not modify backend or Git remotes; keep gameplay graph-based (no matrix/grid/tile runtime); no timer, no fake timer, no random level generation, no APK, no real audio assets; keep local-first and non-blocking backend sync/leaderboard; full-arrow collision; exit animation; collision rollback; lives/game-over; level-selection refresh with a test; redesign 15 levels (1-5 easy, 6-10 medium, 11-15 hard, hard not all rectangles, blockedEdges empty); no free nodes with a test; add tests; run flutter analyze and flutter test.
- Result obtained: Rewrote `MovementResolver` for full-shape forward-ray collision; preserved atomic rollback and lives/score logic in `MoveArrowUseCase`/`GameSession`; made `GraphBoard` stateful with exit-slide and collision-shake animations rendering the already-resolved trace; added `GameAttemptTrace` and a disposal-safe controller; threaded `enableBoardAnimations`; fixed `LevelSelectionScreen` to reload progress after navigation pop; redesigned all 15 levels via a new build-time generator `tool/gen_levels.js` that validates structure, no-free-nodes, difficulty, hard-not-all-rectangular, and full-exit solvability before writing the asset; added/updated tests (full-shape collision, rollback, trace/flash/restart, no-free-nodes, solvability, hard-not-all-rectangular, level-selection refresh). `flutter analyze` passed with no issues; `flutter test` passed 92 tests; generator confirmed all 15 levels valid, no free nodes, solvable, 0 hard rectangles.
- Modifications made by the team: Phase 9 was iterated in stages with team direction (full-arrow collision over head-only, sliding not growing, lives threshold `3 - mistakes~/2`, score `1000 - 100*mistakes - 5*moves`, all levels filled so no node is free, hard levels not rectangular). A localization build break (missing ARB keys after regeneration) was fixed by adding keys to `app_en.arb`/`app_es.arb` and regenerating.
- Lessons learned: Resolving rules instantly in the domain and animating the resolved trace in presentation keeps the rule/render boundary clean and tests non-brittle. Generating levels with a validating tool that mirrors the runtime resolver guarantees solvability and the no-free-nodes invariant without manual trial-and-error. Generated localization files must be regenerated from ARB sources rather than hand-edited.
- Limitations found: Manual emulator validation is still pending; stuck/deadlock detection was left optional and not implemented; no timer, random levels, final audio, or APK. Backend and Git remotes untouched.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: Phase 9 strengthens the core graph-based mechanic (full-shape collision, atomic rollback, lives) and visual feedback while preserving every prior constraint — Flutter owns gameplay, backend stays non-blocking, gameplay stays local-first and graph-based, and no timer or random generation was introduced.

## Phase 10 Level Authoring, Density Tuning, and Board UX Polish Entry

- Date: 2026-05-31
- AI tool/model: Claude (Anthropic) coding agent.
- Role of the tool: Author the level-authoring guide, densify the 15 manual levels, make the JSON authoritative with a safe validate-only tool mode, and add board pan/zoom with a reset-view button, plus tests.
- Task or problem addressed: Write `docs/LEVEL_AUTHORING.md`; raise level density to easy 10-15, medium 15-30, hard 20-50 (warn 51-60, fail 61+) arrows with a soft easy ramp; keep 15 levels, numbers 1-15, difficulty progression, no-free-nodes, solvability, graph-based shape, and hard-not-all-rectangular; make `tool/gen_levels.js` non-destructive by default with `--validate-only` (reads on-disk JSON, never writes) and `--generate` (writes intentionally); add board pinch-zoom/drag with a reset-view button; add/maintain tests for density, validation, solvability, no-free-nodes, and pan/zoom/reset.
- Prompt or faithful paraphrase: Work only inside `frontend-poc-arrow`; do not modify backend or Git remotes; no runtime random generation, timer, real audio, or APK; keep gameplay graph-based and local-first; backend sync/leaderboard non-blocking; do not change Phase 9 rules unless a bug is found. JSON is authoritative; do not overwrite it by default; provide `--validate-only` and `--generate`; keep density controlled and boards readable.
- Result obtained: Added the authoring guide; rewrote `tool/gen_levels.js` with explicit `--validate-only`/`--generate` modes, a greedy (sound+complete) solver, density bands with a warning range, and denser disjoint-lane builders; regenerated `manual_levels.json` (easy 10-15, medium 16-28, hard 22-50; tier averages 12.2 < 21.2 < 33.4; 0 hard rectangles; every node occupied; all greedy-solvable); wrapped `GraphBoard` in `InteractiveViewer` with a localized reset-view button while keeping tap-to-activate working; switched the Dart solvability test to greedy and added density/zoom tests. `node tool/gen_levels.js --validate-only` validates without writing (byte-identical asset, exit 0); `flutter analyze` clean; `flutter test` 95 passed.
- Modifications made by the team: Clarified that the JSON must remain authoritative, the tool must not overwrite by default (explicit `--generate` only), and density must stay controlled (hard target 20-50, warn 51-60, fail 61+) without creating unreadable boards.
- Lessons learned: Greedy exit-any-available is provably complete for this game (exiting only frees nodes), which makes dense-level validation tractable where DFS would not scale. Node-disjoint filled lanes guarantee solvability and the no-free-nodes invariant while allowing varied dense silhouettes. Making the JSON authoritative with a read-only validator protects hand edits.
- Limitations found: Manual emulator validation of the dense boards is still pending; very dense hard levels rely on pinch-zoom/drag for comfortable play on small screens.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: Phase 10 increases challenge and authorability without touching the Phase 9 rules: the JSON is the source of truth, the tool is safe-by-default, density is bounded and validated, and the board scales to larger levels while gameplay stays graph-based, local-first, and non-blocking.

## Phase 15 Audio Playback Stability Entry

- Date: 2026-06-22/23
- AI tool/model: Claude (Anthropic) coding agent (Sonnet 4.6).
- Role of the tool: Root-cause diagnosis and fix of user-reported, real-device audio bugs; correction of a prior phase's audit conclusion.
- Task or problem addressed: User reported intermittent crashes, background music and SFX silencing each other, crackling/distorted playback, and victory/defeat sound effects playing back sped up. This directly contradicted the Phase 14 Task A audit, which had concluded the audio code needed "no changes" — that audit checked Clean Architecture compliance only, not runtime device behavior.
- Prompt or faithful paraphrase: User described the four symptoms and asked why they happen; after diagnosis, asked to implement the fix using the Singleton pattern (and, after clarification, also an Object Pool for SFX), naming the singleton `AudioManager`. Two follow-up bugs were reported after the first fix shipped: lower the music volume relative to SFX, and fix the Next Level button stopping the music.
- Result obtained: Read the actual `audioplayers` Android plugin Kotlin source to confirm an out-of-range volume (`1.1`) was passed unclamped into native `MediaPlayer.setVolume`; parsed raw MP3 frame headers to confirm `victory.mp3` was encoded at 48kHz against 44.1kHz for the other SFX assets. Replaced the per-screen `AudioDependencies` factory (which constructed fresh, never-disposed `AudioPlayer`s on every level/retry/next-level navigation) with an app-lifetime `AudioManager` singleton; gave SFX a pool of 3 players instead of one shared, raced instance; added explicit, coordinated Android `AudioContext`/focus configuration to both the music and SFX ports; clamped and retuned the music volume; re-encoded `victory.mp3` to 44100 Hz (installed `ffmpeg` via `scoop` after `choco install` failed on a permissions lock, since this environment's shell isn't elevated). After the first fix shipped, the user found that the singleton introduced a new bug — `Navigator.pushReplacementNamed` on "Next Level" disposes the old `GameScreen` while mounting a new one, racing the old screen's `stopMusic()` against the new screen's `startMusic()` on the shared singleton. Fixed with reference-counted claims/releases so only the first start and the last stop touch the underlying player.
- Modifications made by the team: Pending team review on a real device/emulator.
- Lessons learned: An architecture-compliance audit (ports/adapters correctness) is not the same as a runtime-behavior audit — Phase 14 Task A passed the former and missed five live defects, all of which required reading native plugin source and raw asset bytes, not just the Dart call sites, to confirm root cause before fixing. When converting a per-screen-recreated resource into a shared singleton, every navigation path that disposes one screen while mounting another (`pushReplacement*`) must be checked for start/stop ordering races on the new shared state.
- Limitations found: No automated regression tests were added — all five root causes (native audio-focus negotiation, native volume clamping, player resource lifecycle, sample-rate handling, navigation-driven lifecycle races) are real-device/native-plugin behaviors that this project's fake-based unit tests (`_FakeAudioPort`, `_FakeSettingsRepository`) cannot exercise. Manual on-device validation is required and still pending, as it is for Phases 9–14.1.
- Approximate percentage of AI-assisted code: Pending.
- Critical reflection: This phase is a useful counter-example to "audit passed, no changes needed" conclusions in this log — Clean Architecture compliance describes where code lives, not whether it behaves correctly on a real device. Future audits of adapter code (audio, storage, network) should include at least a manual device smoke test before declaring "no action needed," not just a static review of layering.
