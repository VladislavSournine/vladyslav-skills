---
name: qsave
description: Quick-save the latest decision/problem/milestone to MemPalace with zero questions — derives everything from the current conversation. Use for a fast mid-session capture, or accept it when offered at task completion.
type: Engineer (light)
---

# QSave

**Type:** Engineer (light)
**Requires:** MemPalace MCP server

Frictionless one-shot capture of the most recent decision, preference, problem, or milestone into the current project's MemPalace wing. It asks **no questions** — it reads what just happened from the conversation and files it. Unlike `compact-save`, it stores *semantic knowledge*, not task-resume state, and does **not** wait for context compaction.

Absorbed the `save` skill in v5.0.0 (13 real invocations vs 0 — zero-question capture won): if the user **provides the content in their message** ("qsave: we switched X to Y because Z"), use it verbatim instead of deriving from the conversation. Everything else stays zero-question.

This exists because the `SessionEnd` auto-miner only fires when a session ends, and `compact-save` only fires on compaction — so a quick fix in the middle of a long session would otherwise sit uncaptured until then. `qsave` closes that gap on demand.

## When this runs

- User says `/vladyslav:qsave`, `/qsave`, "quick save", "qsave this", "швидко збережи", "save to MemPalace", "remember this", "запам'ятай це", "збережи в MemPalace"
- **Proactively offered** by the assistant when it judges a substantive task complete and a concrete decision/problem/milestone emerged (see the global `CLAUDE.md` rule). The user must accept — `qsave` never writes unprompted.

## Steps

### Step 1: Detect wing

Derive the wing from the working-directory **basename** (preserve case; replace whitespace/underscores/dots with single hyphens; do NOT lowercase, do NOT add a stack prefix), then confirm it against the wings list in `~/.claude/CLAUDE.md`. This matches `scripts/derive-wing.sh` and the `SessionEnd` miner. If the basename is not in the wings list and the directory is clearly outside a known project, ask the user to confirm the wing in one line — otherwise proceed silently. An explicit wing named by the user (e.g. "qsave to ops") overrides derivation — `ops` is the thematic wing for cross-project server/deploy knowledge.

### Step 2: Extract content — no questions

If the user provided the content in their message, use it directly. Otherwise read the recent conversation and pull out the single most salient item to record. Do not interrogate the user. Classify the room:

- **decision** — a choice that was made with rationale ("we switched X to Y because Z")
- **preference** — how the user wants things done ("always do X", "never do Y")
- **problem** — a bug, gotcha, or constraint that surfaced
- **milestone** — a "this now works / shipped" moment

Default to `decision` when ambiguous. If genuinely nothing record-worthy happened, say so in one line and stop — do not invent content.

### Step 3: Write to MemPalace

Call `mempalace_add_drawer` (it duplicate-checks before writing) with:

- `wing`: detected wing
- `room`: `decision` / `preference` / `problem` / `milestone`
- `added_by`: `vlad`
- `content`: the standard record shape from `_shared/references/mempalace-record.md`:

```
[WHAT] <one keyword-rich sentence — what changed / what broke / what shipped>
[WHY] <one sentence — the driver, if known>
[FILES] <up to 5 absolute paths touched; omit the line if irrelevant>
[DATE] <today's date, ISO 8601>
```

Omit `[WHY]` / `[FILES]` if not applicable. Keep it to those four lines — `qsave` is for searchable atoms, not narrative.

### Step 4: Confirm

Output exactly one line:

`qsaved → wing:<wing>  room:<room>  "<slug>"`

## Failure modes

- **MemPalace unreachable** → one-line warning, suggest noting it manually. Never block.
- **Wing undetectable AND outside a known project** → ask once, in one line. Never guess a wing silently.
