---
name: add-feature
description: Use when adding a feature to a production project. Full cycle: brainstorm, plan, implement, docs.
---

# Add Feature

## Overview

Full-cycle feature addition: idea → design → plan → implement → docs. Orchestrates superpowers skills in the right order and owns the gates between them.

**Type:** Architect

Every step declares what must be true before the next one starts, per `<plugin>/skills/_shared/references/exit-criteria.md` — including its anti-gaming rules, which bind every subagent and every repair attempt in this skill.

**This skill invokes the skills it needs via the `Skill` tool, in both modes.** Mode controls where it *stops for approval*, never who runs the sub-skill.

## Process

### Step 0.1: Verify working directory

Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`. If `CLAUDE.md` is missing, apply `<plugin>/skills/_shared/references/self-heal-shell.md` rather than dead-ending.

**Exit criteria:** `CLAUDE.md` confirmed present; project name extracted from it; canonical MemPalace wing derived; the path-validation rule in force for this skill's MemPalace reads.
**Evidence:** project name and wing, stated in one line.
**Blocker:** user declines the bootstrap → STOP.

### Step 0.5: Choose mode

Ask: **"Manual mode or Auto mode?"**

- **Manual** (default, safest) — approval stop after every phase. Use when the feature is unusual, high-risk, or you want tight control.
- **Auto** — after the contract and plan are approved, execution, review, security, tests, commits, docs and merge-to-dev run without further stops, except on a guard rail.

**Auto-mode guard rails (automatic STOP + ask):**
- More than **2 files touched outside the approved plan**
- **Any file marked "read-only reference" modified** — regardless of size
- **Contract changed during execution**
- **Pre-commit auto-gate failure** — *quality* failures get up to 2 repair attempts first; *scope* failures escalate immediately

**Exit criteria:** the mode is recorded and came from an explicit user answer — or was passed down by `vladyslav:orchestrate`, which already asked.
**Blocker:** defaulting to Auto silently. Asking again when the orchestrator already supplied a mode is a bug, not extra safety.

### Step 1: Read project context

Read in one parallel batch: `CLAUDE.md`, `docs/architecture/system.md`, `docs/architecture/api.md` (if present), `docs/product/prd.md`, `docs/plans/tasks.md`. Dispatch mechanics: `_shared/references/orchestration-conventions.md`.

> **Optional CodeGraph:** when exploring the codebase (here and during brainstorming/planning), prefer CodeGraph per `<plugin>/skills/_shared/references/codegraph.md` if available — `impact` on affected symbols helps predict the plan's file list for the Step 5 guard rails.

**Exit criteria:** every file that exists has been read in full; missing ones noted rather than assumed empty.
**Blocker:** no `docs/architecture/` at all → suggest `/vladyslav:ingest` first.

### Step 2: Get feature description

Ask the user to describe the feature. Free text.

**Exit criteria:** the feature is stated as an observable capability a user gains, not as an implementation ("users can reset their password by email", not "add a reset endpoint"). This is **approval point #1**.
**Blocker:** a description that cannot be turned into an acceptance check → ask what the user should be able to do afterwards.

### Step 3: Create worktree

Invoke `superpowers:using-git-worktrees` via the `Skill` tool to create a `feature/<feature-name>` worktree. If the project does not use worktrees (not a git repo, or opted out in `CLAUDE.md`), create a regular `feature/<feature-name>` branch.

**Exit criteria:** work is isolated on a feature branch or worktree, and its name is recorded for later steps.
**Evidence:** `git branch --show-current`.

### Step 4: Design the feature

**Existing roadmap check (both modes).** Before brainstorming, look for an existing roadmap: `docs/roadmap/<slug>.md` matching the feature name (lowercased, hyphens-normalized), then `ROADMAP.md` at the project root with unchecked items relevant to this feature. On a match, ask:

> "Знайшов роадмап `<slug>`. Продовжуємо з наступної незакінченої фази?"

- **Yes** → skip brainstorming. Load the roadmap, take the first phase with unchecked items as the scope for Step 4.5, and record that this run is a phase continuation. The contract in Step 4.5 covers **that phase only**.
- **No** → normal brainstorming.

Otherwise invoke `superpowers:brainstorming` via the `Skill` tool with the Step 2 description plus the Step 1 context, then present the result:

> "Here's the brainstorm result: <summary>. Approve to continue, reopen to iterate, or abort?"

**Exit criteria:** a design exists that names the components to be built and the MVP cut, and the user approved it — **approval point #2**. On the roadmap path: the phase's task list is loaded and recorded instead.
**Evidence:** the design doc path or the captured summary; on the roadmap path, the roadmap file and phase name.
**Blocker:** proceeding to the contract without approval.

### Step 4.5: Define contract

Write the contract explicitly, 3-10 lines: types / signatures / API schema · one input-output example · known error and edge cases. Save it inside the Step 4 design doc or as `docs/plans/<feature>-contract.md`.

The contract is the alignment point between intent, code, and tests. Without it, tests verify what was written rather than what was intended.

**Both modes:** present it and stop — **approval point #3**. It is 3-10 lines; read it out in full.

**Auto mode:** after approval, record the baseline for the contract-drift guard rail: `sha256sum <contract path> | awk '{print $1}' > <contract path>.sha256` (`shasum -a 256` on stock macOS). The Step 6 gate (`quality-gate.sh` → `check-plan-scope.sh`) compares against this file and STOPs if the contract drifted mid-execution. Delete the `.sha256` after the last batch — it is gate plumbing, not a deliverable.

**Exit criteria:** the contract file exists at a recorded path, the user approved it verbatim, and (Auto) its hash baseline is written.
**Evidence:** the contract path; the `.sha256` file in Auto mode.
**Blocker:** entering planning without an approved contract. A contract that names no error cases is incomplete — tests derived from it will only cover the happy path.

### Step 4.7: Roadmap gate

**Applies to:** both modes, after contract approval, before planning.

The feature is multi-phase if **any one** holds: the design has ≥3 distinct components/subsystems · it implies ≥5 major tasks · the user's language signals phasing ("поетапно", "спочатку X потім Y", "фази", "поступово", "gradually", "phases", "step by step").

If so, ask: "Ця фіча виглядає багатофазно — є сенс розбити на фази з роадмапом перед тим як писати детальний план. Зробити?"

**If yes:** write `docs/roadmap/<feature-slug>.md` (slug = feature name lowercased, spaces → hyphens; "User Authentication" → `user-authentication`). If that file already exists, ask whether to overwrite or write `<slug>-v2.md`, and use the chosen name for the rest of the run. Format:

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

Commit it: `git add <roadmap-file> && git commit -m "docs: add roadmap for <feature-slug>"`. Only Phase 1 goes to Step 5 as scope.

**Exit criteria:** either the gate did not fire and no file was created, or the roadmap is committed, every phase has a one-sentence `**Done when:**`, and Phase 1's tasks are recorded as the plan scope — **approval point #8**.
**Evidence:** the roadmap path and commit sha.
**Blocker:** a phase whose `**Done when:**` restates its task list instead of naming an outcome — rewrite it before committing.

### Step 5: Create implementation plan

Invoke `superpowers:writing-plans` via the `Skill` tool, feeding it the contract and the design. On the roadmap path, pass Phase 1 as a hard scope constraint — the plan implements Phase 1 only.

The plan must state, per task: which contract piece it implements, and **which files it will create or modify**. That file list is the baseline for the scope guard rails.

> **Tests mandate (both modes):** every task includes writing tests *alongside* implementation, derived from the contract. Not deferred to the end.

Present the plan and stop — **approval point #4**. Show: numbered tasks · files created (new) · files modified (existing) · files that are read-only reference and must not be refactored.

**Exit criteria:** an approved plan whose every task names its contract piece, its file list, and its tests; the three file lists are recorded as guard-rail baselines.
**Evidence:** the plan document; the recorded file lists.
**Blocker:** a plan task with no test sub-step, or with no file list — both make the Step 6 guard rails unenforceable. Send it back rather than filling the gaps by guessing.

### Step 6: Execute the plan

> **Auto mode:** read `<plugin>/skills/add-feature/references/auto-mode.md` and follow its Steps 6, 6.5, 7, 8 instead of the blocks below. Step 9 is mode-agnostic.

**Manual mode.** Ask which execution approach, recommending parallel agents by default, and invoke it via the `Skill` tool:

| Approach | Skill |
|---|---|
| Parallel agents (recommended) | `superpowers:dispatching-parallel-agents` |
| Subagent-driven, this session | `superpowers:subagent-driven-development` |
| Sequential execution | `superpowers:executing-plans` |

Rules that apply to every execution mode:
- **Tests and code together** — both derived from the contract. No "code first, tests after".
- **Blast Radius Rule** — smallest justified change, no "while I'm here" refactors, ask before expanding scope.

**After each chunk/phase — not only at the end** — dispatch a focused review via the `Agent` tool: `subagent_type: "pr-review-toolkit:code-reviewer"`, `model: "opus"`, scoped to what that chunk changed. Fix its findings inside the same chunk. In Manual mode, stop for the user after each chunk's review is clean.

**Exit criteria:** every plan task is implemented with its tests; each chunk was reviewed and its HIGH findings resolved before the next chunk started; the files touched match the Step 5 lists.
**Evidence:** `git diff --stat` against the branch point; the per-chunk review dispositions; a green test run.
**Blocker:** carrying a chunk's unresolved findings into the next chunk. Any file touched outside the plan's lists, or any read-only-reference file modified → stop and ask; that is the user's call under the Scope Sentinel, not a judgment to absorb silently.

### Step 7: Final code review (Manual mode)

Run the deterministic gate on the whole branch first, so review time goes to design rather than mechanics:

```bash
bash <plugin>/scripts/quality-gate.sh --pwd . --base $(git merge-base HEAD <dev-branch>) --test-cmd "<project test command>"
```

Then invoke `superpowers:requesting-code-review` via the `Skill` tool for a full-feature review, and `superpowers:receiving-code-review` to process the feedback with verification rather than agreement.

**Exit criteria:** the gate exits 0 on the full branch diff; a reviewer has seen the whole feature; every HIGH finding is resolved or explicitly accepted by the user.
**Evidence:** the gate's exit code and JSON; the findings list with a disposition per item.
**Blocker:** a red gate, or an unresolved HIGH finding. Neither is cleared by re-running the reviewer on a narrower diff.

### Step 8: Finish the branch (Manual mode)

Invoke `superpowers:finishing-a-development-branch` via the `Skill` tool.

**Exit criteria:** the feature is merged to the development branch, or a PR against `develop` is open, per the user's choice.
**Evidence:** merge commit sha or PR URL.
**Blocker:** merging to `main` without explicit approval — that is **approval point #5**, and PRs target `develop` (see `~/.claude/CLAUDE.md`).

### Step 9: Post-implementation

After merge, in both modes (Auto does this without stopping; Manual confirms the merge happened first):

1. **Roadmap**, if one was used in this run: the implemented phase's completed tasks are checked off, and a phase with everything checked is marked `**Status: Complete ✓**`. Commit: `docs: mark Phase N complete in <slug> roadmap`. No roadmap in this run → skip.
2. `docs/product/user-stories.md` — the feature added as a story
3. `docs/architecture/api.md` — if any endpoints changed
4. `docs/plans/tasks.md` — completed tasks marked
5. **MemPalace `decision` record** in the project wing, after `mempalace_check_duplicate`: `[WHAT] feature <name> implemented, [CONTRACT] <path>, [FILES] <list>, [DATE] <today>`

**Exit criteria:** the roadmap (if any) reflects reality; all four docs updated or each skipped one named with a reason; the palace record written or its failure reported.
**Evidence:** the paths committed; `git diff --stat main...HEAD` for the blast-radius line; the drawer id.
**Blocker:** none blocks the release — but a skipped update is reported, never dropped silently.

Print the architect report:

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
- `/vladyslav:write-docs` — generate test plan + QA checklist (tests mode) or update user stories (stories mode)
- `/vladyslav:pre-release-check` — pre-release verification

**Exit criteria for the run as a whole:** every step above either met its criteria or is named in the report as unmet, with the reason.
**Blocker:** reporting clean success while any step's criteria went unmet.

## Auto-mode reference

For Auto-mode-specific instructions (Steps 6, 6.5, 7, 8) and the approval map, see `<plugin>/skills/add-feature/references/auto-mode.md`.
