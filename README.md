# Arrow POC Frontend

Flutter mobile app for the Arrow Maze inspired semester project.

## Current Phase

Phase 6 makes the app playable with the required 15 deterministic manual graph-based levels loaded from local Flutter assets.

The normal user flow supports:

- Opening the app and entering level selection.
- Viewing the 15 local manual levels.
- Selecting a level.
- Rendering the graph board with persistent nodes and edges.
- Rendering active arrow paths over graph edges.
- Tapping arrows to activate movement through the existing game engine.
- Updating moves and score.
- Showing victory, retry, back-to-levels, and next-level actions.

Local levels are stored at:

```text
assets/levels/manual_levels.json
```

The asset mirrors the backend seed shape as closely as possible:

```json
{
  "levels": [
    {
      "number": 1,
      "name": "First Exit",
      "difficulty": "easy",
      "definitionJson": {
        "nodes": [],
        "edges": [],
        "arrows": [],
        "blockedEdges": [],
        "metadata": {}
      }
    }
  ]
}
```

Phase 6 does not implement backend integration, random level generation, advanced persistence, or APK preparation.

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
- `LevelRepository`
- `GetLocalLevelsUseCase`
- `GetLocalLevelByNumberUseCase`

Main infrastructure concepts:

- `LocalLevelDataSource`
- `AssetLevelRepository`
- `LevelDefinitionMapper`
- `RootBundleAssetTextLoader`
- `LocalLevelDependencies`

Main presentation concepts:

- `LevelSelectionScreen`
- `GameScreen`
- `GameScreenController`
- `GraphBoard`
- `GraphBoardPainter`
- `GraphBoardLayout`
- `GraphBoardHitTester`

## Movement Semantics

Phase 4 movement is intentionally simple and deterministic:

- An arrow moves from its head/end node in its current direction.
- `BoardGraph.getNeighbor(nodeId, direction)` works from either endpoint of an undirected edge.
- If the next edge is blocked, the arrow does not move.
- If another active arrow occupies the target edge, the arrow does not move.
- If no neighbor exists in the arrow direction, the move is treated as an exit.
- Escaped arrows remain stored with `isEscaped = true`, but are inactive and do not block collisions.
- If all arrows escape, the session status becomes `victory`.

The UI does not implement movement rules. It selects an arrow id from a tap and delegates movement to `GameSessionService`, which uses the existing application/domain services.

## Graph Rendering

The board is rendered from graph entities only:

- `BoardGraph.nodes` provide persistent visible dots.
- `BoardGraph.edges` provide guide paths and blocked-edge accents.
- `ArrowPath.occupiedEdgeIds` provide active arrow path segments.

`GraphBoardLayout` centralizes graph-coordinate to canvas-coordinate mapping for both painting and hit testing. It lives in presentation and is not domain logic.

Escaped arrows are skipped when rendering active arrows, but graph nodes and edges remain visible.

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

- Add local progress persistence and level completion state.
- Add backend integration for auth, levels, progress, and leaderboard.
- Add random graph-based levels only after the manual playable path is stable.
- Prepare Android APK near final delivery.

## Commit Convention

Use Conventional Commits in English:

```text
feat(game): add graph-based engine domain
feat(levels): add local manual graph levels
feat(game): add playable graph board ui
test(game): add movement and graph validation tests
docs(frontend): document game engine domain
```
