# Changelog

## v5.0.0

**BREAKING:** five unused skills removed after a usage audit. Recover any of them from git history (`git log --diff-filter=D --name-only`) if ever needed again.

### Removed
- **`discover` + `discover-apple-check`** — product-discovery research pipeline. Replacement: fill `start-project.md` sections 6–10 manually or with a one-off AI-research prompt; for iOS rejection-risk call the `apple-appstore-reviewer` skill directly.
- **`design-sync` + `design-page`** — design-token canonization and Pencil screen generation. The Design System Discipline *rule* (global CLAUDE.md) remains in force; `templates/DesignSystem.md` and the `init-project` design-system module are kept.
- **`help`** — static catalogue; superseded by `orchestrate` as the entry point and by README/SkillsManual as references.
- **`save`** — merged into `qsave` (transcript audit: 13 real invocations of qsave vs 0 of save). `qsave` gained the `preference` room type and an explicit-content mode ("qsave: <content>"); explicit wing override ("qsave to ops") already existed.
- **`write-user-stories` + `write-test-docs` + `write-project-docs`** — merged into one menu-driven **`write-docs`** (modes: stories / tests / project / all). Same outputs, same structures, same parallel-sonnet fan-out; one command instead of three (all three had 0 real invocations).
- `scripts/extract-tokens.sh` — orphaned by `design-sync` removal.

### Added
- **Thematic MemPalace wing `ops`** — cross-project operational knowledge (Docker patterns, DigitalOcean deploys, alembic pitfalls) now has a documented home; `save`/`qsave` accept an explicit wing override ("save to ops"). Convention documented in `_shared/references/mempalace-record.md`.
- The `orchestrate` activation trigger is now installed in the user's global `~/.claude/CLAUDE.md` ("Orchestrator Entry Point").

### Changed
- Skill counts and MemPalace-dependency lists updated everywhere (README, CLAUDE.md, SkillsManual, plugin description: 7 skills require MemPalace).
- `orchestrate` routing table: UI/visual work now routes through the Design System Discipline rule + `add-feature`/`fix-bug` instead of the removed design skills.

## v4.9.0

Orchestrator entry point, a security step `fix-bug` never had, and bounded self-repair on the quality gate.

- **`orchestrate` (new skill)** — single entry point for code work. Classifies a raw request, announces the route in one line, delegates via the `Skill` tool. Reimplements no pipeline. Trivial work (typo, version bump, one-liner, git operation) deliberately bypasses it — wrapping a typo in a full pipeline violates the ladder rule.
- **`fix-bug` Step 6.5 (new)** — invokes `owasp-security` on the fix diff. Previously `owasp-security` was wired only into `add-feature` Auto mode, so bug fixes shipped with no security review at all.
- **Bounded self-repair (`add-feature/references/auto-mode.md`)** — *quality* failures (tests, hygiene, HIGH review finding, security finding) now get up to 2 automatic repair attempts before escalating. *Scope* failures (contract changed, read-only file touched, >2 files outside plan, `SCOPE EXPANSION REQUIRED`) still escalate immediately and are never self-repaired — Scope Sentinel stays absolute. A new "Forbidden repairs" section bans the predictable cheats: deleting/skipping tests, weakening assertions, narrowing the security scope, or adding suppressions.
- **`add-feature` Step 0.5** — accepts a Manual/Auto mode supplied by `orchestrate` instead of asking a second time.
- **`save` wing derivation fixed** — it lowercased the derived wing, contradicting both `scripts/derive-wing.sh` and `_shared/references/mempalace-record.md` ("case preserved"). Wings such as `Svitlana` and `phD` resolved to names that match nothing. `save` now defers to the shared reference for both the wing algorithm and the record shape, which is what kept `qsave` correct.

## v4.8.0

Optional CodeGraph integration — faster code navigation for the scanning skills, zero new required dependency.

- **`_shared/references/codegraph.md` (new)** — contract for the optional CodeGraph local index (detect → task/command map → caveats → grep/LSP fallback). CodeGraph is never required: absent it, `ingest` / `add-feature` / `fix-bug` behave exactly as before.
- **Pointers added** — `ingest` (Step 4), `add-feature` (Step 1), `fix-bug` (Step 4) now prefer `codegraph_explore` / `impact` when available, falling back to grep/Glob/LSP otherwise.
- **Self-heal Tier 2** — now offers an optional `codegraph init` (separate y/n) when the CLI is present; skipped silently otherwise.
- **`.codegraph/` gitignored** — added to the `init-project` (`core.sh`) and `attach-project` scaffolders; the local index is machine-specific build output.
- **README / CLAUDE.md** — new "Optional: CodeGraph code index" section and an optional-dependency note; the required-MemPalace lists are unchanged.

## v4.7.0

Self-heal shell + plan-first discipline for the code-lifecycle skills.

- **Self-heal shell (`_shared/references/self-heal-shell.md`, new)** — when `add-feature`
  or `fix-bug` starts in a directory with no `CLAUDE.md`, Step 0 now offers a two-tier
  inline bootstrap (Tier 1: bare shell via `attach-project.sh`; Tier 2: optional
  `ingest`) instead of dead-ending. Nothing runs without a `y/n`. `init-project` /
  `attach-project` remain available as explicit commands.
- **`fix-bug` plan-first triage (Step 4.5)** — after diagnosis, the skill analyzes the
  fix, recommends direct-vs-plan while surfacing critical-path risk, and lets the user
  decide. The plan path writes a proportional plan + approval before any code changes.
- **`fix-bug` MemPalace `problem` record (Step 8)** — a successful fix now records root
  cause + fix + regression test to the project wing (`check_duplicate` first), closing
  the gap versus `add-feature` (which already wrote a `decision`).

## v4.6.0

Quality-system hardening: dead standards removed, gates made deterministic.

- **Removed orphaned per-language standards** — `skills/init-project/references/stack-{swift,go,python,kotlin,flutter,other}.md` + `backend-shared.md` were unreferenced since the v4.4.0 bash-module rewrite of `init-project`. Per-project conventions come from the project itself (`ingest`, `design-sync`), not from plugin-global prose.
- **Removed the Heavy Engineer contract artifacts** — `skills/_shared/references/{subagent-preamble,yaml-return,present-summary}.md` and `scripts/parse-yaml-return.sh`; no consumer since v3.1.0. CLAUDE.md / README / SkillsManual / architecture doc no longer present the tier as live.
- **`orchestration-conventions.md`** — dropped `pre-release-check` from the consumer list (it reads the Apple reviewer skill via the Read tool, never dispatches).
- **Validator Check F (orphan references)** — `scripts/validate-skills.sh` now fails when any `skills/*/references/*.md` has no consumer among SKILL.md files, `commands/`, `scripts/`, or CLAUDE.md. References citing each other do not count — that is exactly how the Heavy Engineer contract rotted unnoticed. 5 new harness tests (26 total).
- **`scripts/quality-gate.sh` (new)** — deterministic per-task "done" gate run in the target project: tests (given or auto-detected command) + diff hygiene (conflict markers, `REPLACE_ME`, debugger leftovers) + high-precision secret shapes + optional plan-scope check (delegates to `check-plan-scope.sh`). Single-line JSON report; exit code is the gate. 15-test harness in `scripts/test-quality-gate.sh`.
- **`add-feature`** — Auto-mode Step 6 guard rails and Step 6.5 test check now run through `quality-gate.sh` instead of prose instructions (the ≤2-files-outside-plan tolerance is preserved at the skill layer); contract baseline is now a `<contract>.sha256` file consumed by the gate. Manual mode runs the gate before the final review (Step 7).
- **`fix-bug`** — Step 5 requires a green `quality-gate.sh` run before code review.

## v4.5.0

- `smoke-test-skills` skill + `scripts/validate-skills.sh`: deterministic repo-wide
  static validation of all skills (frontmatter, command delegation, cross-references,
  Architect `model=` rule, README↔MemPalace sync), with a `scripts/test-validate-skills.sh`
  harness. Stage A of the batch smoke-test; run via `/vladyslav:smoke-test-skills`.

---

## v4.4.0

- `init-project` rewritten as a modular adaptive orchestrator: bare AI shell (CORE) by
  default; `interactive` mode adds docs / backend-infra / agents only on explicit
  confirmation ("don't know → don't create").
- `scripts/scaffold-project.sh` decomposed into idempotent `scripts/modules/*.sh`
  (core, docs, design-system, architecture, docker, postgres, redis, alembic,
  backend-skeleton, agents) with a shared `_lib.sh` and a `tests/` suite.
- Roadmap-gate inherited by `init-project`; smart context-aware `Next:` suggestion.
- No code scaffolding for frontend/Swift — handled by native tooling. `attach-project`
  unchanged.

---

## v4.3.2 — 2026-06-17

Shareable global-instructions template. No skill behavior changes.

### Added

- **`examples/CLAUDE.example.md`** — a sanitized, public version of the global `~/.claude/CLAUDE.md` that pairs with this plugin. Includes the new **"the ladder"** rung (YAGNI → stdlib → native → existing dep → one line → minimal code) in the Minimal Change Principle, plus a matching check in the Code Review checklist. Private data (project/wing list, personal stats, people's names) removed; MemPalace / QSave / Compact-Save sections marked as plugin-dependent.

### Changed

- **`README.md`** — added a pointer to `examples/CLAUDE.example.md` under Requirements.
- **`.claude-plugin/plugin.json`** — version 4.3.1 → 4.3.2.

---

## v4.3.1 — 2026-06-14

Operational safety net for the MemPalace dependency. No skill behavior changes.

### Added

- **`scripts/ensure-mempalace.sh`** — idempotent self-heal script that guarantees the MemPalace MCP server is registered at **user scope** (global, so it covers every project — current and future — with zero per-project setup). If the user-scope record is already present it does nothing; if it was lost (fresh machine, reset `~/.claude.json`, accidental `claude mcp remove`) it re-registers it after sanity-checking the interpreter. Override via `MEMPALACE_INTERP` / `MEMPALACE_PALACE_PATH`.

### Changed

- **`docs/operations/dependencies.md`** — new sections explaining *why* MemPalace works in every project automatically (user scope vs project/local scope, and that `--settings` launch profiles only touch `enabledPlugins`, never `mcpServers`), how to verify it (`claude mcp get mempalace`), and how to run the self-heal script.
- **`.claude-plugin/plugin.json`** — version 4.3.0 → 4.3.1.

---

## v4.3.0 — 2026-06-11

New `qsave` skill + a fix to the canonical wing-deriver. Closes the mid-session memory-capture gap and removes a latent split-brain wing bug.

### Added

- **`skills/qsave/SKILL.md` + `commands/qsave.md`** — `/vladyslav:qsave`, a zero-question quick-save. Derives the most salient decision/problem/milestone from the current conversation and files it to the wing in the `[WHAT]/[WHY]/[FILES]/[DATE]` shape. Sits between `compact-save` (task-resume state, fires on compaction) and `save` (full Q&A). Intended to also be **offered proactively** by the assistant at task completion — see the global `CLAUDE.md` rule. Requires MemPalace.
- **`docs/operations/wing-migration.md`** — how to detect and merge split / duplicate MemPalace wings (case mismatches, stale prefixes), for users upgrading from ≤ v4.2.0. Includes a prompt-based and a script-based merge, plus the personal-miner fix.

### Changed

- **`scripts/derive-wing.sh`** — simplified to **basename-only** (separators normalized to hyphens; case preserved). Removed the lowercasing step (which turned `phD` → `phd`) and the `detect-stack.sh` prefix-prepend step (which turned `vladyslav-skills` → `plugin-vladyslav-skills`). Both diverged from the real wing names in the palace and from the `SessionEnd` miner's bare-basename naming, silently splitting a project's memory across two wings. The canonical wings already carry their convention prefix in the directory name where one applies.
- **`skills/_shared/references/mempalace-record.md`** — wing-derivation guidance updated to match the basename-only algorithm.
- **`README.md`, `.claude-plugin/plugin.json`** — MemPalace-dependent skill count 9 → 10; added `qsave` to the skills tables and Session Continuity section; version 4.2.0 → 4.3.0.

---

## v4.2.0 — 2026-05-31

Opus 4.8 orchestration pass. Centralises the subagent-dispatch contract into one shared reference and applies safe parallel fan-out + conservative model overrides where the work is genuinely independent. Process discipline (approval gates, contract-first, Blast-Radius, MemPalace `check_duplicate`/path-validation, never-overwrite, the Apple-review prompt contract) is unchanged.

### Added

- **`skills/_shared/references/orchestration-conventions.md`** — single source of truth for `Skill` vs `Agent` vs `Workflow`, model tiers (`opus` reasoning / `sonnet` generation / `haiku` mechanical, conservative default), and parallelism-safety rules (what is / is not safe to fan out). Extends the model-override rule in `CLAUDE.md`; does not replace it.
- **`docs/operations/dependencies.md`** — install / update steps for the MemPalace MCP server (required) and Graphify (optional, ad-hoc code knowledge-graph; evaluated and deliberately **not** integrated into any skill). Includes the interpreter-pinning gotcha for the MemPalace MCP `command`.

### Changed

- **`write-project-docs`** — the three independent doc generations (README + onboarding + deployment) now fan out to parallel `sonnet` subagents (~3× wall-clock). Opus main keeps pre-flight, the no-AI-mention gate, and the merge.
- **`write-test-docs`** — test-plan + manual-QA generated as two parallel `sonnet` subagents (~2×). Coverage-target semantics and preservation stay in Opus main.
- **`ingest`** — the two scan scripts run in parallel (Step 2); doc synthesis (`sonnet`) and MemPalace decision-extraction (`opus`) run as a concurrent fan-out (Steps 4+5) once the Step 3 user gate is settled. MemPalace writes still serialise behind `check_duplicate`.
- **`discover`, `design-sync`, `discover-apple-check`** — read-only MemPalace search batches now dispatched as parallel reads. The hypothesis/known-risk gates remain serial. `discover`'s section chain (4→5→6→7) is explicitly documented as a genuine dependency pipeline that must **not** be parallelized.
- **`add-feature`, `fix-bug`** — Step 1 context-file reads parallelised; both now point to `orchestration-conventions.md` for dispatch/model/parallelism rules.
- **`design-page`** — added a pointer to the shared reference; screen drawing stays on `opus` (design is judgment, not mechanical generation).
- **`CLAUDE.md`, `docs/architecture/system.md`** — document the new shared reference and unify the model-override guidance.
- **`examples/mcp-config.example.json`** — corrected the MemPalace example from a stale `node`/`dist/server.js`/`MEMPALACE_DB_PATH` config to the real Python config (`python3 -m mempalace.mcp_server`, `MEMPALACE_PALACE_PATH`), with an absolute-interpreter `command`. `README.md` Requirements links to the new dependencies doc.

### Deliberately NOT changed

- The 34-line `apple-appstore-reviewer` prompt in `discover-apple-check` Step 4 — it is the reviewer's contract (9 guideline areas + decide-now/during/before format), not orchestrator hand-holding. Trimming it would shrink Apple-review coverage.
- `init-project`, `attach-project` (pure bash), `save`, `compact-save`, `help`, `swiftui-pro` — no meaningful dispatch to parallelise; forcing changes would be churn.

---

## v4.1.0 — 2026-05-15

New `save` skill for saving semantic knowledge to MemPalace on demand — without compaction, without task-state framing.

### Added

- **`vladyslav:save`** (`skills/save/SKILL.md`, `commands/save.md`) — Engineer (light) skill. Saves a single knowledge record (decision / preference / milestone / problem) to MemPalace for the current project wing. Duplicate-checks before writing. Triggered by `/vladyslav:save`, "save to MemPalace", "remember this", "запам'ятай це".

  Complements `compact-save`: `compact-save` captures *task state before compaction* (structured YAML: task/files/next); `save` captures *semantic knowledge at any time* (decisions, preferences, milestones).

### Changed

- `README.md`, `SkillsManual.md`, `docs/diagrams/skill-flows.md` — updated to include `save` in all relevant sections.

---

## v4.0.1 — 2026-05-11

Pure-docs patch closing the two TODOs deferred from v4.0.0. No code or skill behaviour changes.

### Changed — `SkillsManual.md`

- **Example 1 (chess-duel) refreshed** — removed the v1.x `/model opus` manual switching artifacts:
  - Step 1 label: `(Engineer Sonnet)` → `(Engineer light — bash-driven, v3.0+)`. Body now mentions `scripts/scaffold-project.sh` and ~1-second runtime.
  - Step 3 label: `(Architect Opus). Перемикаєш: /model opus` → `(Architect, в тій самій сесії)`.
  - Step 4 label: `(Architect Opus)` → `(Architect)`.
- **New "Helper scripts" section** added near the end (before the footer). Groups all 15 scripts into three buckets: Discovery/detection (7), Scaffolding (4), Verification/reporting (4). Cross-links to `docs/architecture/system.md` as the canonical reference.

### Migration

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…or skip — v4.0.1 only changes documentation. Runtime is identical to v4.0.0.

---

## v4.0.0 — 2026-05-11

**BREAKING.** Removes the deprecated `analyze-project` and `seed-mempalace` skills (introduced as stubs in v3.3.0 when `ingest` superseded them). All cross-references across SKILL.md, docs, diagrams, README, and SkillsManual cleaned up. SkillsManual deep-refreshed to v3.x/v4.0 reality.

### Removed (BREAKING)

- `skills/analyze-project/` — entire directory deleted
- `skills/seed-mempalace/` — entire directory deleted
- `commands/analyze-project.md` — deleted
- `commands/seed-mempalace.md` — deleted

Users on automation calling these slash commands will see "command not found" after `/plugin update`. Migrate to `/vladyslav:ingest` — it produces both outputs (architecture docs + MemPalace records) from a single source-of-truth scan.

### Changed (cross-reference cleanup)

14 files updated to remove or replace stale references:

- `README.md` — "Deprecated" table removed; MemPalace skill list updated; Architect table dropped both, added `swiftui-pro` and `ingest`; Existing-project workflow now `attach-project → ingest → add-feature`; New-project workflow now `init-project → discover → add-feature → ...`; Superpowers integration table updated.
- `CLAUDE.md` — MemPalace-requiring skills list: `seed-mempalace` → `ingest`.
- `docs/architecture/system.md` — Architect examples cleaned of deprecation note; `scan-architecture.sh` row updated; `verify-pwd.md` consumers list updated; script count 13→15.
- `docs/diagrams/skill-flows.md` — skill count 18→16; `analyze-project` and `seed-mempalace` flowchart blocks deleted; new `ingest` flowchart added; `attach-project` done-node updated to `→ /ingest`.
- `docs/diagrams/skills-ecosystem.md` — count 18→16; replaced two old nodes with `ingest`.
- `docs/diagrams/workflows.md` — New Project flow uses `/ingest`; Existing Project flow collapsed from `seed-mempalace + analyze-project` two-step to single `ingest` step.
- `skills/attach-project/SKILL.md` — `Next:` line: `analyze-project` → `ingest`.
- `skills/discover-apple-check/SKILL.md` — option 1 in the no-records warning updated.
- `skills/help/SKILL.md` — full catalogue rewrite to v3.x taxonomy.
- `skills/ingest/SKILL.md` — Overview no longer says "Replaces (deprecates)"; "When to use" cleaned; old "Migration from analyze-project / seed-mempalace" section replaced with "Re-running ingest on a previously-seeded project" (the merge/re-seed flow handled in Step 3).
- `skills/write-project-docs/SKILL.md` — required-input fallback prompt: `analyze-project` → `ingest`.
- `skills/_shared/references/mempalace-record.md` — "Used by" list updated.
- `skills/_shared/references/verify-pwd.md` — consumer list updated; `attach-project` skip reason improved.
- `examples/mcp-config.example.json` — comment string updated.

### SkillsManual.md — deep refresh

Targeted updates to ~10 sections of the manual:

- Prerequisites + MemPalace list — replaced `seed-mempalace` with `ingest`; removed `analyze-project` from "works without MemPalace" list.
- "Приєднання Claude" section — two old entries replaced with single `ingest` entry.
- "Документування проекту" — references updated.
- Scenario A (new project) and Scenario B (existing project) — workflows updated; steps renumbered as `analyze-project` + `seed-mempalace` collapsed.
- Example 2 (python-tax) — steps 1-3 rewritten to use `ingest`.
- "Always requires explicit call" list — updated.
- Full skill list table — `analyze-project` + `seed-mempalace` rows removed; `ingest` row added (Architect 🧠).
- Taxonomy summary — counts updated: Architect 8 skills, Engineer bash-driven 3, Engineer Opus inline 5.
- Footer — `v4.0.0` note added.

Still TODO (low priority, deferred to v4.0.1):
- Example 1 (chess-duel) in SkillsManual still uses `/model opus|sonnet` manual switching (v1.x artifact). Rewriting it requires non-trivial narrative changes, kept for later.
- A dedicated "Helper Scripts" subsection in SkillsManual was NOT added (the canonical reference for scripts lives in `docs/architecture/system.md`).

### Final state

- **16 active skills** (was 18 in v3.3.0 with two deprecated stubs)
- **15 helper scripts** in `scripts/`
- **0 lint failures** across all 16 SKILL.md files
- All v2.x dispatch boilerplate eliminated; all Heavy Engineer skills migrated to Light Engineer (bash or Opus inline)

### Migration

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…and restart Claude. If your automation called `/vladyslav:analyze-project` or `/vladyslav:seed-mempalace`, replace with `/vladyslav:ingest`.

---

## v3.3.0 — 2026-05-11

`ingest` unification — collapse `analyze-project` + `seed-mempalace` into a single Architect skill that runs both bash scans once and produces architecture docs AND MemPalace seed records from the same source-of-truth pass.

### Added

- **`scripts/gather-seed-signals.sh`** (~200 lines) — companion to `scan-architecture.sh`. Collects git signals (head commit, branch, first commit date, last 30 commit subjects, decision-prefixed commits, top-10 most-edited files), package manifest summaries, existing `docs/**.md` paths, ADR file paths, and `CLAUDE.md` presence/size. Emits JSON. Paired with `scan-architecture.sh` these two scripts produce everything an LLM needs to write architecture docs AND seed MemPalace.
- **`skills/ingest/SKILL.md`** (~210 lines, Architect type) — single-pass intake for existing projects:
  1. Verify pwd + wing (via `_shared/verify-pwd.md`)
  2. Run `scan-architecture.sh` → ARCH JSON
  3. Run `gather-seed-signals.sh` → SIGNALS JSON
  4. Check existing MemPalace state (empty / stale / curated) and ask user policy
  5. Write `docs/architecture/{system,api,db-schema.sql}.md` (preserving user-edited sections)
  6. Extract 10–20 MemPalace records (decisions / problems / milestones)
  7. Verify searchability + update `CLAUDE.md` `## Memory` pointer
  8. Architect report
- **`commands/ingest.md`** — v2.3.2+ Glob+Read dispatch pattern.

Total `scripts/` helpers now: **14**.
Total skills: **18** (added `ingest`).

### Deprecated

- **`skills/analyze-project/SKILL.md`** — 95 → 32 lines. Now a deprecation stub that prompts the user to run `/vladyslav:ingest` instead. Removal scheduled for v4.0.
- **`skills/seed-mempalace/SKILL.md`** — 154 → 32 lines. Same deprecation pattern. Removal scheduled for v4.0.

Both deprecation stubs still register their slash commands so existing references to `/vladyslav:analyze-project` and `/vladyslav:seed-mempalace` don't break — they redirect with a one-line prompt.

### Strategic rationale

The two old skills both started with a discovery pass over the same inputs (git log, package manifests, existing docs, file tree). Running them in sequence meant two separate scans and two LLM passes — and the outputs sometimes told slightly different stories about the same codebase. v3.2.0's `scan-architecture.sh` already extracted the architecture-discovery half into bash. v3.3.0 adds the symmetric `gather-seed-signals.sh` and uses both to drive a single Architect skill, so the two outputs are forced to agree.

Performance: discovery is now ~0.5s for `scan-architecture.sh` + ~0.5s for `gather-seed-signals.sh` = ~1s of bash, vs. two separate Sonnet-dispatched runs of file globbing in v2.x.

### Migration

After merging develop → main:

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…and restart your Claude session.

- New project intake: `/vladyslav:ingest` instead of `/vladyslav:analyze-project` + `/vladyslav:seed-mempalace`.
- Old commands still work but redirect. Existing automation that calls them will keep working until v4.0.

---

## v3.2.1 — 2026-05-11

Pure-docs release synchronising documentation to the v3.0/3.1/3.2 reality. No code or skill behaviour changes.

### Changed

- **`docs/architecture/system.md`** — rewritten end-to-end. Added new `Skill Taxonomy` section documenting the three patterns (Architect / Engineer light bash-driven / Engineer light Opus inline) and the deprecated Heavy Engineer. Updated the `Helper Scripts` table from 9 entries to all 13 active scripts (added `scaffold-project.sh`, `attach-project.sh`, `pre-release-checks.sh`, `extract-tokens.sh`, `scan-architecture.sh`). Added `Slash-command dispatch (v2.3.2+)` section explaining the Glob+Read bypass. Marked the four currently-unused `_shared/references/` files as reserved-for-future-use.
- **`README.md`** — replaced the v2.0 "One-Terminal Workflow" table with v3.x classification (Architect 9 / Engineer light bash 3 / Engineer light Opus 5). Added a deprecation note for Heavy Engineer. Updated the Skills table to group skills by pattern with their consuming script.
- **`docs/diagrams/skill-flows.md`** — `init-project` and `attach-project` diagrams now show the v3.x Light Engineer flow (Pre-flight → resolve plugin root → run bash script → parse JSON → summary) instead of the old Heavy Engineer Sonnet dispatch.
- **`docs/diagrams/add-feature-flow.md`** — last v2.x reference ("next Sonnet prompt") replaced with "next-step suggestion" since the two-terminal workflow is gone since v2.0.

### Verified clean (no v2.x stale references)

- `docs/diagrams/fix-bug-flow.md`
- `docs/diagrams/skills-ecosystem.md`
- `docs/diagrams/workflows.md`
- `SkillsManual.md` (Heavy Engineer / Sonnet subagent terms not present)

### Not changed

- No `SKILL.md` files touched.
- No `scripts/` files touched.
- No new behaviour, no version of any helper changed.

### Migration

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…or skip entirely. v3.2.1 only changes documentation — runtime is identical to v3.2.0.

---

## v3.2.0 — 2026-05-11

Targeted architectural cleanup of the 11 remaining (non-v3.0/v3.1) skills, driven by a fresh architect review that identified hidden deterministic work in `design-sync` and `analyze-project` plus a 6-skill duplication of the `_shared/verify-pwd.md` block.

### Added

- **`scripts/extract-tokens.sh`** (~370 lines) — per-platform design-token extractor for `design-sync`. Auto-detects platform via `detect-stack.sh`, then parses iOS `Assets.xcassets/.colorset/Contents.json` + Swift `Color(hex:)` / `Color(red:)` inline literals + SwiftUI `.font(.system(...))` + SF Symbols + `.padding(N)` (iOS); CSS variables + inline hex + `tailwind.config` (web); Android `colors.xml` (Kotlin). Emits JSON with colors / typography / icons / spacing arrays sorted by usage count. The LLM's job in `design-sync` becomes purely judgemental (drift vs canonical), not mechanical grep.
- **`scripts/scan-architecture.sh`** (~280 lines) — architecture inventory scanner for `analyze-project`. Emits JSON of `{stacks, entry_points, routes, schema_files, deps, doc_files}`. Detects routes for FastAPI, Flask, Express, and Go stdlib 1.22+. Detects schemas for SQL migrations, Prisma, Drizzle, Alembic.

Total `scripts/` helpers now: **13**.

### Changed

**Six skills now reference `_shared/references/verify-pwd.md`** instead of inlining the 11-22-line wing-derivation + path-validation block:
- `add-feature` (Step 0.1) — 295 → 278 lines (kept skill-specific "extract project name from CLAUDE.md")
- `fix-bug` (Step 0) — 118 → 104 lines
- `discover` (Step 1) — 141 → 146 lines (verify-pwd ref + section-status.sh wiring +5 net)
- `design-sync` (Step 0) — 292 → 247 lines (-45, also dedup of duplicated drift steps after extract-tokens wiring)
- `design-page` (Step 0) — 211 → 210 lines
- `seed-mempalace` (Step 1) — 164 → 154 lines (kept skill-specific multi-source project-name fallback)

**`design-sync` extracted tokens via bash:** Steps 3-5 (was ~80 lines of per-platform grep instructions) → Step 3 (run `extract-tokens.sh`) + Step 4 (drift analysis applied to JSON output, ~12 lines). The semantic "what is canonical vs drift" judgement stays LLM, but discovery (the ~80% mechanical portion) is now 0-token deterministic.

**`analyze-project` extracted architecture via bash:** Step 2 (architecture scan) now calls `scan-architecture.sh` and consumes JSON instead of inlined "read package.json, ls directories, grep for routes" instructions.

**`discover` wired existing helpers:**
- Step 3 "skip done" mode now calls `scripts/section-status.sh docs/product/start-project.md` for filled-vs-pending JSON instead of manual scan.
- Step 3 iOS auto-detection now calls `scripts/detect-stack.sh` instead of manual `swift/ + *.xcodeproj` checks.
- Step 9 verification re-uses `section-status.sh`.

**`discover-apple-check` wired `detect-stack.sh`:** Step 1 iOS verification replaced manual 5-signal check with single script call.

### Skill sizes (post-v3.2.0)

| Skill | v3.1.x | v3.2.0 | Δ |
|---|---|---|---|
| add-feature | 295 | 278 | −17 |
| fix-bug | 118 | 104 | −14 |
| discover | 141 | 146 | +5 |
| design-sync | 292 | 247 | **−45** |
| design-page | 211 | 210 | −1 |
| seed-mempalace | 164 | 154 | −10 |
| analyze-project | 90 | 95 | +5 |
| discover-apple-check | 181 | 177 | −4 |
| **Net** | **1492** | **1411** | **−81** |

### Skills NOT migrated in v3.2.0

`swiftui-pro`, `compact-save`, `help` — already minimal and right-shaped. Verified leave-alone in the architect review.

### Deferred to v3.3.0 (roadmap)

- **`ingest` unification** — collapse `analyze-project` + `seed-mempalace` into a single skill that runs `scan-architecture.sh` + a future `gather-seed-signals.sh` once and emits both architecture docs AND MemPalace seed-records from one source-of-truth pass. Naturally falls out of v3.2.0's groundwork.
- **`roadmap-ops.sh`** — lift `add-feature` Step 9's roadmap marking (`sed [ ] → [x]`) into a dedicated bash helper. Lower ROI; bundled into v3.3.0.
- **Architect report shared template** (`_shared/references/architect-report.md`) — standardise the `✓ Architect report` shape across 8 Architect skills. Cosmetic, low priority.

### Migration

After merging develop → main:

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…and restart your Claude session. All migrated skills work identically from the user's perspective — same Q&A, same outputs, the difference is invisible except `design-sync` and `analyze-project` are now much faster.

---

## v3.1.0 — 2026-05-11

Heavy → Light Engineer migration for four more skills, following the v3.0.0 `init-project` pattern.

### Changed — `attach-project` (Heavy → Light Engineer)

- **New script `scripts/attach-project.sh`** (~370 lines). Auto-detects stack via `scripts/detect-stack.sh`, then writes only missing files (skip-if-exists semantics): `CLAUDE.md`, `.claude/agents/{docs-agent,code-review-agent}.md`, `.claude/settings.json`, `docs/{architecture/system,product/prd,plans/tasks}.md` stubs, per-stack `.gitignore` appendices (Python / Go / Flutter / Swift / Kotlin / Node / Web / private-mode), per-stack placeholder directories. Idempotent. Does NOT init git (project already has version control) and does NOT scaffold backend code (that's `init-project`'s job).
- **`skills/attach-project/SKILL.md`** rewritten as **Engineer (light)** — 162 → 122 lines. Pre-flight Q&A + Bash invocation + JSON-based summary.
- Smoke verified: Python project (9 files, 0.5s) · idempotent re-run (0 files written, all skipped) · Swift project (auto-detected `ios`).

### Changed — `pre-release-check` (Heavy → Light Engineer + thin LLM)

- **New script `scripts/pre-release-checks.sh`** (~330 lines). Runs the 5 cross-platform checks deterministically: tasks completion (counts `[x]`/`[ ]` in tasks.md), tests (auto-detect runner — pytest / go test / xcodebuild test / npm test — and execute with 300s timeout), config sanity (REPLACE_ME / `*to be filled*` placeholders via `grep-replace-me.sh`), docs sync (stub detection + auto-changelog via `changelog-from-git.sh`), translations (platform-aware detection). Writes `docs/release/pre-release-report-<date>.md` and emits JSON with overall result.
- **`skills/pre-release-check/SKILL.md`** rewritten as **Engineer (light)** — 240 → 112 lines. Cross-platform checks run as bash; only iOS Apple App Store review (Check 6) requires LLM and is dispatched to the `apple-appstore-reviewer` skill conditionally on `platform=ios`. The model only contributes a one-line "overall reason" synthesis at the bottom of the summary.
- Smoke verified on this repo: 0.6s, JSON output correct, report written.

### Changed — `write-*` family (Heavy → Light Engineer, Opus inline)

- **`skills/write-user-stories/SKILL.md`** — 125 → 85 lines.
- **`skills/write-test-docs/SKILL.md`** — 134 → 137 lines (output structure expanded, but boilerplate removed).
- **`skills/write-project-docs/SKILL.md`** — 208 → 194 lines.
- All three now run **inline in Opus main** — no Sonnet subagent dispatch, no YAML return contract, no allowlist enforcement boilerplate. Content generation legitimately needs LLM (translating code/PRD into product-language stories, test plans, READMEs), but the dispatch overhead added cost without value. Each skill now reads inputs → generates inline → writes one to three known output files → renders a summary.

### Aggregate impact

| Skill | v2.3.x lines | v3.1.0 lines | Speed (scaffold step) | Tokens (scaffold step) |
|---|---|---|---|---|
| `init-project` (v3.0.0) | 379 | 183 | ~1s | 0 |
| `attach-project` | 162 | 122 | ~0.5s | 0 |
| `pre-release-check` | 240 | 112 | ~0.6s (5 checks) | 0 |
| `write-user-stories` | 125 | 85 | LLM-bound (inline) | full generation cost |
| `write-test-docs` | 134 | 137 | LLM-bound (inline) | full generation cost |
| `write-project-docs` | 208 | 194 | LLM-bound (inline) | full generation cost |

For the three deterministic skills (`init-project`, `attach-project`, `pre-release-check`): **~8 minutes total runtime in v2.x → ~2 seconds total in v3.1.0** when used end-to-end on a new project. Token cost for those mechanical steps: ~50k → 0.

For the three `write-*` skills: same generation work, ~50 lines of boilerplate eliminated per skill, dispatch overhead (~30s round-trip) removed.

### New scripts

- `scripts/attach-project.sh` — full attach-project scaffolder
- `scripts/pre-release-checks.sh` — 5 deterministic release checks

These join the v2.3.0 / v3.0.0 helpers (`detect-stack.sh`, `derive-wing.sh`, `init-git-repo.sh`, `write-stub.sh`, `grep-replace-me.sh`, `parse-yaml-return.sh`, `section-status.sh`, `changelog-from-git.sh`, `check-plan-scope.sh`, `scaffold-project.sh`) — total **11 bash helpers** in `scripts/`.

### Skills NOT migrated in v3.1.0

`add-feature`, `fix-bug`, `discover`, `discover-apple-check`, `design-sync`, `design-page`, `analyze-project`, `swiftui-pro`, `seed-mempalace`, `compact-save`, `help` — these either need genuine LLM reasoning throughout (semantic decisions on existing code, brainstorm composition, design judgement) or are already lean utility/reference skills.

### Migration

After merging to `main`:

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…and restart your Claude session. All five migrated skills work identically from the user's perspective — same Q&A, same outputs. The difference is invisible except for the dramatic speedup.

---

## v3.0.0 — 2026-05-11

### BREAKING — `init-project` is no longer a Heavy Engineer skill

The scaffolding step in `init-project` (mkdir + cp + sed + git init) was being executed by a dispatched Sonnet subagent in v2.x. That was **architecturally wrong**: none of those operations need LLM thinking. A real-world v2.3.2 smoke run cost **~43k tokens and 8 minutes 34 seconds** to do work that pure bash finishes in **~1 second with 0 tokens**.

In v3.0.0 the subagent dispatch is removed entirely.

### Changed

- **New script `scripts/scaffold-project.sh`** (~580 lines of POSIX bash, no python/node dependency). Accepts every pre-flight parameter via CLI flags and writes the complete scaffold deterministically — base directories, base `.gitignore` with stack-specific appendices, backend files (Python or Go), frontend files (Swift via `xcodegen`, Flutter/Kotlin placeholders, "other" stacks), CLAUDE.md, agent definitions, doc stubs, optional nginx config when a domain is set, optional private-mode gitignore extras. Emits JSON `{status, files_written, files_skipped, warnings, error?}` to stdout. Idempotent: re-running on an existing project skips pre-existing files and reports them in `files_skipped`.

- **`skills/init-project/SKILL.md` rewritten as Engineer (light)** — 379 → 183 lines. Steps are now:
  1. Pre-flight Q&A (Opus main) — unchanged in user experience, identical questions.
  2. Resolve plugin root (via Glob in cache or development clone).
  3. Run `scripts/scaffold-project.sh` with collected parameters (via Bash tool).
  4. Parse the JSON output and render a one-screen summary.

- **No more Sonnet subagent for init-project.** The Heavy Engineer dispatch pattern (preamble, YAML return contract, allowlist enforcement) is retained for skills where it genuinely earns its cost (`add-feature`, `pre-release-check`, `discover` — these need semantic decisions on existing code). For `init-project` the cost was 100% waste.

- **`skills/init-project/references/stack-*.md` retained** as human-readable historical reference. They are no longer composed into a subagent prompt — the same logic now lives directly in `scaffold-project.sh`. They will be removed in v3.1.0 unless they prove useful as documentation.

### Performance

| | v2.x | v3.0.0 | Δ |
|---|---|---|---|
| Time | ~8m 34s | ~1 sec | **−99.8%** |
| Tokens | ~43,000 | 0 (bash) | **−100%** for the scaffold step |
| LLM model needed | Opus + Sonnet | Opus only (for Q&A) | — |

Pre-flight Q&A in Opus main still costs ~2-3k tokens (unchanged).

### Migration

For users on v2.x — no action required. After `/plugin update vladyslav` and a fresh `cla` session, `/vladyslav:init-project` Just Works: same Q&A as before, just instant scaffold instead of an 8-minute pause.

For other heavy-engineer skills (`attach-project`, `write-*`, `pre-release-check`) — the same Heavy → Light migration is on the v3.1.0 roadmap. `attach-project` is the next highest-priority candidate (also ~95% deterministic). `write-*` skills genuinely need LLM for generation but the file-writing wrapper can be lifted out. `pre-release-check` has deterministic checks (test runner, grep, git log) and a small interpretive layer; only the latter needs the model.

---

## v2.3.2 — 2026-05-10

### Fixed

- **Bypass Skill tool dispatch in all 17 commands.** During v2.3.1 smoke-tests, `/vladyslav:<name>` slash-commands were still showing `Successfully loaded skill` repeatedly with no SKILL.md body delivered to the model. Root cause: in current Claude Code (2.1.138), the `Skill` tool — which gets invoked when a command body says `Invoke the X skill` — returns a launch acknowledgement but does not actually deliver the skill body into the conversation. v2.3.1 fixed the pre-existing `disable-model-invocation` block, but did not change this dispatch path.
- All 17 `commands/*.md` rewritten so their bodies tell the model to **read SKILL.md directly via `Glob` + `Read`**, never going through the `Skill` tool. The new pattern is:

  ```
  Locate and read the skill body for vladyslav:<name>. Use the Glob tool with
  pattern '~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/skills/<name>/SKILL.md'
  to find it (the version directory varies). If Glob returns no match, fall back to
  '/Volumes/DevSSD/Development/vladyslav-skills/skills/<name>/SKILL.md' (development clone).
  Read the matched file with the Read tool, then follow its instructions exactly from
  top to bottom. Do not call the Skill tool — load the file directly.
  ```

### Migration

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…and restart your Claude session. `/vladyslav:<name>` slash-commands now load SKILL.md content reliably.

---

## v2.3.1 — 2026-05-10

### Fixed

- **Removed `disable-model-invocation: true`** from all 16 `commands/*.md` frontmatter. The original intent (block automatic model-driven skill invocation while keeping explicit slash-commands available) was broken by current Claude Code semantics: the field also blocked the `Skill` tool from delivering the SKILL.md body to the model when a slash-command was used. Result was endless `Successfully loaded skill` echoes with no instructions reaching the model. Removing the field restores normal slash-command behaviour. Skills still self-describe in their `description:` field so the model knows when *not* to invoke automatically.
- `marketplace.json` and `plugin.json` synced to v2.3.1.
- `SkillsManual.md` updated to remove the obsolete policy paragraph.

### Migration

After pulling this version, run inside Claude Code:

```
/plugin marketplace update vladyslav-marketplace
/plugin update vladyslav
```

…then restart your Claude session. Slash-commands like `/vladyslav:init-project` will now load the skill body normally.

---

## v2.3.0 — 2026-05-10

Strategic refactor pass: deduplicate boilerplate across heavy-engineer skills, lift deterministic operations into bash scripts, propagate the modular Hybrid layout introduced for `init-project` to the next three largest skills.

### Added

- **`skills/_shared/references/`** — five shared reference files used across 6 heavy-engineer skills:
  - `subagent-preamble.md` — Sonnet subagent role + five mandatory rules (allowlist, no AskUserQuestion, plugin assets, idempotency, reporting)
  - `yaml-return.md` — structured YAML return contract (single source of truth for `status` / `files_written` / `scope_expansion_required` / etc.)
  - `present-summary.md` — orchestrator-side rendering for the four `status` branches plus re-dispatch flow
  - `mempalace-record.md` — required `[WHAT] [WHY] [FILES] [DATE]` record shape and room-type rules
  - `verify-pwd.md` — Step 0.1 contract for architect skills: `CLAUDE.md` check + canonical wing derivation

- **`scripts/` directory** — 9 portable bash helpers replacing deterministic in-skill instructions:
  - `detect-stack.sh` — probes pwd → JSON describing detected stacks
  - `derive-wing.sh` — canonical MemPalace wing name (eliminates case-mismatch bugs)
  - `write-stub.sh` — idempotent placeholder Markdown writer
  - `init-git-repo.sh` — idempotent `git init` + initial commit
  - `grep-replace-me.sh` — quote-safe placeholder grep
  - `parse-yaml-return.sh` — extracts and validates the last fenced ```yaml block from a subagent response
  - `section-status.sh` — scans `start-project.md` for filled vs pending sections
  - `changelog-from-git.sh` — drafts a Markdown CHANGELOG section from `git log`
  - `check-plan-scope.sh` — verifies an `add-feature` Auto-mode diff stays within the approved plan

- **New per-skill references** for the three additional Hybrid refactors:
  - `skills/add-feature/references/auto-mode.md` — Auto-mode-specific Steps 6-8 plus approval map
  - `skills/pre-release-check/references/ios-apple-check.md` — iOS-only Apple-review block
  - `skills/discover/references/discover-section.md` — generic per-section flow plus per-step parameter blocks for Steps 4-7

### Changed

- **All 17 skill descriptions shortened** in frontmatter — total 3437 → 2034 chars (~350 token saving in system prompt). Top three reductions: `design-sync` (375 → 173), `discover-apple-check` (321 → 154), `design-page` (300 → 154).
- **Six heavy-engineer SKILL.md** files refactored to compose from shared references instead of carrying inline boilerplate:
  - `init-project` 439 → 379 lines
  - `attach-project` 215 → 162
  - `write-user-stories` 172 → 125
  - `write-test-docs` 183 → 134
  - `write-project-docs` 259 → 208
  - `pre-release-check` 370 → 320 (further reduced to 240 in the Hybrid pass below)
- **Three additional Hybrid layouts** (SKILL.md + `references/` per skill, following the `init-project` pattern):
  - `add-feature` 388 → 294 lines (Auto-mode → `references/auto-mode.md`)
  - `pre-release-check` 320 → 240 (iOS Apple-check → `references/ios-apple-check.md`)
  - `discover` 330 → 140 (per-section flow → `references/discover-section.md`)
- `docs/architecture/system.md` updated with new `Shared references` and `Helper Scripts` sub-sections under Skill Layout.

### Strategic notes

- Combined effect: **~10k tokens of duplication removed** from skill bodies + **~350 tokens shaved from the system-prompt skill listing**. The latter is what unblocks `vladyslav:*` skills from the `descriptions dropped` budget when many other plugins are installed.
- Lean and untouched (already well-factored): `compact-save` (60 lines), `swiftui-pro` (61), `analyze-project` (89), `help` (106), `fix-bug` (117).
- NOT collapsed: `init-project` ↔ `attach-project` (workflows different — clean-slate vs append-only). `add-feature` ↔ `fix-bug` (phases and ordering differ enough that a shared core would leak).

---

## v2.2.0 — 2026-05-09

### Added

- `.claude/hooks/session-start.sh` — silent SessionStart hook reminding which MemPalace wing this project uses.
- `.claude/hooks/lint-skill-frontmatter.sh` — PostToolUse hook validating SKILL.md frontmatter (`name`, `description`, `Type:`) on every Edit/Write/MultiEdit. Pure bash + awk, no python/node dependency.
- `.claude/hooks/check-docs-sync.sh` — Stop hook that blocks turn-stop with `exit 2` if plugin internals (`skills/`, `.claude/hooks/`, `.claude-plugin/`, `commands/`, `examples/`) were modified without a matching update to `docs/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, or `SkillsManual.md`. Loop-safe via `stop_hook_active` flag. Forces documentation to stay in sync with code automatically.
- `examples/mcp-config.example.json` — copy-paste MCP config block for the MemPalace dependency. Linked from the README Requirements section.
- CLAUDE.md sections: `Review Checklist`, `Skill Testing`, `Hooks`. The checklist enumerates the rules that the new lint hook enforces automatically and the rules that remain manual.

### Changed

- **`init-project` skill restructured into the modular `SKILL.md` + `references/` + `assets/` layout (Hybrid refactor).**
  - Stack-specific scaffolding instructions extracted into `skills/init-project/references/stack-{python,go,swift,flutter,kotlin,other}.md` and `references/backend-shared.md`. Each fragment is composed into the subagent prompt only when its stack was selected in pre-flight.
  - Exclusive file templates moved from the repo-root `templates/` into `skills/init-project/assets/` (preserving the `swift/`, `backend/`, `infra/`, `docs/operations/` subtree). Only `templates/DesignSystem.md` stays at the root because it is shared with the `design-sync` skill.
  - `SKILL.md` shrunk from 621 lines to 439 — pre-flight Q&A and cross-stack scaffolding (CLAUDE.md template, agents, doc stubs, git init) remain in place; everything stack-specific now loads on demand.
  - Subagent dispatch pattern preserved: pre-flight in Opus main → Sonnet subagent writes the scaffold → YAML return contract. No user-facing behavioural change.
  - Added new `Step 1: Compose stack fragments` to the Process section, documenting how Opus main reads the relevant `references/` files and substitutes them into the `<STACK_FRAGMENTS>` placeholder of the subagent prompt.

### Fixed

- `skills/help/SKILL.md` and `skills/swiftui-pro/SKILL.md` were missing the `Type:` line required by `CLAUDE.md` working rules. Added `Type: Engineer (light)` and `Type: Architect` respectively.
- README requirements line previously claimed "9 skills" require MemPalace; the actual list is 8.

---

## v2.0.0 — 2026-05-06

### BREAKING

- **Drop two-terminal workflow.** Single-terminal: Opus main session + Sonnet subagent dispatch for execution work. Manual `/model` switching no longer needed.
- **Architect skills** no longer print `━━━ Next (Sonnet terminal) ━━━` handoff blocks. They run interactively in Opus main and end with a plain "Next steps:" list.
- **Heavy Engineer skills** (`write-test-docs`, `write-project-docs`, `write-user-stories`, `attach-project`, `init-project`, `pre-release-check`) now wrap their body in a Sonnet subagent dispatched from Opus main, with pre-flight Q&A in the main session and a YAML-formatted return contract enforcing a strict file allowlist.
- **Light Engineer skills** (`stash`, `unstash`) keep inline behavior in main thread (~30s utility operations; dispatch overhead would exceed the work).
- Architect skills with internal `Agent(...)` dispatches now annotate every dispatch with explicit `model=` (`"sonnet"` for executor work, `"opus"` for synthesis/research). Affected: `add-feature` (5 dispatches → sonnet), `design-page` (1 dispatch → opus).
- Skill `Type:` headers updated: `Architect (Opus)` → `Architect`; `Engineer (Sonnet)` → `Engineer` (heavy) or `Engineer (light)` (stash, unstash).
- `commands/*.md` files no longer contain `/model …` switch instructions.

### Migration

If you were on the v1.x two-terminal workflow:
1. Close your "Engineer" terminal.
2. Run all skills from a single Opus session.
3. No code changes on your side — skills handle dispatching internally.

### Documentation

- `README.md`, `CLAUDE.md`, `skills/help/SKILL.md` updated to describe the one-terminal workflow.
- New design doc: `docs/superpowers/specs/2026-05-06-opus-subagent-dispatch-design.md`.
- New plan doc: `docs/superpowers/plans/2026-05-06-opus-subagent-dispatch.md`.

---

## v1.8.0 — 2026-04-30

Roadmap gate for `add-feature` and `init-project`.
