# Design: Orchestrator stance + context-cost reduction

> Created: 2026-07-30
> Status: approved (design), pending implementation plan

## Problem

The plugin already contains full orchestration machinery: `add-feature` Auto mode dispatches
parallel subagents, runs a deterministic quality gate, code review, and `owasp-security`,
then commits and merges to dev with only four approval gates. None of it was reliably
*activated*. Sessions that began with an explicit "you are the orchestrator, use
opus/sonnet/haiku as needed" framing behaved markedly better — more autonomous, and did not
forget the security review. Sessions without it defaulted to conservative, one-step-at-a-time
behaviour.

The gap is **activation, not capability**. Nothing sets the orchestrator stance at session
start, and nothing turns a raw request ("fix this", "add X") into a skill choice.

Two secondary problems surfaced while measuring:

1. `fix-bug` runs a deterministic gate and code review but **never runs a security check**.
   `owasp-security` is wired only into `add-feature` Auto mode. Bug fixes therefore ship with
   no security review at all, regardless of stance.
2. Every gate failure escalates to the user immediately. There is no bounded self-repair, so
   routine failures (a failing test, one HIGH review finding) cost a round trip.

## Measured context cost

Established by direct measurement, not estimation:

| Item | Size | Loaded |
|------|------|--------|
| `~/.claude/CLAUDE.md` (global) | 2238 words (~3000 tokens) | every session, every project |
| `CLAUDE.md` (this project) | 861 words (~1150 tokens) | every session in this repo |
| All 20 skill `description:` lines combined | 369 words (~500 tokens) | every session |
| Skill bodies (2755 lines total) | — | only when invoked |

**Consequence:** deleting a skill saves ~27 tokens. Skill consolidation is *not* justified on
token grounds and this design does not claim it is. The only meaningful token sink is
`CLAUDE.md`. Consolidation is justified separately, on routing-clarity grounds: overlapping
skill descriptions make the router in Phase A ambiguous.

## Design principle (unifies all three phases)

**Short always-on triggers; long procedural detail loaded on demand.**

A rule that must always fire needs only a trigger line in `CLAUDE.md`. The procedure it
invokes belongs in a skill or reference file that loads when relevant. This is the same move
in all three phases: Phase A applies it to the orchestrator stance, Phase B applies it to
`CLAUDE.md` itself, Phase C removes the duplication that makes triggers ambiguous.

---

## Phase A — `vladyslav:orchestrate`

### A1. Activation (hybrid)

Three lines in `~/.claude/CLAUDE.md` point at the skill; all logic lives in the skill:

> For any non-trivial code task, invoke `vladyslav:orchestrate` first. It classifies the
> request, routes it to the right skill, and owns the quality mandate. Trivial edits
> (typo, version bump, one-liner, git operation) skip it — do them inline.

Rejected alternatives:
- **Full stance section in `CLAUDE.md`** — adds ~60 words to the largest token sink, and puts
  iterable logic somewhere unversioned and untested by `validate-skills.sh`.
- **Skill only, no trigger** — the user must still type the skill name, so the
  "which skill do I pick" problem remains unsolved.

### A2. Skill shape

`skills/orchestrate/SKILL.md`, **Type: Architect**. A thin dispatcher. It does not reimplement
any pipeline.

- **Step 0 — verify working directory.** Apply `_shared/references/verify-pwd.md`; on missing
  `CLAUDE.md` apply `_shared/references/self-heal-shell.md`. No duplication.
- **Step 1 — classify and announce.** Map the raw request to one route (table below). The
  chosen route is announced in one line before dispatch so the user can override.
- **Step 2 — set autonomy once, and only where it applies.** Only `add-feature` has a
  Manual/Auto mode (its Step 0.5). When the route is `add-feature`, `orchestrate` asks once and
  **passes the chosen mode down**; `add-feature` Step 0.5 must accept a mode supplied by the
  orchestrator as satisfying its "always ask" requirement — the ask happened, one level up.
  Without this the user is asked the same question twice. For every other route there is no
  mode concept, so Step 2 is skipped entirely. This design does **not** add a mode to
  `fix-bug` — that is scope creep, and `fix-bug` is short enough to run as-is.
- **Step 3 — delegate.** Invoke the target skill via the `Skill` tool. Model tiers and
  parallelism-safety come from `_shared/references/orchestration-conventions.md` by reference.

### A3. Routing table

| Signal in the request | Route |
|---|---|
| "doesn't work", traceback, regression, failing test | `fix-bug` |
| "add", "make", new behaviour | `add-feature` |
| existing project with no `docs/architecture/` | `ingest`, then re-classify |
| new project from scratch | `init-project` |
| screens, tokens, visual work | `design-sync` / `design-page` |
| "preparing a release" | `pre-release-check` |
| **trivial** — typo, version bump, one-liner, git operation | **no skill; act inline** |

The trivial row is mandatory. Without it the orchestrator adds ceremony to small work, which
violates the ladder rule in `~/.claude/CLAUDE.md` ("prefer the laziest solution that works").

### A4. Explicit non-goals

- **`orchestrate` does not use `/loop`.** `/loop` is for recurring interval work and its own
  documentation says not to use it for one-off tasks. It is the wrong primitive for driving a
  single task end to end.
- **`orchestrate` does not self-grant `Workflow`.** `Workflow` requires explicit per-session
  user opt-in. If a task genuinely needs fan-out over more than four independent items,
  `orchestrate` asks for opt-in once and proceeds without it if declined.

---

## Phase B — loop-until-green + close the `fix-bug` security gap

Changes `skills/add-feature/references/auto-mode.md` (where the gate already lives) and
`skills/fix-bug/SKILL.md`. No new gate is written.

### B1. Failure classification

The split that keeps Scope Sentinel intact:

| Class | Failures | Behaviour |
|---|---|---|
| **Quality** | failing tests, HIGH code-review finding, `owasp-security` finding | self-repair, max **2** attempts |
| **Scope** | `contract_changed`, `readonly_touched`, files outside plan, `SCOPE EXPANSION REQUIRED` | **never** self-repair — escalate immediately |

Self-repair dispatches a fix agent (`model: "sonnet"`) with the failure output and **the same
file allowlist** as the original task, then re-runs `quality-gate.sh`. After two failed
attempts, stop and report to the user with both attempts' output.

Scope failures are questions about *what may change*, not about correctness. They remain the
user's decision, so Scope Sentinel and the Blast Radius Rule stay absolute.

### B2. Forbidden repairs

Stated explicitly because it is the predictable failure mode. A repair attempt must not:

- delete, skip, or `xfail` a failing test
- weaken an assertion or narrow its input
- reduce the scope passed to `owasp-security`
- add `# noqa`, `eslint-disable`, or equivalent suppression

Repair means fixing the cause. If the agent concludes the test itself is wrong, that is an
escalation, not a repair.

### B3. Security step for `fix-bug`

Add a security step after Step 6 (code review): invoke `owasp-security` via the `Skill` tool,
scoped to the fix diff, with the same blocker semantics as `add-feature` Step 6.5 #4
(injection risk, secrets in diff, authZ gap on mutations, silent catch without logging).
This closes a gap that exists today independently of the orchestrator.

---

## Phase C — remove duplication that makes routing ambiguous

**Audit result: the overlap is far smaller than assumed.** Verified non-overlapping and left
alone: the `write-*` trio (distinct artifacts and triggers), `design-sync` → `design-page`
(sequential), `attach-project` → `ingest` (sequential, distinct outputs), `discover` /
`discover-apple-check` (sub-step, but independently valid for iOS).

Two concrete items only:

1. **`skills/docs/`** — empty directory, 0 files. Delete.
2. **`save` + `qsave`** — genuine duplicate. Both write a decision/problem/milestone to
   MemPalace for the current wing; the only difference is that `qsave` asks no questions. Merge
   into `save` with a zero-question mode, keep `/qsave` as a command alias so existing muscle
   memory and the CLAUDE.md QSave Offer keep working. `compact-save` is distinct
   (hook-triggered task-state snapshot, not a knowledge record) and stays.

---

## Phase D — shorten `CLAUDE.md`

Applies the design principle to the 2238-word global file. Target ~1000 words with **no rule
lost** — each moved rule keeps a one-line trigger in `CLAUDE.md` pointing at its reference.

| Section | Words | Action |
|---|---|---|
| Design System Discipline | ~450 | Move to an on-demand reference. It is UI-only but currently loads in every session, including this plugin repo and backend projects with no UI. Keep a one-line trigger. |
| MemPalace — Long-term Memory | ~450 | Keep the search-first rule and the mandatory path-validation rule inline. Move operational detail out; **drop the hardcoded 25-wing list** — it goes stale and is derivable at runtime via `mempalace_list_wings`. |
| Mandatory Code Review | ~200 | Compress. `quality-gate.sh`, `code-reviewer`, and (after Phase B) `owasp-security` now enforce most items automatically; the prose checklist duplicates machinery. |
| Compact-Save Continuity | ~180 | Move the procedure into the `compact-save` skill; keep the two trigger points inline. |

Untouched: Minimal Change Principle / Blast Radius, Scope Sentinel, Contract-First, MCP Tool
Discipline, PR Target Branch, LSP-over-Grep. These are short, always-relevant, and cheap.

**Gate:** `~/.claude/CLAUDE.md` is outside this repository and affects every project. Every
edit to it is presented to the user for approval before being applied, and the original is
backed up first.

---

## Decomposition

Phases A, B, and C ship together as one implementation plan: all three are in-repo, all three
serve the orchestrator, and Phase C is a prerequisite for unambiguous routing in Phase A.

**Phase D is a separate cycle** with its own plan. It edits a file outside this repository that
affects every project, its risk profile is different (a lost rule degrades every future
session), and it is gated edit-by-edit. Bundling it would mean one approval covering both a
new skill and a rewrite of the user's global instructions.

## Testing

No automated suite exists — skills are Markdown. Verification per `CLAUDE.md` "Skill Testing":

1. `bash scripts/validate-skills.sh` — must pass. Covers new-skill frontmatter, `commands/`
   delegation, the Architect `model=` rule, orphan references (Check F), and README↔MemPalace
   sync.
2. `bash scripts/test-validate-skills.sh` and `bash scripts/test-quality-gate.sh` — must stay
   at 26/26 and 16/16.
3. Smoke run `orchestrate` in a fresh session; confirm it loads, classifies, and announces a
   route without executing anything.
4. Routing check: give the orchestrator one request per row of the A3 table and confirm the
   announced route matches — including that a typo request produces **no** skill dispatch.
5. Self-repair check: on a throwaway project, introduce a deliberately failing test and
   confirm at most two repair attempts occur, then escalation — and that the test was fixed,
   not deleted.

## Risks

- **Router misclassification.** Mitigated by announcing the route in one line before dispatch,
  so a wrong guess costs one word of correction rather than a wrong pipeline.
- **Self-repair masking a real problem.** Mitigated by B2 (forbidden repairs) and by reporting
  both attempts' output on escalation, so silent absorption is visible.
- **Phase D losing a rule.** Mitigated by the one-line-trigger requirement and per-edit
  approval; nothing is deleted, only relocated.
- **Trigger line ignored.** The `CLAUDE.md` trigger is advisory to the model, not enforced by
  the harness. If it proves unreliable in practice, a `SessionStart` hook is the fallback —
  deliberately deferred rather than built speculatively.
