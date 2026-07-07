# Self-heal shell (bootstrap-if-missing)

The offer a code-lifecycle skill makes when its working directory has **no AI shell**
(`CLAUDE.md` absent). Replaces a bare "STOP — go run attach-project" dead-end with an
inline, consented bootstrap. Two-tier, nothing runs silently.

Consumers: `add-feature`, `fix-bug`. (`ingest` is Tier 2 itself — it must never enter here.)

## Precondition

The caller's Step 0 has already run the `verify-pwd.md` check and found `CLAUDE.md`
missing in the working directory. Only then apply this contract.

## Tier 1 — bare shell (cheap, ~0.5s)

AskUserQuestion:

> "AI-оболонки в цьому проєкті нема. Збудувати зараз (attach-project), щоб продовжити? (y/n)"

- **y →** run the `attach-project.sh` scaffolder inline with low-friction defaults (no
  onboarding wizard — the user is here to do a task, not to onboard):
  1. Resolve the plugin root exactly as `attach-project` does: Glob
     `~/.claude/plugins/cache/vladyslav-marketplace/vladyslav/*/scripts/attach-project.sh`,
     take the directory two levels up; fall back to
     `/Volumes/DevSSD/Development/vladyslav-skills` (dev clone).
  2. Run:
     ```bash
     <plugin-root>/scripts/attach-project.sh \
         --pwd . \
         --plugin-root <plugin-root> \
         --domain "" \
         --private-mode no
     ```
  3. If the JSON reports `status: error` → surface the error and **STOP** (do not
     continue the calling skill).
  4. On success, re-read the freshly-written `CLAUDE.md` (and any docs stubs) and
     continue the calling skill's Step 0 (derive wing, etc.).
  - For full interactive control (domain, private mode, extra stacks) the user can run
    `/vladyslav:attach-project` explicitly instead — mention this once.
- **n →** **STOP** with the historic message: the skill cannot proceed without shell
  context. Suggest `/vladyslav:attach-project` or `/vladyslav:init-project`.

## Tier 2 — fill docs + code map (minutes; only if Tier 1 accepted)

AskUserQuestion (separate gate):

> "Наповнити доки + карту коду через ingest? Сканує код і сіє MemPalace — кілька хвилин. (y/n)"

- **y →** invoke `vladyslav:ingest` via the Skill tool, let it complete, then return to
  the calling skill.
- **n →** continue on the bare shell; the calling skill proceeds normally.

## Tier 2 addendum — CodeGraph index (optional)

If the `codegraph` CLI is available (see `_shared/references/codegraph.md`), Tier 2
additionally offers, as a separate `y/n`, to build a local code index:

> "Побудувати CodeGraph-індекс коду (`codegraph init`)? Прискорює навігацію в майбутніх сесіях. (y/n)"

- **y →** run `codegraph init` at the project root.
- **n →** skip.

Skipped silently if the CLI is absent — CodeGraph is optional and never required.
