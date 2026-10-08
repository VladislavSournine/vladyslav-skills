#!/usr/bin/env bash
# Test harness for pre-release-checks.sh — builds fixture projects, asserts per-check results.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CHECKS="$HERE/pre-release-checks.sh"
pass=0; failc=0

T() { # desc, check-name, expected-result, script args...
  local desc="$1" name="$2" exp="$3" got; shift 3
  got="$("$CHECKS" --plugin-root "$ROOT" "$@" 2>/dev/null | tail -1 | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(next(c["result"] for c in d["checks"] if c["name"] == sys.argv[1]))
' "$name" 2>/dev/null)"
  if [ "$got" = "$exp" ]; then
    pass=$((pass+1)); printf 'ok   - %s\n' "$desc"
  else
    failc=$((failc+1)); printf 'FAIL - %s (%s=%s, want %s)\n' "$desc" "$name" "${got:-<none>}" "$exp"
  fi
}

make_proj() { # prints path to a fresh fixture project
  local p; p="$(mktemp -d)"
  mkdir -p "$p/docs/plans"; printf '# Tasks\n\n- [x] done\n' > "$p/docs/plans/tasks.md"
  printf '%s' "$p"
}

# --- tests check ---
P="$(make_proj)"
T "--test-cmd that passes → PASS" tests PASS --pwd "$P" --test-cmd true

P="$(make_proj)"
T "--test-cmd that fails → FAIL" tests FAIL --pwd "$P" --test-cmd false

P="$(make_proj)"; mkdir -p "$P/App/App.xcodeproj"
T "Xcode project in a subdirectory without --test-cmd → WARN, not a bogus FAIL" tests WARN --pwd "$P"

# --- config check ---
P="$(make_proj)"; printf 'API_KEY=REPLACE_ME\n' > "$P/app.yml"
T "REPLACE_ME in a config file → FAIL" config FAIL --pwd "$P" --test-cmd true

P="$(make_proj)"; printf 'status: TBD\n' > "$P/app.yml"
T "standalone TBD in a config file → FAIL" config FAIL --pwd "$P" --test-cmd true

P="$(make_proj)"; printf 'names: [TBDATA, TBDELE]\n' > "$P/app.yml"
T "TBD inside a longer word (TBDATA) → PASS" config PASS --pwd "$P" --test-cmd true

P="$(make_proj)"; mkdir -p "$P/backend/venv/lib/site-packages/pkg"
printf 'x = "REPLACE_ME"\n' > "$P/backend/venv/lib/site-packages/pkg/mod.py"
T "placeholders inside a Python venv are ignored" config PASS --pwd "$P" --test-cmd true

P="$(make_proj)"; mkdir -p "$P/docs/release"
printf '| config | FAIL | REPLACE_ME found |\n' > "$P/docs/release/pre-release-report-2000-01-01.md"
T "markdown docs (e.g. an old report) are not config → PASS" config PASS --pwd "$P" --test-cmd true

# --- usage ---
"$CHECKS" --plugin-root "$ROOT" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); echo "ok   - missing --pwd is a usage error"
else failc=$((failc+1)); echo "FAIL - missing --pwd is a usage error (exit $rc)"; fi

echo; echo "$pass passed, $failc failed"
[ "$failc" -eq 0 ]
