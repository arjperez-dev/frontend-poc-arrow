# Codex Handoff

## Current Repository

- Repository: `frontend-poc-arrow`
- Branch: `feat/playable-game-ui`
- Do not modify Git remotes automatically.
- Do not modify `backend-poc-arrow` from this frontend phase.

## Completed Phases

- Phase 3 Flutter Bootstrap: completed and merged.
- Phase 4 Graph-Based Game Engine Domain: completed and merged.
- Phase 5 Manual Graph-Based Levels: completed and merged.
- Phase 6 Playable Game UI with Local Manual Levels: implemented on this branch.

## Implemented Phase 6 State

- Replaced placeholder route targets with real level selection and game screens.
- Normal user flow uses real local levels from `assets/levels/manual_levels.json`.
- Level selection displays the 15 manual levels with number, name, and difficulty.
- Game route receives an `int` level number and shows a friendly error state for missing/invalid values.
- Game screen loads the selected local level, starts `GameSession`, renders the graph, and activates arrows by tap.
- Moves and score update after successful movement/escape.
- Victory overlay supports retry, back to levels, and next level.
- Backend integration, random generation, advanced persistence, and APK build remain unimplemented.

## Rendering Strategy

- `GraphBoardPainter` draws directly from `BoardGraph.nodes`, `BoardGraph.edges`, and active `ArrowPath.occupiedEdgeIds`.
- Graph nodes and edges are always rendered, including after arrow escape.
- Escaped arrows are not rendered as active arrows.
- Blocked edges use a distinct accent style.
- Arrowheads are drawn at each active arrow head using `ArrowPath.direction`.
- `DottedBoardPlaceholder` remains presentation-only and is not the game engine.

## Coordinate Mapping and Hit Testing

- `GraphBoardLayout` centralizes graph-coordinate to canvas-coordinate mapping.
- `GraphBoardLayout` lives in presentation and is not domain logic.
- `GraphBoardHitTester` uses the shared layout to map tap positions to an active arrow id.
- Hit testing does not decide movement rules.
- Movement still goes through `GameSessionService`, `MoveArrowUseCase`, and `MovementResolver`.
- No matrix, cell, tile, or cell-runtime model was introduced.

## State Management

- `GameScreenController` is a small `ChangeNotifier`.
- It holds load state, current level, current session, and last movement outcome.
- It starts/restarts sessions through `GameSessionService`.
- It delegates arrow activation through `GameSessionService.activateArrow`.
- It does not contain gameplay movement rules.

## Files Future Sessions Should Inspect First

- `lib/core/routing/app_routes.dart`
- `lib/features/levels/presentation/level_selection_screen.dart`
- `lib/features/game/presentation/game_screen.dart`
- `lib/features/game/presentation/game_screen_controller.dart`
- `lib/features/game/presentation/widgets/graph_board.dart`
- `lib/features/game/presentation/widgets/graph_board_layout.dart`
- `lib/features/game/presentation/widgets/graph_board_hit_tester.dart`
- `lib/features/game/presentation/widgets/graph_board_painter.dart`
- `lib/features/game/infrastructure/local_level_dependencies.dart`
- `test/features/game/presentation/playable_game_ui_test.dart`

## Tests Added

- `should_display_manual_levels_when_level_selection_loads`
- `should_open_game_screen_when_manual_level_is_selected`
- `should_render_game_screen_with_graph_nodes`
- `should_update_moves_when_arrow_is_activated`
- `should_show_victory_when_all_arrows_escape_for_simple_level`
- `should_keep_graph_nodes_visible_after_arrow_exits`

Tests use real local manual levels for selection/navigation/game loading. Fixture levels are used only for deterministic victory/escape checks.

## Verification Results

- `flutter pub get`: passed.
- `flutter analyze`: passed.
- `flutter test`: passed with 29 tests.
- `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000`: launched successfully on Android emulator, then was stopped with `q`.
- Targeted playable UI tests passed.
- Backend repository remained untouched.
- Git remotes were not modified.

## Known Limitations

- No backend auth, remote levels, progress sync, or leaderboard integration.
- No random level generation.
- No advanced persistence or level locking.
- No APK build.
- Painter tests avoid pixel-perfect assertions and use keys/semantics instead.

## Next Recommended Phase

Recommended next phase: add local progress persistence and level completion flow, or begin backend integration for auth/progress/leaderboard after the playable local loop is reviewed.
