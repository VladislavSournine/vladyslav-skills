---
name: pre-release-check
description: Use before any production deployment. Verifies tasks, tests, configs, docs, translations, and iOS Apple-review readiness.
---

# Pre-Release Check

**Type:** Engineer (light)

## Overview

Final gate before deployment. Five cross-platform checks run as pure bash in `scripts/pre-release-checks.sh` (~0.5s, 0 LLM tokens). For iOS projects, one additional LLM-heavy check (Apple App Store review) is dispatched separately to the `apple-appstore-reviewer` skill — this is the only part that legitimately needs model reasoning.

This was a Heavy Engineer skill until v3.1.0. The dispatched Sonnet subagent spent most of its time running `grep` and counting `[x]/[ ]` checkboxes — pure mechanics. Now those run in bash; the model only interprets the JSON result and (if iOS) drives the Apple review.

## Process

### Step 0: Pre-flight (Opus main)

1. **Verify project root.** Read `CLAUDE.md` from `pwd`. If missing → STOP: "No CLAUDE.md found — are you in the right project? Run `/vladyslav:attach-project` if this is an existing project without the AI workflow structure."

2. **Verify required input.** Confirm `docs/plans/tasks.md` exists. If missing, ask:
   > "Required input `docs/plans/tasks.md` is missing. Options: (a) create stub now / (b) abort. Which?"
   - On abort → exit cleanly.
   - On stub → create `# Tasks\n\n*to be filled*\n` and proceed (the check will then report WARN, which is fine).

3. **Resolve plugin root.** Glob `~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/scripts/pre-release-checks.sh` and take the directory two levels up. Fall back to `/Volumes/DevSSD/Development/vladyslav-skills` (dev clone).

**Exit criteria:** `CLAUDE.md` and `docs/plans/tasks.md` both present (the latter possibly as a just-created stub the user approved); `<plugin-root>/scripts/pre-release-checks.sh` executable.
**Evidence:** the two paths, and `test -x` on the script.
**Blocker:** a missing `tasks.md` silently treated as "no outstanding tasks" — that inverts the check this skill exists to run.

Steps below follow the exit-criteria contract in `<plugin>/skills/_shared/references/exit-criteria.md`.

### Step 1: Run the deterministic checks

Execute (via the Bash tool):

```bash
<plugin-root>/scripts/pre-release-checks.sh \
    --pwd <project pwd> \
    --plugin-root <plugin-root> \
    [--test-cmd "<cmd>"] [--test-timeout <seconds>]
```

Pass `--test-cmd` whenever the project's `CLAUDE.md` documents its test commands, and always for monorepos or an Xcode project outside the repo root — auto-detection only finds a runner at the root, and bare `xcodebuild test` has no scheme or destination. Chain several suites with `&&` (e.g. `cd backend && pytest -q && cd ../App && xcodebuild test -project … -scheme … -destination …`). Raise `--test-timeout` (default 300 s) for full iOS builds.

Apart from the test run, this takes ~0.5 seconds. It writes `docs/release/pre-release-report-<YYYY-MM-DD>.md` AND emits JSON to stdout:

```json
{
  "status": "success",
  "overall": "PASS" | "WARN" | "FAIL",
  "platform": "ios" | "web" | "backend" | "plugin" | "other",
  "needs_apple_check": true | false,
  "report_file": "docs/release/pre-release-report-2026-05-11.md",
  "checks": [
    {"name": "tasks",        "result": "PASS|WARN|FAIL", "severity": "low|medium|high|blocker", "evidence": "..."},
    {"name": "tests",        "result": "...", "severity": "...", "evidence": "..."},
    {"name": "config",       "result": "...", "severity": "...", "evidence": "..."},
    {"name": "docs",         "result": "...", "severity": "...", "evidence": "..."},
    {"name": "translations", "result": "...", "severity": "...", "evidence": "..."}
  ]
}
```

What each check does (deterministic, no LLM):

- **`tasks`** — counts `- [x]` vs `- [ ]` in `docs/plans/tasks.md`. PASS if all complete, WARN(high) if incomplete remain, FAIL(blocker) if file missing/empty/stub.
- **`tests`** — auto-detects the test runner (pytest / `go test` / `flutter test` / `xcodebuild test` / `swift test` / `npm test`), runs it with a 300s timeout, captures exit code. PASS on exit 0, FAIL(blocker) on non-zero, WARN(medium) if no runner detected.
- **`config`** — greps for `REPLACE_ME` / `TBD` / `<PROJECT_NAME>` / `*to be filled*` in production config files. FAIL(blocker) if any hits found.
- **`docs`** — checks four key docs (`manual-qa.md`, `rollback.md`, `user-stories.md`, `changelog.md`) for stub content. Auto-generates `changelog.md` from git log (since last tag) if missing/stubbed. WARN(low) for remaining stubs.
- **`translations`** — finds `.xcstrings`/`Localizable.strings` (iOS), or `i18n/`/`locales/`/`messages/` (web). PASS if found, WARN(low) if not.

**Exit criteria:** the script exited, its JSON parsed, all five checks carry a result, and the report file it names exists on disk.
**Evidence:** the JSON; `test -f <report_file>`.
**Blocker:** a check reported without its `evidence` field, or the JSON re-derived by hand because the script failed. If the script cannot run, that is a failure to report — not a set of checks to perform manually and present as equivalent.

### Step 2: iOS Apple App Store review (only if `needs_apple_check: true`)

If the JSON has `needs_apple_check: true` (platform = ios):

Read `<plugin-root>/skills/pre-release-check/references/ios-apple-check.md` and apply its checks. This part **requires LLM** — semantic review against the App Store Guidelines, severity calls based on app-specific facts. Use the `apple-appstore-reviewer` skill directly (it lives under `~/.claude/skills/apple-appstore-reviewer/`) — that gives you the full review checklist.

Capture the Apple-check outcome as a 6th check result: `{"name": "apple_review", "result": "...", "severity": "...", "evidence": "..."}` and APPEND it to the report file written in Step 1.

For non-iOS projects (`needs_apple_check: false`) — skip this step entirely.

**Exit criteria:** on iOS, a sixth check result exists and is appended to the report file; on every other platform, the step is explicitly marked skipped rather than silently absent.
**Evidence:** the `apple_review` entry in the report file, or `needs_apple_check: false` in the JSON.
**Blocker:** an Apple verdict issued without the guidelines review actually running.

### Step 2.5: Verify before reporting

Invoke `superpowers:verification-before-completion` via the `Skill` tool. This is the step that makes the verdict trustworthy: the skill's job is to confirm that each claim about to be printed is backed by output that was actually observed in this run.

**Exit criteria:** every check's result traces to evidence produced in this run — the script's JSON or the Apple review — and none rests on an assumption about what the project "normally" does.
**Evidence:** the verification pass over the six results.
**Blocker:** a PASS whose evidence field is empty, or a stale report file from a previous date being read as this run's output. On any mismatch, re-run Step 1 rather than reconciling by hand.

### Step 3: Render summary

Print to the user:

```
═══ Pre-Release Check — <YYYY-MM-DD> ═══

Tasks:        ✅/⚠️/❌ <RESULT> — <evidence>
Tests:        ✅/⚠️/❌ <RESULT> — <evidence>
Config:       ✅/⚠️/❌ <RESULT> — <evidence>
Docs:         ✅/⚠️/❌ <RESULT> — <evidence>
Translations: ✅/⚠️/⏭ <RESULT> — <evidence>
Apple review: ✅/⚠️/❌/⏭ <RESULT> — <evidence>   ← iOS only

Overall: <PASS | WARN | FAIL> — <one-line reason from the model>

Full report: <report_file from JSON>
Next step:
  - PASS or WARN (no blockers) → /vladyslav:write-docs (project mode)
  - FAIL → fix blockers (listed above), then re-run /vladyslav:pre-release-check
```

The **one-line reason** at the bottom is the only part that genuinely benefits from the model — synthesize what's driving the overall result. Example: "FAIL because 1 task is incomplete and tests have 3 failures; address those before ship." Keep it under 25 words.

**Exit criteria:** every printed line carries the result and evidence the script produced; the overall verdict is the worst of the individual results; the report file path is real and named.
**Evidence:** the rendered block, checkable line-by-line against the JSON.
**Blocker:** softening the overall verdict below its worst check ("mostly PASS", "FAIL but only on docs"). A blocker-severity FAIL means the release is not ready, and this skill exists to say so.

---

## Why this is a Light Engineer skill

- **5 of 6 checks are 100% deterministic.** Counting checkboxes, running a test command, grepping for placeholders, detecting translation files — none need LLM thinking. They run in bash in ~0.5 seconds.
- **The 6th check (Apple review) genuinely needs LLM.** That's why it stays as a separate skill dispatch — but only fires for iOS projects.
- **No allowlist enforcement boilerplate.** The script writes exactly one file (`docs/release/pre-release-report-<date>.md`) plus optionally `docs/release/changelog.md` (auto-generated). No risk of scope expansion.

## Output files

- `docs/release/pre-release-report-<YYYY-MM-DD>.md` — always written by the script.
- `docs/release/changelog.md` — written by the script only if it was missing or contained only a stub. Auto-generated from `git log` since the last `v*` tag (via `scripts/changelog-from-git.sh`).
- iOS only: optional `docs/release/apple-review-submission.md` — written by the model during Step 2 if the Apple-check produces a submission worksheet.
