---
name: add-feature
description: Use when adding a feature to a production project. Full cycle: brainstorm, plan, implement, docs.
---

# Add Feature

## Overview

Full-cycle feature addition: idea → design → plan → implement → docs. Orchestrates superpowers skills in the right order with project-specific reminders.

**Type:** Architect

## Process

### Step 0.1: Verify working directory

Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`: confirms CLAUDE.md exists, derives the canonical MemPalace wing name, warns on stale-wing duplicates, and establishes the mandatory path-validation rule for the rest of this skill's MemPalace reads.

**If `CLAUDE.md` is missing, do not dead-end** — apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline shell bootstrap, then continue. Only STOP if the user declines.

Additionally, read the project name from `CLAUDE.md` (first heading or `# <ProjectName>` line).

### Step 0.5: Choose mode

Ask the user: **"Manual mode or Auto mode?"**

- **Manual** (default, safest) — the historic flow: stop after each phase and tell the user to run `/superpowers:<name>` in their terminal. Use when the feature is unusual, high-risk, or you want tight control.
- **Auto** — after approving the contract and the plan, I run execution, code review, security check, tests, commits, docs update, and merge-to-dev **without further stops**, except when a guard rail triggers. Use for routine features where the contract is clear.

Record the chosen mode for the rest of the flow. Do **not** default to Auto silently — always ask.

**Auto-mode guard rails (automatic STOP + ask):**
- More than **2 files touched outside the approved plan** (new files not in the plan)
- **Any existing file refactored outside the plan** (refactor of a file that was "read-only reference" → STOP, regardless of size)
- **Contract or spec changed during execution** (the contract file from Step 4.5 has been modified)
- **Pre-commit auto-gate failure** (see Steps 6/6.5) — quality gate (tests, diff hygiene, secrets, scope via `scripts/quality-gate.sh`), code review, or security check reports blocker

Any guard rail → stop, report the situation to the user, ask what to do. Do NOT attempt to work around a guard rail silently.

### Step 1: Read project context

Read these files before anything else (independent reads — fetch them in one parallel batch). For subagent dispatch, model tiers, and parallelism-safety rules used throughout this skill, see `_shared/references/orchestration-conventions.md`.
- `CLAUDE.md`
- `docs/architecture/system.md`
- `docs/architecture/api.md` (if exists)
- `docs/product/prd.md`
- `docs/plans/tasks.md`

> **Optional CodeGraph:** when exploring the codebase for context (here and during brainstorming/planning), prefer CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available — `impact` on affected symbols helps predict the plan's file list for the Step 5 guard rails. Falls back to grep/LSP when absent.

### Step 2: Get feature description

Ask the user to describe the feature they want to add. Free text.

### Step 3: Create worktree (optional)

**Manual mode:**
⏸ Stop. Tell the user:
"Step 3 complete. Now run /superpowers:using-git-worktrees in your terminal.
When done, come back and say 'done' to continue."

**Auto mode:**
Invoke the `superpowers:using-git-worktrees` skill via the Skill tool to create a `feature/<feature-name>` worktree directly. If the project does not use git worktrees (e.g. not a git repo or user opted out in CLAUDE.md), create a regular `feature/<feature-name>` branch via `git checkout -b`. Record the branch name for later steps.

### Step 4: Design the feature

**Existing roadmap check (both modes):**
Before starting brainstorming, check for an existing roadmap in two locations (in order):
1. `docs/roadmap/` — look for a `.md` file whose slug matches the feature name from Step 2 (lowercased, hyphens-normalized)
2. `ROADMAP.md` at the project root — check if it exists and contains phases with unchecked items relevant to this feature

If a match is found in either location, ask:
> "Знайшов роадмап `<slug>`. Продовжуємо з наступної незакінченої фази?"
- **Yes** → skip brainstorming (Step 4). Load the roadmap file, identify the first phase with unchecked items, pass those items as the scope to Step 4.5. In Step 4.5, write a focused contract scoped to that phase only (not the full feature), then continue normally to Step 4.7 and Step 5. Record that this run is a phase continuation.
- **No** → proceed with normal brainstorming as if no roadmap exists.

**Manual mode:**
⏸ Stop. Tell the user:
"Step 4 complete. Now run /superpowers:brainstorming in your terminal.
When done, come back and say 'done' to continue."

**Auto mode:**
Invoke the `superpowers:brainstorming` skill via the Skill tool with the feature description from Step 2 plus the project context from Step 1. Capture the brainstorm output (design doc, key decisions, MVP cut).

Present the output to the user and ⏸ **stop for approval**:
"Here's the brainstorm result: <summary>. Approve to continue, reopen to iterate, or abort?"

This is **approval point #2** (first was the feature description in Step 2). Do NOT proceed to the contract until the user says approve.

### Step 4.5: Define contract

Before planning, write down the contract explicitly (3-10 lines is enough):
- Types / function signatures / API schema
- 1 input/output example
- Known error cases / edge cases

The contract is the alignment point between intent, code, and tests. Skipping it means tests will end up verifying what you wrote, not what you intended.

Save the contract as a section inside the design doc from Step 4, or as a separate file `docs/plans/<feature>-contract.md`.

**Both modes:** Present the contract to the user and ⏸ **stop for approval** — this is **approval point #3**. Read the contract out loud (it's 3-10 lines, trivial to verify). Do not proceed until the user approves.

**Auto mode:** After approval, record the contract baseline for the "contract changed during execution" guard rail: `sha256sum <contract path> | awk '{print $1}' > <contract path>.sha256` (use `shasum -a 256` where `sha256sum` is unavailable, e.g. stock macOS). The gate in Step 6 (`quality-gate.sh` → `check-plan-scope.sh`) compares against this file; if the contract drifts during execution, it triggers a STOP. Delete the `.sha256` file after the last batch — it is gate plumbing, not a deliverable.

### Step 4.7: Roadmap gate

**Applies to:** both modes. Runs after contract approval, before writing-plans.

Assess whether the feature is multi-phase using **any one** of:
- Design from Step 4 has ≥3 distinct components/subsystems
- Design from Step 4 implies ≥5 major tasks
- User language in Step 2 signals phasing: "поетапно", "спочатку X потім Y", "фази", "поступово", "gradually", "phases", "step by step"

If any condition is true, ask:
> "Ця фіча виглядає багатофазно — є сенс розбити на фази з роадмапом перед тим як писати детальний план. Зробити?"

**If yes:**
1. Create `docs/roadmap/` directory if it does not exist.
2. If a file `docs/roadmap/<feature-slug>.md` already exists, ask: "Роадмап для `<slug>` вже існує. Перезаписати чи зберегти старий і створити `<slug>-v2.md`?" — on overwrite, replace the file; on "v2", write to `<slug>-v2.md` and use that filename for all subsequent references in this run.
3. Generate `docs/roadmap/<feature-slug>.md` using this format:

```markdown
# Roadmap: <Feature Name>

> Created: YYYY-MM-DD

## Phase 1: <Name>
**Done when:** <one sentence criteria>

- [ ] Task 1
- [ ] Task 2

## Phase 2: <Name>
**Done when:** <one sentence criteria>

- [ ] Task 1
- [ ] Task 2

<!-- Add Phase 3, 4… as needed — one phase per logical milestone -->
```

4. Commit: `git add docs/roadmap/<feature-slug>.md && git commit -m "docs: add roadmap for <feature-slug>"`
5. Pass **only Phase 1 tasks** as the scope to writing-plans in Step 5.

**`<feature-slug>` derivation:** feature name from Step 2, lowercased, spaces replaced with hyphens. Example: "User Authentication" → `user-authentication`.

**If no (or gate did not fire):**
Proceed to Step 5 with the full feature scope as before. No file is created.

### Step 5: Create implementation plan

After the contract (Step 4.5) is locked:

**Manual mode:**
⏸ Stop. Tell the user:
"Step 5 complete. Now run /superpowers:writing-plans in your terminal.
When done, come back and say 'done' to continue."

**Auto mode:**
Invoke the `superpowers:writing-plans` skill via the Skill tool, feeding it the contract + brainstorm output. Capture the plan — it must list each bite-sized task, which contract piece it implements, and (crucially) **which files each task will create or modify**. The file list is the baseline for the "files touched outside plan" guard rail. If a roadmap was created in Step 4.7, pass the Phase 1 task list as the scope constraint — writing-plans must produce a plan that implements Phase 1 only, not the full feature.

Present the plan to the user and ⏸ **stop for approval** — this is **approval point #4**. Show:
- Task list (numbered)
- Files that will be created (new)
- Files that will be modified (existing)
- Files that are "read-only reference" (must NOT be refactored during execution)

Do not proceed to Step 6 until the user approves. Record the file lists — main thread will enforce them as guard rails.

Each task in the plan must reference which part of the contract it implements.

> **Tests mandate (both modes):** Every task in the plan must include a "Write tests" sub-step *alongside* implementation — not deferred to after the feature is complete. Tests derive from the contract (Step 4.5). Remind the user of this rule before finalizing the plan.

### Step 6: Execute the plan

> **Auto mode:** Steps 6, 6.5, 7, and 8 below have an Auto-mode counterpart. If the user chose Auto in Step 0.5, read `<plugin>/skills/add-feature/references/auto-mode.md` and follow its instructions for Steps 6, 6.5, 7, and 8 instead of the Manual blocks below. Step 9 (post-implementation) is mode-agnostic and stays inline. The Manual blocks below are the default reading path.

**Manual mode:**

Ask the user which execution approach. **Parallel agents is recommended by default.**

- **Parallel agents (recommended):**
  ⏸ Stop. Tell the user:
  "Step 6 complete. Now run /superpowers:dispatching-parallel-agents in your terminal.
  When done, come back and say 'done' to continue."

- **Subagent-driven (this session):**
  ⏸ Stop. Tell the user:
  "Step 6 complete. Now run /superpowers:executing-plans in your terminal.
  When done, come back and say 'done' to continue."

- **Parallel session:**
  ⏸ Stop. Tell the user:
  "Step 6 complete. Now run /superpowers:executing-plans in a new terminal.
  When done, come back and say 'done' to continue."

**Rules that apply to every execution mode:**
- **Tests and code in parallel** — both derive from the contract (Step 4.5). No "code first, tests after".
- **Blast Radius Rule** (see `~/.claude/CLAUDE.md`) — smallest justified change, no "while I'm here" refactors, ask the user before expanding scope.

**Manual mode — PR review after each chunk:**

After **each chunk/phase** of the plan completes (not just at the very end):

⏸ Stop. Tell the user:
"Chunk complete. Run /pr-review-toolkit:code-reviewer now for a focused review of what was just implemented.
This is mandatory — do not skip. When done, come back and say 'done' to continue to the next chunk."

If the reviewer returns feedback → fix issues in the same chunk before moving on. Do NOT accumulate technical debt across chunks.

Repeat this step after each chunk until all chunks are done.

### Step 7: Final code review (Manual mode)

After ALL chunks are complete, run the deterministic gate on the branch before any reviewer looks at it:

`bash <plugin>/scripts/quality-gate.sh --pwd . --base $(git merge-base HEAD <dev-branch>) --test-cmd "<project test command>"`

Fix and re-run until it exits 0 — it catches the mechanical failures (failing tests, debug leftovers, conflict markers, credential-shaped strings) so review time is spent on design, not noise.

Then ⏸ Stop. Tell the user:
"Step 7 complete. Now run /superpowers:requesting-code-review in your terminal for a final full-feature review.
When done, come back and say 'done' to continue."

If feedback is received:

⏸ Stop. Tell the user:
"Step 7 complete. Now run /superpowers:receiving-code-review in your terminal to process the feedback.
When done, come back and say 'done' to continue."

### Step 8: Finish the branch (Manual mode)

⏸ Stop. Tell the user:
"Step 8 complete. Now run /superpowers:finishing-a-development-branch in your terminal.
When done, come back and say 'done' to continue."

### Step 9: Post-implementation

After merge (both modes — auto does this without stopping, manual requires the user to confirm merge happened):

1. **Update roadmap (if applicable):** If a roadmap file was used in this run (created in Step 4.7 or loaded via the resume path in Step 4):
   - Open the roadmap file (`docs/roadmap/<slug>.md` or `ROADMAP.md` — whichever was used)
   - Find the phase that was just implemented
   - Replace `- [ ]` with `- [x]` for every task that was completed
   - If all tasks in the phase are now checked, add `**Status: Complete ✓**` on the line immediately after the `**Done when:**` line
   - Commit: `git add <roadmap-file> && git commit -m "docs: mark Phase N complete in <slug> roadmap"`
   - If no roadmap was used in this run, skip this step entirely.
2. Update `docs/product/user-stories.md` — add the new feature as a story
3. Update `docs/architecture/api.md` — if any endpoints changed
4. Update `docs/plans/tasks.md` — mark completed tasks
5. Write a MemPalace `decision` record to the project wing: `[WHAT] feature <name> implemented, [CONTRACT] <path>, [FILES] <list>, [DATE] <today>`
6. **Auto mode:** run `git diff --stat main...HEAD` to produce the blast-radius summary for the report (files touched vs plan)

Print architect report:

```
✓ Architect report:
- Feature: <description>
- Mode: <manual|auto>
- Design: <key decisions>
- Implementation: <files changed, endpoints added>
- Blast radius: <files touched> / <files planned> — <match|expanded with approval|within plan>
- Tests: <count> passing
- Auto-gate runs: <count> (auto mode) — review HIGH issues: <count>, security issues: <count>
- Guard rail triggers: <count> (auto mode) — all resolved with user approval
- Merged to: <branch>
- Merge to main: <yes|pending user approval|never on auto>

Updated:
- docs/product/user-stories.md
- docs/architecture/api.md (if changed)
- docs/plans/tasks.md
- MemPalace wing <name> — decision record added

Do NOT add translations — wait for pre-release-check phase.
```

Next steps:
- `/vladyslav:write-test-docs` — generate test plan + QA checklist
- `/vladyslav:write-user-stories` — update user-stories registry
- `/vladyslav:pre-release-check` — pre-release verification

## Auto-mode reference

For Auto-mode-specific instructions (Steps 6, 6.5, 7, 8) and the approval map, see `<plugin>/skills/add-feature/references/auto-mode.md`.
