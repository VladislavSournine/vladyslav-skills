# Add Feature — Auto Mode (Steps 6 / 6.5 / 7 / 8)

This file contains the Auto-mode-specific instructions for `add-feature`. The orchestrator (`SKILL.md`) reads this when the user chose **Auto** in Step 0.5.

Manual-mode instructions remain inline in `SKILL.md`. Steps 1-5 and Step 9 are mode-agnostic and live in `SKILL.md` as well.

---

## Step 6 (Auto): Execute the plan

Execute the plan directly via parallel subagents. **Do NOT stop to ask between tasks** unless a guard rail triggers.

For each batch of parallelizable tasks from the plan:

1. **Launch two subagents in parallel via the Agent tool** (single message, two tool calls):
   - Agent A — `subagent_type: "general-purpose"`, `isolation: "worktree"`, `model: "sonnet"`. Prompt includes: the contract, the brainstorm result, the relevant task from the plan, and this strict instruction:
     > "You may only CREATE or MODIFY these files: `<plan's file list for this task>`. Files outside this list are read-only — do NOT touch them. If you discover you need to modify a file outside the list, STOP and report `SCOPE EXPANSION REQUIRED: <path> — <reason>` instead of making the change. Do NOT modify the contract file `<contract path>` under any circumstances — that file is frozen."
   - Agent A writes **tests** for the contract piece.
   - Agent B — `subagent_type: "general-purpose"`, `isolation: "worktree"`, `model: "sonnet"`. Agent B writes the **implementation** for the contract piece, against the same file list constraint.

2. **Wait for both agents to return.**

3. **Run the deterministic gate on the combined changes:**
   - Write the plan's file list for this task to a temp file (one path per line; include the contract file and its `.sha256` baseline — they are gate plumbing, not scope violations). If the plan marked files "read-only reference", write those globs to a second temp file.
   - Run:
     `bash <plugin>/scripts/quality-gate.sh --pwd <worktree> --test-cmd "<project test command>" --plan-list <temp plan file> --contract <contract path> --readonly-globs <temp globs file>`
   - It emits JSON with per-check results (`hygiene`, `secrets`, `scope`, `tests`). Interpret:
     - **`hygiene`, `secrets`, or `tests` fail** → auto-gate blocker: STOP + report (same failure flow as Step 6.5).
     - **`scope` fail** → apply the guard rails from its detail JSON: `contract_changed: true` or any `readonly_touched` entry → STOP + report; more than **2** `files_outside_plan` → STOP + report; 1–2 files outside the plan → note them in the report and continue.
   - **Scope expansion keyword:** scan either agent's output for `SCOPE EXPANSION REQUIRED`. If present → STOP + report that agent's message verbatim to the user.

4. **If the gate and the keyword scan pass → proceed to Step 6.5** (auto-gate). If Step 6.5 also passes → commit and move to the next batch.

5. **Repeat** until the plan is fully executed.

**Rules that apply to every execution mode:**
- **Tests and code in parallel** — both derive from the contract (Step 4.5). No "code first, tests after".
- **Blast Radius Rule** (see `~/.claude/CLAUDE.md`) — smallest justified change, no "while I'm here" refactors, ask the user before expanding scope.

---

## Step 6.5: Auto-gate (auto mode only)

**Runs before every commit in auto mode. Blocks the commit on failure. No user approval needed for the gate itself — only if it fails.**

Execute these checks sequentially. If all pass → commit. If any fails → STOP, report, ask the user what to do.

1. **Deterministic gate.** Tests, diff hygiene, secrets, and plan scope already ran via `quality-gate.sh` in Step 6. If anything changed since that run (review fixes, new files), re-run the same command. **Blocker if it exits non-zero.**

2. **Code review.** Dispatch a review agent via the Agent tool:
   - `subagent_type: "pr-review-toolkit:code-reviewer"`, `model: "sonnet"` (preferred), or `subagent_type: "feature-dev:code-reviewer"`, `model: "sonnet"` as fallback
   - Prompt: "Review the staged diff (`git diff --cached`) for bugs, logic errors, security issues, and project-convention violations. Report only HIGH-confidence issues. Flag silent failures and inadequate error handling specifically."
   - **Blocker if the agent reports any HIGH-severity issue.**

3. **SwiftUI review (iOS projects only).** If the project uses Swift/SwiftUI (detected by `.xcodeproj`, `Package.swift`, or `.swift` files in the staged diff), invoke the `vladyslav:swiftui-pro` skill via the Skill tool, scoped to the staged diff files. **Blocker if the skill reports any HIGH-severity issue** (deprecated API, accessibility violation, Swift concurrency data race).

4. **Security.** Invoke the security checker:
   - Preferred: Skill tool → `owasp-security` (scoped to the staged diff)
   - Fallback: Agent tool → `subagent_type: "pr-review-toolkit:silent-failure-hunter"`, `model: "sonnet"`
   - **Blocker if: injection risks, secrets in diff, authZ gaps on mutations, silent catch blocks without logging.**

**If all checks pass:** proceed to commit. The pre-commit hook (`~/.claude/hooks/pre-commit-review.sh`) will still fire as an additional safety net — that's expected, not redundant. Compose a concise commit message referencing the contract piece, stage only the files from the plan (not `git add -A`), commit.

**If any check fails — classify first:**

| Class | Failures | Behaviour |
|---|---|---|
| **Quality** | `tests` fail, `hygiene` fail, HIGH code-review finding, `owasp-security` finding | Self-repair, max **2** attempts |
| **Scope** | `contract_changed`, any `readonly_touched`, >2 `files_outside_plan`, `SCOPE EXPANSION REQUIRED` in agent output | **Escalate immediately — never self-repair** |

Scope failures are questions about *what may change*, not about correctness. They stay the user's decision — see the Scope Sentinel and Blast Radius rules in `~/.claude/CLAUDE.md`.

**Self-repair loop (quality failures only):**

1. Dispatch a fix agent — `Agent` tool, `subagent_type: "general-purpose"`, `model: "sonnet"` — with: the failing check's output verbatim, the contract, and **the same file allowlist** the original task had.
2. Re-run `quality-gate.sh` with the identical arguments used in Step 6.
3. Green → continue to commit. Red → attempt 2.
4. Still red after attempt 2 → **stop**. Report to the user: the original failure, what each attempt changed (`git diff` per attempt), and why it still fails. Do not attempt a third time.

A scope failure appearing *during* a repair attempt aborts the loop immediately and escalates — repairs never widen scope in order to succeed.

**Forbidden repairs.** A repair attempt must never:

- delete, skip, or `xfail` a failing test
- weaken an assertion, or narrow its inputs so it stops covering the failure
- reduce the scope passed to `owasp-security` or the code reviewer
- add `# noqa`, `eslint-disable`, `@ts-ignore`, or any equivalent suppression

Repair means fixing the cause. If the agent concludes the test itself is wrong, that is an **escalation**, not a repair — report it and let the user decide. Do NOT bypass the gate. Do NOT weaken the check ("the test is flaky, let's skip it"). The gate is a contract with the user.

**When the repair budget is spent**, ask: "Auto-gate failure at <step> after 2 repair attempts. <details>. How to proceed? (fix and retry / reopen plan / abort feature)"

> **Tests checkpoint:** Before accepting "done" from Step 6, explicitly ask: "Did each task include tests written alongside the implementation (not deferred)?" If not, send the user back to write the missing tests before proceeding.

---

## Step 7 (Auto): Final code review

The per-commit auto-gate (Step 6.5) already runs the code review agent on each commit, so a final code review pass is usually redundant. Exception: run one **whole-branch review** at the end via Agent tool `subagent_type: "pr-review-toolkit:code-reviewer"`, `model: "sonnet"` with prompt "Review the entire branch diff (`git diff main...HEAD`) for cross-commit issues — inconsistencies, partial refactors, dead code left between commits."

If the whole-branch review surfaces issues: dispatch another subagent to fix them (same file-scope constraint as Step 6), re-run auto-gate, then proceed. No user approval needed unless a guard rail triggers.

---

## Step 8 (Auto): Finish the branch

Merge the feature branch into `dev` (or the project's development branch — detect from `git branch -r` or CLAUDE.md) **automatically, without user approval**. Use a merge commit (not squash) by default so the per-commit history is preserved, unless the project's CLAUDE.md specifies otherwise.

Do **NOT** merge into `main` automatically. Merge-to-main is **approval point #5** — after the report in Step 9, ask the user: "All checks passed, dev branch is updated. Merge to main now? (yes / not yet / never on auto)". On `yes`, merge to main. On `not yet`, leave it on dev and note in the report. On `never on auto`, record a preference memory and never ask again for this project.

---

## Auto-mode approval map (quick reference)

**Approval required (user must say yes):**
1. Feature description (Step 2)
2. Brainstorm output (Step 4)
3. Contract (Step 4.5)
4. Plan (Step 5)
5. Merge to `main` (Step 8 end)
6. Any guard rail trigger (Step 6 checks #1-4, Step 6.5 failures)
7. Final pre-release check (separate skill: `/vladyslav:pre-release-check`)
8. Roadmap generation (Step 4.7) — when multi-phase gate fires and user confirms roadmap creation

**Automatic (no approval — runs nonstop):**
- Worktree / branch creation (Step 3)
- Parallel agent dispatch for tests + code (Step 6)
- Deterministic quality gate (tests, hygiene, secrets, scope — `quality-gate.sh`) → code review → SwiftUI review (iOS only) → security checks before each commit (Steps 6–6.5)
- Commit messages, staging, committing
- Merge to `dev` branch (Step 8)
- Updates to `docs/product/user-stories.md`, `docs/architecture/api.md`, `docs/plans/tasks.md`
- MemPalace `decision` record writes

**Guard rails — silent auto-STOP + ask:**
- More than 2 files touched outside the plan
- Any existing file refactored that was marked "read-only reference"
- Contract file hash changed during execution
- `SCOPE EXPANSION REQUIRED` in any agent's output
- Auto-gate blocker: test failure / HIGH-severity review issue / security finding

**Design principle:** Auto mode is fast for **routine** features where the contract is clear. When something unexpected comes up, a guard rail should catch it and escalate — not silently absorb it. If a user finds themselves repeatedly approving guard rail triggers for the same kind of expansion, that's a signal the plan format should be richer, not that the guard rails should be loosened.
