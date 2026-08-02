# Memory Lint (Phase E) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. The skill being built is report-only toward MemPalace; the only writes are two files under `~/.claude/`.

**Goal:** A `vladyslav:memory-lint` skill that health-checks the MemPalace palace (five read-only checks), appends a dated report to `~/.claude/memory-lint.md`, and regenerates the wing index `~/.claude/references/mempalace-wings.md` — the file that replaces the wings list deleted from `CLAUDE.md` in Phase D.

**Architecture:** Engineer (light), Opus inline — `mempalace_*` are MCP tools callable only by the model, so this is a skill, not a script. Bash is used solely for `test -e` path checks. Both output files live in `~/.claude` (dotfiles-synced).

**Tech Stack:** Markdown skill + MCP calls (`mempalace_status`, `mempalace_search`) + bash existence checks.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-01-memory-lint-design.md`. **Post-Phase-D adaptation:** the spec's checks 1 and 5 referenced the CLAUDE.md wings list and prose counts — both deleted in Phase D. They become: check 1 = palace wings vs the generated index (drift since last run); check 5 = index freshness (stored counts vs live `mempalace_status`).
- **Report-only toward MemPalace:** the skill must contain no `mempalace_add_drawer`, `update_drawer`, `delete_drawer`, or `kg_invalidate` call.
- Check 4 samples; the report states the sample size explicitly.
- The log is newest-first: each run prepends its dated section; existing entries are never edited.
- New skill ⇒ minor bump to **5.1.0**; `memory-lint` calls `mempalace_*` ⇒ every MemPalace-dependency list/count goes 6 → 7.

---

### Task 1: The skill and its command

**Files:**
- Create: `skills/memory-lint/SKILL.md`, `commands/memory-lint.md`

Five checks, all read-only: (1) wings vs stored index → new/vanished wings; (2) split-brain clusters — strip `python-`/`swift-`/`flutter-` prefixes, group by exact match + substring containment, report clusters with counts (over-reporting accepted, output is a report); (3) rooms vs the table in `_shared/references/mempalace-record.md` → undocumented rooms with counts; (4) stale paths — sample searches across the largest wings, `test -e` every absolute path, report `<stale>/<checked> (sample)`; (5) index freshness — stored totals vs live. Outputs: prepend dated section to `~/.claude/memory-lint.md` (with "Changed since last run" line), regenerate `~/.claude/references/mempalace-wings.md` (name · drawer count · one-line description carried forward from the previous index, `unknown — verify` for new wings).

- [ ] Write both files following the repo command-delegation format
- [ ] `bash scripts/validate-skills.sh` fails on README list → proceed to Task 2

### Task 2: Repoint the deleted wings list and update counts

**Files:**
- Modify: `skills/qsave/SKILL.md` (Step 1 "confirm against the wings list in `~/.claude/CLAUDE.md`" → against `~/.claude/references/mempalace-wings.md`)
- Modify: `skills/_shared/references/mempalace-record.md` ("reconcile against the wings list in `~/.claude/CLAUDE.md`" → against the generated index; same in the `ops` paragraph if present)
- Modify: README (MemPalace block + "6 skills" count), repo `CLAUDE.md`, `SkillsManual.md`, `examples/mcp-config.example.json`, `.claude-plugin/plugin.json` description — all 6 → 7 with `memory-lint`

- [ ] Apply, then `grep -rn "wings list in \`~/.claude/CLAUDE.md\`" skills/` → no hits

### Task 3: Docs, changelog, version, validation

**Files:**
- Modify: `CHANGELOG.md` (5.1.0), `.claude-plugin/plugin.json` + `marketplace.json` (5.1.0), `README.md` + `SkillsManual.md` + `docs/architecture/system.md` (skill tables)

- [ ] `validate-skills.sh` PASS, both test suites green, commit

### Task 4: First live run (also the acceptance test)

Spec testing §2: the first run must report the known-bad state — the 11-wing drift, the `artur` split-brain family, the `decisions` typo room, undocumented `emotional`. A clean first report means a broken check.

- [ ] Run the five checks live, write both output files, commit the dotfiles repo
- [ ] Confirm findings match the spec's measured baseline (23,015 drawers / 37 wings on 2026-08-01)

## Self-Review

Spec coverage: E1 → Task 1, E2 → Task 1 (log format), E3 → Tasks 1-2 (index + consumer repoint; the "gated CLAUDE.md migration" from the spec already happened in Phase D — the list is gone, so only the consumers needed repointing). Non-goals honored: no autofix, no scheduler, no per-drawer index, no palace writes. Deviation: checks 1/5 redefined post-Phase-D as stated in Global Constraints.
