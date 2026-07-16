# PHASE 33 — Nodus Project Landing Page

Read before starting:
- `frontend-poc-arrow/docs/CODEX_HANDOFF.md`
- `frontend-poc-arrow/harness/context/current_constraints.md`
- `frontend-poc-arrow/README.md` (for accurate project/architecture facts)

Git context:
- Working branch: `feat/phase-33-landing-page`
- Base branch: `main`
- Tech stack for this deliverable: HTML, CSS, and JavaScript (static, no build step, no framework).

---

## Mandatory Pre-Implementation

Before writing any code:

1. Audit the facts you will present. Confirm — from the repository, not from memory — each claim before writing it: 30 total levels, 2D/3D modes, challenge modes, progressive difficulty, Flutter + Clean Architecture (Domain → Application → Infrastructure → Presentation), backend Node.js + Express + Prisma, Docker-based deployment, AWS EC2 hosting, and local/cloud backend flexibility.
2. Confirm the three-stage AI-workflow narrative (prompt engineering → spec-driven development → harness engineering) against `harness/` and `docs/` so the description of token/context-window optimization is grounded, not invented.
3. Explain your understanding of the current state.
4. State your confidence level. Must be ≥ 95% to proceed. If lower, ask clarifying questions.
5. **Wait for explicit approval before writing any code.**

---

## Task

Create a **static landing page** that presents the Nodus project. All files live in `frontend-poc-arrow/docs/pages/`. Plain HTML + CSS + JavaScript only — no framework, no build tooling, no external network dependencies (self-contained; assets embedded or local).

Create in `frontend-poc-arrow/docs/pages/`:

- `index.html` — the landing page markup.
- `styles.css` — page styling (responsive; readable on mobile and desktop).
- `script.js` — any interactivity (e.g. the context-window visualization, smooth scroll, section reveal).

The page must contain **exactly four sections**, in this order:

### 1. Project Overview
Describe Nodus: a graph-based puzzle game where the player taps rigid arrows to exit the board. Cover 2D and 3D modes, challenge modes, and progressive difficulty across 30 levels. Position it as a university capstone project.

### 2. AI Workflow Evolution
Present the three-stage evolution of the team's AI-assisted development workflow:
1. **Prompt engineering**
2. **Spec-driven development**
3. **Harness engineering**

Explain how each stage improved token usage and context-window efficiency. Include a **visual** (SVG or Canvas via `script.js`, no external libraries) that:
- Shows context-window composition (input vs. output tokens).
- Shows the improvement in efficiency across the three stages.

### 3. Technical Highlights
Present relevant project data as scannable items/cards:
- Backend deployed on **AWS EC2**.
- **Docker-based** deployment.
- **Local / cloud backend flexibility** (the app runs fully offline on local levels; backend is additive).
- **Flutter + Clean Architecture** frontend.
- **Node.js + Express + Prisma** backend.
- **Graph-based game engine**.
- **30 levels**.
- **Challenge modes**.

### 4. Closing
Conclusions and a thank-you to **Professor Carlos Alonso**. Include these links:
- Backend: `https://github.com/arjperez-dev/backend-poc-arrow.git`
- Frontend: `https://github.com/arjperez-dev/frontend-poc-arrow.git`
- Lucidchart: `https://lucid.app/lucidchart/5c09fbb7-74be-4dc2-89c5-af638b2b2b71/edit?viewport_loc=-2132%2C-1969%2C10447%2C4578%2CZ0MbVBNDveSs&invitationId=inv_7c5f886f-d720-4be1-86f9-55d565e84361`

The page should be visually coherent (consistent palette, spacing, and typography), responsive, and readable without an internet connection.

---

## Constraints

- **Only create files in `frontend-poc-arrow/docs/pages/`.** Create nothing elsewhere.
- **Do NOT modify any source code, test code, or configuration files** in `lib/`, `test/`, `assets/`, or `tool/`.
- Do NOT modify `backend-poc-arrow` or any backend code.
- Do NOT add dependencies or a build step. No CDN scripts, external fonts, or remote assets — the page must be self-contained.
- Do NOT modify Git remotes.
- Do NOT commit or push automatically — manual audit required.
- Every technical claim on the page must be accurate to the repository. Do not overstate or invent metrics; if a token figure is illustrative, label it as illustrative.

---

## Validation

No automated suite applies (static page outside the app source). Manually verify:

- `docs/pages/index.html` opens directly in a browser (via `file://`) and renders all four sections in order, with no console errors and no failed network requests.
- Every fact, number, and link matches the repository and the task above; all three links resolve to the correct targets.
- The context-window visualization renders and communicates both composition (input/output) and cross-stage improvement.
- Layout is responsive (mobile and desktop widths).

Optionally confirm nothing else changed:

```bash
git status            # only new files under docs/pages/
node tool/gen_levels.js --validate-only   # sanity: level data still valid (no files touched)
```

---

## After Completion

1. Update `docs/CODEX_HANDOFF.md` using `harness/templates/handoff_update_template.md`.
2. Update `harness/context/phase_registry.md`.
3. Update `harness/metrics/improvement_log.md`.

---

Do not be verbose. Be direct.
