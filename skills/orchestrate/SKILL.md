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

The trivial row is not optional. Wrapping a typo in a full pipeline violates the ladder rule in `~/.claude/CLAUDE.md` ("prefer the laziest solution that actually works"). When genuinely torn between trivial and `fix-bug`, ask in one line.

**Announce the route in one line before dispatching**, so a wrong guess costs a word of correction rather than a wrong pipeline:

`Route: fix-bug — this reads as a regression in the auth middleware. Override?`

## Step 2: Set autonomy once

Only `add-feature` has a Manual/Auto mode. When the route is `add-feature`, ask **once**:

> "Manual or Auto?"

Then pass the answer down. `add-feature` Step 0.5 accepts a mode supplied by the orchestrator as satisfying its "always ask" rule — the ask happened, one level up. Asking again at that level is a bug, not extra safety.

For every other route there is no mode concept: skip this step. Do not invent one.

## Step 3: Delegate

Invoke the routed skill via the `Skill` tool. For dispatch mechanisms, model tiers, and what is safe to parallelize, follow `<plugin>/skills/_shared/references/orchestration-conventions.md` — do not restate those rules here.

## Quality mandate

Not optional, and not waived by autonomy level. The routed skill owns each item; this skill's job is to notice when one was silently skipped:

- Tests written **alongside** implementation, both derived from the contract — never deferred.
- Code review before merge.
- Security check (`owasp-security`) on the diff — `add-feature` Step 6.5, `fix-bug` Step 6.5.
- Docs updated per the routed skill's post-implementation step.
- Approval gates stay serial and stay with the user.

If a routed skill finishes without one of these, say so plainly in the summary instead of reporting clean success.

## Non-goals

- **Does not use `/loop`.** `/loop` is for recurring interval work and its own documentation says not to use it for one-off tasks. It is the wrong primitive for driving a single task end to end.
- **Does not self-grant `Workflow`.** `Workflow` needs explicit per-session user opt-in. If a task genuinely needs fan-out over more than four independent items, ask once; if declined, proceed without it.
- **Does not bypass Scope Sentinel.** Scope expansion is always the user's decision.
