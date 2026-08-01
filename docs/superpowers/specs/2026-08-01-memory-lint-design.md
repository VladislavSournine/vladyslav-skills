# Design: MemPalace lint + generated wing index (Phase E)

> Created: 2026-08-01
> Status: approved (design), plan not yet written
> Companion to `2026-07-30-orchestrator-stance-design.md`. Independent of it — neither blocks the other.

## Problem

MemPalace is an LLM-maintained knowledge base with no health check. Its schema document
(`~/.claude/CLAUDE.md`) is hand-maintained and has drifted badly from the data it describes.
Measured on 2026-08-01 via `mempalace_status`:

| `~/.claude/CLAUDE.md` claims | Actual |
|---|---|
| "6,879+ records across 17 projects" | **23,015 drawers across 37 wings** |
| a 26-entry wings list | 11 wings missing from it, holding **4,200 drawers (18%)** |
| room types: decision, emotional, problem, milestone, preference | plus undocumented `decisions`, `stash`, `project`, `curriculum`, `_registry` |

The drift is **load-bearing, not cosmetic**. `skills/save/SKILL.md`, `skills/qsave/SKILL.md`,
and `skills/_shared/references/mempalace-record.md` all instruct reconciling a derived wing
against the list in `CLAUDE.md`. A stale list therefore causes new mis-assignments, which
enlarge the drift — a self-reproducing defect.

Concrete symptoms today:

- **Split-brain across the `artur` family — seven wings:** `python-artur` (744), `artur-ep`
  (1366), `python-artur2` (253), `artur2` (114), `artur-esp32` (16), `python-artur-ep` (4),
  `artur` (1). Also `exam` (2128) / `python-exam` (18), `swift-calories` (9493) / `calories`
  (70), `docs` (9) / `documents` (87). The user has repaired split-brain before (534 records
  reassigned, 2679 purged); it recurred because nothing detects it.
- **A typo room:** `decisions` (5) alongside `decision` (3423).
- **`emotional` holds 15,377 drawers — 67% of the palace — and is absent from the room table
  in `_shared/references/mempalace-record.md`.** Two thirds of memory sits in a type the
  skills do not document.

This is what the llm-wiki pattern (karpathy) calls knowledge rot, and its prescribed remedy is
a periodic **lint** pass over the wiki. The bookkeeping is the part humans abandon and LLMs do
well.

## Non-problem: prose quality

The slop-cop idea (detecting LLM writing tells) was evaluated and **rejected on evidence**. A
scan of 80,000 words of LLM-written prose across `docs/`, `skills/`, and root markdown found 2
occurrences of "crucial", 1 of "leverage", 6 of "Not just", and zero of "delve", "seamless",
"robust", "comprehensive", "it's important to note", or "In an era". The one real signal is
em-dash density at 17 per 1000 words, which is stylistic, not rot. Building a linter for this
would be a solution in search of a problem. The existing "no vague phrasing" rule in
`mempalace-record.md` already does the useful part.

## Scope decision

**Report-only.** The lint diagnoses and never mutates the palace. Merging wings, purging
records, and reassigning rooms stay explicit user decisions. At 23,015 drawers an automated
mutation with a wrong heuristic is expensive to undo, and the split-brain clusters need human
judgement (`chord` and `python-guitar` may or may not be the same project; `T` is unknown).

## Design

### E1. `vladyslav:memory-lint` — five read-only checks

**Implementation constraint that dictates the form:** `mempalace_*` are MCP tools invoked by
the model, not callable from bash. This is therefore a **skill**, not a script like
`validate-skills.sh`. Bash is used only for filesystem existence checks.

| # | Check | Source | Catches today |
|---|---|---|---|
| 1 | Wings in palace vs the list in `~/.claude/CLAUDE.md` | `mempalace_status` | 11 undocumented wings, 4200 drawers |
| 2 | Split-brain candidates | `mempalace_status` wing names | the `artur` family, `exam`, `calories`, `docs`/`documents` |
| 3 | Rooms vs the table in `_shared/references/mempalace-record.md` | `mempalace_status` | `decisions` typo, `stash`, `project`, `curriculum`, `_registry`, and the undocumented `emotional` |
| 4 | Stale absolute paths in record bodies | sampled `mempalace_search` + `test -e` | records pointing at deleted directories |
| 5 | Numeric claims in `CLAUDE.md` prose vs reality | `mempalace_status` | "6,879+ across 17 projects" |

**Check 2 heuristic:** normalise each wing name by stripping a known stack prefix
(`python-`, `swift-`, `flutter-`) and then group by (a) exact match after stripping and (b)
substring containment (`artur` ⊂ `artur-ep` ⊂ `python-artur-ep`). Report clusters with per-wing
drawer counts. Containment is deliberately loose — it over-reports rather than missing a
cluster, and since output is report-only, a false positive costs one line of reading.

**Check 4 is a sample, not a sweep.** Validating paths in all 23,015 drawers is not feasible in
one pass. The check samples per wing and **the report states the sample size explicitly** —
silent sampling would read as "everything was verified" when it was not.

### E2. Output — an append-only log

`~/.claude/memory-lint.md`, newest run first. This is the llm-wiki `log.md`. It lives in
`~/.claude/` rather than a project because MemPalace is global.

Each run appends a dated section: the five check results, and a "Changed since last run" line
comparing totals against the previous entry, so drift becomes visible over time rather than
being re-derived from scratch each run.

### E3. Generated wing index replaces the hand-maintained list

A full per-drawer `index.md` over 23,015 records is not feasible. A **wing-level** index is: 37
entries, each with name, drawer count, dominant rooms, and a one-line description of what the
wing holds.

The important part is not the file — it is that this index **replaces** the hand-maintained
wings list in `~/.claude/CLAUDE.md`. That list drifted by 11 wings precisely because it is
maintained by hand while being consumed as authoritative by three skills. A generated index
cannot drift.

`CLAUDE.md` keeps a pointer; the generated file holds the data. This is the same move already
applied twice in the companion spec: a short always-on trigger, details loaded on demand.

**Migration is gated.** Editing `~/.claude/CLAUDE.md` is outside the repo and affects every
project. The list is replaced only with explicit user approval, after a backup, and the three
consumers (`save`, `qsave`, `mempalace-record.md`) are repointed at the index in the same
change — otherwise they would reference a list that no longer exists.

## Explicit non-goals

- **No slop linter** — refuted by measurement above.
- **No autofix** — report-only, per the scope decision.
- **No scheduler or `/loop` wrapper yet.** The skill runs on demand first. Wiring periodic
  execution before the report has proven useful would build the schedule before the thing being
  scheduled has earned it — a ladder violation. Revisit once a few runs exist.
- **No per-drawer index** — wing-level is sufficient and feasible.
- **No query compounding** (the llm-wiki idea of promoting a synthesis into a new page) — it
  requires writing to the palace, which contradicts the report-only decision. Separate cycle if
  ever.

## Testing

No automated suite — this is a Markdown skill driven by MCP calls. Verification:

1. `bash scripts/validate-skills.sh` passes (frontmatter, `commands/memory-lint.md` present,
   references resolve, README MemPalace list updated since the skill calls `mempalace_*`).
2. Run the skill once and confirm each of the five checks reports the known-bad state
   documented in this spec — in particular the 11 undocumented wings and the `decisions` typo.
   A check that reports clean is a broken check, since the defects are known to exist today.
3. Run it twice and confirm the second run appends rather than overwrites, and that its
   "Changed since last run" line reads zero.
4. Confirm the skill performs no writes to MemPalace: no `mempalace_add_drawer`,
   `mempalace_update_drawer`, `mempalace_delete_drawer`, or `mempalace_kg_invalidate` call
   appears anywhere in the skill body.

## Risks

- **Check 2 over-reports.** Accepted deliberately: report-only output makes a false positive
  cheap, and missing a split-brain cluster is the expensive error.
- **Check 4 gives false confidence.** Mitigated by printing the sample size in the report.
- **The index goes stale between runs.** It is generated, so staleness is bounded by run
  frequency, unlike the current list whose staleness is unbounded.
- **`emotional` (67% of the palace) is out of this design's scope.** The lint reports it as
  undocumented; deciding what that room is for, and whether the skills should write to it, is a
  separate question this spec deliberately does not answer.
