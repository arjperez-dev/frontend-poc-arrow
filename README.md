# Arrow POC Frontend

Flutter mobile app for the Arrow Maze inspired semester project.

## Current Phase

Phase 4 implements the pure Dart graph-based game engine domain/application foundation:

- Persistent graph domain model.
- Dynamic arrow path model.
- Structural graph level validation.
- Movement command/use case.
- Collision detection.
- Exit detection.
- Victory detection.
- Score calculation strategy.
- Pure Dart unit tests for graph and movement behavior.

This phase does not implement full gameplay UI, backend integration, the 15 manual levels, random level generation, or APK preparation.

## Architecture Direction

The frontend follows Clean Architecture:

```text
lib/
  core/
    config/
    errors/
    localization/
    routing/
    theme/
    network/
    storage/
  features/
    game/
      domain/
      application/
      infrastructure/
      presentation/
    auth/
    levels/
    leaderboard/
    settings/
```

Domain and application code in `features/game` is pure Dart. It does not import Flutter widgets, BuildContext, HTTP, storage, assets, or generated localization.

## Critical Gameplay Boundary

Flutter owns the playable game engine.

The backend stores and serves users, graph-based levels, progress, and leaderboard data. The backend must not process every player move.

The runtime game model is graph-based, not matrix-only:

- Graph nodes represent visible dots.
- Graph edges represent valid paths between dots.
- Arrows are dynamic multi-segment paths over graph edges.
- When an arrow exits, the arrow becomes escaped/inactive, but graph nodes and edges remain intact.

`DottedBoardPlaceholder` is presentation-only and is not the game engine.

## Game Engine Domain

Main domain concepts:

- `BoardGraph`
- `GraphNode`
- `GraphEdge`
- `BoardCoordinate`
- `Direction`
- `ArrowPath`
- `ArrowSegment`
- `Level`
- `GameSession`
- `GameStatus`
- `Score`

Main application concepts:

- `MoveArrowCommand`
- `MoveArrowUseCase`
- `MovementResolver`
- `CollisionDetector`
- `CheckVictoryUseCase`
- `ScoreStrategy`
- `ScoreCalculator`
- `GameSessionService`

## Movement Semantics

Phase 4 movement is intentionally simple and deterministic:

- An arrow moves from its head/end node in its current direction.
- `BoardGraph.getNeighbor(nodeId, direction)` works from either endpoint of an undirected edge.
- If the next edge is blocked, the arrow does not move.
- If another active arrow occupies the target edge, the arrow does not move.
- If no neighbor exists in the arrow direction, the move is treated as an exit.
- Escaped arrows remain stored with `isEscaped = true`, but are inactive and do not block collisions.
- If all arrows escape, the session status becomes `victory`.

## Level Validation

`LevelDefinitionValidator` performs structural validation only:

- Unique node ids.
- Unique edge ids.
- Edge endpoints reference existing nodes.
- Edges are orthogonal.
- Unique arrow ids.
- Arrow occupied edges exist.
- Arrow start/end nodes exist.
- Blocked edge ids exist.
- Metadata exists.

It does not solve puzzles, validate beatability, generate random levels, or create the 15 manual levels.

## Backend URL

The default API base URL is configured in `lib/core/config/app_config.dart`:

```dart
String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
)
```

Android Emulator note: use `http://10.0.2.2:3000` to reach a backend running on the host machine.

Override example:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Running Locally

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

## CI

GitHub Actions workflow:

```text
.github/workflows/flutter.yml
```

It runs:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

## Next Phases

Recommended next work:

- Integrate the pure engine with the game UI.
- Add local manual level assets mirroring backend graph JSON.
- Build game screen interactions around `GameSession`.
- Add backend integration for auth, levels, progress, and leaderboard.
- Prepare Android APK near final delivery.

## Commit Convention

Use Conventional Commits in English:

```text
feat(game): add graph-based engine domain
test(game): add movement and graph validation tests
docs(frontend): document game engine domain
```
