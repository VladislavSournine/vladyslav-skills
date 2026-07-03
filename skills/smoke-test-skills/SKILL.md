---
name: smoke-test-skills
description: Use to batch-validate all skills in this plugin. Runs deterministic repo-wide static checks (frontmatter, command delegation, cross-references, Architect model= rule, orphan references, README<->MemPalace sync) and reports pass/fail per skill.
---

**Type:** Architect

Run the deterministic validator and report results. This is Stage A (static
checks only); isolated subagent invocation of smoke-safe skills is a planned
follow-up (Stage B).

## Steps

1. Run `bash scripts/validate-skills.sh` from the repo root.
2. Surface its full output to the user.
3. If it exits non-zero, summarize each `FAIL:` line grouped by skill and suggest the fix. Do not auto-fix — report only.
4. End with a one-line `Next:` suggestion (e.g. re-run after fixes, or `/loop 10m /vladyslav:smoke-test-skills` for periodic checks).

The validator is pure bash (macOS + Linux), takes an optional `ROOT` argument (defaults to repo root), and is safe to run anytime — it never writes files.
