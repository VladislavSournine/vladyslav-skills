# Self-heal Shell + Plan-first Triage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `add-feature` and `fix-bug` offer to bootstrap a missing AI shell instead of dead-ending, give `fix-bug` a proportional plan-first gate, and make `fix-bug` write a MemPalace `problem` record after a successful fix.

**Architecture:** Pure Markdown-skill edits. One new shared reference (`_shared/references/self-heal-shell.md`) holds the self-heal contract; `add-feature` and `fix-bug` gain one-line pointers to it. `fix-bug` gets a new triage step (4.5) and a MemPalace write in Step 8. No code, no runtime; correctness is verified by the repo's static validator plus targeted greps.

**Tech Stack:** Markdown (`SKILL.md` + `references/*.md`), `scripts/validate-skills.sh` (POSIX bash validator), `.claude-plugin/plugin.json` (semver).

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-07-07-self-heal-plan-first-design.md` — the authority; every task traces to it.
- **No behaviour is silent** — every heavier step is a `y/n` gate or an approval gate. Copy this discipline into the reference verbatim.
- **`verify-pwd.md` and `ingest/SKILL.md` are NOT edited** (out of scope — `ingest` is itself the Tier-2 bootstrap).
- **`add-feature` triage is NOT added** — a feature always plans; only `fix-bug` gets the triage.
- **CodeGraph is OUT of scope** — the reference may mention it only as an inert one-line "future hook", never as a live dependency.
- **Validator is the gate:** `bash scripts/validate-skills.sh` must exit 0 at the end of every task. A new `references/*.md` with no consumer FAILS Check F — so the reference and its pointers land in the same task.
- **Version bump:** `4.6.0` → `4.7.0` (minor, additive).
- **Commit trailer:** end every commit body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Branch:** work stays on the current branch `feature/quality-system-hardening` (not `main`).

---

### Task 1: Self-heal shell reference + Step 0 pointers

Traces to spec §A. The reference is inert without consumers and would fail validator Check F alone, so it ships with both pointers in one task.

**Files:**
- Create: `skills/_shared/references/self-heal-shell.md`
- Modify: `skills/add-feature/SKILL.md` (Step 0.1 block, around lines 16–21)
- Modify: `skills/fix-bug/SKILL.md` (Step 0 block, around lines 16–18)
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Produces: a reference at path `skills/_shared/references/self-heal-shell.md` whose **basename** `self-heal-shell.md` is cited in both `add-feature/SKILL.md` and `fix-bug/SKILL.md` (this is what satisfies Check F, which matches by basename).
- Consumes: `attach-project.sh` (existing scaffolder) and the `vladyslav:ingest` skill — both already exist; the reference only *instructs* the caller to invoke them.

- [ ] **Step 1: Create the reference file**

Create `skills/_shared/references/self-heal-shell.md` with exactly this content:

```markdown
# Self-heal shell (bootstrap-if-missing)

The offer a code-lifecycle skill makes when its working directory has **no AI shell**
(`CLAUDE.md` absent). Replaces a bare "STOP — go run attach-project" dead-end with an
inline, consented bootstrap. Two-tier, nothing runs silently.

Consumers: `add-feature`, `fix-bug`. (`ingest` is Tier 2 itself — it must never enter here.)

## Precondition

The caller's Step 0 has already run the `verify-pwd.md` check and found `CLAUDE.md`
missing in the working directory. Only then apply this contract.

## Tier 1 — bare shell (cheap, ~0.5s)

AskUserQuestion:

> "AI-оболонки в цьому проєкті нема. Збудувати зараз (attach-project), щоб продовжити? (y/n)"

- **y →** run the `attach-project.sh` scaffolder inline with low-friction defaults (no
  onboarding wizard — the user is here to do a task, not to onboard):
  1. Resolve the plugin root exactly as `attach-project` does: Glob
     `~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/scripts/attach-project.sh`,
     take the directory two levels up; fall back to
     `/Volumes/DevSSD/Development/vladyslav-skills` (dev clone).
  2. Run:
     ```bash
     <plugin-root>/scripts/attach-project.sh \
         --pwd . \
         --plugin-root <plugin-root> \
         --domain "" \
         --private-mode no
     ```
  3. If the JSON reports `status: error` → surface the error and **STOP** (do not
     continue the calling skill).
  4. On success, re-read the freshly-written `CLAUDE.md` (and any docs stubs) and
     continue the calling skill's Step 0 (derive wing, etc.).
  - For full interactive control (domain, private mode, extra stacks) the user can run
    `/vladyslav:attach-project` explicitly instead — mention this once.
- **n →** **STOP** with the historic message: the skill cannot proceed without shell
  context. Suggest `/vladyslav:attach-project` or `/vladyslav:init-project`.

## Tier 2 — fill docs + code map (minutes; only if Tier 1 accepted)

AskUserQuestion (separate gate):

> "Наповнити доки + карту коду через ingest? Сканує код і сіє MemPalace — кілька хвилин. (y/n)"

- **y →** invoke `vladyslav:ingest` via the Skill tool, let it complete, then return to
  the calling skill.
- **n →** continue on the bare shell; the calling skill proceeds normally.

## Future hook (inert now — do not implement here)

When the CodeGraph integration lands, Tier 2 will additionally offer `codegraph init`
to build the code index. Left as a documented note only; this reference adds no
CodeGraph behaviour today.
```

- [ ] **Step 2: Add the pointer in `add-feature`**

In `skills/add-feature/SKILL.md`, the Step 0.1 block currently reads (verbatim anchor):

```
Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`: confirms CLAUDE.md exists, derives the canonical MemPalace wing name, warns on stale-wing duplicates, and establishes the mandatory path-validation rule for the rest of this skill's MemPalace reads.

Additionally, read the project name from `CLAUDE.md` (first heading or `# <ProjectName>` line).
```

Insert a sentence between those two paragraphs so the block becomes:

```
Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`: confirms CLAUDE.md exists, derives the canonical MemPalace wing name, warns on stale-wing duplicates, and establishes the mandatory path-validation rule for the rest of this skill's MemPalace reads.

**If `CLAUDE.md` is missing, do not dead-end** — apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline shell bootstrap, then continue. Only STOP if the user declines.

Additionally, read the project name from `CLAUDE.md` (first heading or `# <ProjectName>` line).
```

- [ ] **Step 3: Add the pointer in `fix-bug`**

In `skills/fix-bug/SKILL.md`, the Step 0 block currently reads (verbatim anchor):

```
Apply the verify-working-directory contract from `<plugin>/skills/_shared/references/verify-pwd.md`: confirms CLAUDE.md exists, derives the canonical MemPalace wing name, warns on stale-wing duplicates, and establishes the mandatory path-validation rule for the rest of this skill's MemPalace reads.
```

Append one sentence right after it:

```

**If `CLAUDE.md` is missing, do not dead-end** — apply `<plugin>/skills/_shared/references/self-heal-shell.md` to offer an inline shell bootstrap, then continue. Only STOP if the user declines.
```

- [ ] **Step 4: Verify the validator passes (Check F included)**

Run: `bash scripts/validate-skills.sh`
Expected: exits `0`; no line containing `orphan reference: skills/_shared/references/self-heal-shell.md`.

Also confirm the basename is cited by both skills:
Run: `grep -lF self-heal-shell.md skills/add-feature/SKILL.md skills/fix-bug/SKILL.md`
Expected: both file paths printed.

- [ ] **Step 5: Commit**

```bash
git add skills/_shared/references/self-heal-shell.md skills/add-feature/SKILL.md skills/fix-bug/SKILL.md
git commit -m "feat: self-heal shell bootstrap for add-feature and fix-bug

Step 0 of both skills now offers an inline attach (Tier 1) + optional
ingest (Tier 2) when CLAUDE.md is missing, instead of dead-ending.
New shared contract: _shared/references/self-heal-shell.md.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: fix-bug plan-first triage (Step 4.5)

Traces to spec §B. Independent deliverable — a reviewer can accept/reject the triage without touching self-heal.

**Files:**
- Modify: `skills/fix-bug/SKILL.md` (insert new Step 4.5 between Step 4 "Diagnose the bug" and Step 5 "Write regression test + fix")
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Consumes: the root cause produced by Step 4 (`systematic-debugging`).
- Produces: for the "plan" path, an approved fix-plan that Step 5 executes against; for the "direct" path, no artifact (Step 5 proceeds as before).

- [ ] **Step 1: Insert Step 4.5**

In `skills/fix-bug/SKILL.md`, immediately **after** the Step 4 block (which ends at the `- Avoid jumping to conclusions` line) and **before** `### Step 5: Write regression test + fix`, insert:

```
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

```

- [ ] **Step 2: Verify structure and validator**

Run: `grep -n "### Step 4.5: Triage" skills/fix-bug/SKILL.md`
Expected: one match, positioned before the `### Step 5:` line (confirm with
`grep -n "^### Step" skills/fix-bug/SKILL.md` — 4.5 appears between 4 and 5).

Run: `bash scripts/validate-skills.sh`
Expected: exits `0`.

- [ ] **Step 3: Commit**

```bash
git add skills/fix-bug/SKILL.md
git commit -m "feat: fix-bug plan-first triage gate (Step 4.5)

After diagnosis, analyze the fix, recommend direct-vs-plan (surfacing
critical-path risk), and let the user decide. Plan path writes a
proportional plan + approval before Step 5 executes.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: fix-bug MemPalace `problem` record (Step 8)

Traces to spec §C. Closes the gap where `fix-bug` writes no MemPalace record at all.

**Files:**
- Modify: `skills/fix-bug/SKILL.md` (Step 8 "Update docs", add a MemPalace item; and reflect it in the Step 9 report block)
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Consumes: the wing name derived in Step 0 (`verify-pwd.md`), and the fix details (root cause, files, regression test) from Steps 4–6.
- Produces: one MemPalace `problem` drawer in the project wing.

- [ ] **Step 1: Add the MemPalace write to Step 8**

In `skills/fix-bug/SKILL.md`, Step 8 currently lists three doc updates:

```
1. `docs/product/user-stories.md` — add note about the fix or update affected story status
2. `docs/testing/manual-qa.md` — add regression check for this bug
3. `docs/plans/tasks.md` — mark bug task as done (if it was tracked)
```

Append a fourth item:

```
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
```

- [ ] **Step 2: Reflect it in the Step 9 report**

In `skills/fix-bug/SKILL.md`, the Step 9 report block lists updated artifacts:

```
Updated:
- docs/product/user-stories.md
- docs/testing/manual-qa.md
- docs/plans/tasks.md
```

Change it to:

```
Updated:
- docs/product/user-stories.md
- docs/testing/manual-qa.md
- docs/plans/tasks.md
- MemPalace wing <name> — problem record added
```

- [ ] **Step 3: Verify**

Run: `grep -n "MemPalace .problem. record\|mempalace_check_duplicate\|problem record added" skills/fix-bug/SKILL.md`
Expected: matches for the Step 8 item, the `check_duplicate` mention, and the Step 9 report line.

Run: `bash scripts/validate-skills.sh`
Expected: exits `0` (in particular, README↔MemPalace sync still passes — `fix-bug` was already a MemPalace consumer, so no README list change is required).

- [ ] **Step 4: Commit**

```bash
git add skills/fix-bug/SKILL.md
git commit -m "feat: fix-bug writes a MemPalace problem record after a fix

Step 8 now records root cause + fix + regression test to the project
wing (check_duplicate first), closing the gap vs add-feature. Reflected
in the Step 9 report.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Release metadata (CHANGELOG + version bump)

Traces to spec §D. Also satisfies the `check-docs-sync.sh` Stop hook (skill changes accompanied by CHANGELOG/docs touch).

**Files:**
- Modify: `CHANGELOG.md` (new `## v4.7.0` section at the top, above `## v4.6.0`)
- Modify: `.claude-plugin/plugin.json` (`version`)
- Verify: `scripts/validate-skills.sh`

**Interfaces:**
- Consumes: the three behaviour changes from Tasks 1–3.
- Produces: version `4.7.0` and a changelog entry describing them.

- [ ] **Step 1: Add the CHANGELOG entry**

In `CHANGELOG.md`, insert directly below the `# Changelog` heading (line 1) and above `## v4.6.0`:

```markdown
## v4.7.0

Self-heal shell + plan-first discipline for the code-lifecycle skills.

- **Self-heal shell (`_shared/references/self-heal-shell.md`, new)** — when `add-feature`
  or `fix-bug` starts in a directory with no `CLAUDE.md`, Step 0 now offers a two-tier
  inline bootstrap (Tier 1: bare shell via `attach-project.sh`; Tier 2: optional
  `ingest`) instead of dead-ending. Nothing runs without a `y/n`. `init-project` /
  `attach-project` remain available as explicit commands.
- **`fix-bug` plan-first triage (Step 4.5)** — after diagnosis, the skill analyzes the
  fix, recommends direct-vs-plan while surfacing critical-path risk, and lets the user
  decide. The plan path writes a proportional plan + approval before any code changes.
- **`fix-bug` MemPalace `problem` record (Step 8)** — a successful fix now records root
  cause + fix + regression test to the project wing (`check_duplicate` first), closing
  the gap versus `add-feature` (which already wrote a `decision`).

```

- [ ] **Step 2: Bump the version**

In `.claude-plugin/plugin.json`, change:

```json
  "version": "4.6.0",
```

to:

```json
  "version": "4.7.0",
```

- [ ] **Step 3: Verify**

Run: `grep -n '"version": "4.7.0"' .claude-plugin/plugin.json && grep -n "## v4.7.0" CHANGELOG.md`
Expected: one match each.

Run: `bash scripts/validate-skills.sh`
Expected: exits `0`.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: v4.7.0 — self-heal shell + fix-bug plan-first & MemPalace record

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- §A self-heal reference + pointers → Task 1 ✓
- §B fix-bug triage Step 4.5 → Task 2 ✓
- §C fix-bug MemPalace problem record → Task 3 ✓
- §D CHANGELOG + plugin.json bump → Task 4 ✓
- §"CodeGraph out of scope" → honored; only an inert note in the reference ✓
- §"init/attach unchanged", "verify-pwd/ingest untouched", "no add-feature triage" → no task edits them ✓

**2. Placeholder scan:** No "TBD/TODO/handle edge cases". The `<опис>`, `<причина>`, `<плагін-root>` tokens are runtime fill-ins **inside skill prose** (the deliverable is the instruction, not a value to compute now) — consistent with how existing skills like `add-feature` Step 9 and `ingest` Step 5 template MemPalace records. Not plan placeholders.

**3. Type consistency:** The reference basename `self-heal-shell.md` is used identically in Task 1 Steps 1–5 and matches the Check F basename-match. Step numbers (4.5 between 4 and 5) and file paths are consistent across tasks. `check_duplicate` naming matches `orchestration-conventions.md`.

**Verification model note:** this repo has no unit-test suite — skills are Markdown. The per-task "test" is `scripts/validate-skills.sh` (frontmatter, command delegation, cross-references, Architect `model=` rule, **Check F orphan references**, README↔MemPalace sync) plus targeted greps, exactly as the project's `Skill Testing` section prescribes. A final manual smoke run of both skills in a fresh session is recommended post-merge but is not a plan task.
