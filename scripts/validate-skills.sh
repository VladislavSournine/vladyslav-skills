#!/usr/bin/env bash
# Repo-wide static validator for skills. See docs/superpowers/specs/2026-06-22-smoke-test-skills-design.md
set -u
shopt -s nullglob

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SKILLS="$ROOT/skills"
COMMANDS="$ROOT/commands"
README="$ROOT/README.md"
fail=0

err() { printf 'FAIL: %s\n' "$1"; fail=1; }

# Print the frontmatter block (between the first two --- lines).
frontmatter() {
  awk 'NR==1&&/^---[[:space:]]*$/{f=1;next} f&&/^---[[:space:]]*$/{exit} f' "$1"
}
# Print the body (everything after the frontmatter block).
body() {
  awk 'state=="body"{print}
       NR==1&&/^---[[:space:]]*$/{state="fm";next}
       state=="fm"&&/^---[[:space:]]*$/{state="body"}' "$1"
}

# Iterate real skills. A skill is a directory containing SKILL.md, which
# excludes non-skill dirs like _shared/ and docs/. Usage: for_each_skill <fn>
for_each_skill() {
  local fn="$1" d name
  for d in "$SKILLS"/*/; do
    name="$(basename "$d")"
    [ "$name" = "_shared" ] && continue
    [ -f "$d/SKILL.md" ] || continue
    "$fn" "$name" "$d/SKILL.md"
  done
}

check_frontmatter() { # name, file
  local name="$1" f="$2" fm nm
  [ -f "$f" ] || { err "$name: missing SKILL.md"; return; }
  fm="$(frontmatter "$f")"
  [ -n "$fm" ] || { err "$name: no frontmatter block"; return; }
  nm="$(printf '%s\n' "$fm" | sed -nE 's/^name:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' | head -1)"
  [ -n "$nm" ] || { err "$name: missing name field"; return; }
  [ "$nm" = "$name" ] || err "$name: frontmatter name '$nm' != dir"
  printf '%s\n' "$fm" | grep -qE '^description:[[:space:]]*\S' || err "$name: missing description"
  body "$f" | grep -qiE '^\**Type:' || err "$name: body missing Type: line"
}

check_commands() { # name, file (file unused; kept for for_each_skill signature)
  local name="$1" cmd="$COMMANDS/$1.md"
  if [ ! -f "$cmd" ]; then err "$name: missing commands/$name.md"; return; fi
  grep -q "$name" "$cmd" || err "$name: command does not reference skill"
}

check_orphan_commands() {
  local cmd name
  for cmd in "$COMMANDS"/*.md; do
    [ -f "$cmd" ] || continue
    name="$(basename "$cmd" .md)"
    [ -d "$SKILLS/$name" ] || err "command $name.md has no skill dir"
  done
}

check_crossrefs() { # name, file
  # Only intra-repo references are validated: skills/_shared/references/*.md.
  # docs/**.md paths in a SKILL.md are targets the skill creates in the END
  # USER's project, not files in this plugin repo, so they are NOT checked.
  local name="$1" f="$2" refs ref
  [ -f "$f" ] || return
  refs="$(grep -oE 'skills/_shared/references/[A-Za-z0-9_./-]+\.md' "$f" | sort -u)"
  for ref in $refs; do
    [ -e "$ROOT/$ref" ] || err "$name: broken reference $ref"
  done
}

check_agent_model() { # name, file
  # Architect skills must pass model= to every Agent() dispatch. Block-aware
  # heuristic: an Agent( call spans from its opening line to the line that
  # closes the paren; model may appear anywhere in that block (e.g. on its
  # own line in a multi-line call). Flags a block where model never appears.
  local name="$1" f="$2" start
  [ -f "$f" ] || return
  body "$f" | grep -qiE '^\**Type:\**[[:space:]]*Architect' || return
  # A block closes on a line whose first non-space char is ")" (idiomatic
  # multi-line call style), so a ")" embedded in a string value does not
  # close it early. A single-line Agent(...) closes on its own opening line.
  # "model" counts only with assignment syntax (model= or model:), so prose
  # mentioning "the model" does not suppress a real finding.
  while IFS= read -r start; do
    err "$name: Agent() call without model= (near line $start)"
  done < <(awk '
    function flush() { if (inblk && !hasmodel) print start; inblk=0; hasmodel=0 }
    {
      if (!inblk && /Agent\(/) {
        inblk=1; start=NR; hasmodel=0
        if (/model[[:space:]]*[=:]/) hasmodel=1
        rest=$0; sub(/.*Agent\(/, "", rest)
        if (rest ~ /\)/) { flush(); next }
        next
      }
      if (inblk) {
        if (/model[[:space:]]*[=:]/) hasmodel=1
        if (/^[[:space:]]*\)/) flush()
      }
    }
    END { if (inblk) flush() }
  ' "$f")
}

check_orphan_references() {
  # Every references/*.md under skills/ (incl. _shared) must have at least
  # one consumer. Consumers are SKILL.md files, commands/*.md, scripts, or
  # the repo CLAUDE.md — deliberately NOT other references files: two dead
  # references citing each other must still fail (that is exactly how the
  # Heavy Engineer contract references rotted unnoticed for two versions).
  # Match is by basename (grep -F), a heuristic that tolerates any citation
  # style (relative, repo-rooted, prose) at the cost of cross-skill
  # basename collisions — acceptable at this repo's size.
  local ref base
  for ref in "$SKILLS"/*/references/*.md; do
    [ -f "$ref" ] || continue
    base="$(basename "$ref")"
    cat "$SKILLS"/*/SKILL.md "$COMMANDS"/*.md "$ROOT"/scripts/*.sh \
        "$ROOT"/scripts/*/*.sh "$ROOT/CLAUDE.md" 2>/dev/null \
      | grep -qF "$base" || err "orphan reference: ${ref#"$ROOT"/}"
  done
}

check_mempalace_readme() {
  local section d name f
  [ -f "$README" ] || { err "README: file missing"; return; }
  if ! grep -q 'mempalace-skills:start' "$README"; then
    err "README: mempalace-skills markers not found"; return
  fi
  section="$(awk '/<!-- mempalace-skills:start -->/{p=1;next} /<!-- mempalace-skills:end -->/{p=0} p' "$README")"
  # forward: every mempalace caller is listed
  for d in "$SKILLS"/*/; do
    name="$(basename "$d")"; [ "$name" = "_shared" ] && continue
    f="$d/SKILL.md"; [ -f "$f" ] || continue
    grep -q 'mempalace_' "$f" || continue
    printf '%s' "$section" | grep -q "\`$name\`" || err "$name: calls mempalace_* but missing from README list"
  done
  # backward: every listed name is a real skill. We do NOT require a literal
  # mempalace_ token: orchestrator skills (e.g. add-feature, fix-bug) require
  # MemPalace via natural-language instructions ("write a MemPalace record")
  # without calling the tool by name, so a token grep would false-positive.
  # This pass exists to catch stale entries (deleted/renamed skills).
  for name in $(printf '%s' "$section" | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u); do
    [ -d "$SKILLS/$name" ] || err "README list has unknown skill \`$name\`"
  done
}

main() {
  [ -d "$SKILLS" ] || { printf 'FAIL: no skills/ under %s\n' "$ROOT"; exit 2; }
  for_each_skill check_frontmatter
  for_each_skill check_commands
  check_orphan_commands
  for_each_skill check_crossrefs
  for_each_skill check_agent_model
  check_orphan_references
  check_mempalace_readme
  if [ "$fail" -ne 0 ]; then printf -- '--- validate-skills: FAILURES found\n'; exit 1; fi
  printf -- '--- validate-skills: all checks PASS\n'; exit 0
}
main
