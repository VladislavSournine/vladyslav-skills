---
name: save
description: Save a knowledge record (decision, preference, milestone, or problem) to MemPalace for the current project wing. Use at end of session or any time after a key insight — no compaction needed.
type: Engineer (light)
---

# Save

**Type:** Engineer (light)
**Requires:** MemPalace MCP server

Save a knowledge record to MemPalace for the current project wing. Unlike `compact-save`, this is for capturing *semantic knowledge* (decisions, preferences, milestones, problems) — not task state before compaction.

## When this runs

- User says `/vladyslav:save`, "save to MemPalace", "remember this", "запам'ятай це", "збережи в MemPalace"
- Explicitly triggered at the end of a session when the user wants to persist a key insight without compacting

## Steps

### Step 1: Detect wing

Derive the wing using the algorithm in `<plugin>/skills/_shared/references/mempalace-record.md` ("Wing" section) — the project directory **basename**, with whitespace/underscores/dots collapsed to single hyphens, **case preserved**. `scripts/derive-wing.sh` implements exactly this; prefer running it when a shell is available.

Do **not** lowercase — wings such as `Svitlana` and `phD` carry meaningful case, and lowercasing them produces a wing that matches nothing. After deriving, reconcile against the wings list in `~/.claude/CLAUDE.md` to catch case drift. If ambiguous or outside a known project, prompt the user to confirm or specify the wing. Never guess silently.

An explicit wing named by the user overrides derivation — e.g. "save to ops" targets the thematic `ops` wing for cross-project server/deploy knowledge (see the "Wing" section of the shared reference).

### Step 2: Identify content and type

If the user provided the content to save in their message → use it directly.

If no content was provided → ask:

> "What should I save to MemPalace? Please describe it briefly, and tell me the type: **decision**, **preference**, **milestone**, or **problem**."

Classify the room type based on the content:
- **decision** — architectural or design choice with rationale ("we use X because Y")
- **preference** — how the user wants things done ("always do X", "never do Y")
- **milestone** — completed work worth remembering ("shipped feature X")
- **problem** — known issue, gotcha, or constraint ("Z breaks when W")

Default to `decision` if the type is unclear.

### Step 3: Check for duplicates

Call `mempalace_check_duplicate` with `wing` = detected wing and `query` = first 80 characters of content.

If a similar record exists → show it to the user and ask:
> "A similar record already exists: `<existing name>`. Update it, save a new one, or cancel?"

### Step 4: Save to MemPalace

Call `mempalace_add_drawer` with:

- `wing`: detected wing
- `room`: classified room type (`decision` / `preference` / `milestone` / `problem`)
- `name`: short kebab-case slug from the content (max 40 chars), e.g. `use-vitest-not-jest`
- `content`: the record shape defined in `<plugin>/skills/_shared/references/mempalace-record.md` ("Required structure") — `[WHAT]`, `[WHY]`, `[FILES]`, `[DATE]`. Omit `[WHY]` and `[FILES]` when not applicable.

### Step 5: Confirm

Output one line: `Saved to MemPalace — wing:<wing>  room:<room>  "<name>"`

## Failure modes

- **MemPalace unreachable** → output a one-line warning and suggest the user save the note manually. Never block on this.
- **Wing undetectable** → prompt the user before saving. Never guess a wing silently.
