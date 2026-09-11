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

**Exit criteria:** `CLAUDE.md` present and the wing derived, or the user declined the bootstrap and the skill stopped.
**Blocker:** routing a task from an unverified directory — the routed skill will re-derive the wing and may land in a different one.

Every step here follows the exit-criteria contract in `<plugin>/skills/_shared/references/exit-criteria.md`; so does every skill this one routes to.

## Step 1: Classify and announce

Map the request to exactly one route:

| Signal in the request | Route |
|---|---|
| "doesn't work", traceback, regression, failing test, "не працює" | `vladyslav:fix-bug` |
| "add", "make", new behaviour, "додай", "зроби" | `vladyslav:add-feature` |
| existing project with no `docs/architecture/` | `vladyslav:ingest`, then classify again |
| new project from scratch | `vladyslav:init-project` |
| "preparing a release", pre-deploy verification | `vladyslav:pre-release-check` |
| UI/visual work | no dedicated skill — follow the Design System Discipline rule in `~/.claude/CLAUDE.md`, then route the code change as `add-feature`/`fix-bug` |
| **trivial** — typo, version bump, one-liner, git operation, question about the code | **no skill — act inline** |

The trivial row is not optional. Wrapping a typo in a full pipeline violates the ladder rule in `~/.claude/CLAUDE.md` ("prefer the laziest solution that actually works"). When genuinely torn between trivial and `fix-bug`, ask in one line.

**Announce the route in one line before dispatching**, so a wrong guess costs a word of correction rather than a wrong pipeline:

`Route: fix-bug — this reads as a regression in the auth middleware. Override?`

**Exit criteria:** exactly one route chosen and announced before any dispatch, with the reason that decided it.
**Blocker:** dispatching a pipeline for something the trivial row covers. Torn between trivial and `fix-bug` → ask in one line; that costs less than either wrong answer.

## Step 2: Set autonomy once

Only `add-feature` has a Manual/Auto mode. When the route is `add-feature`, ask **once**:

> "Manual or Auto?"

Then pass the answer down. `add-feature` Step 0.5 accepts a mode supplied by the orchestrator as satisfying its "always ask" rule — the ask happened, one level up. Asking again at that level is a bug, not extra safety.

For every other route there is no mode concept: skip this step. Do not invent one.

**Exit criteria:** on the `add-feature` route, a mode came from the user and is being passed down; on every other route, nothing was asked.
**Blocker:** inventing a Manual/Auto choice for a route that has none.

## Step 3: Delegate

Invoke the routed skill via the `Skill` tool. For dispatch mechanisms, model tiers, and what is safe to parallelize, follow `<plugin>/skills/_shared/references/orchestration-conventions.md` — do not restate those rules here.

**Exit criteria:** the routed skill ran to its own final step and reported which of its exit criteria were met.
**Blocker:** a route abandoned mid-pipeline without saying where it stopped and why.

## Quality mandate

Not optional, and not waived by autonomy level. This is the exit criteria for the run as a whole. The routed skill owns each item; this skill's job is to notice when one was silently skipped:

| Must be true when the route finishes | Evidence |
|---|---|
| Tests written **alongside** implementation, both derived from the contract | a test run, and tests present in the same commits as the code |
| Code review happened before merge | the reviewer's findings with a disposition each |
| Security check ran on the diff (`add-feature` 6.5, `fix-bug` 6.5) | the checker's output and the diff range it saw |
| Docs updated per the routed skill's post-implementation step | the committed paths |
| Approval gates stayed serial and stayed with the user | the user's answers at each gate |

The mandate is about **evidence, not effort**: "the reviewer was invoked" is not the same claim as "the findings were resolved". If a routed skill finishes without one of these, say so plainly in the summary instead of reporting clean success — a reported gap is a normal outcome, a hidden one is a defect.

## Non-goals

- **Does not use `/loop`.** `/loop` is for recurring interval work and its own documentation says not to use it for one-off tasks. It is the wrong primitive for driving a single task end to end.
- **Does not self-grant `Workflow`.** `Workflow` needs explicit per-session user opt-in. If a task genuinely needs fan-out over more than four independent items, ask once; if declined, proceed without it.
- **Does not bypass Scope Sentinel.** Scope expansion is always the user's decision.
