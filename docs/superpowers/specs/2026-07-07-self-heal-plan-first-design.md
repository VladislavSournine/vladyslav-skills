# Design: Self-heal shell + plan-first triage for code skills

> Created: 2026-07-07
> Status: approved (brainstorming) — pending implementation plan
> Scope: `add-feature`, `fix-bug`, one new shared reference. **Not** CodeGraph (paused, separate effort).

## Problem

Two ergonomic/quality gaps in the code-lifecycle skills:

1. **Prerequisite friction.** `add-feature` and `fix-bug` require an AI shell (`CLAUDE.md`, `.claude/`, docs). Today Step 0 only *checks* and, if the shell is missing, **STOPs** and tells the user to go run `attach-project` / `init-project` first. The user must know and run the bootstrap sequence manually before they can do the actual task.

2. **Uneven plan-first discipline + missing bug memory.**
   - `add-feature` already enforces plan-first (brainstorm → contract → `writing-plans`).
   - `fix-bug` jumps from diagnosis (Step 4) straight to test+fix (Step 5) — no plan gate. Trivial bugs are fine that way, but non-trivial ones (research needed, multi-file, critical path) get fixed with no explicit, approved plan.
   - `fix-bug` writes **no MemPalace record at all** (unlike `add-feature`, which writes a `decision`). The same bug class can be re-encountered in a future session with no memory of the root cause.

## Non-goals (YAGNI)

- Merging `attach-project` + `ingest` into one skill.
- Removing or changing `init-project` / `attach-project` as standalone commands — they encode distinct intent (new project vs. existing) and real Q&A; they stay.
- CodeGraph integration — paused, resumes as its own effort. This design only leaves a documented hook for it.
- Adding triage to `add-feature` — a feature is non-trivial by definition; it always plans.

## Decisions (from brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Availability/prereq model | Runtime check, zero config |
| 2 | Integration form | Shared reference + one-line pointers (matches `verify-pwd.md`, `orchestration-conventions.md`) |
| 3 | Self-heal depth | **Two-tier gate**: Tier 1 = bare shell (attach), Tier 2 = separate y/n for docs + code map (ingest) |
| 4 | fix-bug plan gate | **Analyze → state assumption + recommendation → ask user** (not a rigid autonomous rule) |

## Design

### A. Self-heal shell — new shared reference

**New file:** `skills/_shared/references/self-heal-shell.md`

Single source of truth for the "shell missing" branch. Consumers: `add-feature`, `fix-bug` only. `verify-pwd.md` and `ingest` are **not** touched (`ingest` *is* the Tier-2 bootstrap; it must not offer to run itself).

Contract:

1. Precondition: caller's Step 0 has determined `CLAUDE.md` is absent in the working directory.
2. **Tier 1 (cheap, ~0.5s)** — AskUserQuestion:
   > "AI-оболонки в цьому проєкті нема. Збудувати зараз (attach-project), щоб продовжити? y/n"
   - `y` → run the `attach-project.sh` scaffolder inline (stack detect + bare shell; never overwrites). Resolve plugin root the same way `attach-project` does. Then re-read the freshly-written `CLAUDE.md` and continue the calling skill.
   - `n` → **STOP** (current behaviour) — the calling skill cannot proceed without shell context.
3. **Tier 2 (separate y/n, minutes)** — only if Tier 1 was accepted:
   > "Наповнити доки + карту коду через ingest? (сканує код, сіє MemPalace — кілька хвилин) y/n"
   - `y` → invoke `vladyslav:ingest` via the Skill tool, then return to the calling skill.
   - `n` → continue on the bare shell.
4. **CodeGraph hook (documented, inert now):** when the CodeGraph effort lands, Tier 2 additionally offers `codegraph init`. Left as a one-line note so the two efforts stay decoupled.

**Pointer edits (one line each):**
- `add-feature/SKILL.md` Step 0.1 — on "CLAUDE.md missing", apply `_shared/references/self-heal-shell.md` instead of a bare STOP+suggest.
- `fix-bug/SKILL.md` Step 0 — same.

### B. fix-bug plan-first triage — new Step 4.5

Insert between Step 4 (diagnose / `systematic-debugging`) and Step 5 (write regression test + fix).

1. With the root cause identified, the skill **analyzes** the fix and **states an assumption + recommendation**, e.g.:
   - *"Тривіальний однорядковий — інвертована умова, low blast radius → рекомендую фіксити напряму, без плану."*
   - *"Зачіпає auth-шлях / потрібен ресерч → рекомендую спершу короткий план."*
   Criticality (auth, payments, data integrity) is surfaced by the model as part of its assessment — it is not a hard rule; the user decides.
2. **Ask the user:** fix directly, or write a plan first?
3. **Plan path** → write a short, proportional plan — *root cause → the exact change → files touched → regression-test approach* — then ⏸ **approval gate**. Step 5 then executes **only** per the approved plan (already governed by the Blast Radius Rule). Plan length scales with bug size: two sentences for a one-liner, a real plan for a structural bug.
4. **Direct path** → proceed to Step 5 as today.

This satisfies "any process builds a plan first, and the fix follows the plan" — while keeping trivial fixes from drowning in process.

### C. fix-bug MemPalace `problem` record — Step 8 addition

After a successful fix and docs update, add a mandatory MemPalace write (currently absent):

```
[WHAT] баг <опис>
[ROOT CAUSE] <причина>
[FIX] <що змінено>
[FILES] <список>
[REGRESSION TEST] <файл::тест>
[DATE] <today>
```

- Room type: `problem`.
- Run `mempalace_check_duplicate` before the write (per orchestration conventions — MemPalace writes are never parallelized and always dedup-checked first).
- Wing = the one derived in Step 0 (`verify-pwd.md`).
- Purpose: a future session searching the symptom surfaces this rake immediately.

`fix-bug` is already on the README "requires MemPalace" list (it reads via `verify-pwd`), so no README dependency-list change is needed — but it now *writes*, which is a behaviour change worth a CHANGELOG note.

### D. Edit surface

| File | Change |
|------|--------|
| `skills/_shared/references/self-heal-shell.md` | **new** contract (A) |
| `skills/add-feature/SKILL.md` | Step 0.1 pointer to self-heal |
| `skills/fix-bug/SKILL.md` | Step 0 pointer to self-heal; **new Step 4.5** triage (B); Step 8 MemPalace `problem` (C) |
| `CHANGELOG.md` | entry under next version |
| `.claude-plugin/plugin.json` | bump **minor** |
| project `CLAUDE.md` | only if the doc-sync `Stop` hook requires a docs touch |

## Error handling / edge cases

- **Tier 1 attach fails** (`attach-project.sh` returns `status: error`): surface the error, do **not** continue the calling skill — STOP.
- **Tier 1 declined:** STOP with the current message (calling skill needs shell context).
- **Directory already has a shell:** self-heal reference is never entered (Step 0 found `CLAUDE.md`); no behaviour change for the common case.
- **fix-bug triage, user overrides recommendation:** the user's choice wins (e.g. model recommends "direct" but user asks for a plan, or vice-versa). The recommendation is advisory.
- **MemPalace unavailable at Step 8:** follow existing MemPalace-write degradation used elsewhere in the plugin — report that the record could not be written, do not fail the whole fix.

## Testing

- `vladyslav:smoke-test-skills` — Check F (orphan references) must pass: `self-heal-shell.md` has 2 consumers.
- Frontmatter lint hook — n/a for a reference file (not a `SKILL.md`), applies to the two edited skills.
- Smoke run of `add-feature` and `fix-bug` in a fresh session: confirm Step 0 self-heal offer renders on a shell-less dir, and `fix-bug` Step 4.5 triage renders after diagnosis.
- Manual: the runtime detect/attach path was already exercised by hand.

## Rollout

Single minor version bump. No migration — purely additive behaviour; existing projects with a shell see no change until they hit `fix-bug` on a non-trivial bug (new triage gate) or a shell-less directory (new self-heal offer).
