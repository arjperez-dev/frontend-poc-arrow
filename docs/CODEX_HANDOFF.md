# Codex Handoff

## Current Repository

- Repository: `frontend-poc-arrow`
- Branch: `feat/game-engine-domain`
- Do not modify Git remotes automatically.
- Do not modify `backend-poc-arrow` from this frontend phase.

## Completed Phases

- Phase 3 Flutter Bootstrap: completed and merged before this branch.
- Phase 4 Graph-Based Game Engine Domain: pure Dart engine foundation implemented.

## Implemented Phase 4 Foundation

- Persistent graph domain model.
- Undirected graph edge traversal.
- Dynamic arrow path model.
- Structural level definition validation.
- Move command/use case.
- Movement resolver.
- Collision detector.
- Victory checker.
- Score strategy/calculator.
- Pure Dart unit tests for domain/application behavior.

## Important Constraints

- Flutter owns gameplay logic.
- Backend does not process every move.
- Future game board must remain graph-based, not matrix-only.
- `DottedBoardPlaceholder` is presentation-only and is not the game engine.
- Phase 4 did not implement full gameplay UI.
- Phase 4 did not implement backend integration.
- Phase 4 did not implement the 15 manual levels.
- Phase 4 did not implement random level generation.
- Phase 4 did not build an APK.

## Domain Classes

Implemented under `lib/features/game/domain`:

- `BoardCoordinate`
- `Direction`
- `GraphNode`
- `GraphEdge`
- `BoardGraph`
- `ArrowSegment`
- `ArrowPath`
- `Level`
- `LevelDefinition`
- `LevelDefinitionValidator`
- `GameSession`
- `GameStatus`
- `Score`

## Application Classes

Implemented under `lib/features/game/application`:

- `MoveArrowCommand`
- `MovementResult`
- `MovementResolver`
- `CollisionDetector`
- `MoveArrowUseCase`
- `CheckVictoryUseCase`
- `ScoreStrategy`
- `ScoreCalculator`
- `GameSessionService`

## Movement Semantics

- An arrow moves from its `endNodeId` in its current `direction`.
- `GraphEdge` represents an undirected connection.
- `BoardGraph.getNeighbor(nodeId, direction)` works from either endpoint.
- If an edge connects A(0,0) and B(1,0), `getNeighbor(A, right)` returns B and `getNeighbor(B, left)` returns A.
- If the next edge is blocked, the arrow does not move.
- If another active arrow occupies the target edge, the arrow does not move.
- If no neighbor exists in the direction, the arrow escapes.
- Escaped arrows remain stored with `isEscaped = true`, but are inactive and do not block collisions.
- If all arrows escape, the session status becomes `victory`.

## Level Validation

`LevelDefinitionValidator` is structural only:

- Validates unique node ids.
- Validates unique edge ids.
- Validates edge endpoints reference existing nodes.
- Validates edges are orthogonal.
- Validates unique arrow ids.
- Validates arrow occupied edges exist.
- Validates arrow start/end nodes exist.
- Validates blocked edge ids exist.
- Validates metadata exists.

It does not solve puzzles, validate completion, generate random levels, or create the 15 manual levels.

## Verification Results

- `flutter analyze`: passed.
- `flutter test`: passed.
- Existing Phase 3 widget tests still pass.
- Phase 4 domain/application tests pass.

## Notes

- No `mocktail` dependency was added.
- No Singleton pattern was added.
- No presentation files were changed for engine logic.
- No backend files were touched.

## Next Recommended Phase

Recommended next phase: integrate the pure graph engine with gameplay UI or create local manual level assets, depending on project priority.

Suggested next steps:

- Keep using test-first development.
- Add the 15 manual graph-based levels as local Flutter assets in a future phase.
- Wire `GameSession` into the game screen only after domain behavior remains stable.
- Keep backend integration separate from core engine rules.

## Files Future Codex Sessions Should Inspect First

- `README.md`
- `AI_USAGE.md`
- `lib/features/game/domain/board_graph.dart`
- `lib/features/game/domain/level_definition_validator.dart`
- `lib/features/game/domain/game_session.dart`
- `lib/features/game/application/move_arrow_use_case.dart`
- `lib/features/game/application/movement_resolver.dart`
- `test/features/game/domain/level_definition_validator_test.dart`
- `test/features/game/application/move_arrow_use_case_test.dart`
- `test/features/game/application/score_calculator_test.dart`
