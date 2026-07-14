# PHASE 30 — Level Reorganization (Sequential Renumbering by Difficulty)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/docs/LEVEL_AUTHORING.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit all files relevant to this task.
2. Explain your understanding of the current state.
3. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
4. **Wait for explicit approval before writing any code.**

---

## Task

A teammate reorganized level presentation by difficulty. The current difficulty order (easiest → hardest, left-to-right) uses non-sequential internal numbers, which breaks leaderboard and progress sync: the frontend resolves backend `Level.id` via `GET /levels` keyed on `Level.number`, and the backend seed only has anchor rows for numbers 1–25 (26–30 are missing). This phase (a) closes the backend gap and (b) renumbers frontend levels to be strictly sequential while preserving the current difficulty order.

Current difficulty order:
- 2D: `1,5,3,4,2,10,9,6,7,11,8,14,15,20,13,16,12,18,17,19`
- 3D: `29,25,27,30,21,26,23,24,28,22`

### 1. Backend — add anchor rows for numbers 26–30

Repository: `backend-poc-arrow` — branch `feat/phase-30-backend-levels-26-30` (base `main`).

- Modify `backend-poc-arrow/prisma/levels/manual-levels.ts`: change the generator `...Array.from({ length: 10 }, (_, index): LevelSpec => { const number = 16 + index; ... })` to `{ length: 15 }`, so `number = 16 + index` yields **16–30**. Keep placeholder `difficulty: 'hard'` and the existing minimal valid `definitionJson` convention used for 16–25.
- Update the explanatory comment above the generator to state the range now covers 16–30 (was 16–25).
- Re-run `prisma db seed` (upsert-by-`number` is idempotent; only 26–30 are inserted, 1–25 untouched).
- Update backend tests: any `toHaveLength` seed-count assertions and any `/030` (Level 30) existence checks.

### 2. Frontend — renumber levels sequentially, preserving difficulty order

Repository: `frontend-poc-arrow` — branch `feat/phase-30-level-reorganization` (base `main`).

Apply the exact old→new number remapping below. **Only the internal `number` changes**; every level's board content, shapes, arrows, blocked edges, and difficulty tier are preserved.

2D (`assets/levels/manual_levels_2d.json`) — new numbers 1–20:

| current | new | current | new | current | new | current | new |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 5 | 8 | 11 | 20 | 14 |
| 5 | 2 | 10 | 6 | 14 | 12 | 13 | 15 |
| 3 | 3 | 9 | 7 | 15 | 13 | 16 | 16 |
| 4 | 4 | 6 | 8 | | | 12 | 17 |
| | | 7 | 9 | | | 18 | 18 |
| | | 11 | 10 | | | 17 | 19 |
| | | | | | | 19 | 20 |

Canonical 2D old→new list (in current-order sequence): `1→1, 5→2, 3→3, 4→4, 2→5, 10→6, 9→7, 6→8, 7→9, 11→10, 8→11, 14→12, 15→13, 20→14, 13→15, 16→16, 12→17, 18→18, 17→19, 19→20`.

3D (`assets/levels/manual_levels_3d.json`) — new numbers 21–30:
`29→21, 25→22, 27→23, 30→24, 21→25, 26→26, 23→27, 24→28, 28→29, 22→30`.

Files to update:
- `assets/levels/manual_levels_2d.json` — rewrite `number` on each level per the map. Ensure the file is ordered/consistent with existing conventions; content otherwise unchanged.
- `assets/levels/manual_levels_3d.json` — same, for 21–30.
- `tool/gen_levels.js` — update any builders that hardcode level numbers or depend on specific number→seed mappings.
- Dart code with hardcoded level-number assumptions: `AppConfig` (level counts/ranges), display/label mapping, unlock logic, leaderboard level picker, and their tests. Preserve behavior; only the number values change.

Preserve: all level content and shapes; 2D easy/medium/hard tiers; 3D all-hard. The new numbering must make internal order == difficulty order so no runtime re-sort is required.

---

## Constraints

- **Backend changes ARE allowed in this phase** — required and scoped to the single seed file `prisma/levels/manual-levels.ts` plus its tests.
- Do not modify Git remotes.
- Do not commit or push automatically — manual audit required.
- Graph-based runtime only.
- `manual_levels_2d.json` and `manual_levels_3d.json` are authoritative for level content.
- Do not change level board content, shapes, arrows, blocked edges, or difficulty tiers — only internal `number`.

---

## Validation

Run these after implementation. All must pass.

Frontend:
```bash
node tool/gen_levels.js --validate-only   # 2D and 3D
flutter analyze
flutter test
```

Backend (`backend-poc-arrow`):
```bash
npx tsc --noEmit
npm test
npm run test:e2e
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.
4. Report to me. Do not commit or push.

---

Do not be verbose. Be direct.
