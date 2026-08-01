# Orchestration conventions (Opus 4.8+)

How skills dispatch work: which mechanism, which model, what is safe to run in parallel.

Used by every skill that dispatches subagents or fans work out (`orchestrate`, `add-feature`, `fix-bug`, `ingest`, `write-docs`). Skills point here instead of repeating these rules inline.

This **extends** the model-override rule in `CLAUDE.md` ("Working Rules") — it does not replace it. If they ever conflict, `CLAUDE.md` wins.

---

## Three dispatch mechanisms — pick the smallest that fits

| Mechanism | Use when | Notes |
|-----------|----------|-------|
| **inline** (no dispatch) | The step is one pass of reasoning or a short utility (<~15s). Dispatch overhead would exceed the work. | Default for Light Engineer skills and single-pass synthesis. |
| **`Skill` tool** | Delegating to another skill (superpowers, c-level-skills). | The invoked skill chooses its own model; do not set one. |
| **`Agent` tool** | One subagent for a self-contained task, OR a handful of independent tasks dispatched in a single message to run concurrently. | Always set `model` explicitly (see below). For 2–4 independent tasks, emit all `Agent` calls in ONE message — they run in parallel. |
| **`Workflow` tool** | Many independent items (fan-out), or a multi-stage pipeline where each item flows stage→stage, or loop-until-done / adversarial-verify patterns. | Deterministic control flow. Prefer over hand-rolled parallel `Agent` calls once you have >4 items or real staging. |

**Rule of thumb:** inline → `Agent` (parallel in one message) → `Workflow`. Escalate only when the smaller mechanism stops fitting.

## Model tiers (conservative default)

Quality is the priority. Drop a tier only when the work is genuinely mechanical or pure generation.

| Tier | Use for | Examples |
|------|---------|----------|
| **`opus`** | Reasoning, synthesis, judgment, design, review. **Default when unsure.** | brainstorming, contract design, planning, systematic-debugging, code review, HIG audit, user-story synthesis (code-vs-intent), final narrative summaries, competitor/monetization research |
| **`sonnet`** | Content generation from already-decided inputs; executor work. | writing README / onboarding / deployment guides, test-plan + manual-QA drafting, writing impl + tests against an approved plan, doc/record stitching in `ingest` |
| **`haiku`** | Mechanical, deterministic, no judgment. | parallel file reads, MemPalace searches, "does this file exist" checks, grep-style scans |

When you fan out to `sonnet`/`haiku`, the Opus main session stays the control plane: it validates inputs, owns approval gates, and synthesizes the final result.

## What is safe to parallelize

Fan out ONLY genuinely independent work — no shared mutable state, no ordering dependency.

**Safe:**
- Reading N different files / running N independent searches.
- Generating N independent documents that don't reference each other's output (README + onboarding + deployment; test-plan + manual-QA).
- Researching independent sections (e.g. competitors and validation-signals don't depend on each other).
- Drawing pre-assigned, non-overlapping regions of any shared canvas or document — coordinates/sections must be assigned by the orchestrator BEFORE dispatch.

**NOT safe (keep serial):**
- Anything behind a **user approval gate** — gates are serial by definition.
- **MemPalace writes** — each must be preceded by `mempalace_check_duplicate`; concurrent writes race the duplicate check. Searches (reads) are safe to parallelize; writes are not.
- **Writes to the same file** — two agents editing one file conflict. Use `isolation: 'worktree'` only if they must mutate the repo in parallel (expensive — last resort).
- **Pipeline stages with a real dependency** — if stage B needs stage A's output for the SAME item, that's a pipeline, not a barrier; let `Workflow.pipeline` handle it rather than forcing a parallel batch.
- **Pencil token sync** — only the orchestrator calls `set_variables`; subagents never sync tokens.

## Fan-out shapes

**A few independent tasks → parallel `Agent` calls in one message:**
```
Dispatch in a single message (they run concurrently):
  Agent(description: "Generate README",     model: "sonnet", ...)
  Agent(description: "Generate onboarding",  model: "sonnet", ...)
  Agent(description: "Generate deployment",  model: "sonnet", ...)
Then the Opus main session reviews/merges the three results.
```

**Many items or staged work → `Workflow`:**
```
parallel(items.map(i => () => agent(`research ${i}`, {model: 'opus', schema: ...})))
// or pipeline(items, scan, draft, verify) when each item flows stage→stage
```
`Workflow` runs in the background and reports when done; it is the right tool for >4 items, loop-until-dry discovery, or adversarial verification. See the `Workflow` tool description for the full API.

## Discipline is never bypassed by orchestration

Parallelism and cheaper models change HOW work runs, never WHETHER the rules apply. Preserve, regardless of dispatch:

- **Approval gates** (feature description, brainstorm, contract, plan, merge) — serial, in the main session, with the user.
- **Contract-first / Blast-Radius / minimal-change** — a fanned-out executor still gets the contract and the file allowlist.
- **Mandatory doc updates** after changes (architecture/structure/user-stories/etc.).
- **MemPalace `check_duplicate` before every write**, path-validation (`[STALE]` filter), "never apply a found record silently — present as hypothesis."
- **Never-overwrite** user-edited sections — merge, don't clobber.

If parallelizing or down-tiering a step would weaken any of the above, keep it serial / on `opus`.
