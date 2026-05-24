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
