# MemPalace decision-record template

Used by all skills that write to MemPalace (`add-feature`, `fix-bug`, `ingest`, `pre-release-check`, `compact-save`, `save`, `qsave`).

Every drawer should be addable in one search query later — write for **searchability**, not narrative.

---

## Required structure

Every record body uses this shape (exactly):

```
[WHAT] <one-sentence headline of the decision/problem/milestone — keyword-rich>
[WHY] <one-sentence motivation — the user request, constraint, or incident that drove it>
[FILES] <comma-separated list of relevant absolute paths; max 5; use trailing / for directories>
[DATE] <YYYY-MM-DD>
```

- `[WHAT]` and `[WHY]` are keyword-rich sentences. No vague phrasing like "improved things" — say what specifically changed.
- `[FILES]` lists absolute paths, comma-separated. Use trailing `/` for directories. If irrelevant, omit the line.
- `[DATE]` is always ISO format. Future-self relies on this for chronological context.

## Room types

Use these `room` values consistently:

| Room | When to use |
|------|------|
| `decision` | An architectural choice that future sessions should respect (e.g. "use FastAPI not Flask") |
| `problem` | A bug, incident, or class of error that recurred |
| `milestone` | A meaningful release, deployment, or "this works now" moment |
| `preference` | A user-stated preference that shapes how to collaborate |
| `compact-save` | Reserved for the `compact-save` skill — do not use elsewhere |

## Wing

Always pass the canonical wing name. Use `scripts/derive-wing.sh` (or for manual paths, follow the same algorithm: the project directory **basename**, with whitespace/underscores/dots collapsed to single hyphens — case preserved, no lowercasing, no added stack prefix). The basename already carries its own convention prefix where one applies (`swift-calories`, `python-tax`) and deliberately omits it where it doesn't (`brain`, `documents`, `phD`, `vladyslav-skills`). After deriving, reconcile against the wings list in `~/.claude/CLAUDE.md` to catch case drift like `swift-Sudoku` vs `swift-sudoku`.

**Exception — thematic wing `ops`:** cross-project operational knowledge (Docker patterns, DigitalOcean deploy steps, alembic pitfalls, nginx/env tricks) goes to the wing `ops`, NOT to the project wing where it happened to surface. Test: "would this record help on a *different* project's server work?" — if yes, `ops`. Project-specific deploy decisions (droplet size for X, domain for Y) stay in the project wing. An explicit wing named by the user always overrides derivation.

## Searchability test

Before writing a record, ask: "If I were six months in the future searching for this, what term would I type?" If the [WHAT] line doesn't contain that term, rewrite it. Records you can't find are records you don't have.
