# Orchestrator Stance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the plugin's existing orchestration machinery activate reliably — via a thin router skill, bounded self-repair on quality gates, and a security step that `fix-bug` currently lacks.

**Architecture:** A new `orchestrate` Architect skill classifies a raw request and delegates to an existing skill; it reimplements nothing. Gate behaviour changes live in `add-feature/references/auto-mode.md` where the gate already is. Duplication is removed by pointing `save` at an existing shared reference rather than by merging skills.

**Tech Stack:** Markdown skill files, bash validators (`scripts/validate-skills.sh`, `scripts/test-validate-skills.sh`, `scripts/test-quality-gate.sh`). No application code.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-orchestrator-stance-design.md`. Phase D (`CLAUDE.md` shortening) is **out of scope** for this plan.
- Every skill dir needs a matching `commands/<name>.md` — `validate-skills.sh:60` errors on a command with no skill dir, and `:51` errors on a skill with no command.
- Frontmatter needs `name:` (matching the directory name) and `description:`; the body needs a line starting with `Type:` or `**Type:` (`validate-skills.sh:42-46`).
- Architect skills must pass `model=` to every `Agent(` call (`validate-skills.sh:76-108`). `orchestrate` delegates via the `Skill` tool and must contain **no** `Agent(` call.
- Every `skills/*/references/*.md` needs at least one consumer among `skills/*/SKILL.md`, `commands/*.md`, `scripts/**/*.sh`, or the repo `CLAUDE.md` (`validate-skills.sh:110-127`).
- Any skill whose SKILL.md contains the literal `mempalace_` must be listed in the README block between `<!-- mempalace-skills:start -->` and `<!-- mempalace-skills:end -->` (`validate-skills.sh:129-141`).
- Wing derivation is **case-preserving** — basename with whitespace/underscores/dots collapsed to single hyphens, no lowercasing (`scripts/derive-wing.sh`, `_shared/references/mempalace-record.md:38`).
- Commit messages carry no AI attribution (repo rule, `skills/help/SKILL.md:97`).
- Verification after every task: `bash scripts/validate-skills.sh` exits 0.

---

### Task 1: Remove the empty `skills/docs/` directory

**Files:**
- Delete: `skills/docs/` (contains 0 files)

**Interfaces:**
- Consumes: nothing
- Produces: nothing — this is pure cleanup that removes a directory the router could otherwise mistake for a skill

- [ ] **Step 1: Confirm the directory is genuinely empty**

```bash
find skills/docs -type f | wc -l
```

Expected: `0`

- [ ] **Step 2: Confirm nothing references it**

```bash
grep -rn "skills/docs" --include='*.md' --include='*.sh' --include='*.json' . | grep -v '^./docs/superpowers/'
```

Expected: no output (matches inside `docs/superpowers/` are this plan and the spec, which describe the deletion).

- [ ] **Step 3: Delete it**

```bash
rm -rf skills/docs
```

- [ ] **Step 4: Verify the validator still passes**

```bash
bash scripts/validate-skills.sh
```

Expected: `--- validate-skills: all checks PASS`

- [ ] **Step 5: Commit**

```bash
git add -A skills/docs
git commit -m "chore: remove empty skills/docs directory"
```

---

### Task 2: Fix the wing-derivation bug in `save` by using the shared reference

`skills/save/SKILL.md:23` says "strip leading dots → lowercase → match wings list". This contradicts `scripts/derive-wing.sh` and `_shared/references/mempalace-record.md:38`, which preserve case. Wings such as `Svitlana` and `phD` are derived incorrectly today. `qsave` already points at the shared reference; `save` does not, which is how the two drifted.

**Files:**
- Modify: `skills/save/SKILL.md` (Step 1 at line 21-23, Step 4 record shape at line 48-63)

**Interfaces:**
- Consumes: `skills/_shared/references/mempalace-record.md` — supplies the wing algorithm, the room-type table, and the `[WHAT]/[WHY]/[FILES]/[DATE]` record shape
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Verify the bug exists**

```bash
grep -n "lowercase" skills/save/SKILL.md
grep -n "case preserved" skills/_shared/references/mempalace-record.md
```

Expected: `save` line 23 contains "lowercase"; the reference line 38 contains "case preserved" — a direct contradiction.

- [ ] **Step 2: Replace Step 1 of the skill**

Replace the body of `### Step 1: Detect wing` (currently one paragraph starting "Derive wing from working directory basename") with:

```markdown
Derive the wing using the algorithm in `<plugin>/skills/_shared/references/mempalace-record.md` ("Wing" section) — the project directory **basename** with whitespace/underscores/dots collapsed to single hyphens, **case preserved**. `scripts/derive-wing.sh` implements exactly this; prefer running it when a shell is available.

Do **not** lowercase — wings such as `Svitlana` and `phD` carry meaningful case. After deriving, reconcile against the wings list in `~/.claude/CLAUDE.md` to catch case drift. If ambiguous or outside a known project, prompt the user to confirm the wing. Never guess silently.
```

- [ ] **Step 3: Replace the record shape in Step 4**

Replace the fenced record block under `### Step 4: Save to MemPalace` (the three-line `[WHAT]/[WHY]/[DATE]` block) with a pointer, so the shape has exactly one definition:

```markdown
- `content`: the record shape defined in `<plugin>/skills/_shared/references/mempalace-record.md` ("Required structure") — `[WHAT]`, `[WHY]`, `[FILES]`, `[DATE]`. Omit `[WHY]` and `[FILES]` when not applicable.
```

- [ ] **Step 4: Verify the contradiction is gone and the reference is consumed**

```bash
grep -n "lowercase" skills/save/SKILL.md || echo "OK: no lowercase rule left"
grep -c "mempalace-record.md" skills/save/SKILL.md
```

Expected: first command prints `OK: no lowercase rule left`; second prints `2`.

- [ ] **Step 5: Run the validator**

```bash
bash scripts/validate-skills.sh
```

Expected: `--- validate-skills: all checks PASS` (the skill still contains `mempalace_` calls, so its README listing stays valid).

- [ ] **Step 6: Commit**

```bash
git add skills/save/SKILL.md
git commit -m "fix: save derives wing case-preserving via shared reference"
```

---

### Task 3: Add a security step to `fix-bug`

`fix-bug` runs a deterministic gate (Step 5.7) and code review (Step 6) but never invokes a security checker. `owasp-security` is wired only into `add-feature` Auto mode, so bug fixes ship with no security review.

**Files:**
- Modify: `skills/fix-bug/SKILL.md` — insert a new `### Step 6.5: Security check` after the existing `### Step 6: Code review` section

**Interfaces:**
- Consumes: the same blocker semantics as `add-feature/references/auto-mode.md:57-60`
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Confirm the gap**

```bash
grep -cin "owasp\|security" skills/fix-bug/SKILL.md
```

Expected: `0`

- [ ] **Step 2: Locate the insertion point**

```bash
grep -n "^### Step" skills/fix-bug/SKILL.md
```

Note the heading that follows `### Step 6: Code review` — the new section goes immediately before it.

- [ ] **Step 3: Insert the security step**

```markdown
### Step 6.5: Security check

Invoke the security checker on the fix diff — a bug fix touches the same
attack surface a feature does, and skipping this is how a regression fix
introduces a vulnerability.

- Preferred: `Skill` tool → `owasp-security`, scoped to the fix diff (`git diff` against the branch point).
- Fallback: `Agent` tool → `subagent_type: "pr-review-toolkit:silent-failure-hunter"`, `model: "sonnet"`.

**Blocker if any of these appear:** injection risk (SQL, command, XSS), secrets in the diff, missing authZ on a mutation, or a silent catch block with no logging.

On a blocker: fix the cause and re-run this step. Do **not** narrow the scope passed to the checker to make a finding disappear — that is a forbidden repair (see `<plugin>/skills/add-feature/references/auto-mode.md`, "Forbidden repairs").
```

- [ ] **Step 4: Verify the step landed and the Agent call has a model**

```bash
grep -n "Step 6.5: Security check" skills/fix-bug/SKILL.md
bash scripts/validate-skills.sh
```

Expected: the grep matches; validator prints `--- validate-skills: all checks PASS`. The `Agent` fallback is written on one line with `model:` present, satisfying `check_agent_model` — if the validator reports "Agent() call without model=", the block was reformatted across lines and needs `model:` inside it.

- [ ] **Step 5: Commit**

```bash
git add skills/fix-bug/SKILL.md
git commit -m "feat: fix-bug runs owasp-security on the fix diff"
```

---

### Task 4: Bounded self-repair (loop-until-green) in the auto-mode gate

Today every gate failure escalates immediately. This adds at most two repair attempts for *quality* failures only, leaving *scope* failures escalating on the first occurrence so Scope Sentinel and the Blast Radius Rule stay absolute.

**Files:**
- Modify: `skills/add-feature/references/auto-mode.md` — replace the `**If any check fails:**` block (lines 64-68) and add a "Forbidden repairs" subsection
- Modify: `skills/add-feature/SKILL.md:33-39` — the Auto-mode guard-rail list, to state that quality failures self-repair first

**Interfaces:**
- Consumes: `scripts/quality-gate.sh` JSON output — per-check results `hygiene`, `secrets`, `scope`, `tests` (documented at `auto-mode.md:27`)
- Produces: the "Forbidden repairs" subsection, cited by `fix-bug` Step 6.5 from Task 3

- [ ] **Step 1: Replace the failure block in `auto-mode.md`**

Replace the existing `**If any check fails:**` block with:

```markdown
**If any check fails — classify first:**

| Class | Failures | Behaviour |
|---|---|---|
| **Quality** | `tests` fail, `hygiene` fail, HIGH code-review finding, `owasp-security` finding | Self-repair, max **2** attempts |
| **Scope** | `contract_changed`, any `readonly_touched`, >2 `files_outside_plan`, `SCOPE EXPANSION REQUIRED` in agent output | **Escalate immediately — never self-repair** |

Scope failures are questions about *what may change*, not about correctness. They stay the user's decision.

**Self-repair loop (quality failures only):**

1. Dispatch a fix agent — `Agent` tool, `subagent_type: "general-purpose"`, `model: "sonnet"` — with: the failing check's output verbatim, the contract, and **the same file allowlist** the original task had.
2. Re-run `quality-gate.sh` with the identical arguments used in Step 6.
3. Green → continue to commit. Red → attempt 2.
4. Still red after attempt 2 → **stop**. Report to the user: the original failure, what each attempt changed (`git diff` per attempt), and why it still fails. Do not attempt a third time.

A scope failure appearing *during* a repair attempt aborts the loop immediately and escalates — repairs never widen scope to succeed.

**Forbidden repairs.** A repair attempt must never:

- delete, skip, or `xfail` a failing test
- weaken an assertion, or narrow its inputs so it stops covering the failure
- reduce the scope passed to `owasp-security` or the code reviewer
- add `# noqa`, `eslint-disable`, `@ts-ignore`, or any equivalent suppression

Repair means fixing the cause. If the agent concludes the test itself is wrong, that is an **escalation**, not a repair — report it and let the user decide. Do not weaken the check: the gate is a contract with the user.
```

- [ ] **Step 2: Update the guard-rail list in `SKILL.md`**

In `skills/add-feature/SKILL.md`, replace the bullet reading "**Pre-commit auto-gate failure** (see Steps 6/6.5) — quality gate (tests, diff hygiene, secrets, scope via `scripts/quality-gate.sh`), code review, or security check reports blocker" with:

```markdown
- **Pre-commit auto-gate failure** (see Steps 6/6.5) — *quality* failures (tests, hygiene, code review, security) get up to 2 automatic repair attempts first; *scope* failures (contract changed, read-only file touched, >2 files outside plan) escalate immediately. Escalation happens only after the repair budget is spent.
```

- [ ] **Step 3: Verify both edits and the cross-reference from Task 3**

```bash
grep -n "Forbidden repairs" skills/add-feature/references/auto-mode.md skills/fix-bug/SKILL.md
grep -n "max \*\*2\*\* attempts" skills/add-feature/references/auto-mode.md
bash scripts/validate-skills.sh
```

Expected: "Forbidden repairs" appears in both files (the `fix-bug` hit is the citation added in Task 3); the repair budget line is present; validator passes.

- [ ] **Step 4: Confirm the gate scripts still pass their own suites**

```bash
bash scripts/test-quality-gate.sh
bash scripts/test-validate-skills.sh
```

Expected: `16 passed, 0 failed` and `26 passed, 0 failed`. No script changed in this task — a regression here means an edit went into a script by mistake.

- [ ] **Step 5: Commit**

```bash
git add skills/add-feature/references/auto-mode.md skills/add-feature/SKILL.md
git commit -m "feat: bounded self-repair for quality gate failures in auto mode"
```

---

### Task 5: The `orchestrate` skill

**Files:**
- Create: `skills/orchestrate/SKILL.md`
- Create: `commands/orchestrate.md`

**Interfaces:**
- Consumes: `_shared/references/verify-pwd.md`, `_shared/references/self-heal-shell.md`, `_shared/references/orchestration-conventions.md` — all three already exist and already have other consumers
- Produces: the routing table and the autonomy hand-off consumed by Task 6's `add-feature` change

- [ ] **Step 1: Write `skills/orchestrate/SKILL.md`**

```markdown
---
name: orchestrate
description: Use as the entry point for any non-trivial code task. Classifies the request, routes it to the right skill, owns the quality mandate.
---

# Orchestrate

## Overview

Single entry point for code work. Classifies a raw request, announces the route, and delegates. This skill **reimplements nothing** — every pipeline it dispatches to already exists.

**Type:** Architect

## Step 0: Verify working directory

Apply the contract in `<plugin>/skills/_shared/references/verify-pwd.md`. If `CLAUDE.md` is missing, apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline bootstrap rather than dead-ending. Only STOP if the user declines.

## Step 1: Classify and announce

Map the request to exactly one route:

| Signal in the request | Route |
|---|---|
| "doesn't work", traceback, regression, failing test, "не працює" | `vladyslav:fix-bug` |
| "add", "make", new behaviour, "додай", "зроби" | `vladyslav:add-feature` |
| existing project with no `docs/architecture/` | `vladyslav:ingest`, then classify again |
| new project from scratch | `vladyslav:init-project` |
| screens, design tokens, visual work | `vladyslav:design-sync` (no `docs/design/system.md`) or `vladyslav:design-page` |
| "preparing a release", pre-deploy verification | `vladyslav:pre-release-check` |
| **trivial** — typo, version bump, one-liner, git operation, question about the code | **no skill — act inline** |

The trivial row is not optional. Wrapping a typo in a full pipeline violates the ladder rule in `~/.claude/CLAUDE.md` ("prefer the laziest solution that actually works"). When in doubt between trivial and `fix-bug`, ask in one line.

**Announce the route in one line before dispatching**, so a wrong guess costs a word of correction rather than a wrong pipeline:

`Route: fix-bug — this reads as a regression in the auth middleware. Override?`

## Step 2: Set autonomy once

Only `add-feature` has a Manual/Auto mode. When the route is `add-feature`, ask **once**:

> "Manual or Auto?"

Then pass the answer down. `add-feature` Step 0.5 accepts a mode supplied by the orchestrator as satisfying its "always ask" rule — the ask happened, one level up. Asking again at that level is a bug.

For every other route there is no mode concept: skip this step. Do not invent one.

## Step 3: Delegate

Invoke the routed skill via the `Skill` tool. For dispatch mechanisms, model tiers, and what is safe to parallelize, follow `<plugin>/skills/_shared/references/orchestration-conventions.md` — do not restate those rules here.

## Quality mandate

These are not optional and are not waived by autonomy level. The routed skill owns each one; this skill's job is to notice when one was silently skipped:

- Tests written **alongside** implementation, both derived from the contract — never deferred.
- Code review before merge.
- Security check (`owasp-security`) on the diff — `add-feature` Step 6.5, `fix-bug` Step 6.5.
- Docs updated per the routed skill's post-implementation step.
- Approval gates stay serial and stay with the user.

If a routed skill completes without one of these, say so plainly in the summary rather than reporting clean success.

## Non-goals

- **Does not use `/loop`.** `/loop` is for recurring interval work and its own documentation says not to use it for one-off tasks. It is the wrong primitive for driving a single task end to end.
- **Does not self-grant `Workflow`.** `Workflow` needs explicit per-session user opt-in. If a task genuinely needs fan-out over more than four independent items, ask once; if declined, proceed without it.
- **Does not bypass Scope Sentinel.** Scope expansion is always the user's decision.
```

- [ ] **Step 2: Verify the skill has no `Agent(` call**

```bash
grep -c "Agent(" skills/orchestrate/SKILL.md
```

Expected: `0`. This skill is Architect-typed, so any `Agent(` without `model=` would fail `check_agent_model`. It delegates via the `Skill` tool only.

- [ ] **Step 3: Write `commands/orchestrate.md`**

Follow the exact delegation format every other command uses (`commands/add-feature.md`):

```markdown
---
description: "Entry point for any non-trivial code task - classifies the request, routes it to the right skill, owns the quality mandate"
---

Locate and read the skill body for vladyslav:orchestrate. Use the Glob tool with pattern '~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/skills/orchestrate/SKILL.md' to find it (the version directory varies). If Glob returns no match, fall back to '/Volumes/DevSSD/Development/vladyslav-skills/skills/orchestrate/SKILL.md' (development clone). Read the matched file with the Read tool, then follow its instructions exactly from top to bottom. Do not call the Skill tool — load the file directly.
```

- [ ] **Step 4: Run the validator**

```bash
bash scripts/validate-skills.sh
```

Expected: `--- validate-skills: all checks PASS`. This confirms frontmatter name matches the directory, the `Type:` line is present, the command exists and references the skill, and all three `_shared` references resolve.

- [ ] **Step 5: Smoke-run the skill**

Per `CLAUDE.md` "Skill Testing" step 2, a skill change is not done without a smoke run. In a fresh session, invoke `/vladyslav:orchestrate` with the request `виправ одруківку в README` and confirm it announces the **trivial** route and dispatches no skill. Then invoke it with `додай експорт у CSV` and confirm it announces `add-feature` and asks Manual/Auto exactly once.

- [ ] **Step 6: Commit**

```bash
git add skills/orchestrate/SKILL.md commands/orchestrate.md
git commit -m "feat: orchestrate skill - classifies a request and routes it"
```

---

### Task 6: Accept an orchestrator-supplied mode in `add-feature`

Without this, a user routed through `orchestrate` is asked "Manual or Auto?" twice — once by the orchestrator and again by `add-feature` Step 0.5, which currently says "Do **not** default to Auto silently — always ask."

**Files:**
- Modify: `skills/add-feature/SKILL.md:24-31` (Step 0.5)

**Interfaces:**
- Consumes: the mode value passed by `orchestrate` Step 2
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Amend Step 0.5**

Replace the final line of Step 0.5 ("Record the chosen mode for the rest of the flow. Do **not** default to Auto silently — always ask.") with:

```markdown
Record the chosen mode for the rest of the flow.

Do **not** default to Auto silently. The mode must come from an explicit user answer — but that answer may have been given one level up: if `vladyslav:orchestrate` routed here and already asked, it passes the mode down, and that satisfies this requirement. Asking again is a bug, not extra safety. Ask here only when no mode was supplied.
```

- [ ] **Step 2: Verify**

```bash
grep -n "one level up" skills/add-feature/SKILL.md
bash scripts/validate-skills.sh
```

Expected: the grep matches; validator passes.

- [ ] **Step 3: Commit**

```bash
git add skills/add-feature/SKILL.md
git commit -m "feat: add-feature accepts a mode supplied by orchestrate"
```

---

### Task 7: Documentation, README, and version bump

The repo's `Stop` hook (`check-docs-sync.sh`) blocks finishing a turn when `skills/` or `commands/` changed but no doc did, so this task is mandatory, not optional polish.

**Files:**
- Modify: `skills/help/SKILL.md` — add `orchestrate` to the Architect table
- Modify: `README.md` — add `orchestrate` to the skill list
- Modify: `CHANGELOG.md` — new `## 4.9.0` entry
- Modify: `.claude-plugin/plugin.json` — version `4.8.0` → `4.9.0`
- Modify: `docs/architecture/system.md` — note `orchestrate` as the entry point
- Modify: `SkillsManual.md` — add the skill

**Interfaces:**
- Consumes: everything from Tasks 1-6
- Produces: the released documentation surface

- [ ] **Step 1: Add `orchestrate` to the help catalogue**

In `skills/help/SKILL.md`, add as the **first** row of the `**Architect:**` table (it is the entry point, so it reads first):

```markdown
| `orchestrate` | Entry point — classifies a request, routes it to the right skill |
```

- [ ] **Step 2: Bump the version**

```bash
sed -i '' 's/"version": "4.8.0"/"version": "4.9.0"/' .claude-plugin/plugin.json
grep '"version"' .claude-plugin/plugin.json
```

Expected: `"version": "4.9.0"`. (`sed -i ''` is the macOS form; on Linux use `sed -i`.)

- [ ] **Step 3: Add the changelog entry**

Add at the top of the entries in `CHANGELOG.md`:

```markdown
## 4.9.0

### Added
- `orchestrate` skill — single entry point that classifies a request and routes it to the right skill; trivial edits deliberately bypass it
- `fix-bug` now runs `owasp-security` on the fix diff (Step 6.5) — previously bug fixes shipped with no security review
- Bounded self-repair in the auto-mode quality gate: quality failures get up to 2 repair attempts, scope failures still escalate immediately

### Fixed
- `save` derived the wing lowercased, contradicting `derive-wing.sh` and `_shared/references/mempalace-record.md`; wings such as `Svitlana` and `phD` resolved incorrectly

### Removed
- Empty `skills/docs/` directory
```

- [ ] **Step 4: Update README and architecture docs**

In `README.md`, add `orchestrate` to the skill list alongside the other Architect skills, described as the entry point. In `docs/architecture/system.md`, note that `orchestrate` is the routing layer above the existing skills and reimplements no pipeline. In `SkillsManual.md`, add an `orchestrate` section matching the format of the surrounding entries.

Do **not** add `orchestrate` to the README MemPalace list — its SKILL.md contains no `mempalace_` call, and `check_mempalace_readme` verifies that list in both directions.

- [ ] **Step 5: Full verification**

```bash
bash scripts/validate-skills.sh
bash scripts/test-validate-skills.sh
bash scripts/test-quality-gate.sh
```

Expected: `all checks PASS`, `26 passed, 0 failed`, `16 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: v4.9.0 - orchestrate skill, fix-bug security step, bounded self-repair"
```

---

### Task 8: The `CLAUDE.md` activation trigger (gated)

**This task edits `~/.claude/CLAUDE.md`, which is outside this repository and affects every project.** Present the exact diff to the user and get explicit approval before writing. Back up first.

**Files:**
- Modify: `~/.claude/CLAUDE.md` (user's global instructions — **not** in this repo)

**Interfaces:**
- Consumes: the `orchestrate` skill from Task 5
- Produces: activation — without this, the skill exists but nothing invokes it

- [ ] **Step 1: Back up the current file**

```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak-2026-07-30
wc -w ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak-2026-07-30
```

Expected: both report 2238 words.

- [ ] **Step 2: Show the user the exact insertion and wait for approval**

Proposed new section, placed immediately after the `# Global Instructions` heading so it is read before the rules it routes to:

```markdown
## Orchestrator Entry Point

For any non-trivial code task, invoke `vladyslav:orchestrate` first — it classifies the
request, routes it to the right skill, and owns the quality mandate (tests alongside code,
code review, `owasp-security`, docs). Trivial edits — typo, version bump, one-liner, git
operation, a question about the code — skip it and are done inline.
```

Four lines, ~55 words. Do not proceed without an explicit yes.

- [ ] **Step 3: Apply the approved edit**

Use the `Edit` tool on `~/.claude/CLAUDE.md` with the approved text. Do not reformat, reorder, or "tidy" any surrounding section — that is Phase D's job and it is out of scope here.

- [ ] **Step 4: Verify only the intended change landed**

```bash
diff ~/.claude/CLAUDE.md.bak-2026-07-30 ~/.claude/CLAUDE.md
```

Expected: only the added section appears in the diff. Any other change means an unintended edit — restore from the backup and redo.

- [ ] **Step 5: Confirm with the user, then remove the backup**

Only after the user confirms the trigger behaves as expected in a fresh session:

```bash
rm ~/.claude/CLAUDE.md.bak-2026-07-30
```

---

## Self-Review

**Spec coverage.** Phase A → Tasks 5, 6, 8. Phase B → Tasks 3, 4. Phase C → Tasks 1, 2. Phase D → deliberately absent (separate cycle, per the spec's Decomposition section). The spec's testing requirements 1-3 map to the verification steps in every task; requirement 4 (routing check) is Task 5 Step 5; requirement 5 (self-repair check) has **no automated coverage** — it needs a live run on a throwaway project and is called out below.

**Deviation from the approved spec — Phase C.** The spec said to merge `save` + `qsave`. Implementation research showed this is the wrong move: `validate-skills.sh:60` requires a skill directory for every command, so keeping `/qsave` as an alias fails validation; deleting it breaks the QSave Offer rule in the global `CLAUDE.md`; and the real duplication is already solved by `_shared/references/mempalace-record.md`, which `save` simply fails to cite — which is exactly how the two drifted into contradicting each other on wing case. Task 2 fixes the actual bug and removes the actual duplication at lower risk. Both skills and both commands stay.

**Placeholder scan.** No TBD/TODO. Every edit step contains the literal text to insert. Task 7 Step 4 describes three doc edits in prose rather than exact text — acceptable because the surrounding format varies per file and must be matched, but it is the least prescriptive step in the plan.

**Type consistency.** Route names in Task 5's table match the real skill directory names in `skills/`. The `Forbidden repairs` heading created in Task 4 is the exact string cited by Task 3 — verified by the grep in Task 4 Step 3. The mode hand-off in Task 5 Step 2 matches the acceptance wording in Task 6.

**Known gap.** Self-repair (Task 4) is instruction-only: it changes what the model does, and no script asserts the 2-attempt bound or the forbidden-repair rules. `test-quality-gate.sh` covers the gate script, not the loop around it. First real use should be watched directly.
