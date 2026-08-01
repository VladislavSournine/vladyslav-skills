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

### Step 1: Run the deterministic checks

Execute (via the Bash tool):

```bash
<plugin-root>/scripts/pre-release-checks.sh \
    --pwd <project pwd> \
    --plugin-root <plugin-root>
```

This runs in ~0.5 seconds. It writes `docs/release/pre-release-report-<YYYY-MM-DD>.md` AND emits JSON to stdout:

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

### Step 2: iOS Apple App Store review (only if `needs_apple_check: true`)

If the JSON has `needs_apple_check: true` (platform = ios):

Read `<plugin-root>/skills/pre-release-check/references/ios-apple-check.md` and apply its checks. This part **requires LLM** — semantic review against the App Store Guidelines, severity calls based on app-specific facts. Use the `apple-appstore-reviewer` skill directly (it lives under `~/.claude/skills/apple-appstore-reviewer/`) — that gives you the full review checklist.

Capture the Apple-check outcome as a 6th check result: `{"name": "apple_review", "result": "...", "severity": "...", "evidence": "..."}` and APPEND it to the report file written in Step 1.

For non-iOS projects (`needs_apple_check: false`) — skip this step entirely.

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

---

## Why this is a Light Engineer skill

- **5 of 6 checks are 100% deterministic.** Counting checkboxes, running a test command, grepping for placeholders, detecting translation files — none need LLM thinking. They run in bash in ~0.5 seconds.
- **The 6th check (Apple review) genuinely needs LLM.** That's why it stays as a separate skill dispatch — but only fires for iOS projects.
- **No allowlist enforcement boilerplate.** The script writes exactly one file (`docs/release/pre-release-report-<date>.md`) plus optionally `docs/release/changelog.md` (auto-generated). No risk of scope expansion.

## Output files

- `docs/release/pre-release-report-<YYYY-MM-DD>.md` — always written by the script.
- `docs/release/changelog.md` — written by the script only if it was missing or contained only a stub. Auto-generated from `git log` since the last `v*` tag (via `scripts/changelog-from-git.sh`).
- iOS only: optional `docs/release/apple-review-submission.md` — written by the model during Step 2 if the Apple-check produces a submission worksheet.
