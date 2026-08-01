# Global CLAUDE.md Shortening (Phase D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Every edit to `~/.claude/CLAUDE.md` is presented to the user as a diff and applied only on explicit approval — this plan cannot run unattended.

**Goal:** Cut the always-loaded `~/.claude/CLAUDE.md` from ~2290 words to ≤1300 with zero rules lost — every moved section keeps a short always-on trigger pointing at an on-demand reference file.

**Architecture:** The same move applied three times already (orchestrate trigger, plugin references, wing index): short trigger inline, procedure in a file loaded when relevant. Reference files live in `~/.claude/references/` — tracked by the dotfiles repo initialized 2026-08-01, so they sync between machines with the file that points to them.

**Tech Stack:** Markdown only. The dotfiles git repo in `~/.claude` provides versioning and rollback.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-orchestrator-stance-design.md`, Phase D section.
- **Every CLAUDE.md edit is user-gated:** show the exact before/after, wait for explicit yes, apply, `git diff` in `~/.claude` to confirm only the intended change landed.
- Sections stay **verbatim when moved** — relocation, not rewriting. Rewriting risks losing a rule; that review is a separate task if ever wanted.
- Untouched sections (short, always-relevant): Orchestrator Entry Point, Code Navigation (LSP), Minimal Change / Blast Radius + ladder, Contract-First, MCP Tool Discipline, Scope Sentinel, PR Target Branch.
- Baseline measured 2026-08-01: 2238 words + ~55 (orchestrator trigger) ≈ 2290.

---

### Task 1: Prepare the references directory

**Files:**
- Modify: `~/.claude/.gitignore` (whitelist `references/`)
- Create: `~/.claude/references/` (directory)

**Interfaces:**
- Produces: the synced home every later task writes into

- [ ] **Step 1: Whitelist in the dotfiles repo**

Append to `~/.claude/.gitignore`, directly after the `!commands/**` line:

```
!references/
!references/**
```

- [ ] **Step 2: Create the directory and back up CLAUDE.md**

```bash
mkdir -p ~/.claude/references
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.phaseD-backup
wc -w ~/.claude/CLAUDE.md
```

Record the exact starting word count for the Task 6 comparison.

- [ ] **Step 3: Commit the scaffolding**

```bash
cd ~/.claude && git add .gitignore && git commit -m "chore: whitelist references/ for phase D"
```

---

### Task 2: Move "Design System Discipline" (~450 → ~70 words)

**Files:**
- Create: `~/.claude/references/design-system-discipline.md`
- Modify: `~/.claude/CLAUDE.md` (section `## Design System Discipline (UI / visual tasks)`)

- [ ] **Step 1: Create the reference file** — copy the ENTIRE current section body (Steps 1–5, the why-paragraph, the iOS paragraph) verbatim under a `# Design System Discipline` heading.

- [ ] **Step 2: Present this replacement section to the user; on approval, apply:**

```markdown
## Design System Discipline (UI / visual tasks)

Before ANY visual or UI change, read `~/.claude/references/design-system-discipline.md`
and follow it exactly. Non-negotiable core: `docs/design/system.md` is a locked contract;
reuse existing tokens — never invent colors/icons/spacing/fonts inline; a genuinely new
token requires STOP + explicit user approval; no design system → ask before ad-hoc work.
iOS additionally: dark mode, Dynamic Type, VoiceOver, 44pt targets, WCAG AA.
```

- [ ] **Step 3: Verify** — `git -C ~/.claude diff` shows only this section changed; the reference file contains every step verbatim.

---

### Task 3: Move MemPalace operational detail (~450 → ~150 words)

**Files:**
- Create: `~/.claude/references/mempalace-protocol.md`
- Modify: `~/.claude/CLAUDE.md` (section `## MemPalace — Long-term Memory (Strict Use)`)

**What moves:** session-start steps, during-work triggers, after-completion record format, search tips. **What is deleted outright:** the hardcoded wings list — measured stale by 11 wings (4,200 drawers); wing derivation already lives in `skills/_shared/references/mempalace-record.md` + `derive-wing.sh`, and Phase E's generated index will replace the lookup role.

**What stays inline (rules that must fire without opening a file):**

- [ ] **Step 1: Create the reference file** with the moved content verbatim under `# MemPalace Protocol`.

- [ ] **Step 2: Present this replacement to the user; on approval, apply:**

```markdown
## MemPalace — Long-term Memory (Strict Use)

MemPalace is the canonical cross-session memory. Full protocol:
`~/.claude/references/mempalace-protocol.md`. Non-negotiable core:

- **Search before scanning:** for any non-trivial task, `mempalace_search` the project's
  wing FIRST — do not re-scan a codebase MemPalace already describes.
- **Path validation (mandatory):** after every search, `test -e` any absolute path in the
  results; a dead path marks the record `[STALE]` — report it, never act on it.
- **Write-backs:** after a completed feature/fix/decision, record it (`mempalace_kg_add` or
  the flow in the reference). Wing derivation: case-preserving basename — see
  `derive-wing.sh`; thematic wing `ops` for cross-project server/deploy knowledge.
- **QSave Offer:** when a substantive task completes with a record-worthy outcome, offer
  `/vladyslav:qsave` once (y/n) — never write unprompted, never re-ask after decline.
```

- [ ] **Step 3: Verify** — diff shows one section changed; wings list is gone; the four core rules read complete without the reference.

---

### Task 4: Compress "Mandatory Code Review" (~200 → ~60 words)

**Files:**
- Modify: `~/.claude/CLAUDE.md` (section `## Mandatory Code Review (before declaring any task done)`)

No reference file — the checklist's mechanical half is now enforced by machinery (`quality-gate.sh`, code-reviewer agents, `owasp-security` in both add-feature and fix-bug), and the judgment half compresses to four lines.

- [ ] **Step 1: Present this replacement to the user; on approval, apply:**

```markdown
## Mandatory Code Review (before declaring any task done)

Every change passes review before "done" — no exceptions. The deterministic parts run via
`quality-gate.sh` + reviewer agents + `owasp-security` inside the lifecycle skills; when
working outside those skills, self-check: root cause not symptom · edge cases (empty/null/
boundary) · no injection, no secrets, authZ on mutations · no dead code or speculative
abstractions · diff matches declared scope (Blast Radius) · the ladder was climbed.
If any check fails → fix before declaring done; if uncertain → run the reviewer skills.
```

- [ ] **Step 2: Verify** — every bullet of the old checklist maps to either the machinery clause or a self-check item; nothing silently vanished.

---

### Task 5: Move "Compact-Save Continuity" procedure (~180 → ~45 words)

**Files:**
- Create: `~/.claude/references/compact-save-continuity.md`
- Modify: `~/.claude/CLAUDE.md` (section `## Compact-Save Continuity`)

- [ ] **Step 1: Create the reference file** — move the two trigger procedures (session-start search parameters, post-compaction restore steps) verbatim.

- [ ] **Step 2: Present this replacement; on approval, apply:**

```markdown
## Compact-Save Continuity

Two triggers, procedure in `~/.claude/references/compact-save-continuity.md`:
**session start** in a wing-mapped project → check for a compact-save from the last 24h and
offer to continue; **after a compaction message** → silently restore task state from the
newest compact-save. Once per trigger; skip entirely if the user says "ignore memory".
```

- [ ] **Step 3: Verify** — diff clean, procedures verbatim in the reference.

---

### Task 6: Final verification and commit

- [ ] **Step 1: Word count against target**

```bash
wc -w ~/.claude/CLAUDE.md   # expect ≤1300 (from ~2290)
```

- [ ] **Step 2: Rule-coverage checklist** — for each of the four edited sections, confirm: trigger present inline · reference file exists and is verbatim · no rule exists only in the deleted text. Read the backup side-by-side once.

- [ ] **Step 3: Live-fire smoke** — in a fresh session in any project: a UI question must surface the design-discipline trigger; a "what did we decide about X" question must trigger a MemPalace search with path validation.

- [ ] **Step 4: Commit and clean up**

```bash
cd ~/.claude
git add CLAUDE.md references/
git commit -m "refactor: phase D - CLAUDE.md triggers inline, procedures in references/"
# after the user confirms a few sessions behave correctly:
rm ~/.claude/CLAUDE.md.phaseD-backup ~/.claude/CLAUDE.md.bak-2026-08-01
```

---

## Self-Review

**Spec coverage.** Spec Phase D table: Design System ✓ (Task 2), MemPalace + wings-list drop ✓ (Task 3), Code Review compress ✓ (Task 4), Compact-Save ✓ (Task 5). Untouched list honored in Global Constraints.

**Deviations from spec, stated:** (1) target relaxed from ~1000 to ≤1300 words — the spec's untouched sections alone are ~1050 words, so ~1000 was arithmetically unreachable without touching sections the spec froze; (2) references live in `~/.claude/references/` rather than the plugin — the dotfiles repo (created after the spec was written) versions them and syncs them with CLAUDE.md itself, and personal config does not belong in the public plugin repo.

**Placeholder scan:** every replacement section is spelled out verbatim above; moved bodies are verbatim-copies by rule, so their content is fully specified by the source section named in each task.

**Known gap:** compressed triggers are judged sufficient by reading, but only live sessions prove the model still fires the rules — hence Task 6 Step 3, and the backups are kept until the user confirms.
