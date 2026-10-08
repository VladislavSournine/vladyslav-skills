#!/usr/bin/env bash
# pre-release-checks.sh — run the 5 cross-platform pre-release checks
# deterministically (no LLM) and emit a JSON report.
#
# What this DOES handle (deterministic):
#   1. Tasks completion          — count [x]/[ ] in docs/plans/tasks.md
#   2. Tests configured + pass   — detect test runner, run it, capture exit code
#   3. Config sanity             — grep REPLACE_ME placeholders
#   4. Documentation sync        — detect TBD/`*to be filled*` in key docs;
#                                  auto-generate changelog from git log if empty
#   5. Translations              — detect translation files for the platform
#
# What this does NOT do (handled by the skill, with LLM):
#   - Check 6 Apple review (iOS only) — semantic review against App Store
#     Guidelines, requires apple-appstore-reviewer skill.
#   - The "Recommended next action" text in the rendered summary — that
#     comes from Opus interpreting the JSON.
#
# Usage:
#   pre-release-checks.sh \
#       --pwd <project-dir> \
#       --plugin-root <plugin-root> \
#       [--test-cmd "<cmd>"] [--test-timeout <seconds>]
#
# --test-cmd overrides runner auto-detection (same flag as quality-gate.sh). Use it
# for monorepos and for Xcode projects, which need -project/-scheme/-destination.
# --test-timeout defaults to 300 s (only enforced when timeout/gtimeout exists).
#
# Output: JSON to stdout describing each check's result and the overall outcome.
# Side-effect: writes docs/release/pre-release-report-<YYYY-MM-DD>.md
# Exit code: 0 always (overall result is in the JSON, not the exit code).

set -u

PROJECT_PWD=""
PLUGIN_ROOT=""
TEST_CMD=""
TEST_TIMEOUT=300

while [ $# -gt 0 ]; do
    case "$1" in
        --pwd) PROJECT_PWD="$2"; shift 2 ;;
        --plugin-root) PLUGIN_ROOT="$2"; shift 2 ;;
        --test-cmd) TEST_CMD="$2"; shift 2 ;;
        --test-timeout) TEST_TIMEOUT="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

[ -z "$PROJECT_PWD" ] && { echo "--pwd required" >&2; exit 2; }
[ -z "$PLUGIN_ROOT" ] && { echo "--plugin-root required" >&2; exit 2; }
[ -d "$PROJECT_PWD" ] || { echo "pwd not found: $PROJECT_PWD" >&2; exit 2; }

cd "$PROJECT_PWD" || exit 2

TODAY=$(date +%Y-%m-%d)
REPORT_FILE="docs/release/pre-release-report-${TODAY}.md"

# ─── platform detection ──────────────────────────────────────────────────

DETECT="$PLUGIN_ROOT/scripts/detect-stack.sh"
DETECTION=""
[ -x "$DETECT" ] && DETECTION="$("$DETECT" "$PROJECT_PWD" 2>/dev/null)"

json_bool() {
    case "$DETECTION" in
        *\"$1\":true*) echo true ;;
        *) echo false ;;
    esac
}

PLATFORM="other"
if [ "$(json_bool ios)" = "true" ]; then
    PLATFORM="ios"
elif [ "$(json_bool plugin)" = "true" ]; then
    PLATFORM="plugin"
elif [ "$(json_bool web)" = "true" ]; then
    PLATFORM="web"
elif [ "$(json_bool backend)" = "true" ] || [ "$(json_bool python)" = "true" ] || [ "$(json_bool go)" = "true" ]; then
    PLATFORM="backend"
fi

# ─── check helpers ──────────────────────────────────────────────────────

# Per-check result fields — flat variables (macOS bash 3.2 has no
# associative arrays). Indexed by name suffix: RESULT_tasks, SEVERITY_tasks,
# EVIDENCE_tasks, and likewise for tests / config / docs / translations.
RESULT_tasks=""; SEVERITY_tasks=""; EVIDENCE_tasks=""
RESULT_tests=""; SEVERITY_tests=""; EVIDENCE_tests=""
RESULT_config=""; SEVERITY_config=""; EVIDENCE_config=""
RESULT_docs=""; SEVERITY_docs=""; EVIDENCE_docs=""
RESULT_translations=""; SEVERITY_translations=""; EVIDENCE_translations=""

# Escape a string for inclusion in JSON: backslashes, quotes, newlines, tabs.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

set_check() {
    local name="$1" result="$2" sev="$3" evidence="$4"
    eval "RESULT_${name}=\"\$result\""
    eval "SEVERITY_${name}=\"\$sev\""
    eval "EVIDENCE_${name}=\"\$evidence\""
}

get_check() {
    # $1 = field (RESULT|SEVERITY|EVIDENCE), $2 = name
    eval "printf '%s' \"\$${1}_${2}\""
}

# ─── Check 1: Tasks completion ──────────────────────────────────────────

check_tasks() {
    local f="docs/plans/tasks.md"
    if [ ! -f "$f" ]; then
        set_check "tasks" "FAIL" "blocker" "docs/plans/tasks.md is missing"
        return
    fi
    local content
    content="$(cat "$f")"
    if [ -z "$(printf '%s' "$content" | tr -d '[:space:]')" ]; then
        set_check "tasks" "FAIL" "blocker" "docs/plans/tasks.md is empty"
        return
    fi
    # Treat the standard stub as empty
    if printf '%s' "$content" | grep -q '\*to be filled\*' && \
       [ "$(printf '%s' "$content" | grep -cE '^- \[' )" -eq 0 ]; then
        set_check "tasks" "FAIL" "blocker" "docs/plans/tasks.md still has the stub placeholder"
        return
    fi

    local total
    local complete
    total=$(printf '%s' "$content" | grep -cE '^- \[[ x]\]' || true)
    complete=$(printf '%s' "$content" | grep -cE '^- \[x\]' || true)

    if [ "$total" -eq 0 ]; then
        set_check "tasks" "WARN" "low" "no task checkboxes found in tasks.md — manual verification advised"
        return
    fi
    if [ "$complete" -eq "$total" ]; then
        set_check "tasks" "PASS" "low" "${complete}/${total} tasks complete"
    else
        local incomplete=$((total - complete))
        set_check "tasks" "WARN" "high" "${complete}/${total} tasks complete; ${incomplete} incomplete tasks remain"
    fi
}

# ─── Check 2: Tests ──────────────────────────────────────────────────────

detect_test_command() {
    if [ -f pyproject.toml ] && grep -q 'pytest' pyproject.toml 2>/dev/null; then
        echo "pytest"; return
    fi
    if [ -f pytest.ini ] || [ -d tests ]; then
        echo "pytest"; return
    fi
    if [ -f go.mod ]; then
        echo "go test ./..."; return
    fi
    if [ -f pubspec.yaml ]; then
        echo "flutter test"; return
    fi
    # Bare `xcodebuild test` only works from the project's own directory; a project
    # in a subdirectory is reported by check_tests as "pass --test-cmd" instead.
    if find . -maxdepth 1 -name '*.xcodeproj' -print -quit 2>/dev/null | grep -q .; then
        echo "xcodebuild test"; return
    fi
    if [ -f Package.swift ]; then
        echo "swift test"; return
    fi
    if [ -f package.json ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            echo "npm test"; return
        fi
    fi
    echo ""
}

check_tests() {
    local cmd
    cmd="${TEST_CMD:-$(detect_test_command)}"
    if [ -z "$cmd" ]; then
        local xcproj
        xcproj="$(find . -maxdepth 2 -name '*.xcodeproj' -print -quit 2>/dev/null)"
        if [ -n "$xcproj" ]; then
            set_check "tests" "WARN" "medium" "Xcode project at ${xcproj#./} — pass --test-cmd with -project/-scheme/-destination"
        elif [ "$PLATFORM" = "plugin" ]; then
            set_check "tests" "WARN" "low" "plugin type — no traditional test runner; manual verification only"
        else
            set_check "tests" "WARN" "medium" "no test runner detected"
        fi
        return
    fi

    # Run with a generous timeout. Use gtimeout if available (macOS via coreutils).
    local timeout_cmd=""
    if command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout $TEST_TIMEOUT"
    elif command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout $TEST_TIMEOUT"
    fi

    local output rc tmp
    tmp=$(mktemp)
    if [ -n "$timeout_cmd" ]; then
        $timeout_cmd sh -c "$cmd" > "$tmp" 2>&1
        rc=$?
    else
        sh -c "$cmd" > "$tmp" 2>&1
        rc=$?
    fi
    output="$(tail -c 2000 "$tmp")"
    rm -f "$tmp"

    if [ "$rc" -eq 0 ]; then
        set_check "tests" "PASS" "low" "${cmd} → exit 0"
    elif [ "$rc" -eq 124 ]; then
        set_check "tests" "FAIL" "blocker" "${cmd} → timed out after ${TEST_TIMEOUT}s"
    else
        # Truncate output to keep JSON readable
        local snippet
        snippet="$(printf '%s' "$output" | tail -c 800)"
        set_check "tests" "FAIL" "blocker" "${cmd} → exit ${rc}: ${snippet}"
    fi
}

# ─── Check 3: REPLACE_ME placeholders ────────────────────────────────────

check_config() {
    local grep_script="$PLUGIN_ROOT/scripts/grep-replace-me.sh"
    local hits=""
    if [ -x "$grep_script" ]; then
        hits="$("$grep_script" "$PROJECT_PWD" 2>/dev/null || true)"
    else
        # Inline fallback
        hits="$(grep -R -n \
            --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv \
            --include='*.env*' --include='*.yml' --include='*.yaml' \
            --include='*.json' --include='*.toml' \
            -e 'REPLACE_ME' "$PROJECT_PWD" 2>/dev/null | head -30 || true)"
    fi
    if [ -z "$hits" ]; then
        set_check "config" "PASS" "low" "no REPLACE_ME placeholders found"
    else
        local count
        count=$(printf '%s' "$hits" | wc -l | tr -d ' ')
        set_check "config" "FAIL" "blocker" "${count} placeholder(s) found: $(printf '%s' "$hits" | head -3 | tr '\n' '|')"
    fi
}

# ─── Check 4: Docs sync ──────────────────────────────────────────────────

doc_is_stub() {
    # Returns 0 (true) if the file is missing or contains only stub content
    local f="$1"
    [ ! -f "$f" ] && return 0
    local body
    body="$(cat "$f")"
    # Stripped of whitespace + first heading
    local stripped
    stripped="$(printf '%s' "$body" | sed -E '/^# /d; /^\*to be filled\*/d' | tr -d '[:space:]')"
    [ -z "$stripped" ] && return 0
    return 1
}

check_docs() {
    local stubbed=()
    for f in docs/testing/manual-qa.md docs/release/rollback.md docs/product/user-stories.md; do
        doc_is_stub "$f" && stubbed+=("$f")
    done

    # Changelog auto-generation
    local changelog="docs/release/changelog.md"
    if doc_is_stub "$changelog"; then
        local gen_script="$PLUGIN_ROOT/scripts/changelog-from-git.sh"
        local since=""
        since="$(git tag --sort=-creatordate 2>/dev/null | head -1 || true)"
        local gen=""
        if [ -x "$gen_script" ]; then
            gen="$("$gen_script" "auto-generated" "$since" 2>/dev/null || true)"
        fi
        if [ -n "$gen" ]; then
            mkdir -p docs/release
            printf '%s\n' "$gen" > "$changelog"
            stubbed+=("docs/release/changelog.md (auto-generated)")
        else
            stubbed+=("docs/release/changelog.md (stub, no git history)")
        fi
    fi

    if [ ${#stubbed[@]} -eq 0 ]; then
        set_check "docs" "PASS" "low" "all key doc files have real content"
    else
        local list
        list="$(IFS=', '; printf '%s' "${stubbed[*]}")"
        set_check "docs" "WARN" "low" "stub docs detected: ${list}"
    fi
}

# ─── Check 5: Translations ───────────────────────────────────────────────

check_translations() {
    case "$PLATFORM" in
        ios)
            local found
            found="$(find . -maxdepth 5 \( -name '*.xcstrings' -o -name 'Localizable.strings' \) -not -path '*/build/*' -not -path '*/DerivedData/*' 2>/dev/null | head -3)"
            if [ -n "$found" ]; then
                set_check "translations" "PASS" "low" "translation files found"
            else
                set_check "translations" "WARN" "low" "no .xcstrings or Localizable.strings found (add translations now if app is user-facing)"
            fi
            ;;
        web)
            local found
            found="$(find . -maxdepth 5 \( -path '*/i18n/*' -o -path '*/locales/*' -o -path '*/messages/*' \) -not -path '*/node_modules/*' 2>/dev/null | head -3)"
            if [ -n "$found" ]; then
                set_check "translations" "PASS" "low" "translation files/directories found"
            else
                set_check "translations" "WARN" "low" "no i18n/locales/messages directories found"
            fi
            ;;
        plugin|backend|other)
            set_check "translations" "WARN" "low" "platform ${PLATFORM} — translations N/A or manual verification required"
            ;;
    esac
}

# ─── run all 5 checks ────────────────────────────────────────────────────

check_tasks
check_tests
check_config
check_docs
check_translations

# ─── compute overall ─────────────────────────────────────────────────────

OVERALL="PASS"
for name in tasks tests config docs translations; do
    sev=$(get_check SEVERITY "$name")
    case "$sev" in
        blocker) OVERALL="FAIL" ;;
        high|medium)
            [ "$OVERALL" = "PASS" ] && OVERALL="WARN"
            ;;
    esac
done

# ─── write report.md ─────────────────────────────────────────────────────

mkdir -p docs/release

emoji_for() {
    case "$1" in
        PASS) echo "✅" ;;
        WARN) echo "⚠️" ;;
        FAIL) echo "❌" ;;
        *) echo "?" ;;
    esac
}

{
    printf '# Pre-Release Report — %s\n\n' "$TODAY"
    printf '**Platform:** %s\n\n' "$PLATFORM"
    printf '**Overall:** %s %s\n\n' "$(emoji_for "$OVERALL")" "$OVERALL"
    printf '## Checks\n\n'
    printf '| Check | Result | Severity | Evidence |\n'
    printf '|-------|--------|----------|---------|\n'
    for name in tasks tests config docs translations; do
        r=$(get_check RESULT "$name")
        s=$(get_check SEVERITY "$name")
        e=$(get_check EVIDENCE "$name")
        printf '| %s | %s %s | %s | %s |\n' \
            "$name" \
            "$(emoji_for "$r")" \
            "$r" \
            "$s" \
            "$(printf '%s' "$e" | tr '\n' ' ' | head -c 250)"
    done
    if [ "$PLATFORM" = "ios" ]; then
        printf '\n## iOS Apple App Store Review\n\n'
        printf '*Check 6 (Apple review) requires LLM reasoning and is handled by the `pre-release-check` skill via the `apple-appstore-reviewer` skill — not included in this deterministic report.*\n'
    fi
} > "$REPORT_FILE"

# ─── emit JSON ───────────────────────────────────────────────────────────

NEEDS_APPLE="false"
[ "$PLATFORM" = "ios" ] && NEEDS_APPLE="true"

printf '{"status":"success","overall":"%s","platform":"%s","needs_apple_check":%s,"report_file":"%s","checks":[' \
    "$OVERALL" "$PLATFORM" "$NEEDS_APPLE" "$REPORT_FILE"

first=1
for name in tasks tests config docs translations; do
    [ $first -eq 1 ] || printf ','
    r=$(get_check RESULT "$name")
    s=$(get_check SEVERITY "$name")
    e=$(get_check EVIDENCE "$name")
    printf '{"name":"%s","result":"%s","severity":"%s","evidence":"%s"}' \
        "$name" "$r" "$s" "$(json_escape "$e")"
    first=0
done

printf ']}\n'
exit 0
