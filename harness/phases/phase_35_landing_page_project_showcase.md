# PHASE 35 — Landing Page Project Showcase (Framing, AI Techniques, Technical Depth)

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md` (Phase 33 and Phase 33.1 sections)
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/harness/context/phase_registry.md`
- `backend-poc-arrow/README.md` (section "AOP — Aspect-Oriented Programming") — read-only

---

## Git Context

- Repository: `frontend-poc-arrow`. Do **not** modify `backend-poc-arrow` — read-only inspection is allowed, and required, to keep technical claims accurate.
- Create branch `feat/phase-35-landing-page-showcase` from the latest `main`. Never work directly on `main`.
- Do not modify Git remotes.
- Never commit or push automatically. At the end, report the exact commands the user should run for a manual audit (diff, add, commit, push, PR).

---

## Context

The landing page (Phase 33 + 33.1) is a self-contained bilingual EN/ES static site in `docs/pages/` — `index.html`, `styles.css`, `script.js`. No build step, no framework, no external network dependencies. Copy is keyed with `data-i18n` / `data-i18n-aria`; `script.js` holds a `translations` object with full EN and ES strings, defaults to English, and persists the choice in `localStorage` (`nodus-lang`). Current sections: 01 Project Overview (6 cards), 02 AI Workflow Evolution (3 stage cards + a CSS context-window diagram + a `<canvas>` chart), 03 Technical Highlights (8 cards), 04 Closing (links + thank-you).

The Step 1 audit established the following. Treat these as verified findings, not assumptions.

**Framing errors.** The hero eyebrow is already correct ("Software Development Project"), but four strings frame the work as a capstone/degree project and must be corrected:
- `index.html` footer: "Nodus — University Capstone Project"
- `script.js` EN `footer.text`: same string
- `script.js` ES `footer.text`: "Nodus — Proyecto de Grado Universitario"
- `script.js` EN `s4.lead`: "…guidance throughout this capstone project" (note: the `index.html` fallback for the same key says "throughout this semester" — EN HTML and EN JS currently disagree, and the JS wins at runtime; both must end up consistent and correct)

**AI-usage narrative.** The section already names the correct three techniques — prompt engineering → spec-driven development → harness engineering — and Stage 3 is corroborated by the real `harness/` tree (`context/`, `templates/`, `metrics/improvement_log.md`, `checklists/`, `rules/`, 30+ phase files). Nothing is misrepresented or omitted at the level of *which* techniques. The gaps are depth and evidence: each stage is prose-only, no concrete artifact is shown, and the only quantitative claim is a chart whose numbers Phase 33 recorded as invented and user-approved as illustrative.

**Technical depth — the main gap.** Section 03 is a stack list, not an explanation. The page nowhere says how the frontend works, how the backend works, what each is responsible for, or how they relate. AOP is not mentioned at all.

**AOP — verified in code, correcting the prior assumption.** The concern is **not** primarily security. `backend-poc-arrow/src/main.ts` globally registers exactly two aspects: `LoggingPerformanceInterceptor` (wraps every HTTP handler, logs `METHOD /path STATUS TIMEms` on success and a warning on failure, with zero controller changes) and `HttpExceptionFilter` (normalises any thrown exception into a consistent `{ statusCode, timestamp, path, method, message, errorCode }` response, so controllers need no try/catch for error formatting). Security is a third, **per-route metadata-driven** aspect: `JwtAuthGuard` applied via `@UseGuards` on progress, leaderboard, and admin level routes, plus `RolesGuard` + `@Roles(UserRole.ADMIN)` on the two admin level endpoints. The page must present all three concerns and must not describe security as the global one.

**Architecture — verified.** Both repositories use Clean Architecture. Frontend: Domain → Application → Infrastructure → Presentation per feature, with a pure domain (no Flutter/HTTP/storage imports). Backend: `src/{domain, application, infrastructure, interfaces}` with NestJS modules, Prisma as ORM/migration layer, and Swagger at `/api/docs`.

**Relationship — verified.** The backend is strictly additive. Local levels remain the offline source of truth; the frontend maps to backend level ids via `GET /levels`; progress sync uses a merge policy that never discards better local results; leaderboard submission happens only when authenticated and is best-effort and non-blocking.

**Charts.** The `<canvas id="workflowCanvas">` (stacked input/output bars + dashed falling-overhead trend line, `illustrative` tag, redraws with translated labels on toggle) is the AI section's only real graphic, and its data is fabricated. The "Anatomy of a Context Window" block is CSS/DOM rather than a chart, and is thin: it lists three input blocks and two output blocks with no proportions and no explanation of why each part costs what it costs.

**The project is a course project for the "Software Development" course — not a capstone, not a thesis, not a "proyecto de grado."**

---

## Task

State WHAT must be achieved. Implementation approach is the implementer's decision.

1. **Correct the project's framing across the whole page.** Every statement about the project's academic nature must present it as a course project for the "Software Development" course. Remove or reword all capstone / thesis / degree-project / "proyecto de grado" framing, in both languages, in both `index.html` and the `translations` object. EN and ES must agree with each other, and the HTML fallback text must agree with its `data-i18n` counterpart.

2. **Improve the overall presentation of the project information** so it is clearer and better organised. The reader should be able to understand what Nodus is, how it was built, and how it works, without re-reading.

3. **Rework the AI-usage section** to explain the three AI techniques actually used — prompt engineering, spec-driven development, harness engineering — clearly and concisely. For each: what it is, what it cost, and why the project moved on from it (or, for harness engineering, why it stuck). Any quantitative claim that is not measured must remain visibly labelled as illustrative.

4. **Add informative graphics to the AI section**, at minimum:
   - **(a)** A graphic/diagram showing how a context window is composed — what input tokens contain and what output tokens contain, with an explanation of each part and why it occupies the space it does. This must be a real improvement over the current thin two-column list.
   - **(b)** A **separate** chart comparing the three techniques along three axes: impact on the context window, token usage, and quality of results obtained. This is in addition to the context-window diagram, not a replacement for it.

5. **Create a new, separate section** presenting concise technical implementation details:
   - how the frontend works and what it is responsible for;
   - how the backend works and what it is responsible for;
   - how the two relate (offline-first local levels, additive backend, level-id mapping, merge policy, best-effort leaderboard, JWT auth);
   - which architecture each repository uses, and the impact of those architectures on software development (testability, isolation of rules, substitutable adapters);
   - the AOP aspect implemented in the project — as verified in the audit above (logging/performance and exception handling applied globally; security/authorisation applied per-route via guards and the `@Roles` decorator). Do not describe security as the global aspect. Do not state anything not verified in the code.

   Section numbering must stay correct and sequential across the whole page after this section is inserted.

6. **Keep the page bilingual EN/ES, self-contained, and visually consistent** with the current design. Every new string needs both EN and ES. New graphics must survive a language toggle (canvas redraw included) and must not introduce any external network dependency.

---

## Constraints

- Changes are limited to `docs/pages/` plus documentation updates (`docs/CODEX_HANDOFF.md`, `harness/context/phase_registry.md`, `harness/metrics/improvement_log.md`).
- Do **not** modify `lib/`, `assets/`, `tool/`, or any application code.
- Do **not** modify or regenerate any files under `assets/levels/`.
- Do **not** modify `backend-poc-arrow` (read-only inspection only).
- Do not modify Git remotes. No automatic commits or pushes.
- Every technical claim on the page must be verifiable against the current codebase and docs. If a claim cannot be verified, either drop it or label it explicitly as illustrative.
- If any task item turns out to require changes outside `docs/pages/` (beyond the documentation updates listed above), **STOP and report before proceeding**.

---

## Validation

- `flutter analyze` / `flutter test`: not applicable unless Dart files were touched (they must not be). Run them anyway as a no-regression sanity check if convenient.
- `node tool/gen_levels.js --validate-only`: not applicable (no level files touched).
- Load `docs/pages/index.html` in the Browser pane over `file://` and confirm: all sections render in order with correct numbering, no console errors, no failed network requests (only the three local files), both new graphics draw correctly.
- Toggle EN → ES → EN and confirm: no empty renders, no untranslated strings, `<html lang>` updates, the canvas chart redraws with translated labels, and the `illustrative` tag survives any title translation.
- Check at 375px width: no horizontal body overflow; multi-column blocks collapse to one column.
- Grep `docs/pages/` for `capstone`, `thesis`, `grado`, `tesis`, `degree` — must return zero hits.

---

## After Completion

Report:
1. Audit summary (what was found and corrected).
2. Files changed.
3. How each TASK item (1–6) was addressed.
4. Any deviations from this phase document, and why.
5. The exact Git commands for manual audit, commit, and push — do not run the commit or push yourself.

Then update:
- `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
- `harness/context/phase_registry.md`.
- `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
