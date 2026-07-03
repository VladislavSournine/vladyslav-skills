---
name: fix-bug
description: Use when fixing a bug in a production project. Full cycle: diagnose, fix, regression test, review, docs.
---

# Fix Bug

## Overview

Full-cycle bug fix: diagnose → fix → test → review → merge → update docs. Orchestrates superpowers skills in the right order with project-specific reminders.

**Type:** Architect

## Process

### Step 0: Verify working directory

Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`: confirms CLAUDE.md exists, derives the canonical MemPalace wing name, warns on stale-wing duplicates, and establishes the mandatory path-validation rule for the rest of this skill's MemPalace reads.

### Step 1: Read project context

Read these files before anything else (independent reads — fetch them in one parallel batch). For subagent dispatch, model tiers, and parallelism-safety rules used throughout this skill, see `_shared/references/orchestration-conventions.md`.
- `CLAUDE.md`
- `docs/architecture/system.md`
- `docs/architecture/api.md` (if exists)
- `docs/product/user-stories.md`
- `docs/plans/tasks.md`

### Step 2: Get bug description

Ask the user to describe the bug. Accept:
- Free text description
- Link to issue/ticket
- Error message or stack trace
- Steps to reproduce

### Step 3: Create worktree

Invoke `superpowers:using-git-worktrees` to create an isolated branch for the fix. Branch name: `fix/<short-bug-description>`.

### Step 4: Diagnose the bug

Invoke `superpowers:systematic-debugging` skill. Follow it exactly — it will:
- Form hypotheses
- Gather evidence systematically
- Identify root cause
- Avoid jumping to conclusions

### Step 5: Write regression test + fix

**Respect the Blast Radius Rule** (see `~/.claude/CLAUDE.md`): the fix must be the smallest justified change that addresses the root cause. If a larger restructuring would genuinely be better, **STOP and ask the user** before expanding scope — don't silently refactor.

Invoke `superpowers:test-driven-development` skill:
1. Write a failing test that reproduces the bug
2. Run test — verify it fails
3. Write the minimal fix that addresses the root cause (not just the symptom)
4. Run test — verify it passes
5. Run full test suite — verify nothing else broke
6. Run `git diff --stat` — confirm the change footprint matches the declared scope
7. Run the deterministic gate: `bash <plugin>/scripts/quality-gate.sh --pwd . --test-cmd "<project test command>"` (add `--base <ref>` if the fix spans commits). Fix and re-run until it exits 0 — do not proceed to review with a red gate.

### Step 6: Code review

Invoke `superpowers:requesting-code-review` to verify:
- Fix addresses root cause, not just symptom
- No regressions introduced
- Test coverage is adequate

If feedback is received, invoke `superpowers:receiving-code-review` to process it with technical rigor — verify before implementing suggestions.

### Step 7: Finish the branch

Invoke `superpowers:finishing-a-development-branch` — it will guide merge, PR, or cleanup.

### Step 8: Update docs

After merge:

1. `docs/product/user-stories.md` — add note about the fix or update affected story status
2. `docs/testing/manual-qa.md` — add regression check for this bug
3. `docs/plans/tasks.md` — mark bug task as done (if it was tracked)

### Step 9: Finish

Print architect report:

```
✓ Architect report:
- Bug: <description>
- Root cause: <what was wrong>
- Fix: <what was changed>
- Regression test: <test file and test name>
- Merged to: <branch>

Updated:
- docs/product/user-stories.md
- docs/testing/manual-qa.md
- docs/plans/tasks.md

Do NOT add translations — wait for pre-release-check phase.

Next steps:
- /vladyslav:write-test-docs — update test documentation for the fix
- /vladyslav:pre-release-check — run pre-release verification before shipping
```
