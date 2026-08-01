---
name: init-project
description: Use when creating a new project. Bare AI shell by default; interactive menu adds docs / backend-infra / agents on demand.
---

# Init Project

**Type:** Engineer (light)

## Overview

Bootstrap a new project with the minimal Claude Code shell (`CLAUDE.md`, `.gitignore`, `.claude/settings.json`). In interactive mode an opt-in menu adds documentation, backend infrastructure, and agent stubs — only the modules you actually tick. Everything runs via focused bash modules under `scripts/modules/`; no LLM cost for the mechanical scaffold work.

## Process

### Step 0: Pre-flight (Opus main)

All Q&A happens here before any bash is executed.

1. **Verify working directory.** Run `ls -A` on the target directory (default: cwd). If it is non-empty — anything beyond `.git/` alone — ask via AskUserQuestion:
   > "The current directory is not empty. Contents: `<list>`. Continue and add project structure here, or abort?"
   - **Abort** → exit cleanly. Do not proceed.
   - **Continue** → proceed. Modules skip files that already exist.

2. **AskUserQuestion — project name** (free text):
   > "What is the project called?"

3. **AskUserQuestion — mode** (single-select):
   > "Scaffold mode?"
   - Options: `minimal` | `interactive`
   - `minimal` — only core module runs (bare AI shell).
   - `interactive` — core runs first, then the module menu (Step 2) is presented.

4. **Resolve plugin root.**
   - Glob `~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/scripts/modules/core.sh`.
   - Take the matching path and go three levels up (strip `scripts/modules/core.sh`) to get `<root>`.
   - Fall back to `/Volumes/DevSSD/Development/vladyslav-skills` if Glob returns nothing (development clone).
   - Verify `<root>/skills/init-project/assets/` exists. If missing, warn the user and continue — assets are optional for core operation.

Capture: `<pwd>`, `<name>`, `<mode>`, `<root>`.

---

### Step 1: Core (always)

Execute via Bash tool:

```bash
<root>/scripts/modules/core.sh \
    --pwd <pwd> \
    --plugin-root <root> \
    --name <name>
```

The script emits a single line of JSON on stdout:

```json
{
  "status": "success" | "partial" | "error",
  "files_written": ["<path>", ...],
  "files_skipped": ["<path>", ...],
  "warnings": ["<msg>", ...],
  "error": "<msg if status=error>"
}
```

Capture this JSON. If `status` is `error`, surface the error and stop — do not proceed to Step 2.

---

### Step 2: Module menu (interactive mode only)

Skip entirely if `<mode>` is `minimal`.

Present **three grouped AskUserQuestion multi-selects**, each with all options unticked by default. Run only the modules the user ticks. Unticked items are silently skipped — "don't know → don't create".

#### Group A — Docs

> "Which documentation scaffolds do you want?"
> (all unticked by default)

| Option | Module call |
|---|---|
| `prd + planning` | `docs.sh --pwd <pwd> --plugin-root <root>` |
| `design system` | `design-system.sh --pwd <pwd> --plugin-root <root> --name <name>` |
| `architecture` | `architecture.sh --pwd <pwd> --plugin-root <root>` |

#### Group B — Backend infra

> "Which backend infrastructure do you want?"
> (all unticked by default)

| Option | Module call |
|---|---|
| `docker` | `docker.sh --pwd <pwd> --plugin-root <root>` |
| `postgres` | `postgres.sh --pwd <pwd> --plugin-root <root>` |
| `redis` | `redis.sh --pwd <pwd> --plugin-root <root>` |
| `alembic` | `alembic.sh --pwd <pwd> --plugin-root <root>` |
| `backend skeleton` | `backend-skeleton.sh --pwd <pwd> --plugin-root <root>` |

#### Group C — Agents

> "Which Claude Code agents do you want installed?"
> (all unticked by default)
>
> Options: `architect-reviewer`, `backend-engineer`, `qa-reviewer`, `release-manager`

Collect the ticked names into a comma-separated string, then run:

```bash
<root>/scripts/modules/agents.sh \
    --pwd <pwd> \
    --plugin-root <root> \
    --agents "<csv>"
```

If no agents are ticked, skip the `agents.sh` call entirely.

Each module call emits the same JSON shape as core. Capture all outputs.

---

### Step 3: Roadmap gate

After modules complete, ask via AskUserQuestion:

> "Які ключові фічі плануєш в цьому проекті? Розіб'ємо на MVP-фази в `ROADMAP.md`"

- If the user provides features → generate `ROADMAP.md` at `<pwd>/ROADMAP.md` using the phase structure below, then commit the file to git.
- If the user skips ("потім", "не знаю", empty answer, or declines) → do not create the file. Continue normally.

This step is **non-blocking** — `init-project` completes regardless of the answer.

**`ROADMAP.md` phase structure:**

```markdown
# Roadmap: <name>

> Created: YYYY-MM-DD

## Phase 1: <Name>
**Done when:** <one sentence criteria>

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Phase 2: <Name>
**Done when:** <one sentence criteria>

- [ ] Task 1
- [ ] Task 2
```

Phases represent MVP milestones — what ships in the first release vs. what comes after.

---

### Step 4: Summary + smart Next

Merge all module JSON outputs. Render to the user:

```
✓ init-project complete
  Project: <name> in <pwd>
  Mode: <minimal|interactive>
  Files written: <total count across all modules>
  Skipped (already existed): <list, omit section if empty>
  Warnings: <list, omit section if empty>
  ROADMAP.md: <created | skipped>
```

Then append a **context-aware `Next:` line** — pick the first that applies:

| Condition | Next line |
|---|---|
| No docs module was ticked | `Next: docs народяться за потреби — write-docs.` |
| Any backend-infra module was ticked | `Next: /vladyslav:add-feature щоб почати фічу.` |
| `minimal` mode | `Next: повернись у interactive за потреби, або одразу /vladyslav:add-feature.` |

The skill **never auto-runs the next skill**. The Next line is informational only.

**`status: error` from any module:** surface the error and which module failed. List files written before the failure. Do not retry automatically.

---

## Why this is a Light Engineer skill

- **No subagent dispatch.** Each module is a deterministic bash script. No LLM reasoning is needed for file creation.
- **Modular and opt-in.** Only requested modules run, so a minimal project stays minimal.
- **Idempotent.** Modules skip files that already exist and report them in `files_skipped`.
- **~1 second, 0 LLM tokens** per module. Q&A in Step 0 is the only model-driven part.

---

## Output allowlist

Paths the modules may write (relative to `<pwd>`). The modules never modify pre-existing files except where noted (append operations on `docker-compose.yml` and `.env`).

**core.sh** (always):
```
.gitignore
.claude/settings.json
CLAUDE.md
.remember/now.md
```

**docs.sh**:
```
docs/product/prd.md
docs/plans/tasks.md
docs/plans/backlog-next.md
```

**design-system.sh**:
```
docs/design/system.md
```

**architecture.sh**:
```
docs/architecture/system.md
```

**docker.sh**:
```
Dockerfile
docker-compose.yml
docs/operations/docker.md
```

**postgres.sh**:
```
docker-compose.yml              (appends postgres service block)
.env                            (appends DATABASE_URL)
```

**redis.sh**:
```
docker-compose.yml              (appends redis service block)
.env                            (appends REDIS_URL)
```

**alembic.sh**:
```
alembic.ini
migrations/env.py
migrations/versions/.gitkeep
migrations/README
```

**backend-skeleton.sh**:
```
requirements.txt
src/__init__.py
src/main.py
```

**agents.sh**:
```
.claude/agents/<name>.md        (one per chosen agent)
```

**Roadmap gate (Step 3)**:
```
ROADMAP.md
```
