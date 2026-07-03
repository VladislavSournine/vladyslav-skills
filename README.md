# vladyslav-skills

Claude Code skills for project scaffolding, analysis, documentation, and release management.

## Install

```bash
git clone git@github.com:VladislavSournine/vladyslav-skills.git ~/.vladyslav-skills
```

Then install the Claude Code plugin:
```bash
claude
# Inside Claude: /plugin marketplace add VladislavSournine/vladyslav-skills
#                /plugin install vladyslav@vladyslav-marketplace
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Superpowers plugin](https://github.com/obra/superpowers) — used by `add-feature`, `fix-bug`, `ingest`, `pre-release-check`, `write-test-docs`
- **MemPalace MCP server** (required for 10 skills marked 🧠 below) — long-term cross-session memory. Configure as an MCP server in your Claude Code setup; without it, the skills below will fail when trying to read/write memory. See [`examples/mcp-config.example.json`](examples/mcp-config.example.json) for a copy-paste config block, and [`docs/operations/dependencies.md`](docs/operations/dependencies.md) for install / update / interpreter-pinning steps.
- **Graphify** (optional, not integrated) — code knowledge-graph CLI you can run ad-hoc. See [`docs/operations/dependencies.md`](docs/operations/dependencies.md).

> **Optional global instructions:** [`examples/CLAUDE.example.md`](examples/CLAUDE.example.md) is a sanitized, shareable `~/.claude/CLAUDE.md` that pairs with this plugin (LSP-over-Grep, Minimal Change + "the ladder", Contract-First, Design System Discipline, Code Review, MemPalace usage). Copy the parts you want.

### Skills that require MemPalace 🧠

<!-- mempalace-skills:start -->
`add-feature`, `fix-bug`, `discover`, `discover-apple-check`, `design-sync`, `ingest`, `pre-release-check`, `compact-save`, `save`, `qsave`
<!-- mempalace-skills:end -->

The other skills (`init-project`, `attach-project`, `write-*`, `help`, `swiftui-pro`, `design-page`, `smoke-test-skills`) work without MemPalace.

Upgrading from ≤ v4.2.0 and seeing duplicate wings (e.g. `swift-Sudoku` vs `swift-sudoku`, or `plugin-foo` vs `foo`)? See [`docs/operations/wing-migration.md`](docs/operations/wing-migration.md) — most users only need to update the plugin.

## One-Terminal Workflow (v3.x)

Run any skill from a single Opus session. No manual `/model` switching required.

| Skill type | Where it runs |
|-----------|---------------|
| **Architect** (8 skills) | Opus main session — interactive design + synthesis. Internal `Agent(...)` dispatches annotated explicitly with `model="sonnet"` (executor work) or `model="opus"` (synthesis/research). |
| **Engineer (light) — bash-driven** (`init-project`, `attach-project`, `pre-release-check`) | Pre-flight Q&A in Opus main → a single deterministic bash helper does the work (~1 second) → summary rendered. |
| **Engineer (light) — Opus inline** (`write-user-stories`, `write-test-docs`, `write-project-docs`, `compact-save`, `save`, `qsave`, `help`) | Pre-flight Q&A + LLM-driven generation, all in Opus main, no Sonnet subagent dispatch. |

> **Heavy Engineer (deprecated):** v2.x wrapped Engineer skills in a Sonnet subagent dispatch with a YAML return contract. As of v3.1.0 no skill uses this pattern — the migrated skills run as Light Engineers. v4.5.0 removed the contract references (`subagent-preamble.md`, `yaml-return.md`, `present-summary.md`, `parse-yaml-return.sh`); recover them from git history if the pattern ever returns. See `docs/architecture/system.md`.

> Migrating from v1.x? The old dual-terminal split (Opus + Sonnet in separate windows) is gone. Close the second terminal — one Opus session handles everything.

## Skills

**Architect:**

| Skill | Purpose |
|-------|---------|
| `/vladyslav:ingest` | Existing-project intake: writes architecture docs AND seeds MemPalace in one scan pass. |
| `/vladyslav:add-feature` | Add feature (full cycle, 9 superpowers) |
| `/vladyslav:fix-bug` | Fix bug (full cycle, 7 superpowers) |
| `/vladyslav:discover` | Auto-fill product/start-project.md via AI research |
| `/vladyslav:discover-apple-check` | Apple App Store compliance pre-check (iOS only) |
| `/vladyslav:design-sync` | Extract design tokens from code into docs/design/system.md |
| `/vladyslav:design-page` | Design app screens in Pencil via parallel subagents |
| `/vladyslav:swiftui-pro` | SwiftUI/Swift code review for iOS 26 / Swift 6.2 best practices |
| `/vladyslav:smoke-test-skills` | Batch-validate all plugin skills (frontmatter, command delegation, cross-references, Architect model= rule, README↔MemPalace sync) |

**Engineer (light) — bash-driven:**

| Skill | Purpose |
|-------|---------|
| `/vladyslav:init-project` | Create new project — bare AI shell (`minimal`) or interactive module menu (`scripts/modules/*`) |
| `/vladyslav:attach-project` | Add structure to existing project (calls `scripts/attach-project.sh`) |
| `/vladyslav:pre-release-check` | Pre-release verification (calls `scripts/pre-release-checks.sh`) |

**Engineer (light) — Opus inline:**

| Skill | Purpose |
|-------|---------|
| `/vladyslav:write-user-stories` | Update user stories |
| `/vladyslav:write-test-docs` | Test plan + manual QA docs |
| `/vladyslav:write-project-docs` | README, onboarding, deployment |
| `/vladyslav:compact-save` | Snapshot task state to MemPalace (auto before compact) |
| `/vladyslav:save` | Save a knowledge record to MemPalace (decision / preference / milestone / problem) |
| `/vladyslav:qsave` | Quick-save the latest decision/problem/milestone to MemPalace — zero questions, derived from the conversation |
| `/vladyslav:help` | This reference |

## Workflows

**New project:**
```
init-project → discover → add-feature → write-test-docs → pre-release-check
```

**Existing project:**
```
attach-project → ingest → add-feature
```

**Before release:**
```
write-user-stories → write-test-docs → write-project-docs → pre-release-check
```

**Bug fix:**
```
fix-bug → write-test-docs → pre-release-check
```

## Stack Support

**Backend:** `python` (default), `go`, `other`, `none`
**Frontend/Mobile:** `flutter`, `swift`, `kotlin`, `other`, `none`

All stacks: CORE (bare AI shell) is always written. Docs / backend-infra / agents are opt-in via the interactive menu. `minimal` mode = CORE only.

## Superpowers Integration

All 13 non-meta superpowers skills are integrated:

| Superpowers Skill | Used In | When |
|-------------------|---------|------|
| `brainstorming` | `add-feature` | Design phase |
| `writing-plans` | `add-feature` | Planning phase |
| `executing-plans` | `add-feature` | Execution (parallel session) |
| `subagent-driven-development` | `add-feature` | Execution (this session) |
| `dispatching-parallel-agents` | `add-feature`, `ingest` | Parallel components |
| `using-git-worktrees` | `add-feature`, `fix-bug` | Isolated branch |
| `test-driven-development` | `add-feature`, `fix-bug`, `write-test-docs` | Tests + implementation |
| `systematic-debugging` | `fix-bug` | Diagnose root cause |
| `requesting-code-review` | `add-feature`, `fix-bug` | After implementation |
| `receiving-code-review` | `add-feature`, `fix-bug` | Process feedback |
| `finishing-a-development-branch` | `add-feature`, `fix-bug` | Merge/PR |
| `verification-before-completion` | `pre-release-check` | Evidence-based checks |
| `writing-skills` | (meta) | Edit vladyslav skills |

### Session Continuity

- **`/vladyslav:compact-save`** — snapshot current task state (task description, modified files, last decision, next action) to MemPalace as a `compact-save` drawer. Called automatically via `PreCompact` hook before Claude Code compresses the context window. Can also be called manually at any time.

- **`/vladyslav:save`** — save a single knowledge record (decision, preference, milestone, or problem) to MemPalace for the current project wing. Use it at the end of a session or any time after a key insight — no compaction required. Duplicate-checks before writing.

- **`/vladyslav:qsave`** — the zero-friction sibling of `save`: asks **no** questions, derives the most salient decision/problem/milestone straight from the conversation, and files it to the current wing. Fills the gap between mid-session work and the `SessionEnd` auto-miner. The assistant may also offer it proactively when it judges a task complete (you accept or decline — it never writes unprompted).

At session start (or after compaction), the global `~/.claude/CLAUDE.md` rule **Compact-Save Continuity** searches for a recent compact-save and restores context automatically — no manual resume command needed.
