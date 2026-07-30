# Optional CodeGraph Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `ingest`, `add-feature`, and `fix-bug` use a local CodeGraph index for code navigation when it is present, falling back to grep/Glob/LSP when it is not — CodeGraph being strictly optional and never a required dependency.

**Architecture:** Pure Markdown-skill + bash-scaffolder edits. One new shared reference (`_shared/references/codegraph.md`) holds the detect/command/fallback contract; three skills gain one-line pointers to it. The self-heal Tier-2 hook is activated. `.codegraph/` is gitignored by both scaffolders. README/CLAUDE.md/CHANGELOG/plugin.json document it as optional. No code, no runtime; verified by the static validator plus greps.

**Tech Stack:** Markdown (`SKILL.md` + `references/*.md`), POSIX bash (`scripts/modules/core.sh`, `scripts/attach-project.sh`), `scripts/validate-skills.sh`, `.claude-plugin/plugin.json` (semver).

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-07-07-codegraph-integration-design.md` — the authority.
- **CodeGraph is OPTIONAL, never required.** No skill fails/stops without it. It must NOT be added to any "required dependency" list (README "Skills that require MemPalace", `plugin.json` description count, CLAUDE.md required-deps). Every pointer/section must state or imply the grep/LSP fallback.
- **Detection is runtime, zero-config:** MCP `codegraph_explore` → CLI + `.codegraph/` → else grep/LSP. No flags, no config file.
- **Shared-reference form:** logic lives in `codegraph.md`; skills get one-sentence pointers only — no step logic rewritten.
- **Validator is the gate:** `bash scripts/validate-skills.sh` must exit 0 at the end of every task. A new `references/*.md` with no consumer FAILS Check F — the reference and its three skill pointers land in the same task.
- **Version bump:** `4.7.0` → `4.8.0` (minor, additive). The `plugin.json` description "10 skills require MemPalace" count is UNCHANGED (CodeGraph adds no required dep).
- **Commit trailer:** end every commit body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Branch:** stay on `feature/quality-system-hardening`.

---

### Task 1: CodeGraph reference + three skill pointers

Traces to spec §B + §C. The reference is inert without consumers (validator Check F), so it ships with all three pointers in one task.

**Files:**
- Create: `skills/_shared/references/codegraph.md`
- Modify: `skills/ingest/SKILL.md` (Step 4 heading area)
- Modify: `skills/add-feature/SKILL.md` (end of Step 1 "Read project context")
- Modify: `skills/fix-bug/SKILL.md` (Step 4 "Diagnose the bug")
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Produces: reference at `skills/_shared/references/codegraph.md`; its basename `codegraph.md` is cited in all three SKILL.md files (satisfies Check F, which matches by basename).

- [ ] **Step 1: Create the reference file**

Create `skills/_shared/references/codegraph.md` with exactly this content:

````markdown
# CodeGraph (optional code-navigation accelerator)

An OPTIONAL local code index (MCP server: SQLite + FTS5 + tree-sitter, MIT, 100% local, no API
keys). When present it returns relevant code + blast-radius in one call, replacing bursts of
grep/Glob/LSP. **It is never required** — if it is not available, do exactly what you would do today
(grep/Glob/LSP). No error, no stop.

Consumers: `ingest`, `add-feature`, `fix-bug`, and the Tier-2 branch of `self-heal-shell.md`.

## Detect (runtime, zero config)

Check in order; stop at the first that holds:

1. Is the MCP tool `codegraph_explore` available this session? → use it. (Primary path for
   `add-feature` / `fix-bug`, which run in the main session with MCP.)
2. Else, is the `codegraph` CLI on PATH AND does `.codegraph/` exist at the project root? → use the
   CLI: `codegraph explore|impact|callers|callees|files`.
3. Else → grep / Glob / LSP as usual. Silent — do not announce "CodeGraph not found".

## Task → command

| Need | CodeGraph | Fallback |
|------|-----------|----------|
| Code relevant to a topic / gather context | `explore "<query>"` (MCP: `codegraph_explore`) | grep + read |
| Blast radius of changing a symbol | `impact <symbol>` | grep references |
| Who calls / is called | `callers <symbol>` / `callees <symbol>` | grep + LSP getReferences |
| Project structure | `files` | Glob / tree |

## Caveats (do not over-trust the graph)

- **Framework-dispatch blind spot.** Call edges created by decorators / DI / routers (aiogram
  router, SwiftUI, DI containers) are under-reported. `impact` and `callers` are a **floor, not a
  ceiling** — verify entrypoints manually before assuming "no callers".
- **Source blocks are already-Read.** CodeGraph's verbatim, line-numbered source output is a Read
  you have already performed — do not re-Read those files. If you doubt freshness, run
  `codegraph sync` first (a file-watcher usually keeps the index current).

## Fallback contract

If CodeGraph is unavailable at any point (not detected, returns nothing, or errors), fall back to
grep / Glob / LSP with no behaviour change and no surfaced error. CodeGraph only ever *saves* calls;
its absence never changes correctness.
````

- [ ] **Step 2: Add the pointer in `ingest`**

In `skills/ingest/SKILL.md`, the Step 4 block begins (verbatim anchor):

```
### Step 4: Synthesise architecture docs  *(`sonnet` subagent)*

Using `ARCH`, write or update:
```

Insert a pointer between the heading and "Using `ARCH`":

```
### Step 4: Synthesise architecture docs  *(`sonnet` subagent)*

> **Optional CodeGraph:** if a local code index is available, enrich the narrative and cross-checks using CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` (`files` for structure, `explore` for load-bearing areas). Falls back to the `ARCH` JSON + reads when absent — CodeGraph is optional.

Using `ARCH`, write or update:
```

- [ ] **Step 3: Add the pointer in `add-feature`**

In `skills/add-feature/SKILL.md`, Step 1 ends with a bullet list whose last line is (verbatim anchor):

```
- `docs/plans/tasks.md`
```

Immediately after that line, add:

```

> **Optional CodeGraph:** when exploring the codebase for context (here and during brainstorming/planning), prefer CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available — `impact` on affected symbols helps predict the plan's file list for the Step 5 guard rails. Falls back to grep/LSP when absent.
```

Note: the string `- \`docs/plans/tasks.md\`` also appears in `fix-bug` and elsewhere; you are editing ONLY `skills/add-feature/SKILL.md`, and only its Step 1 occurrence (the one preceded by `- \`docs/product/prd.md\``). Confirm context before editing.

- [ ] **Step 4: Add the pointer in `fix-bug`**

In `skills/fix-bug/SKILL.md`, Step 4 reads (verbatim anchor):

```
### Step 4: Diagnose the bug

Invoke `superpowers:systematic-debugging` skill. Follow it exactly — it will:
- Form hypotheses
- Gather evidence systematically
- Identify root cause
- Avoid jumping to conclusions
```

Immediately after the `- Avoid jumping to conclusions` line (and before the existing `### Step 4.5: Triage` heading added in v4.7.0), add:

```

> **Optional CodeGraph:** for root-cause localisation and blast radius, use CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available (`explore`, `callers`, `impact`). Falls back to grep/LSP when absent.
```

- [ ] **Step 5: Verify**

Run: `cd /Volumes/DevSSD/Development/vladyslav-skills && grep -lF codegraph.md skills/ingest/SKILL.md skills/add-feature/SKILL.md skills/fix-bug/SKILL.md`
Expected: all three paths printed.

Run: `bash scripts/validate-skills.sh`
Expected: exits 0; no `orphan reference: skills/_shared/references/codegraph.md` line.

- [ ] **Step 6: Commit**

```bash
git add skills/_shared/references/codegraph.md skills/ingest/SKILL.md skills/add-feature/SKILL.md skills/fix-bug/SKILL.md
git commit -m "feat: optional CodeGraph reference + pointers in ingest/add-feature/fix-bug

New _shared/references/codegraph.md (detect → command map → caveats →
grep/LSP fallback). Three skills gain one-line pointers. CodeGraph is
optional; absent it, behaviour is unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Activate the self-heal Tier-2 CodeGraph hook

Traces to spec §D. Replaces the inert "Future hook" note in `self-heal-shell.md` with the live optional offer.

**Files:**
- Modify: `skills/_shared/references/self-heal-shell.md` (the `## Future hook` section)
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Consumes: the detection contract in `codegraph.md` (Task 1).

- [ ] **Step 1: Replace the inert note**

In `skills/_shared/references/self-heal-shell.md`, replace this block (verbatim anchor):

```
## Future hook (inert now — do not implement here)

When the CodeGraph integration lands, Tier 2 will additionally offer `codegraph init`
to build the code index. Left as a documented note only; this reference adds no
CodeGraph behaviour today.
```

with:

```
## Tier 2 addendum — CodeGraph index (optional)

If the `codegraph` CLI is available (detection in `_shared/references/codegraph.md`), Tier 2
additionally offers, as a separate `y/n`, to build a local code index:

> "Побудувати CodeGraph-індекс коду (`codegraph init`)? Прискорює навігацію в майбутніх сесіях. (y/n)"

- **y →** run `codegraph init` at the project root.
- **n →** skip.

Skipped silently if the CLI is absent — CodeGraph is optional and never required.
```

- [ ] **Step 2: Verify**

Run: `cd /Volumes/DevSSD/Development/vladyslav-skills && grep -n "Tier 2 addendum — CodeGraph" skills/_shared/references/self-heal-shell.md`
Expected: one match. And `grep -c "Future hook (inert" skills/_shared/references/self-heal-shell.md` → `0`.

Run: `bash scripts/validate-skills.sh`
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add skills/_shared/references/self-heal-shell.md
git commit -m "feat: activate optional CodeGraph offer in self-heal Tier 2

Replaces the inert future-hook note with a live, optional y/n to run
codegraph init; skipped silently when the CLI is absent.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: gitignore `.codegraph/` in both scaffolders

Traces to spec §E. The local index is machine-specific build output.

**Files:**
- Modify: `scripts/modules/core.sh` (the `.gitignore` written by `init-project`)
- Modify: `scripts/attach-project.sh` (the base `gitignore_append` calls)
- Verify: `scripts/validate-skills.sh`

- [ ] **Step 1: Add to `core.sh`**

In `scripts/modules/core.sh`, the `.gitignore` write block ends with (verbatim anchor):

```
build/
dist/
coverage/
"
```

Insert `.codegraph/` before the closing quote:

```
build/
dist/
coverage/
.codegraph/
"
```

- [ ] **Step 2: Add to `attach-project.sh`**

In `scripts/attach-project.sh`, the base gitignore section reads (verbatim anchor):

```
gitignore_append "Logs / build artifacts" "*.log" "logs/" "build/" "dist/" "coverage/"
```

Add a line immediately after it:

```
gitignore_append "CodeGraph (optional local index)" ".codegraph/"
```

- [ ] **Step 3: Verify**

Run: `cd /Volumes/DevSSD/Development/vladyslav-skills && grep -n '\.codegraph/' scripts/modules/core.sh scripts/attach-project.sh`
Expected: one match in each file.

Run: `bash scripts/validate-skills.sh`
Expected: exits 0.

Optional module smoke (if a module test harness exists): run `ls scripts/modules/tests/ 2>/dev/null` and, if present, `bash scripts/modules/tests/*.sh` — confirm no regressions. If no harness exists, skip.

- [ ] **Step 4: Commit**

```bash
git add scripts/modules/core.sh scripts/attach-project.sh
git commit -m "chore: gitignore .codegraph/ in init-project and attach-project scaffolders

The local CodeGraph index is machine-specific build output, never committed.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: README + CLAUDE.md — document CodeGraph as optional

Traces to spec §F (docs half). Keeps the required-dependency lists untouched.

**Files:**
- Modify: `README.md` (new subsection after the MemPalace section)
- Modify: `CLAUDE.md` (Dependencies section)
- Verify: `scripts/validate-skills.sh`

- [ ] **Step 1: Add the README subsection**

In `README.md`, this line marks the end of the MemPalace requirement block (verbatim anchor):

```
The other skills (`init-project`, `attach-project`, `write-*`, `help`, `swiftui-pro`, `design-page`, `smoke-test-skills`) work without MemPalace.
```

Immediately after it, insert a blank line and:

````
### Optional: CodeGraph code index

[CodeGraph](https://github.com/colbymchenry/codegraph) is an **optional** local code index (MCP server — SQLite + FTS5 + tree-sitter, MIT, 100% local, no API keys). When installed and indexed, `ingest`, `add-feature`, and `fix-bug` fetch relevant code + blast-radius in one call instead of many grep/read calls. It is **not required** — without it these skills fall back to grep/Glob/LSP with no change in behaviour, and it is independent of the (required) MemPalace server.

One-time setup — per machine, then per project:

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
codegraph install                    # wire it into Claude Code as an MCP server
cd your-project && codegraph init    # build the local index (.codegraph/, gitignored)
```
````

- [ ] **Step 2: Add the CLAUDE.md optional-dependency line**

In `CLAUDE.md`, the Dependencies section has this MemPalace bullet (verbatim anchor):

```
- **MemPalace MCP server** — required by 8 skills (`add-feature`, `fix-bug`, `discover`, `discover-apple-check`, `design-sync`, `ingest`, `pre-release-check`, `compact-save`). When editing or adding skills that call `mempalace_*` tools, declare the dependency in the skill's SKILL.md and update the README "Skills that require MemPalace" list.
```

Add a new bullet immediately after it:

```
- **CodeGraph MCP server (optional)** — local code-index accelerator used by `ingest`, `add-feature`, `fix-bug` when present; skills fall back to grep/Glob/LSP without it. Never a hard dependency — do not add it to any "required" list. Detection + usage contract: `skills/_shared/references/codegraph.md`; setup: README "Optional: CodeGraph code index".
```

- [ ] **Step 3: Verify**

Run: `cd /Volumes/DevSSD/Development/vladyslav-skills && grep -n "Optional: CodeGraph code index" README.md && grep -n "CodeGraph MCP server (optional)" CLAUDE.md`
Expected: one match each.

Run: `bash scripts/validate-skills.sh`
Expected: exits 0 (README↔MemPalace sync unaffected — no skill was added to the required list).

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document optional CodeGraph index in README + CLAUDE.md

New 'Optional: CodeGraph code index' README section and an optional
dependency note in CLAUDE.md. Required-MemPalace lists unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Release metadata (CHANGELOG + version bump)

Traces to spec §F (release half).

**Files:**
- Modify: `CHANGELOG.md` (new `## v4.8.0` section above `## v4.7.0`)
- Modify: `.claude-plugin/plugin.json` (`version`)
- Verify: `scripts/validate-skills.sh`

- [ ] **Step 1: Add the CHANGELOG entry**

In `CHANGELOG.md`, insert directly below the `# Changelog` heading (line 1) and above `## v4.7.0`:

```markdown
## v4.8.0

Optional CodeGraph integration — faster code navigation for the scanning skills, zero new required dependency.

- **`_shared/references/codegraph.md` (new)** — contract for the optional CodeGraph local index (detect → task/command map → caveats → grep/LSP fallback). CodeGraph is never required: absent it, `ingest` / `add-feature` / `fix-bug` behave exactly as before.
- **Pointers added** — `ingest` (Step 4), `add-feature` (Step 1), `fix-bug` (Step 4) now prefer `codegraph_explore` / `impact` when available, falling back to grep/Glob/LSP otherwise.
- **Self-heal Tier 2** — now offers an optional `codegraph init` (separate y/n) when the CLI is present; skipped silently otherwise.
- **`.codegraph/` gitignored** — added to the `init-project` (`core.sh`) and `attach-project` scaffolders; the local index is machine-specific build output.
- **README / CLAUDE.md** — new "Optional: CodeGraph code index" section and an optional-dependency note; the required-MemPalace lists are unchanged.

```

- [ ] **Step 2: Bump the version**

In `.claude-plugin/plugin.json`, change `"version": "4.7.0",` to `"version": "4.8.0",`. Do NOT change the `description` string (the "10 skills require MemPalace" count stays — CodeGraph adds no required dep).

- [ ] **Step 3: Verify**

Run: `cd /Volumes/DevSSD/Development/vladyslav-skills && grep -n '"version": "4.8.0"' .claude-plugin/plugin.json && grep -n "## v4.8.0" CHANGELOG.md`
Expected: one match each.

Run: `bash scripts/validate-skills.sh`
Expected: exits 0.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: v4.8.0 — optional CodeGraph integration

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- §A detection → encoded in `codegraph.md` (Task 1) ✓
- §B reference → Task 1 ✓
- §C pointers (ingest/add-feature/fix-bug) → Task 1 Steps 2–4 ✓
- §D self-heal Tier-2 activation → Task 2 ✓
- §E gitignore → Task 3 ✓
- §F docs (README/CLAUDE.md) → Task 4; release (CHANGELOG/plugin.json) → Task 5 ✓
- Hard constraint "optional, never required" → stated in the reference, both pointers' fallback clauses, README, CLAUDE.md, and preserved by NOT touching required lists / the plugin.json count ✓
- Non-goals (no auto-install, no MCP config in repo, no hard dep, no extra-skill pointers) → no task violates them ✓

**2. Placeholder scan:** No "TBD/TODO". `<query>`, `<symbol>`, `<plugin>` are runtime fill-ins inside skill/reference prose (consistent with existing references like `verify-pwd.md` using `<pwd>`), not plan placeholders.

**3. Type consistency:** The reference basename `codegraph.md` is cited identically in Task 1 Steps 2–4 and matches the Check F basename-match. The `.codegraph/` string is identical across Task 3 and the README/CLAUDE.md prose. Version `4.8.0` consistent across Task 5. The Task 3 core.sh anchor (`coverage/` then closing quote) and attach-project.sh anchor (the `Logs / build artifacts` append line) match the current files verified during planning.

**Verification model note:** this repo has no unit-test suite. The per-task gate is `scripts/validate-skills.sh` + targeted greps, plus an optional module-test smoke in Task 3. A final manual smoke run of `ingest`/`add-feature`/`fix-bug` is recommended post-merge but is not a plan task.
