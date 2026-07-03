#!/usr/bin/env bash
# quality-gate.sh — per-task "done" gate for orchestrator skills.
#
# Runs in the TARGET project after implementation, before a skill declares
# the task complete. Every check is deterministic; the exit code is the gate:
# the skill loops "fix, re-run" until exit 0 instead of relying on prose
# instructions the model must remember to follow.
#
# Checks:
#   1. hygiene — added lines (diff vs --base, plus untracked files) must not
#      contain conflict markers, REPLACE_ME, or debugger leftovers
#   2. secrets — added lines must not contain private-key headers or
#      AWS/GitHub/Slack token shapes (high-precision patterns only: a
#      blocking gate that false-positives gets bypassed, so recall is
#      deliberately traded for precision — owasp-security covers the rest)
#   3. scope   — optional; delegates to check-plan-scope.sh when
#      --plan-list is given (plan/contract files must live OUTSIDE the
#      project repo or they show up in its own diff)
#   4. tests   — run the test command (given or auto-detected), require
#      exit 0; no runner detectable → warn, never a silent pass. Run last:
#      it is the expensive check. The caller owns any timeout.
#
# Usage:
#   quality-gate.sh --pwd <project-dir> [--base <git-ref>] [--test-cmd "<cmd>"]
#       [--plan-list <file> --contract <file> [--readonly-globs <file>]]
#
# --base defaults to HEAD (uncommitted work). Pass an earlier ref when the
# skill commits as it goes, e.g. --base $(git merge-base HEAD develop).
#
# Output: single-line JSON {"status":"pass|fail","checks":[{name,status,detail}]}
#         status per check: pass | fail | warn | skip (warn/skip never gate)
# Exit: 0 all pass, 1 at least one check failed, 2 usage error.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PWD="" BASE="HEAD" TEST_CMD="" PLAN_LIST="" CONTRACT="" READONLY_GLOBS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pwd) PROJECT_PWD="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --test-cmd) TEST_CMD="$2"; shift 2 ;;
    --plan-list) PLAN_LIST="$2"; shift 2 ;;
    --contract) CONTRACT="$2"; shift 2 ;;
    --readonly-globs) READONLY_GLOBS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -z "$PROJECT_PWD" ] && { echo "--pwd required" >&2; exit 2; }
[ -d "$PROJECT_PWD" ] || { echo "pwd not found: $PROJECT_PWD" >&2; exit 2; }
cd "$PROJECT_PWD" || exit 2
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $PROJECT_PWD" >&2; exit 2; }
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "unknown --base ref: $BASE" >&2; exit 2; }

fail=0
CHECKS=""

add_check() { # name, status, detail
  local esc
  esc="$(printf '%s' "$3" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  CHECKS="${CHECKS:+$CHECKS,}{\"name\":\"$1\",\"status\":\"$2\",\"detail\":\"$esc\"}"
  [ "$2" = "fail" ] && fail=1
}

# Added lines: working tree + index vs BASE, plus full content of untracked
# files (git diff never sees those, and new files are exactly where fresh
# work — and fresh leftovers — live).
added_lines() {
  git diff --no-color "$BASE" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | cut -c2-
  local f
  while IFS= read -r f; do
    [ -f "$f" ] && cat "$f"
  done < <(git ls-files --others --exclude-standard)
}

ADDED="$(added_lines)"

# ─── 1. hygiene ──────────────────────────────────────────────────────────
HYGIENE_RE='^(<<<<<<<|>>>>>>>)( |$)|REPLACE_ME|^[[:space:]]*debugger;?[[:space:]]*$|pdb\.set_trace\(|breakpoint\(\)|binding\.pry'
hits="$(printf '%s\n' "$ADDED" | grep -E "$HYGIENE_RE" | head -3)"
if [ -n "$hits" ]; then
  add_check hygiene fail "leftover markers in added lines: $hits"
else
  add_check hygiene pass "no conflict markers, placeholders, or debugger leftovers"
fi

# ─── 2. secrets ──────────────────────────────────────────────────────────
SECRETS_RE='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|xox[baprs]-[0-9A-Za-z-]{10,}'
hits="$(printf '%s\n' "$ADDED" | grep -E -e "$SECRETS_RE" | head -3)"
if [ -n "$hits" ]; then
  add_check secrets fail "credential-shaped content in added lines: $hits"
else
  add_check secrets pass "no private keys or known token shapes"
fi

# ─── 3. scope ────────────────────────────────────────────────────────────
if [ -n "$PLAN_LIST" ]; then
  [ -n "$CONTRACT" ] || { echo "--contract required with --plan-list" >&2; exit 2; }
  scope_out="$("$HERE/check-plan-scope.sh" "$PLAN_LIST" "$CONTRACT" ${READONLY_GLOBS:+"$READONLY_GLOBS"} 2>&1)"
  scope_rc=$?
  case "$scope_rc" in
    0) add_check scope pass "diff within plan" ;;
    1) add_check scope fail "$scope_out" ;;
    *) add_check scope fail "check-plan-scope error: $scope_out" ;;
  esac
else
  add_check scope skip "no --plan-list given"
fi

# ─── 4. tests ────────────────────────────────────────────────────────────
detect_test_command() { # mirrors pre-release-checks.sh detection order
  if [ -f pyproject.toml ] && grep -q 'pytest' pyproject.toml 2>/dev/null; then echo "pytest"; return; fi
  if [ -f pytest.ini ] || [ -d tests ]; then echo "pytest"; return; fi
  if [ -f go.mod ]; then echo "go test ./..."; return; fi
  if [ -f pubspec.yaml ]; then echo "flutter test"; return; fi
  if [ -f Package.swift ]; then echo "swift test"; return; fi
  if [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then echo "npm test"; return; fi
  echo ""
}

cmd="${TEST_CMD:-$(detect_test_command)}"
if [ -z "$cmd" ]; then
  add_check tests warn "no test runner detected; pass --test-cmd to gate on tests"
else
  test_out="$(eval "$cmd" 2>&1)"
  test_rc=$?
  if [ "$test_rc" -eq 0 ]; then
    add_check tests pass "$cmd → exit 0"
  else
    add_check tests fail "$cmd → exit $test_rc: $(printf '%s' "$test_out" | tail -3 | tr '\n' ' ')"
  fi
fi

# ─── report ──────────────────────────────────────────────────────────────
status=pass; [ "$fail" -ne 0 ] && status=fail
printf '{"status":"%s","checks":[%s]}\n' "$status" "$CHECKS"
exit "$fail"
