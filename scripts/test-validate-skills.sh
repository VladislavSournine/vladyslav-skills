#!/usr/bin/env bash
# Test harness for validate-skills.sh — builds fixture trees, asserts exit codes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$HERE/validate-skills.sh"
pass=0; failc=0

T() { # desc, expected_exit, root
  local desc="$1" exp="$2" root="$3" got
  "$VALIDATOR" "$root" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$exp" ]; then
    pass=$((pass+1)); printf 'ok   - %s\n' "$desc"
  else
    failc=$((failc+1)); printf 'FAIL - %s (exit %s, want %s)\n' "$desc" "$got" "$exp"
  fi
}

make_valid() { # prints path to a fresh valid fixture root
  local r; r="$(mktemp -d)"
  mkdir -p "$r/skills/alpha" "$r/skills/_shared/references" "$r/commands"
  cat > "$r/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: A valid sample skill.
---

**Type:** Engineer (light)

Body referencing skills/_shared/references/conv.md
EOF
  printf 'conv\n' > "$r/skills/_shared/references/conv.md"
  printf 'delegates to the alpha skill\n' > "$r/commands/alpha.md"
  cat > "$r/README.md" <<'EOF'
# Sample
<!-- mempalace-skills:start -->
Skills that require MemPalace:
<!-- mempalace-skills:end -->
EOF
  printf '%s' "$r"
}

# --- Baseline ---
R="$(make_valid)"; T "valid fixture passes" 0 "$R"

# --- Check A: frontmatter integrity ---
R="$(make_valid)"; sed -i.bak 's/^name: alpha/name: wrong/' "$R/skills/alpha/SKILL.md"
T "frontmatter name != dir fails" 1 "$R"

R="$(make_valid)"; sed -i.bak '/^description:/d' "$R/skills/alpha/SKILL.md"
T "missing description fails" 1 "$R"

R="$(make_valid)"; sed -i.bak '/^\*\*Type:/d' "$R/skills/alpha/SKILL.md"
T "missing Type line fails" 1 "$R"

R="$(make_valid)"; sed -i.bak 's/^name: alpha/name:/' "$R/skills/alpha/SKILL.md"
T "blank name field fails" 1 "$R"

# conv.md must go too: with its consumer skill gone it is a real orphan
# under Check F, and this test is about frontmatter false-positives only.
R="$(make_valid)"; rm -rf "$R/skills/alpha" "$R/commands/alpha.md" "$R/skills/_shared/references/conv.md"
T "empty skills dir does not false-positive" 0 "$R"

# --- Check B: command delegation + orphans ---
R="$(make_valid)"; rm "$R/commands/alpha.md"
T "missing command delegate fails" 1 "$R"

R="$(make_valid)"; printf 'unrelated text\n' > "$R/commands/alpha.md"
T "command not referencing skill fails" 1 "$R"

R="$(make_valid)"; printf 'orphan\n' > "$R/commands/ghost.md"
T "orphan command (no skill) fails" 1 "$R"

# --- Check C: cross-reference existence ---
R="$(make_valid)"
printf 'see skills/_shared/references/missing.md\n' >> "$R/skills/alpha/SKILL.md"
T "broken _shared reference fails" 1 "$R"

R="$(make_valid)"
printf 'see docs/architecture/missing.md\n' >> "$R/skills/alpha/SKILL.md"
T "docs/ reference is NOT checked (user-project target)" 0 "$R"

# --- Non-skill dirs under skills/ are ignored (no SKILL.md) ---
R="$(make_valid)"; mkdir -p "$R/skills/docs/superpowers"
T "non-skill dir under skills/ is ignored" 0 "$R"

# --- Check D: Architect Agent() must pass model= ---
R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch: Agent(prompt, subagent_type="x")\n' >> "$R/skills/alpha/SKILL.md"
T "Architect Agent() without model fails" 1 "$R"

R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch: Agent(prompt, model="sonnet")\n' >> "$R/skills/alpha/SKILL.md"
T "Architect Agent() with model passes" 0 "$R"

R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch:\n  Agent(\n    prompt,\n    model: "opus",\n  )\n' >> "$R/skills/alpha/SKILL.md"
T "Architect multiline Agent() with model on own line passes" 0 "$R"

R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch:\n  Agent(\n    prompt,\n    subagent_type: "x",\n  )\n' >> "$R/skills/alpha/SKILL.md"
T "Architect multiline Agent() without model fails" 1 "$R"

R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch:\n  Agent(\n    prompt: "draw (carefully) now",\n    model: "opus",\n  )\n' >> "$R/skills/alpha/SKILL.md"
T "embedded ) in string does not close block early (passes)" 0 "$R"

R="$(make_valid)"
sed -i.bak 's/^\*\*Type:\*\* Engineer (light)/**Type:** Architect/' "$R/skills/alpha/SKILL.md"
printf 'Dispatch:\n  Agent(\n    prompt: "the model decides",\n    subagent_type: "x",\n  )\n' >> "$R/skills/alpha/SKILL.md"
T "prose word model (no model= ) does not suppress finding (fails)" 1 "$R"

# --- Check E: README <-> MemPalace sync ---
R="$(make_valid)"
printf 'calls mempalace_search here\n' >> "$R/skills/alpha/SKILL.md"
T "mempalace caller missing from README fails" 1 "$R"

R="$(make_valid)"
sed -i.bak 's/Skills that require MemPalace:/Skills that require MemPalace: `beta`/' "$R/README.md"
T "README lists unknown (non-existent) skill fails" 1 "$R"

# A listed name that IS a real skill but has no literal mempalace_ token must
# pass — orchestrators require MemPalace indirectly (via NL instructions).
R="$(make_valid)"
sed -i.bak 's/Skills that require MemPalace:/Skills that require MemPalace: `alpha`/' "$R/README.md"
T "listed real skill without literal mempalace_ passes" 0 "$R"

# --- Check F: orphaned references ---
R="$(make_valid)"
printf 'dead\n' > "$R/skills/_shared/references/dead.md"
T "orphan _shared reference (no consumer) fails" 1 "$R"

R="$(make_valid)"
mkdir -p "$R/skills/alpha/references"
printf 'unused\n' > "$R/skills/alpha/references/unused.md"
T "orphan per-skill reference fails" 1 "$R"

R="$(make_valid)"
mkdir -p "$R/skills/alpha/references"
printf 'used\n' > "$R/skills/alpha/references/used.md"
printf 'see references/used.md\n' >> "$R/skills/alpha/SKILL.md"
T "per-skill reference consumed by own SKILL.md passes" 0 "$R"

# Two dead references citing each other must still fail — references are
# not consumers (this is exactly how the Heavy Engineer contract rotted).
R="$(make_valid)"
printf 'cites cycle-b.md\n' > "$R/skills/_shared/references/cycle-a.md"
printf 'cites cycle-a.md\n' > "$R/skills/_shared/references/cycle-b.md"
T "mutually-referencing dead references still fail" 1 "$R"

R="$(make_valid)"
printf 'script-used\n' > "$R/skills/_shared/references/script-used.md"
mkdir -p "$R/scripts"
printf '# consumes script-used.md\n' > "$R/scripts/consumer.sh"
T "reference consumed by a script passes" 0 "$R"

printf '\n%s passed, %s failed\n' "$pass" "$failc"
[ "$failc" -eq 0 ]
