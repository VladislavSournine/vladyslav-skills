# vladyslav-skills

Claude Code plugin providing skills for project scaffolding, analysis, documentation, and release management.

## Project Type

Claude Code plugin (`vladyslav` namespace). No traditional backend/frontend stack — all functionality is delivered via Markdown skill files.

## Source of Truth

| Doc | Purpose |
|-----|---------|
| `README.md` | Installation, usage, workflow overview |
| `docs/product/prd.md` | Product requirements |
| `docs/architecture/system.md` | Plugin architecture and skill design |
| `docs/plans/tasks.md` | Active tasks |
| `docs/plans/backlog-next.md` | Upcoming work |

## Structure

```
skills/          # Skill SKILL.md files (one dir per skill)
commands/        # Slash command .md files (one per skill)
.claude-plugin/  # Plugin metadata (plugin.json)
.claude/         # Claude Code local config and agents
docs/            # Architecture, product, and planning docs
```

## Working Rules

- Each skill lives in `skills/<name>/SKILL.md`
- Each command lives in `commands/<name>.md` and delegates to its skill
- Skill names follow `vladyslav:<name>` namespace
- Skills declare `Type: Architect` or `Type: Engineer (light)` in their header
- **Architect skills** run interactively in Opus main session. When they dispatch a subagent via `Agent(...)`, they MUST specify `model` explicitly: `model="sonnet"` for executor work (write tests, write impl, run review/security checks); `model="opus"` for synthesis/research work (deep analysis, multi-source research, design decisions). The full dispatch contract — `Skill` vs `Agent` vs `Workflow`, the `haiku` tier for mechanical work, and parallelism-safety rules — lives in `skills/_shared/references/orchestration-conventions.md`. Skills point there instead of repeating it inline.
- **Light Engineer skills** (`compact-save`) run inline in main thread (~15s utility operations; dispatch overhead would exceed the work)
- Engineer skill summaries end with a "Next: …" suggestion; Architect skills end with a "Next steps:" list. Both use one-terminal language — no decorator-handoff blocks, no model-switch instructions
- Do not add translations until the finalization phase (pre-release-check)

## Review Checklist (before committing a skill change)

Run this before every commit that touches `skills/**`, `commands/**`, or `.claude/**`:

- [ ] SKILL.md frontmatter has `name`, `description`, and a `Type:` line in the body
- [ ] Skill name in frontmatter matches directory name (`skills/<name>/SKILL.md` → `name: <name>`)
- [ ] If skill calls `mempalace_*` tools — README "Skills that require MemPalace" list is updated
- [ ] If skill is new — corresponding `commands/<name>.md` exists and delegates to it
- [ ] If behavior changed — `CHANGELOG.md` entry added under current/next version
- [ ] `.claude-plugin/plugin.json` `version` bumped (semver: patch for fixes, minor for new skills, major for breaking renames)
- [ ] No raw paths to `~/.claude/projects/*/tool-results/*` in any skill (MCP discipline)

The `PostToolUse` hook in `.claude/settings.json` lints SKILL.md frontmatter automatically on Edit/Write — that catches the first two items, but the rest are manual.

## Skill Testing

There is no automated test suite — skills are Markdown, not code. Verification is manual:

1. **Frontmatter lint** — runs automatically via `PostToolUse` hook on every `Edit`/`Write` to `skills/**/SKILL.md`. Fails the tool call if `name`/`description` are missing.
2. **Smoke run** — after editing a skill, invoke it (`Skill` tool with the skill name) in a fresh session and confirm it loads without errors and produces the expected first action.
3. **End-to-end** — for orchestrator skills (`add-feature`, `fix-bug`, `init-project`), run the full flow on a throwaway project under `/tmp/` and confirm the produced artifacts (docs, agents, commits) are correct.

Do not declare a skill change "done" without at least step 2.

## Hooks

`.claude/settings.json` registers these lifecycle hooks. All hook scripts live in `.claude/hooks/` and must be executable bash (POSIX, macOS + Linux).

| Hook | Script | Purpose |
|------|--------|---------|
| `SessionStart` | `session-start.sh` | Silent — emits a one-line hint about the current wing if MemPalace context is likely useful. Never blocks, never errors out loud. |
| `PostToolUse` (matcher: `Edit\|Write\|MultiEdit`) | `lint-skill-frontmatter.sh` | After any edit to `skills/**/SKILL.md`, validates that frontmatter has `name`, `description`, and the body has a `Type:` line. Fails the tool call on violation. |
| `Stop` | `check-docs-sync.sh` | Before Claude finishes a turn, scans `git status` for changes to plugin internals (`skills/`, `.claude/hooks/`, `.claude-plugin/`, `commands/`, `examples/`). If any are present and no `docs/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, or `SkillsManual.md` was touched, blocks the stop with `exit 2` and surfaces a reminder so the model updates docs before stopping. Skipped when `stop_hook_active=true` (avoids loops). |
| `PreCompact` | inline echo | Reminds the model to invoke `vladyslav:compact-save` before context summarization. |

When adding a hook, keep it (a) idempotent, (b) under 200ms, (c) failing closed only when failure is meaningful — `SessionStart` always succeeds, lint and doc-sync hooks may block.

## Versioning

Version is defined in `.claude-plugin/plugin.json`. Bump on every meaningful change.

## Dependencies

- [Superpowers plugin](https://github.com/obra/superpowers) — all 13 non-meta superpowers skills are referenced
- **MemPalace MCP server** — required by 7 skills (`add-feature`, `fix-bug`, `ingest`, `pre-release-check`, `compact-save`, `save`, `qsave`). When editing or adding skills that call `mempalace_*` tools, declare the dependency in the skill's SKILL.md and update the README "Skills that require MemPalace" list.
- **CodeGraph MCP server (optional)** — local code-index accelerator used by `ingest`, `add-feature`, `fix-bug` when present; skills fall back to grep/Glob/LSP without it. Never a hard dependency — do not add it to any "required" list. Detection + usage contract: `skills/_shared/references/codegraph.md`; setup: README "Optional: CodeGraph code index".
