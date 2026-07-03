# System Architecture

## Skill Taxonomy

The plugin uses three Engineer/Architect patterns. Picking the right one for a new skill is the most important design decision:

### Architect
- **Where it runs:** Interactive in Opus main session, top to bottom.
- **When to use:** The skill makes semantic decisions on existing code, composes narratives, synthesises across multiple inputs, or coordinates parallel subagent dispatches.
- **Examples:** `add-feature`, `fix-bug`, `discover`, `discover-apple-check`, `design-sync`, `design-page`, `ingest`, `swiftui-pro`.
- **Internal dispatch:** Allowed via `Agent(..., model="sonnet")` for executor work (write tests / write impl / run code review / run security check) or `Agent(..., model="opus")` for synthesis/research work (deep analysis, multi-source research, design decisions). When used, the dispatch is explicit and per-step — not a wholesale subagent that owns the whole skill body.

### Engineer (light) — bash-driven
- **Where it runs:** Pre-flight Q&A in Opus main, then a bash script does the work, then a summary is rendered.
- **When to use:** The skill's body is fundamentally deterministic — `mkdir`, `cp`, `sed`, `git init`, grep, file detection, JSON shaping. No LLM thinking is required for the mechanical part.
- **Examples:** `init-project` (calls `scripts/modules/core.sh` + opt-in modules via `scripts/modules/*`), `attach-project` (calls `attach-project.sh`), `pre-release-check` (calls `pre-release-checks.sh`).
- **Performance impact:** Eliminates ~8 minutes and ~40k tokens per invocation versus the v2.x Heavy Engineer pattern, because the scaffold step is now a 1-second bash run instead of a Sonnet subagent grinding through file writes.

### Engineer (light) — Opus inline
- **Where it runs:** Pre-flight Q&A + LLM-driven generation, all in Opus main, with no Sonnet subagent dispatch.
- **When to use:** The skill needs LLM for content generation (translating code/PRD into product-language stories, test plans, READMEs) but the generation is one synthesis pass over known inputs to known output paths — no orchestration, no allowlist enforcement, no YAML return contract.
- **Examples:** `write-user-stories`, `write-test-docs`, `write-project-docs`, `compact-save`, `help`, `swiftui-pro`.

### Heavy Engineer (deprecated)
Pre-flight Q&A in Opus main + Sonnet subagent dispatch for the body + YAML return contract + allowlist enforcement.

This pattern existed through v2.3.x. **As of v3.1.0, no skill in the plugin uses it.** v4.6.0 deleted the contract artifacts (`subagent-preamble.md`, `yaml-return.md`, `present-summary.md`, `scripts/parse-yaml-return.sh`) after two major versions with no consumer — git history preserves them if the pattern ever returns.

## Skill Layout

Each skill lives at `skills/<name>/`. Two layouts are in use:

### Flat layout

Default for short skills (≤ ~250 lines):

```
skills/<name>/
  SKILL.md
```

### Modular layout

For skills with stack/variant-specific instructions that should load on demand:

```
skills/<name>/
  SKILL.md            # thin orchestrator
  references/         # variant-specific fragments (loaded only when relevant)
    <variant>.md      # e.g. auto-mode.md, ios-apple-check.md, discover-section.md
  assets/             # file templates copied verbatim into projects
```

Currently in modular layout: `init-project`, `add-feature`, `pre-release-check`, `discover`. The shared `_shared/references/` directory hosts cross-skill references.

Templates shared across multiple skills stay at the repo-root `templates/` (currently only `templates/DesignSystem.md`, shared between `init-project` and `design-sync`).

## Shared references (`skills/_shared/references/`)

Three cross-skill references, all with active consumers. (The three Heavy-Engineer contract references — `subagent-preamble.md`, `yaml-return.md`, `present-summary.md` — were removed in v4.6.0 after two major versions with no consumer.)

| Reference | Active in | Purpose |
|---|---|---|
| `mempalace-record.md` | All 8 MemPalace-using skills | Required record shape: `[WHAT] [WHY] [FILES] [DATE]` plus room-type rules and wing canonicalisation. |
| `verify-pwd.md` | 6 Architect skills (`add-feature`, `fix-bug`, `discover`, `design-sync`, `design-page`, `ingest`) | Step 0.1 contract: `CLAUDE.md` presence check + canonical wing derivation. Skills reference this instead of inlining the 11-22-line block. |
| `orchestration-conventions.md` | 9 dispatching skills (`add-feature`, `fix-bug`, `discover`, `discover-apple-check`, `design-sync`, `design-page`, `ingest`, `write-project-docs`, `write-test-docs`) | Opus 4.8 dispatch contract: `Skill` vs `Agent` vs `Workflow`, model tiers (`opus`/`sonnet`/`haiku`), and what is / is not safe to parallelize. Skills point here instead of repeating it inline. |

## Helper Scripts (`scripts/`)

Fifteen POSIX-portable bash helpers (macOS + Linux, no python/node dependency). Each has a one-line synopsis at the top of its file. Skills consume their JSON output rather than re-implementing the same `find` / `grep` / `awk` in instructions.

| Script | Used by | Purpose |
|---|---|---|
| `detect-stack.sh` | `attach-project`, `discover`, `discover-apple-check`, `design-sync`, `extract-tokens`, `scan-architecture`, `pre-release-checks` | Probes pwd → JSON `{ios, swift, flutter, kotlin, android, python, go, node, web, backend, plugin, ui, docker}` |
| `derive-wing.sh` | (callable by any skill; currently unused inline — `_shared/verify-pwd.md` documents the algorithm) | Canonical MemPalace wing name (lowercase, platform-prefixed). Eliminates case-mismatch bugs. |
| `write-stub.sh` | `attach-project` | Idempotent placeholder Markdown writer: `# Title\n\n*to be filled*\n` |
| `init-git-repo.sh` | none (legacy — `core.sh` inlines `git init`) | Idempotent `git init` + initial commit; safe to call on existing repos. |
| `grep-replace-me.sh` | `pre-release-checks` | Quote-safe placeholder grep with consistent excludes. |
| `section-status.sh` | `discover` | Scans `start-project.md` for filled vs pending sections. |
| `changelog-from-git.sh` | `pre-release-checks` | Drafts a Markdown CHANGELOG section from `git log` (human edits before commit). |
| `check-plan-scope.sh` | `quality-gate.sh` (scope check delegate) | Verifies the diff stays within the approved plan (files, contract hash, read-only globs). |
| `quality-gate.sh` (v4.6.0) | `add-feature` (Auto mode Step 6 + Manual Step 7), `fix-bug` (Step 5) | Per-task "done" gate: tests + diff hygiene (conflict markers, placeholders, debugger leftovers) + secret shapes + optional plan scope → JSON; exit code is the gate. Tested by `test-quality-gate.sh`. |
| `scripts/modules/core.sh` + `scripts/modules/*.sh` | `init-project` | Modular adaptive scaffolder. `core.sh` always writes the bare AI shell (CLAUDE.md, .claude/settings.json, .gitignore, .remember/). Optional modules (docs, backend-infra, agents, etc.) run only when selected via the interactive menu. |
| `attach-project.sh` (v3.1.0) | `attach-project` | Auto-detect stack + skip-if-exists scaffolder for existing projects. |
| `pre-release-checks.sh` (v3.1.0) | `pre-release-check` | Runs 5 cross-platform release checks (tasks, tests, config, docs, translations) → JSON. |
| `extract-tokens.sh` (v3.2.0) | `design-sync` | Per-platform design-token extractor → JSON (colors / typography / icons / spacing, sorted by usage count). |
| `scan-architecture.sh` (v3.2.0) | `ingest` | Stack + entry points + routes (FastAPI/Flask/Express/Go stdlib) + schemas + deps → JSON. |
| `gather-seed-signals.sh` (v3.3.0) | `ingest` | Git signals (themes, decision commits, most-edited files) + package manifests + existing docs + ADR paths + CLAUDE.md presence → JSON. Companion to `scan-architecture.sh` for the `ingest` skill. |

## Lifecycle Hooks

Four Claude Code lifecycle hooks registered in `.claude/settings.json`. Hook scripts live in `.claude/hooks/` and must be portable bash (no python/node — `python3` on macOS without Xcode license fails silently).

| Hook | Script | Purpose | Failure mode |
|------|--------|---------|--------------|
| `SessionStart` | `session-start.sh` | One-line stdout reminder of the MemPalace wing for this project. Always exits 0. | Never blocks. |
| `PostToolUse` (matcher: `Edit\|Write\|MultiEdit`) | `lint-skill-frontmatter.sh` | Validates SKILL.md frontmatter (`name`, `description`, `Type:`) on every edit to `skills/**/SKILL.md`. | Exits 2 with stderr message — model corrects the edit. |
| `Stop` | `check-docs-sync.sh` | Before Claude stops a turn, blocks if plugin internals changed without matching doc updates. Loop-safe via `stop_hook_active`. | Exits 2 with reminder; model continues working. |
| `PreCompact` | inline `echo` in `settings.json` | Reminds the model to invoke `vladyslav:compact-save` before context summarisation. | Informational only. |

Hook scripts must be (a) idempotent, (b) under ~200 ms, (c) failing closed only when the failure is meaningful.

## Continuity Primitive

`vladyslav:compact-save` (added in 2.1.0, replaced stash/unstash) provides automatic intra-session state preservation. Triggered by the `PreCompact` Claude Code hook before context compaction; stores a minimal YAML snapshot in MemPalace with `room="compact-save"`. No manual resume command — the global `~/.claude/CLAUDE.md` **Compact-Save Continuity** rule re-loads state at session start or after detecting a compaction event. Latest-wins semantics: the newest drawer per wing (by `created_at`) is the live snapshot.

## Slash-command dispatch (v2.3.2+)

After v2.3.2, every `commands/<name>.md` body instructs Claude to read SKILL.md directly via Glob+Read instead of calling the Skill tool. This bypasses a Skill-tool semantics issue in Claude Code 2.1.138+ where invoking a skill via Skill tool delivered the launch acknowledgement but not the SKILL.md body to the model. The slash-command pattern is:

```
Locate and read the skill body for vladyslav:<name>. Use the Glob tool with pattern
'~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/skills/<name>/SKILL.md'
to find it (the version directory varies). Read with the Read tool, then follow
its instructions exactly. Do not call the Skill tool — load the file directly.
```
