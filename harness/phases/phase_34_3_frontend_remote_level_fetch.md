# PHASE 34.3 — Frontend Remote Level-Definition Fetch Abstraction

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/phases/phase_34_backend_driven_levels.md`
- `backend-poc-arrow/docs/DYNAMIC_LEVELS_CONTRACT.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Current State

- `ApiRemoteLevelRepository` (`lib/features/progress/infrastructure/`) already
  calls `GET /levels` but reads only `number` + `id` for id↔number mapping. It
  must remain unchanged (sync/leaderboard depend on it).
- Gameplay levels are parsed from local assets into `ManualLevelDto` /
  `ManualLevelDefinitionDto` via `LocalLevelDataSource` +
  `ManualLevelCollectionDto`. `ManualGraphNodeDto` already supports optional `z`.
- `core/network/ApiClient` provides `get()`.

## Goal

Add a **read-only** frontend capability to fetch full remote level *definitions*
from the backend and map them into the existing `ManualLevelDto` shape. No merge,
no gameplay wiring, no caching yet — this slice only produces validated
`ManualLevelDto` objects from the backend response.

## Task

1. Add `RemoteLevelDefinitionRepository` (application port) with e.g.
   `Future<List<ManualLevelDto>> fetchRemoteLevels()`.
2. Add an infrastructure implementation (e.g.
   `lib/features/game/infrastructure/api_remote_level_definition_repository.dart`)
   that calls the endpoint defined by the 34.1 contract, and maps each backend
   level (`number`, `name`, `difficulty`, `definitionJson`) into `ManualLevelDto`
   using the existing `ManualLevelDto.fromJson` / `ManualLevelDefinitionDto`
   parsing (reuse, do not duplicate parsing logic).
3. Be tolerant: skip malformed entries (log/ignore), never throw on a single bad
   level; a network failure surfaces as an empty result or a typed
   "unavailable", never a crash — mirroring existing best-effort remote behavior.
4. Do **not** modify `ApiRemoteLevelRepository` or any sync/leaderboard code.
5. Add unit tests with a fake `ApiClient` for: happy path (2D + 3D level mapped,
   `z` preserved), malformed entry skipped, network error → empty/unavailable.

## Constraints

- Read-only. No merge into the playable level list in this slice.
- Do not modify auth, sync, leaderboard, or `ApiRemoteLevelRepository`.
- HTTP access stays in `core/network` + infrastructure; no `http`/`SharedPreferences`
  calls from application/presentation.
- Do not modify Git remotes. Do not commit or push automatically. Never work on `main`.

---

## Validation

```bash
flutter analyze
flutter test
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
