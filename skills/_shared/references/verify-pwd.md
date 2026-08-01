# Verify working directory (architect skills)

Used at the start of every architect skill that operates on an existing project (`orchestrate`, `add-feature`, `fix-bug`, `ingest`, `pre-release-check`).

Composed into Step 0 of each skill — before any user Q&A, before any MemPalace search.

---

## Step 0.1: Verify working directory

1. Run `pwd` — record the absolute path.
2. Check that `CLAUDE.md` exists at the project root.
3. If it does NOT exist, STOP and say:

   > ✗ No CLAUDE.md found at `<pwd>`.
   > This skill operates on an established project — run `/vladyslav:init-project` (new project) or `/vladyslav:attach-project` (existing one without Claude Code structure) first.

   Do NOT proceed — **unless the calling skill defines a self-heal branch** (`orchestrate`, `add-feature`, `fix-bug`), in which case hand off to `_shared/references/self-heal-shell.md` to offer an inline bootstrap instead of stopping. The other consumers (`ingest`, `pre-release-check`) still hard-STOP here.

4. If it DOES exist, read its first 50 lines to confirm it looks like a vladyslav-shaped project (presence of a "Source of Truth" or similar table is a strong signal). If the file looks empty or off-shape, warn the user but allow continuation:

   > ⚠ CLAUDE.md exists but does not match the expected structure. Continuing anyway — verify scope manually.

5. Derive the canonical MemPalace wing name. Use `scripts/derive-wing.sh` (or follow the algorithm in `_shared/references/mempalace-record.md` if the script is unavailable). The wing name is the key for every subsequent MemPalace search/write in this skill.

## Why this step exists

Without it, a skill invoked in the wrong directory (e.g. accidentally in `~/` or in a parent of the real project) silently writes scaffolding into places it shouldn't, or seeds MemPalace records under the wrong wing. The `CLAUDE.md` presence check is a cheap, reliable contract — if it's there, you're in the right place; if not, the user typed the wrong command.

## When to skip this step

Skip ONLY for skills that operate on a NEW project or before scaffolding exists:
- `init-project` — bootstraps from scratch; `CLAUDE.md` is its OUTPUT, not input.
- `attach-project` — bridges an unstructured project into the plugin; `CLAUDE.md` may not exist yet.
- `compact-save`, `swiftui-pro` — utility skills with no scaffolding dependency.
