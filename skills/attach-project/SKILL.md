---
name: attach-project
description: Use when adding Claude Code structure to an existing project. Auto-detects stack, creates only missing files.
---

# Attach Project

**Type:** Engineer (light)

## Overview

Add Claude Code structure to an **existing** project. Never overwrites existing files. Auto-detects stacks via `scripts/detect-stack.sh`. The bash scaffolder (`scripts/attach-project.sh`) does all the work in ~0.5 seconds.

This was a Heavy Engineer skill until v3.1.0. Like `init-project` v3.0.0, the dispatched Sonnet subagent was doing pure mechanics (`mkdir`, `cp`, `sed`) — no LLM thinking needed for any of it.

## Process

### Step 0: Pre-flight (Opus main)

Collect inputs that the scaffolder can't auto-detect.

1. **Verify project root.** Run `ls -A`. The scaffolder will reject the run if no project markers exist, so this is a pre-emptive sanity check. If pwd looks empty (no `.git/`, no language manifest like `package.json` / `requirements.txt` / etc.) → STOP and suggest `/vladyslav:init-project` for a new project.

2. **Run stack detection** for the user's information:

   ```bash
   <plugin-root>/scripts/detect-stack.sh .
   ```

   Parse the JSON to show the user what was detected. Example: "Detected: python, docker". This is informational — the scaffolder runs detection again internally.

3. **AskUserQuestion — additional stacks not auto-detected** (multi-select):
   > "Detected stacks: `<list>`. Want to add any stacks not detected?"
   > Options: `python`, `go`, `flutter`, `swift`, `kotlin`, `other`, `none`.

4. **For each "other" stack** — AskUserQuestion three times:
   - `label` (e.g. "Rust backend")
   - `dir` (e.g. `rust`)
   - `gitignore` entries (comma-separated, e.g. `target/,Cargo.lock`)

5. **AskUserQuestion — domain** (free text, optional):
   > "Project domain / purpose? (e.g. 'iOS fitness app', 'Python data pipeline') — type `none` to skip"

6. **AskUserQuestion — private mode** (single-select):
   > "Private mode? Gitignore AI workflow files (CLAUDE.md, .claude/, docs/plans/)?"
   > Options: `yes`, `no`.

7. **Resolve plugin root.** Same approach as `init-project`: Glob `~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/scripts/attach-project.sh` and take the directory two levels up. Fall back to `/Volumes/DevSSD/Development/vladyslav-skills` (dev clone).

**Exit criteria:** this is an existing project (git repo or a language manifest is present); detected stacks were shown to the user and confirmed or extended; domain and private-mode answered; `<plugin-root>/scripts/attach-project.sh` is executable.
**Evidence:** the `detect-stack.sh` JSON, and the four answers.
**Blocker:** an empty directory → STOP and suggest `/vladyslav:init-project`. Guessing an undetected stack instead of asking.

Steps below follow the exit-criteria contract in `<plugin>/skills/_shared/references/exit-criteria.md`.

### Step 1: Run the scaffolder

Execute (via the Bash tool):

```bash
<plugin-root>/scripts/attach-project.sh \
    --pwd <project pwd> \
    --plugin-root <plugin-root> \
    [--additional-stacks "python,go,..."] \
    [--other-stacks "label1:dir1:gitignore-entries1;label2:dir2:gitignore-entries2"] \
    --domain "<domain-or-empty>" \
    --private-mode <yes|no>
```

**`--other-stacks` format**: semicolon-separated list of `label:dir:gitignore` triples. The `gitignore` part is itself a comma-separated list. Pass empty string `""` if no "other" stacks were chosen.

The script emits JSON:

```json
{
  "status": "success" | "error",
  "detected_stacks": [<auto-detected stack names>],
  "files_written": [<paths>],
  "files_skipped": [<paths that already existed and were preserved>],
  "warnings": [<msgs>],
  "error": "<msg if status=error>"
}
```

Capture this output.

**Exit criteria:** `status: success`; every path in `files_skipped` is byte-identical to what it was before the run; `.gitignore` gained only new lines.
**Evidence:** the JSON, and `git status --porcelain` — pre-existing tracked files show no modification except the `.gitignore` append.
**Blocker:** any pre-existing file overwritten. This skill's entire contract is never-overwrite; a rerun that clobbers is worse than a rerun that does nothing.

### Step 2: Present summary

Parse the JSON. Render to the user:

**`status: success`**:

```
✓ attach-project complete
  Detected: <detected_stacks joined>
  Files written: <files_written count> — <list>
  Files preserved (already existed): <files_skipped count> — <list, if any>
  Warnings: <warnings, if any>
  Next: /vladyslav:ingest  — scan codebase, populate docs/, and seed MemPalace
```

**`status: error`**:

```
✗ attach-project failed
  Error: <error from JSON>
```

**Exit criteria:** the counts shown match the JSON arrays, and preserved files are named rather than summarised as "some files existed".
**Blocker:** presenting `status: error` as a partial success.

---

## What the scaffolder does (auditing reference)

The bash scaffolder, given the parameters above, writes ONLY these paths if they do not already exist:

- `CLAUDE.md` — with auto-generated Stack section based on detected + additional stacks
- `.gitignore` — APPENDED with stack-specific entries (Python / Go / Flutter / Swift / Kotlin / Node / Web), editors/OS, secrets/env, logs, and (if private mode) AI workflow file lines. Existing entries are preserved verbatim, duplicates are skipped via `grep -Fxq`.
- `.claude/settings.json` — with `PROJECT_DOCS_ROOT` env
- `.claude/agents/docs-agent.md` — documentation maintainer
- `.claude/agents/code-review-agent.md` — code-review agent
- `docs/architecture/system.md`, `docs/product/prd.md`, `docs/plans/tasks.md` — stub files (`# Title\n\n*to be filled*\n`)
- Per detected/added stack: a placeholder directory (`python/`, `go/`, `swift/`, `flutter/`, `kotlin/`) with `.gitkeep` — but ONLY if no matching directory (or sibling like `backend/`, `app/`, `ios/`, `android/`) already exists.
- Per "other" stack: the user-specified `<dir>/` with `.gitkeep`.

**Idempotent:** rerun is safe. Every pre-existing file is reported in `files_skipped`. No file is ever overwritten.

**No git init:** the project already has version control. The scaffolder doesn't touch git.

**No backend scaffolding:** unlike `init-project`, this skill does NOT create `requirements.txt`, FastAPI `main.py`, Dockerfile, docker-compose files, etc. Those would conflict with the existing project. attach-project adds only the AI workflow shell.
