#!/usr/bin/env bash
# core.sh — always-on AI shell for init-project. No docs, no code files.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_lib.sh"

NAME=""
parse_common_args "$@"
i=0; while [ $i -lt ${#REMAINING_ARGS[@]} ]; do
    case "${REMAINING_ARGS[$i]}" in
        --name) NAME="${REMAINING_ARGS[$((i+1))]}"; i=$((i+2)) ;;
        *) i=$((i+1)) ;;
    esac
done
[ -n "$NAME" ] || { echo "--name required" >&2; exit 2; }
cd "$PROJECT_PWD" || die "cannot cd to $PROJECT_PWD"

write_file ".gitignore" ".DS_Store
.idea/
.vscode/
*.swp
.claude/settings.local.json
.env
.env.*
!.env.example
secrets/
*.log
logs/
build/
dist/
coverage/
.codegraph/
"

write_file ".claude/settings.json" '{
  "env": {
    "PROJECT_DOCS_ROOT": "docs"
  }
}
'

write_file "CLAUDE.md" "# ${NAME}

## Project Type

*to be filled*

## Stack

- *to be filled*

## MemPalace

This project maps to a MemPalace wing. Search the wing before re-scanning the
codebase; record decisions/problems/milestones after substantive work.

## Working Rules

- Do not add translations until the finalization phase (pre-release-check)
- <add project-specific rules here>
"

write_file ".remember/now.md" "# Now

*session buffer — handoff notes go here*
"

if [ ! -d .git ]; then
    git init -q 2>/dev/null && git add -A 2>/dev/null \
        && git commit -q -m "chore: bootstrap ${NAME}" 2>/dev/null \
        || WARNINGS+=("git bootstrap failed — run manually")
fi

emit_json "success"
exit 0
