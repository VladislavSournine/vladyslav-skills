#!/usr/bin/env bash
# check-plan-scope.sh — verify that the actual diff matches the plan.
#
# Used by `add-feature` (Auto mode) to enforce guard rails: the subagent
# may only modify files explicitly listed in the plan, must not alter the
# contract baseline, and must not silently refactor read-only files.
#
# Usage: check-plan-scope.sh <plan_files_list> <contract_baseline_file> [readonly_globs_file]
#
#   plan_files_list        — newline-separated list of paths the subagent
#                            is permitted to write to (relative to project root).
#   contract_baseline_file — path to the baseline contract; the script compares
#                            its current contents to the recorded baseline hash
#                            stored alongside it as <file>.sha256.
#   readonly_globs_file    — optional. Newline-separated glob patterns that
#                            must NOT appear in the diff at all.
#
# Output: JSON
#   {
#     "ok": true|false,
#     "files_outside_plan": [<paths>],
#     "contract_changed": true|false,
#     "readonly_touched": [<paths>]
#   }
#
# Exit codes:
#   0 — ok=true
#   1 — at least one violation (caller halts the dispatch)
#   2 — bad arguments / git command failure

set -u

if [ $# -lt 2 ]; then
    echo "Usage: check-plan-scope.sh <plan_files_list> <contract_baseline_file> [readonly_globs_file]" >&2
    exit 2
fi

PLAN_LIST="$1"
CONTRACT="$2"
READONLY_GLOBS="${3:-}"

[ -f "$PLAN_LIST" ] || { echo "plan list not found: $PLAN_LIST" >&2; exit 2; }
[ -f "$CONTRACT" ] || { echo "contract file not found: $CONTRACT" >&2; exit 2; }

# Files actually changed in the working tree (staged + unstaged).
CHANGED="$(git status --porcelain 2>/dev/null | sed -E 's/^.{3}//; s/^.* -> //' | sort -u)"

# Outside-plan: changed files not in PLAN_LIST.
PLAN_NORMAL="$(sort -u "$PLAN_LIST")"
OUTSIDE="$(comm -23 <(printf '%s\n' "$CHANGED") <(printf '%s\n' "$PLAN_NORMAL") | sed '/^$/d')"

# Contract drift: compare current sha256 to recorded baseline.
contract_changed=false
BASELINE="$CONTRACT.sha256"
if [ -f "$BASELINE" ]; then
    EXPECTED="$(cat "$BASELINE")"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL="$(sha256sum "$CONTRACT" 2>/dev/null | awk '{print $1}')"
    else
        ACTUAL="$(shasum -a 256 "$CONTRACT" 2>/dev/null | awk '{print $1}')"
    fi
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        contract_changed=true
    fi
fi

# Read-only touched: files in CHANGED that match any glob in READONLY_GLOBS.
readonly_touched=""
if [ -n "$READONLY_GLOBS" ] && [ -f "$READONLY_GLOBS" ]; then
    while IFS= read -r glob; do
        [ -z "$glob" ] && continue
        while IFS= read -r f; do
            case "$f" in
                $glob) readonly_touched="${readonly_touched}${f}"$'\n' ;;
            esac
        done <<< "$CHANGED"
    done < "$READONLY_GLOBS"
fi
readonly_touched="${readonly_touched%$'\n'}"

# Build JSON output.
emit_array() {
    local items="$1"
    if [ -z "$items" ]; then
        printf '[]'
        return
    fi
    printf '['
    local first=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [ $first -eq 1 ] || printf ','
        # naive escape — paths shouldn't contain quotes/backslashes in practice
        printf '"%s"' "$line"
        first=0
    done <<< "$items"
    printf ']'
}

ok=true
[ -n "$OUTSIDE" ] && ok=false
[ "$contract_changed" = "true" ] && ok=false
[ -n "$readonly_touched" ] && ok=false

printf '{"ok":%s,"files_outside_plan":' "$ok"
emit_array "$OUTSIDE"
printf ',"contract_changed":%s,"readonly_touched":' "$contract_changed"
emit_array "$readonly_touched"
printf '}\n'

[ "$ok" = "true" ] && exit 0 || exit 1
