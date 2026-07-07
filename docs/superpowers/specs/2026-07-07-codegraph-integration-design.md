# Design: Optional CodeGraph integration

> Created: 2026-07-07
> Status: approved (brainstorming A/A/A, resumed from pause) — pending implementation plan
> Depends on: v4.7.0 self-heal shell (this activates the inert Tier-2 hook left in `self-heal-shell.md`).

## Problem

The code-scanning skills (`ingest`, `add-feature`, `fix-bug`) discover code structure through
grep/Glob/LSP and manual file reads — many tool calls, many tokens. CodeGraph (a local MCP
server: SQLite + FTS5 + tree-sitter AST, MIT, 100% local, no API keys) can return the relevant
code + blast-radius in one `codegraph_explore` call. A hand-test on `python/linkBase` confirmed
real value (blast radius with caller counts + test-coverage annotations + verbatim deduped source).

## Hard constraint — CodeGraph is OPTIONAL, never required

This is the load-bearing rule of the whole design. Unlike MemPalace (required by 10 skills):

- **No skill fails, stops, or degrades in correctness without CodeGraph.** Absent it, behaviour is
  exactly today's grep/Glob/LSP path.
- **CodeGraph is never added to any "required dependency" list** — not the README "Skills that
  require MemPalace" list, not `plugin.json`'s dependency count, not CLAUDE.md's required-deps.
- README and CLAUDE.md present it under an explicitly **Optional** heading.
- Index-building (`codegraph install` / `codegraph init`) is a user/environment action, documented
  but never forced by a skill.

## Decisions (from brainstorming — A/A/A, reaffirmed)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Availability model | **Runtime detect, zero config** — no flags, nothing to remember |
| 2 | Integration form | **Shared reference + one-line pointers** (matches `verify-pwd.md`, `orchestration-conventions.md`) |
| 3 | Index-building | **Not automated** — documented in README + `.codegraph/` gitignored; skills auto-use if present |

## Design

### A. Detection (runtime, zero config)

The shared reference defines a 3-step check the consuming skill runs:

1. Is the MCP tool `codegraph_explore` available in the session? → use it (primary path for
   `add-feature` / `fix-bug`, which run in the main session with MCP).
2. Else: is the `codegraph` CLI on `PATH` **and** does `.codegraph/` exist at the project root?
   → use the CLI (`codegraph explore/impact/callers/files`).
3. Else → grep/Glob/LSP exactly as today. Silent — no "tried and failed" noise.

### B. New shared reference — `skills/_shared/references/codegraph.md`

Single source of truth. Consumers: `ingest`, `add-feature`, `fix-bug`, and the self-heal Tier-2
hook. Contents:

- **Detection** (the 3 steps above).
- **Task → command map:**
  - "what code is relevant to X" / context gathering → `explore`
  - blast radius of changing a symbol → `impact`
  - who calls / is called → `callers` / `callees`
  - project structure → `files`
  - (MCP tool equivalents: `codegraph_explore`, `codegraph_node`)
- **Two caveats from the live test (must be documented so results aren't over-trusted):**
  - *Framework-dispatch blind spot* — decorator/DI/router-registered call edges (aiogram router,
    SwiftUI, DI containers) are under-reported. `impact` / `callers` are a **floor, not a ceiling**;
    entrypoints still need manual verification.
  - *Source blocks are already-Read* — CodeGraph's verbatim source output should be treated as a
    Read already performed (do not re-Read those files); if freshness is in doubt, `codegraph sync`
    (a file-watcher auto-syncs, but sync is the safe manual refresh).
- **Fallback contract:** if unavailable, the skill does exactly what it does today. No behaviour
  change, no error surfaced.

### C. One-line pointers in consuming skills

| Skill | Location | Pointer intent |
|-------|----------|----------------|
| `ingest/SKILL.md` | Step 4 (synthesise architecture docs) | optionally enrich the narrative via CodeGraph per the reference, if an index exists |
| `add-feature/SKILL.md` | Step 1 (read project context) | when exploring code here and in brainstorm/plan, prefer CodeGraph per the reference if available; `impact` helps predict the plan's file-list for the guard rails |
| `fix-bug/SKILL.md` | Step 4 (diagnose) | for root-cause localisation + blast radius, use CodeGraph per the reference if available |

Each is one sentence citing `_shared/references/codegraph.md`, with the grep/LSP fallback implied by
the reference. No step logic is rewritten.

### D. Activate the self-heal Tier-2 hook

`self-heal-shell.md` currently has an inert note: "when CodeGraph lands, Tier 2 additionally offers
`codegraph init`." Replace the note with the live behaviour: in Tier 2, if the `codegraph` CLI is
available, additionally offer (separate, optional) to build the index — still a `y/n`, still optional,
skipped silently if the CLI is absent.

### E. gitignore `.codegraph/`

- `scripts/modules/core.sh` — add `.codegraph/` to the `.gitignore` that `init-project` writes.
- `scripts/attach-project.sh` — add `.codegraph/` to the gitignore append-list.

Rationale: the local index is machine-specific build output, never committed.

### F. Docs / meta

- `README.md` — a new **"Optional: CodeGraph code index"** section: what it is, one-time setup
  (`curl … | sh` → `codegraph install` → `codegraph init`), and an explicit note that it is optional
  and independent of the required MemPalace server. Placed separate from the MemPalace requirement list.
- `CLAUDE.md` (project) — Dependencies section gains one line marking CodeGraph **optional**.
- `CHANGELOG.md` — entry.
- `.claude-plugin/plugin.json` — bump **minor** (`4.7.0` → `4.8.0`); the `description` string's
  "10 skills require MemPalace" count is unchanged (CodeGraph adds no required dependency).

## Non-goals (YAGNI)

- Auto-installing or auto-building the index inside any skill (index-building stays a user action).
- Shipping any MCP config for CodeGraph in the repo.
- Making CodeGraph a hard dependency of any skill.
- Adding CodeGraph pointers to skills that don't scan code (`design-*`, `pre-release-check`, etc.).
- Replacing LSP for point queries — LSP stays better for single-symbol lookups; CodeGraph wins on
  broad impact/blast-radius.

## Error handling / edge cases

- **CLI present but `.codegraph/` absent:** detection step 2 fails → fall through to grep/LSP. A
  skill never runs `codegraph init` on its own (except the explicit Tier-2 self-heal offer).
- **Stale index:** the reference instructs `codegraph sync` when freshness is in doubt; otherwise
  the file-watcher keeps it current.
- **CodeGraph returns nothing / errors:** treat as "unavailable" → grep/LSP fallback. Never block
  the skill on a CodeGraph failure.

## Testing

- `vladyslav:smoke-test-skills` — Check F (orphan references): `codegraph.md` must have consumers
  (it has ≥3: ingest, add-feature, fix-bug; plus self-heal-shell.md, though reference-to-reference
  citations don't count toward Check F — the skill pointers do).
- Frontmatter lint hook — applies to the edited `SKILL.md` files.
- The runtime detect + `explore`/`impact`/`callers` paths were already exercised by hand on
  `python/linkBase` (v1.2.0 CLI, telemetry disabled).
- Smoke run of `ingest` / `add-feature` / `fix-bug` to confirm the pointer prose reads correctly and
  the fallback is unambiguous.

## Rollout

Single minor bump (`4.8.0`). Purely additive and opt-in: projects without CodeGraph installed see
zero change. Projects with it installed and indexed get faster, cheaper code navigation in the three
scanning skills.
