---
name: fix-bug
description: Use when fixing a bug in a production project. Full cycle: diagnose, fix, regression test, review, docs.
---

# Fix Bug

## Overview

Full-cycle bug fix: diagnose → fix → test → review → merge → update docs. Orchestrates superpowers skills in the right order and owns the gates between them.

**Type:** Architect

Every step below declares what must be true before the next one starts, per `<plugin>/skills/_shared/references/exit-criteria.md` — including its anti-gaming rules, which apply to every repair attempt in this skill.

## Process

### Step 0: Verify working directory

Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`. If `CLAUDE.md` is missing, do **not** dead-end — apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline shell bootstrap.

**Exit criteria:** `CLAUDE.md` confirmed present in `pwd`; canonical MemPalace wing name derived and recorded for Step 8; the path-validation rule is in force for every MemPalace read that follows.
**Evidence:** the wing name, stated in one line to the user.
**Blocker:** user declines the bootstrap → STOP. A wing that resolves to two candidates → ask which, never guess.

### Step 1: Read project context

Read in one parallel batch: `CLAUDE.md`, `docs/architecture/system.md`, `docs/architecture/api.md` (if present), `docs/product/user-stories.md`, `docs/plans/tasks.md`. Dispatch mechanics for this skill: `_shared/references/orchestration-conventions.md`.

**Exit criteria:** every file that exists has been read in full; missing ones noted rather than assumed empty.
**Blocker:** `docs/architecture/system.md` missing → suggest `/vladyslav:ingest` before continuing; proceed only if the user says to.

### Step 2: Get bug description

Ask the user to describe the bug. Free text, issue link, stack trace, or repro steps all count.

**Exit criteria:** a reproducible symptom is stated in one sentence, and the expected behaviour is distinguishable from the observed one.
**Blocker:** "it's broken" with no observable → ask for the symptom before touching code. Do not begin diagnosing an unstated bug.

### Step 3: Create worktree

Invoke `superpowers:using-git-worktrees` via the `Skill` tool. Branch: `fix/<short-bug-description>`.

**Exit criteria:** work is happening on an isolated branch, not on `develop`/`main`.
**Evidence:** `git branch --show-current`.

### Step 4: Diagnose the bug

Invoke `superpowers:systematic-debugging` via the `Skill` tool and follow it.

> **Optional CodeGraph:** for root-cause localisation and blast radius, use CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available (`explore`, `callers`, `impact`). Falls back to grep/LSP when absent.

**Exit criteria:** a named root cause at a specific location, plus the causal chain from it to the observed symptom.
**Evidence:** the file:line of the cause, and one concrete observation (log line, failing assertion, traced value) that would not be explained by any competing hypothesis.
**Blocker:** the leading hypothesis explains the symptom only "probably" → keep gathering evidence. A fix aimed at a plausible-but-unconfirmed cause is a symptom fix; see Step 5's blocker.

### Step 4.5: Triage — is a plan needed?

Decide whether this fix needs an explicit plan. Do **not** apply a rigid rule — analyze, state an assumption + recommendation, then ask. The user's choice always wins.

State your read of the fix, surfacing **criticality** yourself: a one-liner on a critical path (auth, payments, data integrity) may still deserve a plan. Calibration — *"тривіальний однорядковий, інвертована умова, blast radius = місце бага → фіксити напряму"* vs *"зачіпає auth-шлях, кілька файлів → спершу короткий план"*. Then ask: "Фіксити напряму, чи спершу короткий план?"

On the plan path, the plan is proportional — two sentences for a one-liner, a real plan for a structural fix — and covers: root cause, the exact change, files touched, regression-test approach.

**Exit criteria:** the user has chosen direct or plan; on the plan path, the plan is approved verbatim and its file list is recorded as the Step 5 scope baseline.
**Blocker:** proceeding on the plan path without approval. Any expansion beyond the approved file list is a new approval under the Blast Radius Rule, not a judgment call.

### Step 5: Write regression test + fix

Invoke `superpowers:test-driven-development` via the `Skill` tool. The fix is the smallest justified change that addresses the root cause from Step 4 — see the Blast Radius Rule in `~/.claude/CLAUDE.md`. If a larger restructuring would genuinely be better (it kills the fragile workaround the bug lives in), **STOP and ask** — that call is the user's, not this skill's.

Then run the deterministic gate:

```bash
bash <plugin>/scripts/quality-gate.sh --pwd . --test-cmd "<project test command>"
```

(add `--base <ref>` if the fix spans commits)

**Exit criteria:** a test exists that fails on the unfixed code and passes on the fixed code; the full suite is green; the diff touches only the files declared in Step 4.5.
**Evidence:** `quality-gate.sh` exits 0; the regression test's `file::name`; `git diff --stat`.
**Blocker:** the new test passes against the *unfixed* code → it does not reproduce the bug and does not count as a regression test, whatever else it asserts. The fix changes a symptom site rather than the Step 4 root cause → go back to Step 4. Red gate → repair and re-run; never proceed to review with a red gate, and never satisfy it by the routes listed under Anti-gaming in `exit-criteria.md`.

### Step 6: Code review

Invoke `superpowers:requesting-code-review` via the `Skill` tool. If feedback arrives, process it with `superpowers:receiving-code-review` — verify before implementing.

**Exit criteria:** a reviewer has seen the full fix diff and every HIGH-severity finding is resolved or explicitly accepted by the user.
**Evidence:** the reviewer's findings list with a disposition per item.
**Blocker:** an unresolved HIGH finding. Disagreeing with a finding is resolved by verifying it, not by re-running the reviewer on a narrower diff.

### Step 6.5: Security check

A bug fix touches the same attack surface a feature does; skipping this is how a regression fix ships a vulnerability.

- Preferred: `Skill` tool → `owasp-security`, scoped to the fix diff (`git diff` against the branch point).
- Fallback: `Agent` tool → `subagent_type: "pr-review-toolkit:silent-failure-hunter"`, `model: "sonnet"`.

**Exit criteria:** the checker has run against the complete fix diff and reported no blocker-class finding.
**Evidence:** the checker's output, plus the diff range it was given.
**Blocker:** injection risk (SQL, command, XSS), secrets in the diff, missing authZ on a mutation, or a silent catch block with no logging. Fix the cause and re-run. Narrowing the scope passed to the checker to make a finding disappear is a forbidden repair.

### Step 7: Finish the branch

Invoke `superpowers:finishing-a-development-branch` via the `Skill` tool.

**Exit criteria:** the fix is merged (or a PR is open) on the target branch, and the branch state matches what the user chose.
**Evidence:** merge commit sha or PR URL.
**Blocker:** PRs target `develop`, never the repo default — see the PR Target Branch rule in `~/.claude/CLAUDE.md`.

### Step 8: Update docs

After merge:

1. `docs/product/user-stories.md` — note the fix or update the affected story's status
2. `docs/testing/manual-qa.md` — add a regression check for this bug
3. `docs/plans/tasks.md` — mark the bug task done, if it was tracked
4. **MemPalace `problem` record** in the wing from Step 0, so a future session searching the symptom finds this rake. Run `mempalace_check_duplicate` first (MemPalace writes are never parallelized — see `_shared/references/orchestration-conventions.md`):

   ```
   [WHAT] баг <опис>
   [ROOT CAUSE] <причина>
   [FIX] <що змінено>
   [FILES] <список>
   [REGRESSION TEST] <файл::тест>
   [DATE] <today>
   ```

**Exit criteria:** all four updated, or each skipped one is named with a reason in the report.
**Evidence:** the paths written; the drawer id or the duplicate it matched.
**Blocker:** none — MemPalace unavailable is reported and the fix still ships. A silently skipped doc update is not acceptable; an openly reported one is.

### Step 9: Finish

Print the architect report:

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

**Exit criteria:** every step above either met its exit criteria or is named in the report as unmet, with the reason.
**Blocker:** reporting clean success while any step's criteria went unmet. A partial fix reported as partial is an acceptable outcome; a partial fix reported as done is not.
