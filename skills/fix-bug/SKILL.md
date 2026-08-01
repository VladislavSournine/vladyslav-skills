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

**If `CLAUDE.md` is missing, do not dead-end** — apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline shell bootstrap, then continue. Only STOP if the user declines.

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

> **Optional CodeGraph:** for root-cause localisation and blast radius, use CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available (`explore`, `callers`, `impact`). Falls back to grep/LSP when absent.

### Step 4.5: Triage — is a plan needed?

With the root cause identified, decide whether this fix needs an explicit plan. Do
**not** apply a rigid rule — **analyze, state an assumption + recommendation, then ask
the user**. The user's choice always wins.

1. **Assess and recommend.** State your read of the fix, e.g.:
   - *"Тривіальний однорядковий — інвертована умова, blast radius = місце бага → рекомендую фіксити напряму, без плану."*
   - *"Зачіпає auth-шлях / потрібен ресерч, кілька файлів → рекомендую спершу короткий план."*
   Surface **criticality** yourself: if the fix sits on a critical path (auth, payments,
   data integrity), say so — a one-liner there may still deserve a plan. You raise it;
   the user decides.

2. **Ask:** "Фіксити напряму, чи спершу короткий план?"

3. **Plan path** → write a short, proportional plan:
   - root cause (one line)
   - the exact change you will make
   - files touched
   - regression-test approach
   Then ⏸ **stop for approval**. Once approved, Step 5 implements **only** what the plan
   describes — this is under the Blast Radius Rule; any expansion needs a new approval.
   Plan length scales with the bug: two sentences for a one-liner, a real plan for a
   structural fix.

4. **Direct path** → proceed to Step 5 unchanged.

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

### Step 6.5: Security check

Invoke the security checker on the fix diff. A bug fix touches the same attack surface a feature does, and skipping this is how a regression fix ships a vulnerability.

- Preferred: `Skill` tool → `owasp-security`, scoped to the fix diff (`git diff` against the branch point).
- Fallback: `Agent` tool → `subagent_type: "pr-review-toolkit:silent-failure-hunter"`, `model: "sonnet"`.

**Blocker if any of these appear:** injection risk (SQL, command, XSS), secrets in the diff, missing authZ on a mutation, or a silent catch block with no logging.

On a blocker: fix the cause and re-run this step. Do **not** narrow the scope passed to the checker to make a finding disappear — see "Forbidden repairs" in `<plugin>/skills/add-feature/references/auto-mode.md`.

### Step 7: Finish the branch

Invoke `superpowers:finishing-a-development-branch` — it will guide merge, PR, or cleanup.

### Step 8: Update docs

After merge:

1. `docs/product/user-stories.md` — add note about the fix or update affected story status
2. `docs/testing/manual-qa.md` — add regression check for this bug
3. `docs/plans/tasks.md` — mark bug task as done (if it was tracked)
4. **MemPalace `problem` record** — write to the project wing (derived in Step 0) so a
   future session searching the symptom finds this rake immediately. Run
   `mempalace_check_duplicate` first (MemPalace writes are never parallelized and always
   dedup-checked — see `_shared/references/orchestration-conventions.md`). Content:

   ```
   [WHAT] баг <опис>
   [ROOT CAUSE] <причина>
   [FIX] <що змінено>
   [FILES] <список>
   [REGRESSION TEST] <файл::тест>
   [DATE] <today>
   ```

   If MemPalace is unavailable, report that the record could not be written and continue —
   do not fail the fix over it.

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
- MemPalace wing <name> — problem record added

Do NOT add translations — wait for pre-release-check phase.

Next steps:
- /vladyslav:write-docs — update test documentation for the fix (tests mode)
- /vladyslav:pre-release-check — run pre-release verification before shipping
```
