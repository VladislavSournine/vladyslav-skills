# Global Instructions (example)

> **What this is.** A shareable, sanitized version of the global `~/.claude/CLAUDE.md`
> that pairs with the `vladyslav-skills` plugin. Copy the parts you want into your own
> `~/.claude/CLAUDE.md`. Private project data (project names, personal stats, people)
> has been removed.
>
> Sections that reference `vladyslav:*` skills, MemPalace, or compact-save require this
> plugin and the **MemPalace MCP server** installed. If you don't use those, drop the
> MemPalace / QSave / Compact-Save sections — the rest is infrastructure-agnostic.

## Code Navigation — Prefer LSP over Grep

For navigating code in Swift, Python, TypeScript/JavaScript, Kotlin, and Lua projects, **use the LSP tool** instead of Grep when looking for:

| Task | Tool | Why |
|------|------|-----|
| Find where a function/class/symbol is defined | **LSP** (`getDefinition`) | Exact match, no text noise |
| Find all usages of a symbol | **LSP** (`getReferences`) | Understands scope, doesn't match strings/comments |
| Find a symbol by name | **LSP** (`getDocumentSymbols` / `getWorkspaceSymbols`) | Semantic, returns structured data |
| Check type/signature of a symbol | **LSP** (`getHover`) | Full type info, fewer tokens than reading file |
| Find compile errors | **LSP** (`getDiagnostics`) | Instant, no need to run build |

**Still use Grep for:**
- Non-code files (markdown, JSON, YAML, configs)
- String literals, error messages, log patterns
- Files in languages without LSP (Dart, Shell, etc.)
- Quick "does this string exist anywhere" checks

**Rule of thumb:** if you're searching for a *named code symbol* in a supported language, LSP is faster, cheaper (fewer tokens), and more accurate. Grep returns text lines; LSP returns exact symbol locations with context.

**Supported languages (LSP installed):** Swift, Python, TypeScript/JavaScript, Kotlin, Lua

## Minimal Change Principle (Blast Radius Rule)

Before any edit, briefly state the scope: which files and why. Everything outside that scope is off-limits unless renegotiated.

**Core rule: prefer the smallest justified change.**
- When multiple solutions exist, pick the one with **less code**, if it's genuinely justified (same correctness, same clarity, same maintainability).
- If a **larger change** would actually be better (e.g. avoids a fragile workaround, fixes a structural issue, prevents duplicate logic) — **STOP and ASK the user first**, don't silently expand scope.
- The decision between "small surgical fix" vs "larger proper fix" belongs to the user, not to you.

**Hard rules (no exceptions):**
- "While I'm here" fixes are forbidden. Note them as TODO, do not apply.
- No formatting, import sorting, or refactoring unless it IS the task.
- Moving a button 1px should not turn into rewriting the component.
- If you discover the declared scope is wrong (e.g. root cause is elsewhere), STOP, report, ask for new scope — don't chase it quietly.
- **Blast radius check:** every change has a ripple. If the ripple is bigger than the task warrants — pause and confirm with the user.

**The ladder (climb before writing new code).** Smallest change also means the laziest solution that actually works. Before adding new code, go down this list and stop at the first rung that solves it:
1. **YAGNI** — does this task / abstraction need to exist at all? The best code is the code never written.
2. **stdlib** — does the standard library already solve it?
3. **native platform features** — before reaching for a dependency.
4. **an existing dependency** — before adding a new one.
5. **one line** — before fifty.
6. **only then** — minimal working code.

Never let the ladder strip away input validation, error handling, security, accessibility, or an explicitly requested feature — those are non-negotiable regardless of how "lazy" the solution is. A speculative abstraction ("might need later") is a ladder violation, not foresight.

## MemPalace — Long-term Memory (Strict Use)

> Requires the **MemPalace MCP server**. Skip this section if you don't use it.

MemPalace is the canonical cross-session memory. Use it strictly, not optionally.

**At session start for any non-trivial task:**
1. Identify the wing (project name)
2. `mempalace_search` with specific technical terms
3. Do NOT re-scan the codebase from scratch if MemPalace has relevant records. Trust the memory first, verify suspicious details against code.

**During work — search MemPalace when:**
- The user references past decisions, bugs, patterns, or approaches
- You encounter a problem that might have been solved before
- Starting work on an existing feature — check what was discussed previously
- The user references something from a past conversation

**After completing a feature / fix / architectural decision:**
1. `mempalace_kg_add` — record what changed and why
2. Room type: `decision`, `problem`, `milestone`, `preference`
3. Include: what, why, key file paths, date

**QSave Offer (proactive):** When you judge a substantive task complete and a concrete decision / problem / milestone emerged from the work, offer to capture it before moving on:
> Save this to MemPalace via `/qsave`? (y/n)

- Only offer when something genuinely record-worthy happened — never for trivial edits, pure reads, or conversational turns.
- Offer **at most once per task**, and never re-ask if declined.
- On acceptance, run `/vladyslav:qsave` (zero-question capture; derives wing via project basename and content from the conversation). Never write to MemPalace unprompted — the offer is the gate.
- This is the manual complement to the `SessionEnd` auto-miner: it captures the insight *now*, mid-session, without waiting for the session to end or for a context compaction.

**Rule:** If you find yourself about to Grep/Glob the whole project to "get context", stop — search MemPalace first.

**Path validation (mandatory after every mempalace_search):**
Scan each result for absolute file paths (`/Volumes/`, `/Users/`, `/home/`). For every path found:
- Run `ls <path>` or `test -e <path>` to check existence
- If path **exists** → result is live, proceed normally
- If path **does NOT exist** → the drawer is **`[STALE]`**: do NOT act on it, tell the user "Found stale MemPalace record referencing `<path>` which no longer exists — ignoring"
This prevents acting on decisions made in deleted, renamed, or archived directories (e.g. two directories that differ only by case).

**Search tips:** use specific technical terms, not vague queries. Search within the relevant wing when possible. Cross-project search only for patterns or shared decisions.

**Wings (projects):** each wing maps 1:1 to a project directory basename. Run `mempalace_list_wings` to see yours, or list your active projects here so the model can pick the right wing without guessing.

**Room types:** decision, emotional, problem, milestone, preference

## Contract-First Development

For any new feature, endpoint, or API change:

1. **Contract first** — write down (even 3 lines):
   - Types / signature / API schema
   - 1 input/output example
   - Known error cases
2. **Tests and code in parallel** — both derive from the contract
3. **Never skip the contract** — even for tiny features

**Why:** tests written after code verify what you wrote, not what you intended. Contract is the alignment point between intent, code, and tests.

**Exception:** bug fixes follow the `vladyslav:fix-bug` skill (test-first reproduces bug), not contract-first.

## Design System Discipline (UI / visual tasks)

Before ANY visual or UI task — new screen, new component, updating colors/typography/spacing, adding icons, changing layout — you MUST follow this sequence. No exceptions.

**Step 1 — Load the contract.** Read `docs/design/system.md` if it exists. Treat it as a contract: palette, typography, iconography, spacing, component patterns listed there are LOCKED.

**Step 2 — Scan the asset catalog.** Look for existing tokens in:
- iOS: `Assets.xcassets` (`.colorset`, `.imageset`, `.symbolset`), any `Colors.swift` / `Typography.swift` / `Spacing.swift` files
- Web: `tailwind.config.*`, `tokens.css`, CSS variables, theme files
- Flutter: `ThemeData`, `colors.dart`, `typography.dart`
- Android: `colors.xml`, `themes.xml`, Material 3 token declarations

**Step 3 — Reuse, never invent.** Use existing tokens. Hard rules:
- NEVER write raw hex codes in view code (`Color(hex: "#4A90E2")`, `#ff0000`, `rgb(...)`). Use named tokens.
- NEVER invent new SF Symbol names, Material icon names, or custom icon file names. Use the project's canonical set.
- NEVER hard-code padding/spacing values (`padding: 13`). Use spacing tokens.
- NEVER inline `Font.system(size: 17, weight: .semibold)`. Use typography tokens.

**Step 4 — If a new token is genuinely needed**, STOP and ask the user explicitly:
> "I need a new design token: `<name>` = `<value>` for `<purpose>`. Options:
> (a) add it to `docs/design/system.md` and the asset catalog now (recommended)
> (b) reuse an existing token — `<suggest alternative>`
> (c) continue inline this one time (not recommended — causes drift)"

Do not silently add tokens. Do not silently deviate. Drift is the enemy.

**Step 5 — If no design system exists** (`docs/design/system.md` missing AND asset catalog empty), tell the user:
> "No design system found. Recommended: bootstrap `docs/design/system.md` first — scan the existing code for de-facto tokens (colors, typography, spacing) and canonize them, or start from a template. Alternative: proceed with ad-hoc design this time and canonize afterwards — not recommended because it requires cleanup."

Wait for their choice. Do not proceed with ad-hoc design without explicit permission.

**Why this rule exists:** without it, each new screen invents its own colors, icons, and spacing. After 5 screens the app looks like 5 different apps. A design system is only useful if it's actually enforced on every UI change — one undisciplined session undoes months of consistency work.

**iOS specifically:** Apple HIG requires dark mode support, Dynamic Type, VoiceOver, min 44pt tap targets, WCAG AA contrast. All of these are design-system concerns — they live in `docs/design/system.md`, not re-decided per-screen.

## MCP Tool Discipline

**Never grep or read Claude Code's internal tool-result cache files.**

The path pattern `~/.claude/projects/*/tool-results/*.txt` is Claude Code internal storage. Format is unstable, files can be cross-session (session A's cache visible to session B), and parsing them bypasses the MCP abstraction layer entirely.

**Hard rules:**
- If you need output from an MCP tool → **call the tool again**. Do not grep cached results.
- Every MCP server exposes its data through its own tool calls. Use those.
- If a tool call feels "too expensive" to repeat → save the needed slice to your response text or a plan, not by parsing cache files.

**Why:** tool-result caches are write-once side-effects of prior tool calls. Grepping them is an undocumented shortcut that produces stale or cross-session data and is invisible to the user in tool approval flows.

## Mandatory Code Review (before declaring any task done)

Run this checklist against every change. No exceptions.

**Correctness:**
- [ ] Addresses root cause, not symptom
- [ ] Edge cases: empty, null, boundaries
- [ ] No regressions in untouched paths

**Security:**
- [ ] No injection vectors (SQL, command, XSS)
- [ ] No secrets in code/logs/commits
- [ ] Input validation at system boundaries
- [ ] AuthZ on mutations
- [ ] For deeper audit: invoke `owasp-security` skill

**Code smell:**
- [ ] No dead code, no commented-out code
- [ ] No speculative abstractions ("might need later")
- [ ] Function does one thing
- [ ] Names match behavior

**Minimal change compliance:**
- [ ] Diff matches declared scope (Blast Radius Rule)
- [ ] No unrelated formatting/refactoring
- [ ] Climbed the ladder — no new code where stdlib / native / an existing dep / one line would do; no new dependency added casually

If any check fails → fix before declaring done. If uncertain → invoke `pr-review-toolkit:code-reviewer` or `owasp-security`.

## Scope Sentinel (Mid-Execution Requests)

When the user issues a new request WHILE you are already executing a skill or command:

1. STOP — do not begin the new request immediately.
2. Classify silently: (A) clarification of current task, (B) extension of current task, (C) separate task.
3. **(A) Clarification** ("the field is `email` not `mail`") → continue without asking.
4. **(B) Extension** ("also add sorting to this list") → ask: *"Expand current plan to include this, or queue as Deferred follow-up?"*
5. **(C) Separate task** ("by the way, fix the auth bug") → ask: *"Pause current work and switch, or finish current first?"*

Never silently expand scope. (B) and (C) always require explicit user confirmation.

This rule complements the Blast Radius Rule (which governs agent-driven scope expansion); Scope Sentinel governs user-driven mid-execution scope changes.

## PR Target Branch

**Open PRs against your integration branch (e.g. `develop`), not the release line (`main`).**

- Default `gh pr create` (without `--base`) targets the repo's default branch, which is often `main` — usually wrong if you stage work through an integration branch.
- Use `gh pr create --base develop ...` explicitly for every PR.
- Promote `develop → main` manually as a separate, batched merge — one staging point controls what reaches the release line.
- If the repo has no integration branch, ask the user before falling back to `main`.

## Compact-Save Continuity

> Requires the `vladyslav:compact-save` skill + MemPalace MCP. Skip if unused.

`vladyslav:compact-save` automatically records task state to MemPalace before context compaction (via `PreCompact` hook). Load it back at two trigger points:

**Session start** — at the start of any session in a project that maps to a wing:
1. Run `mempalace_search` with `wing=<current-wing>`, `room="compact-save"`, `query="compact-save created_at"`, `limit=3`.
2. If at least one result exists and its `created_at` is within the last 24 hours, take the newest drawer. Prefix the FIRST response in the session with:
   > ℹ Compact-save found: `<task>` (from `<created_at>`). Next: `<next>`. Continue?
3. Then proceed with the user's request. Do NOT block. Pure information.

**After compaction** — when you detect a compaction system message in the conversation:
1. Run the same search above.
2. If a compact-save exists, silently restore context (task, files_modified, last_decision, next) into your working memory.
3. No user notification needed — just pick up where you left off.

This runs once per trigger, not per message. If the user says "ignore memory", skip this check.
