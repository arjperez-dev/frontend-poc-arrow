# PHASE 32 — README Refresh (Frontend + Backend)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/README.md` (current, to be rewritten)
- `backend-poc-arrow/README.md` (current, to be rewritten)

Git context:
- Frontend and backend working tree: `feat/phase-32-readme-refresh`
- Base branch: `main`

---

## Mandatory Pre-Implementation

Before writing any content:

1. Audit both `README.md` files and the actual repository structure they describe.
2. Confirm the frontend architecture directly from the source tree **before** writing about it: verify that `lib/` is organized as Clean Architecture layers (Domain → Application → Infrastructure → Presentation) under `lib/core/` and `lib/features/<feature>/`. It is — every feature folder contains `domain/`, `application/`, `infrastructure/`, `presentation/` subfolders. Only describe layers that actually exist.
3. Confirm the backend stack from `package.json`: it is **NestJS 11** (`@nestjs/*`, `@nestjs/jwt`, `@prisma/client`) on Express under the hood — **not** a bare Express app. Describe it accurately.
4. Explain your understanding of the current state.
5. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
6. **Wait for explicit approval before writing any content.**

---

## Task

Rewrite two files only: `frontend-poc-arrow/README.md` and `backend-poc-arrow/README.md`. Each must be clear, accurate, well-structured, concise, and scannable.

### 1. Frontend README — `frontend-poc-arrow/README.md`

Must include:

- **Project name and short description** — Nodus, a Flutter graph-based puzzle game (frontend/client context only).
- **Purpose / what the app does** — playable graph-puzzle levels where the player taps rigid arrows to exit the board; 2D and 3D level sets; optional online account, progress sync, and leaderboards.
- **Tech stack** — Flutter, Dart, Clean Architecture. (Confirmed: Clean Architecture *is* the architecture used.)
- **Architecture overview** — since Clean Architecture is confirmed, show the four layers **Domain → Application → Infrastructure → Presentation** and a directory tree showing how `lib/` maps to them. Note the `lib/core/` (cross-cutting: `app/`, `config/`, `network/`, `routing/`, `storage/`, `theme/`, `localization/`, `errors/`) vs `lib/features/<feature>/{domain,application,infrastructure,presentation}` split.
- **Full project directory structure** — `lib/`, `assets/` (`audio/`, `fonts/`, `levels/`), `test/`, `tool/`, `docs/`, `harness/`.
- **Key features summary** — gameplay (graph-based full-exit arrows, lives/game-over), audio, auth, progress, leaderboard, settings (incl. language), challenges, 3D mode.
- **Setup instructions** — `flutter pub get`, `flutter gen-l10n`, and the `API_BASE_URL` dart-define (e.g. `--dart-define=API_BASE_URL=http://10.0.2.2:3000`).
- **Run commands** — `flutter run`, `flutter test`, `flutter analyze`.
- **Level authoring / validation commands** —
  - `node tool/gen_levels.js --validate-only` (default; never writes)
  - `node tool/gen_levels.js --generate-2d`
  - `node tool/gen_levels.js --generate-3d`
  - (`--generate` runs both.)
- **Authoritative level sources note** — brief note that `assets/levels/manual_levels_2d.json` (levels 1–20) and `assets/levels/manual_levels_3d.json` (levels 21+) are the authoritative, tool-validated level data.

Do NOT include backend details. Do NOT over-explain.

### 2. Backend README — `backend-poc-arrow/README.md`

Must include:

- **Project name and short description** — Nodus backend REST API (backend/server context only).
- **Purpose / what the backend does** — user auth, level catalog, progress persistence/sync, and leaderboards for the Nodus client.
- **Tech stack** — Node.js, NestJS 11, Prisma 6, PostgreSQL, JWT (`@nestjs/jwt`), TypeScript. Describe the layered / ports-and-adapters architecture.
- **Architecture overview** — ports-and-adapters / layered architecture with a directory tree.
- **Full project directory structure** — `src/domain/`, `src/application/` (incl. `application/ports/`), `src/infrastructure/` (`database/`, `repositories/`, `security/`), `src/interfaces/http/` (per-feature controllers + `dto/`, `filters/`, `interceptors/`, `health/`), `src/modules/`, `prisma/`, `test/`.
- **Key endpoints table** (method, path, auth required, description):
  - `POST /auth/register`
  - `POST /auth/login`
  - `GET /levels`
  - `GET /progress/me`
  - `POST /progress/sync`
  - `DELETE /progress`
  - `GET /leaderboard/:levelId`
  - `POST /leaderboard`
- **Setup instructions** — `npm install`, `docker compose up` (Postgres 17 + API), `npx prisma migrate dev` (or `npm run prisma:migrate`), `npm run prisma:seed`.
- **Run commands** — `npm run start:dev` (watch/dev), `npm test`, `npm run test:e2e`. (Note: the dev script is `start:dev`; there is no `npm run dev`.)
- **Environment variables** — `.env` template covering: `PORT`, `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGIN`, `NODE_ENV`, `DATABASE_URL_TEST`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`.
- **Seed note** — brief note that `prisma/levels/manual-levels.ts` seeds the anchor level rows (stable `levelId`s the client maps to) via `prisma/seed.ts`.

Do NOT include frontend details. Do NOT over-explain.

---

## Constraints

- Only the two `README.md` files may be edited. Do NOT modify any source code, test code, or configuration files.
- Do NOT add new dependencies or change `pubspec.yaml` / `package.json`.
- Do NOT modify Git remotes.
- Do NOT commit or push automatically — manual audit required.
- Backend README lives in `backend-poc-arrow`; editing it is the sole permitted exception to the "do not modify backend" rule for this phase.

---

## Validation

No automated suite applies (docs-only change). Manually verify:

- Every command, path, filename, endpoint, and environment variable in each README matches the actual repository.
- Directory trees match the real layout.
- Frontend README contains no backend details and vice versa.
- Both render cleanly as Markdown.

Optionally confirm nothing else changed:

```bash
git status            # only the two README.md files modified
node tool/gen_levels.js --validate-only   # sanity: level data still valid (no files touched)
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
