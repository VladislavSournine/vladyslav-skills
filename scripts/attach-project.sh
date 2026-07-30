#!/usr/bin/env bash
# attach-project.sh — deterministic scaffolder for adding Claude Code
# structure to an EXISTING project.
#
# This is the v3.1.0 replacement for the attach-project Sonnet subagent.
# Skip-if-exists everywhere — never overwrites a file the user has authored.
#
# Differs from scaffold-project.sh in three ways:
#   1. Auto-detects stacks instead of being told.
#   2. Skips every file that already exists (idempotent + safe for re-runs).
#   3. Does NOT scaffold backend code (no requirements.txt, FastAPI, Dockerfile,
#      compose files) — those are init-project's job. attach-project only adds
#      the AI workflow shell (CLAUDE.md, .claude/agents/, docs/ stubs,
#      gitignore entries, per-stack directory placeholders).
#   4. Does NOT init git — the project already has version control.
#
# Usage:
#   attach-project.sh \
#       --pwd <project-dir> \
#       --plugin-root <plugin-root> \
#       [--additional-stacks <comma-list: python,go,flutter,swift,kotlin,other>] \
#       [--other-stacks <label1:dir1:gitignore1;label2:dir2:gitignore2>] \
#       [--domain <free-text>] \
#       --private-mode <yes|no>
#
# Output: JSON {status, files_written, files_skipped, warnings, detected_stacks, error?}
# Exit codes: 0 success, 1 error, 2 bad args.

set -u

WRITTEN=()
SKIPPED=()
WARNINGS=()
DETECTED=()

emit_json() {
    local status="$1" error_msg="${2:-}"
    printf '{"status":"%s","detected_stacks":[' "$status"
    local first=1
    for s in "${DETECTED[@]:-}"; do
        [ -z "$s" ] && continue
        [ $first -eq 1 ] || printf ','
        printf '"%s"' "$s"
        first=0
    done
    printf '],"files_written":['
    first=1
    for f in "${WRITTEN[@]:-}"; do
        [ -z "$f" ] && continue
        [ $first -eq 1 ] || printf ','
        printf '"%s"' "$f"
        first=0
    done
    printf '],"files_skipped":['
    first=1
    for f in "${SKIPPED[@]:-}"; do
        [ -z "$f" ] && continue
        [ $first -eq 1 ] || printf ','
        printf '"%s"' "$f"
        first=0
    done
    printf '],"warnings":['
    first=1
    for w in "${WARNINGS[@]:-}"; do
        [ -z "$w" ] && continue
        [ $first -eq 1 ] || printf ','
        printf '"%s"' "$w"
        first=0
    done
    if [ -n "$error_msg" ]; then
        printf '],"error":"%s"}\n' "$error_msg"
    else
        printf ']}\n'
    fi
}

die() {
    WARNINGS+=("$1")
    emit_json "error" "$1"
    exit 1
}

mkpath() {
    mkdir -p "$1" || die "mkdir failed: $1"
}

write_if_absent() {
    local path="$1" content="$2"
    if [ -e "$path" ]; then
        SKIPPED+=("$path")
        return 0
    fi
    mkpath "$(dirname "$path")"
    printf '%s' "$content" > "$path" || die "write failed: $path"
    WRITTEN+=("$path")
}

write_stub() {
    local path="$1" title="$2"
    if [ -e "$path" ]; then
        SKIPPED+=("$path")
        return 0
    fi
    mkpath "$(dirname "$path")"
    {
        printf '# %s\n\n' "$title"
        printf '*to be filled*\n'
    } > "$path"
    WRITTEN+=("$path")
}

# Append given lines to .gitignore, but only those not already present.
gitignore_append() {
    local header="$1"; shift
    local entries=("$@")
    local gi=".gitignore"
    [ -f "$gi" ] || touch "$gi"

    local added_header=0
    for entry in "${entries[@]}"; do
        [ -z "$entry" ] && continue
        # Skip if already present (line-exact match)
        if grep -Fxq -- "$entry" "$gi" 2>/dev/null; then
            continue
        fi
        if [ "$added_header" -eq 0 ] && [ -n "$header" ]; then
            # Blank line + header before the first new entry
            printf '\n# %s\n' "$header" >> "$gi"
            added_header=1
        fi
        printf '%s\n' "$entry" >> "$gi"
    done
    if [ "$added_header" -eq 1 ]; then
        # Track .gitignore as modified
        local already=0
        for w in "${WRITTEN[@]:-}"; do [ "$w" = ".gitignore" ] && already=1; done
        [ "$already" -eq 0 ] && WRITTEN+=(".gitignore")
    fi
}

# ─── args ─────────────────────────────────────────────────────────────────

PROJECT_PWD=""
PLUGIN_ROOT=""
ADDITIONAL_STACKS=""
OTHER_STACKS=""
DOMAIN=""
PRIVATE_MODE="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --pwd) PROJECT_PWD="$2"; shift 2 ;;
        --plugin-root) PLUGIN_ROOT="$2"; shift 2 ;;
        --additional-stacks) ADDITIONAL_STACKS="$2"; shift 2 ;;
        --other-stacks) OTHER_STACKS="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --private-mode) PRIVATE_MODE="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

[ -z "$PROJECT_PWD" ] && { echo "--pwd required" >&2; exit 2; }
[ -z "$PLUGIN_ROOT" ] && { echo "--plugin-root required" >&2; exit 2; }
[ -d "$PROJECT_PWD" ] || die "project pwd does not exist: $PROJECT_PWD"
[ -d "$PLUGIN_ROOT" ] || die "plugin root does not exist: $PLUGIN_ROOT"

cd "$PROJECT_PWD" || die "cannot cd: $PROJECT_PWD"

# ─── verify this is a project root ────────────────────────────────────────

is_project_root=0
[ -d .git ] && is_project_root=1
for marker in requirements.txt pyproject.toml setup.py go.mod pubspec.yaml \
              Package.swift package.json build.gradle build.gradle.kts \
              CLAUDE.md .claude-plugin/plugin.json ; do
    [ -e "$marker" ] && { is_project_root=1; break; }
done
# *.xcodeproj
for d in *.xcodeproj; do [ -d "$d" ] && is_project_root=1; done

if [ "$is_project_root" -eq 0 ]; then
    die "Not a project root (no .git, language manifest, or CLAUDE.md found). Confirm pwd or run /vladyslav:init-project for a new project."
fi

# ─── auto-detect stacks ──────────────────────────────────────────────────

DETECT="$PLUGIN_ROOT/scripts/detect-stack.sh"
if [ ! -x "$DETECT" ]; then
    die "scripts/detect-stack.sh not found or not executable in plugin root"
fi
DETECTION="$("$DETECT" "$PROJECT_PWD")"

# Parse JSON values cheaply (no jq dependency)
json_bool() {
    local key="$1"
    case "$DETECTION" in
        *\"$key\":true*) echo true ;;
        *) echo false ;;
    esac
}

[ "$(json_bool ios)"     = "true" ] && DETECTED+=("ios")
[ "$(json_bool flutter)" = "true" ] && DETECTED+=("flutter")
[ "$(json_bool kotlin)"  = "true" ] && DETECTED+=("kotlin")
[ "$(json_bool python)"  = "true" ] && DETECTED+=("python")
[ "$(json_bool go)"      = "true" ] && DETECTED+=("go")
[ "$(json_bool node)"    = "true" ] && DETECTED+=("node")
[ "$(json_bool web)"     = "true" ] && DETECTED+=("web")

# Track which stacks are active (detected ∪ additional)
declare_stack() {
    local s="$1"
    case ",$ACTIVE_STACKS," in
        *",$s,"*) ;;
        *) ACTIVE_STACKS="${ACTIVE_STACKS:+$ACTIVE_STACKS,}$s" ;;
    esac
}

ACTIVE_STACKS=""
for s in "${DETECTED[@]:-}"; do
    [ -z "$s" ] && continue
    declare_stack "$s"
done
# Map detected `ios` → `swift` for compatibility with user-facing stack names
case ",$ACTIVE_STACKS," in *",ios,"*) declare_stack "swift" ;; esac

# Merge in user-supplied additional stacks (excluding "none")
IFS=',' read -r -a addl <<< "$ADDITIONAL_STACKS"
for s in "${addl[@]:-}"; do
    [ -z "$s" ] && continue
    [ "$s" = "none" ] && continue
    declare_stack "$s"
done

has_stack() {
    case ",$ACTIVE_STACKS," in *",$1,"*) return 0 ;; esac
    return 1
}

# ─── project name ─────────────────────────────────────────────────────────

PROJECT_NAME=""
if [ -f CLAUDE.md ]; then
    # Extract from first H1
    PROJECT_NAME="$(awk '/^# /{ sub(/^# /, ""); print; exit }' CLAUDE.md)"
fi
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$(pwd)")"

# ─── per-stack scaffolding (skip-if-exists) ──────────────────────────────

if has_stack "python"; then
    gitignore_append "Python" "__pycache__/" "*.pyc" ".venv/" "dist/" "*.egg-info/"
    [ -d python ] || [ -d backend ] || { mkpath python; write_if_absent python/.gitkeep ""; }
fi

if has_stack "go"; then
    gitignore_append "Go" "/bin/" "*.exe" "*.test" "*.out" "/tmp/" "vendor/"
    [ -d go ] || [ -d backend ] || { mkpath go; write_if_absent go/.gitkeep ""; }
fi

if has_stack "flutter"; then
    gitignore_append "Flutter" ".dart_tool/" ".flutter-plugins" ".flutter-plugins-dependencies" ".packages" "*.iml" ".metadata"
    [ -d flutter ] || { mkpath flutter; write_if_absent flutter/.gitkeep ""; }
fi

if has_stack "swift"; then
    gitignore_append "Swift / Xcode" "DerivedData/" "*.xcuserstate" "*.xcworkspace/xcuserdata/" ".build/" "*.ipa" "Pods/"
    [ -d swift ] || [ -d app ] || [ -d ios ] || { mkpath swift; write_if_absent swift/.gitkeep ""; }
fi

if has_stack "kotlin"; then
    gitignore_append "Kotlin / Android" "*.apk" "*.aab" "local.properties" ".gradle/" "build/" "*.iml"
    [ -d kotlin ] || [ -d android ] || { mkpath kotlin; write_if_absent kotlin/.gitkeep ""; }
fi

if has_stack "node"; then
    gitignore_append "Node" "node_modules/" ".env" "dist/" "build/"
fi

# Parse and apply OTHER_STACKS (label:dir:gitignore;label:dir:gitignore;...)
if [ -n "$OTHER_STACKS" ]; then
    IFS=';' read -r -a others <<< "$OTHER_STACKS"
    for spec in "${others[@]:-}"; do
        [ -z "$spec" ] && continue
        IFS=':' read -r label dir gi <<< "$spec"
        [ -z "$dir" ] && continue
        [ -d "$dir" ] || { mkpath "$dir"; write_if_absent "$dir/.gitkeep" ""; }
        # Convert comma-separated gitignore to array
        IFS=',' read -r -a entries <<< "$gi"
        gitignore_append "$label" "${entries[@]}"
    done
fi

# Base gitignore entries every project should have
gitignore_append "Editors / OS" ".DS_Store" ".idea/" ".vscode/" "*.swp" "*.swo"
gitignore_append "Secrets / env" ".env" ".env.*" "!.env.example" "secrets/" ".claude/settings.local.json"
gitignore_append "Logs / build artifacts" "*.log" "logs/" "build/" "dist/" "coverage/"
gitignore_append "CodeGraph (optional local index)" ".codegraph/"

# Private mode: ignore AI workflow files
if [ "$PRIVATE_MODE" = "yes" ]; then
    gitignore_append "Private mode — AI workflow" "CLAUDE.md" ".claude/" "docs/plans/" "docs/operations/" "docs/marketing/"
fi

# ─── docs/ stubs (always, even in private mode — gitignore handles privacy) ─

mkpath docs/product
mkpath docs/architecture
mkpath docs/plans
write_stub docs/architecture/system.md "System Architecture"
write_stub docs/product/prd.md         "Product Requirements"
write_stub docs/plans/tasks.md         "Tasks"

# ─── .claude/agents/ ────────────────────────────────────────────────────

mkpath .claude/agents

agent_docs='---
name: docs-agent
description: Keeps project documentation in sync with code changes
---

Read CLAUDE.md and the source-of-truth docs listed there. When the user
modifies code, ensure the corresponding docs entry is updated in the same
PR. Flag any code change that lacks a doc counterpart.
'

agent_code_review='---
name: code-review-agent
description: Reviews code changes against project conventions and architecture
---

Read CLAUDE.md, docs/architecture/system.md (if present), and existing
patterns in the codebase before reviewing. Flag deviations from conventions,
architecture violations, and missing tests.
'

write_if_absent .claude/agents/docs-agent.md       "$agent_docs"
write_if_absent .claude/agents/code-review-agent.md "$agent_code_review"

# ─── .claude/settings.json ──────────────────────────────────────────────

write_if_absent .claude/settings.json '{
  "env": {
    "PROJECT_DOCS_ROOT": "docs"
  }
}
'

# ─── CLAUDE.md (only if absent) ─────────────────────────────────────────

if [ ! -f CLAUDE.md ]; then
    # Build Stack section from active stacks
    STACK_LINES=""
    has_stack "python"  && STACK_LINES="${STACK_LINES}- Python\n"
    has_stack "go"      && STACK_LINES="${STACK_LINES}- Go\n"
    has_stack "swift"   && STACK_LINES="${STACK_LINES}- Swift / iOS\n"
    has_stack "flutter" && STACK_LINES="${STACK_LINES}- Flutter\n"
    has_stack "kotlin"  && STACK_LINES="${STACK_LINES}- Kotlin / Android\n"
    has_stack "node"    && STACK_LINES="${STACK_LINES}- Node / JS\n"
    has_stack "web"     && STACK_LINES="${STACK_LINES}- Web frontend\n"
    if [ -n "$OTHER_STACKS" ]; then
        IFS=';' read -r -a others <<< "$OTHER_STACKS"
        for spec in "${others[@]:-}"; do
            [ -z "$spec" ] && continue
            IFS=':' read -r label dir _ <<< "$spec"
            [ -n "$label" ] && STACK_LINES="${STACK_LINES}- ${label} (in ${dir}/)\n"
        done
    fi
    [ -z "$STACK_LINES" ] && STACK_LINES="- to be filled\n"

    PROJECT_TYPE="${DOMAIN:-to be filled}"

    CLAUDE_MD_CONTENT="# ${PROJECT_NAME}

## Project Type

${PROJECT_TYPE}

## Stack

$(printf '%b' "$STACK_LINES")

## Source of Truth

| Doc | Purpose |
|-----|---------|
| \`docs/architecture/system.md\` | Architecture overview |
| \`docs/product/prd.md\` | Product requirements |
| \`docs/plans/tasks.md\` | Active tasks |

## Working Rules

- Do not add translations until the finalization phase
- <add project-specific rules here>
"
    write_if_absent CLAUDE.md "$CLAUDE_MD_CONTENT"
fi

# ─── done ─────────────────────────────────────────────────────────────────

emit_json "success"
exit 0
