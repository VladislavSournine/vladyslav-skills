#!/usr/bin/env bash
# Test harness for quality-gate.sh — builds fixture git repos, asserts exit codes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/quality-gate.sh"
pass=0; failc=0

T() { # desc, expected_exit, gate args...
  local desc="$1" exp="$2" got; shift 2
  "$GATE" "$@" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$exp" ]; then
    pass=$((pass+1)); printf 'ok   - %s\n' "$desc"
  else
    failc=$((failc+1)); printf 'FAIL - %s (exit %s, want %s)\n' "$desc" "$got" "$exp"
  fi
}

make_repo() { # prints path to a fresh git repo with one commit
  local r; r="$(mktemp -d)"
  ( cd "$r" && git init -q && git config user.email t@example.com \
    && git config user.name tester && printf 'hello\n' > base.txt \
    && git add -A && git commit -qm init ) >/dev/null 2>&1
  printf '%s' "$r"
}

# --- baseline + tests check ---
R="$(make_repo)"
T "clean repo with passing tests passes" 0 --pwd "$R" --test-cmd true

R="$(make_repo)"
T "failing test command fails the gate" 1 --pwd "$R" --test-cmd false

R="$(make_repo)"
T "no test runner detected is a warn, not a fail" 0 --pwd "$R"

# --- hygiene check ---
R="$(make_repo)"; printf '<<<<<<< HEAD\n' >> "$R/base.txt"
T "conflict marker in modified file fails" 1 --pwd "$R" --test-cmd true

R="$(make_repo)"; printf 'REPLACE_ME\n' > "$R/new-config.txt"
T "REPLACE_ME in untracked file fails" 1 --pwd "$R" --test-cmd true

R="$(make_repo)"; printf 'import pdb\npdb.set_trace()\n' > "$R/debug.py"
T "debugger leftover in untracked file fails" 1 --pwd "$R" --test-cmd true

# --- secrets check ---
R="$(make_repo)"; printf -- '-----BEGIN RSA PRIVATE KEY-----\n' >> "$R/base.txt"
T "private key header in diff fails" 1 --pwd "$R" --test-cmd true

R="$(make_repo)"; printf 'key = "AKIAIOSFODNN7EXAMPLE"\n' > "$R/creds.txt"
T "AWS access key id in untracked file fails" 1 --pwd "$R" --test-cmd true

# --- --base plumbing: committed work is scanned against the given base ---
R="$(make_repo)"; printf 'REPLACE_ME\n' >> "$R/base.txt"
( cd "$R" && git commit -qam change ) >/dev/null 2>&1
T "committed marker invisible vs default HEAD base" 0 --pwd "$R" --test-cmd true
T "committed marker caught with --base HEAD~1" 1 --pwd "$R" --test-cmd true --base HEAD~1

# --- scope delegation to check-plan-scope.sh ---
# plan/contract fixtures live OUTSIDE the repo so they don't appear in its diff
scope_fixtures() { # $1 = allowed path
  SCOPE_DIR="$(mktemp -d)"
  printf '%s\n' "$1" > "$SCOPE_DIR/plan.txt"
  printf 'contract\n' > "$SCOPE_DIR/contract.md"
  shasum -a 256 "$SCOPE_DIR/contract.md" | awk '{print $1}' > "$SCOPE_DIR/contract.md.sha256"
}

R="$(make_repo)"; printf 'new\n' > "$R/feature.txt"; scope_fixtures "feature.txt"
T "scope: in-plan change passes" 0 --pwd "$R" --test-cmd true \
  --plan-list "$SCOPE_DIR/plan.txt" --contract "$SCOPE_DIR/contract.md"

printf 'rogue\n' > "$R/rogue.txt"
T "scope: outside-plan file fails" 1 --pwd "$R" --test-cmd true \
  --plan-list "$SCOPE_DIR/plan.txt" --contract "$SCOPE_DIR/contract.md"

R="$(make_repo)"
T "scope: skipped when no --plan-list (passes)" 0 --pwd "$R" --test-cmd true

# --- usage errors ---
D="$(mktemp -d)"
T "non-git directory is a usage error" 2 --pwd "$D" --test-cmd true
T "missing --pwd is a usage error" 2 --test-cmd true

printf '\n%s passed, %s failed\n' "$pass" "$failc"
[ "$failc" -eq 0 ]
