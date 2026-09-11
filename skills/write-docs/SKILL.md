---
name: write-docs
description: Use when project documentation is needed — user stories, test plan + QA checklist, or README/onboarding/deployment. One skill, menu-driven; replaces write-user-stories, write-test-docs, write-project-docs.
---

# Write Docs

**Type:** Engineer (light)

## Overview

One entry point for every generated document. Asks which set is needed, then runs only that mode — or all three in sequence (stories feed the test plan).

| Mode | Output files | Reader |
|---|---|---|
| **stories** | `docs/product/user-stories.md` | product owner / QA |
| **tests** | `docs/testing/test-plan.md`, `docs/testing/manual-qa.md` | QA before release |
| **project** | `README.md`, `docs/onboarding.md`, `docs/deployment.md` | humans — no AI mentions allowed |
| **all** | everything above, in the order stories → tests → project | — |

Merged from `write-user-stories` + `write-test-docs` + `write-project-docs` in v5.0.0 — three skills with one shape (pre-flight → read inputs → generate → summary) and zero real invocations as separate commands.

## Process

### Step 0: Pre-flight (shared by all modes)

1. Read `CLAUDE.md` from `pwd`. If missing → STOP: "No CLAUDE.md found — are you in the right project?" Extract project name, stack, platform.
2. Ask which mode: **stories / tests / project / all** (skip the question if the user already named one).
3. Verify the mode's required inputs (table below). For each missing required file, ask: "(a) create stub and continue / (b) run the producing skill or mode first / (c) abort". Never write anything on abort.

| Mode | Required | Optional |
|---|---|---|
| stories | `docs/product/prd.md` | `docs/architecture/api.md`, `system.md`, existing `user-stories.md` |
| tests | `docs/product/prd.md`, `docs/product/user-stories.md` | `docs/architecture/api.md`, existing test docs |
| project | `CLAUDE.md`, `docs/architecture/system.md` | `docs/architecture/api.md`, existing `README.md`, deploy configs |

4. **project mode only:** scan the tree for deploy configs (`Dockerfile`, `docker-compose.yml`, `.github/workflows/*.yml`, `vercel.json`, `fly.toml`, `railway.toml`) — they shape the deployment guide.

**Universal rules (all modes):** read input files in FULL; existing outputs are merged, never clobbered — preserve user-edited sections; dispatch and model tiers per `_shared/references/orchestration-conventions.md`; every step follows the exit-criteria contract in `_shared/references/exit-criteria.md`.

**Exit criteria:** mode chosen; every required input for that mode exists and has been read in full; on any missing input the user chose stub / produce-first / abort.
**Evidence:** the mode, and the input paths with their line counts.
**Blocker:** generating from a stub input as if it were real content — a test plan derived from an empty PRD documents nothing and reads as if it does.

### Mode: stories → `docs/product/user-stories.md`

Runs inline in Opus main (one file — dispatch overhead isn't worth it). Scan the codebase (route handlers, screens, tests, UI wiring) to determine what is **actually implemented** vs described in the PRD.

Story format:

```markdown
## [Feature Area]

### US-NNN: [Short title]
**As** [role], **I can** [action], **so that** [benefit].

**Acceptance criteria:**
- [ ] [Specific verifiable check]

**Status:** ✅ Done / 🚧 Partial / ❌ Not started
**Implemented in:** [file paths or "not yet"]
```

Rules: human-readable language, no internal class names; each criterion independently verifiable by QA without reading code; **status reflects actual code state** (✅ = implementation exists AND tests cover it); sort ✅ → 🚧 → ❌; one section per feature area.

**Exit criteria:** every story's status was determined by looking at code and tests, not at the PRD's intent; every ✅ names the files implementing it; pre-existing user-written stories survive verbatim.
**Evidence:** the ✅/🚧/❌ counts, and the file paths cited per ✅ story.
**Blocker:** a story marked ✅ on the strength of an implementation with no test covering it — that is 🚧, and the distinction is the entire value of this document.

### Mode: tests → `docs/testing/test-plan.md` + `docs/testing/manual-qa.md`

The two files are independent — dispatch **two `Agent` calls in a single message** (concurrent), each `model: "sonnet"`, each owning one path. Opus main validates coverage-target semantics after both return.

**test-plan.md structure:** coverage-targets table (Unit 70% / Integration core flows / E2E smoke; runner per stack — `pytest`, `go test ./...`, `xcodebuild test`), test categories derived from user stories (every ✅ story gets a Unit or Integration entry; every 🚧 story gets a `[ ]` task), stack notes (runner command, CI hook, fixtures path).

**manual-qa.md structure:** pre-flight block (build installed, data seeded, logs visible), per-feature-area happy path + edge cases (`[action] → [expected observable result]`), cross-cutting checks adapted to stack — iOS: Dark Mode, Dynamic Type, VoiceOver; web: zoom 200%, screen reader; backend-only: skip cross-cutting.

**Exit criteria:** every ✅ story has a Unit or Integration entry and every 🚧 story has an unchecked task; every manual-QA step names an observable result a tester can see without reading code; the runner command matches the project's actual stack.
**Evidence:** story-to-test-entry coverage count; the runner command, taken from the project rather than from the stack's convention.
**Blocker:** a QA step whose expected result is "works correctly" — unobservable, and therefore untestable by the person this file is written for.

### Mode: project → `README.md` + `docs/onboarding.md` + `docs/deployment.md`

Three independent docs — dispatch **three `Agent` calls in a single message**, each `model: "sonnet"`, each owning one path.

- **README.md** — one-paragraph description, run-locally block, project structure, API overview (backend only), link to deployment guide.
- **docs/onboarding.md** — prerequisites with versions, setup steps (clone → `.env` → install → run), architecture overview summarised from `system.md` for a newcomer, key files, dev workflow (branching, PR, style), test command, who-to-ask.
- **docs/deployment.md** — environment requirements, concrete deploy steps derived from the configs found in Step 0.4 (stub guidance if none), env-vars table, rollback procedure, monitoring/logging pointers.

**No-AI-mention gate (Opus main, never delegated):** after the three return, grep the outputs for `Claude` / `CLAUDE.md` / `.claude/` / "AI" and fix any leak. These documents are for humans.

**Exit criteria:** the three files exist; the grep returns nothing; the deploy steps derive from configs actually found in Step 0.4, or the file says plainly that none were found.
**Evidence:** `grep -riE 'claude|\.claude/|\bAI\b' README.md docs/onboarding.md docs/deployment.md` — empty.
**Blocker:** invented deploy steps for infrastructure this project does not have. A deployment guide describing a pipeline that does not exist is worse than a stub saying none was found.

### Summary

```
✓ write-docs complete
  Mode: <stories | tests | project | all>
  Files: <list with created | updated per file>
  <mode-specific line: story counts ✅/🚧/❌ · coverage targets set/stub · deploy configs detected>
  Next: /vladyslav:pre-release-check  — verify the release before deployment
```

**Exit criteria:** every file listed is on disk with the created/updated label matching what actually happened.
**Blocker:** listing a file as updated when the merge preserved it unchanged — say unchanged.

## Why this is a Light Engineer skill

- Generation is semantic work (code reality → product language) — stays in-model; but each mode is one predictable write-pass, so no Heavy Engineer contract tax.
- Independent files fan out to parallel `sonnet` subagents (tests: 2, project: 3); single-file stories mode runs inline.
- Judgment steps — coverage-target semantics, preservation, the no-AI-mention gate — never leave the Opus main session.
- Fixed output paths per mode; no allowlist enforcement needed.
