# CodeGraph (optional code-navigation accelerator)

An OPTIONAL local code index (MCP server: SQLite + FTS5 + tree-sitter, MIT, 100% local, no API
keys). When present it returns relevant code + blast-radius in one call, replacing bursts of
grep/Glob/LSP. **It is never required** — if it is not available, do exactly what you would do today
(grep/Glob/LSP). No error, no stop.

Consumers: `ingest`, `add-feature`, `fix-bug`, and the Tier-2 branch of `self-heal-shell.md`.

## Detect (runtime, zero config)

Check in order; stop at the first that holds:

1. Is the MCP tool `codegraph_explore` available this session? → use it. (Primary path for
   `add-feature` / `fix-bug`, which run in the main session with MCP.)
2. Else, is the `codegraph` CLI on PATH AND does `.codegraph/` exist at the project root? → use the
   CLI: `codegraph explore|impact|callers|callees|files`.
3. Else → grep / Glob / LSP as usual. Silent — do not announce "CodeGraph not found".

## Task → command

| Need | CodeGraph | Fallback |
|------|-----------|----------|
| Code relevant to a topic / gather context | `explore "<query>"` (MCP: `codegraph_explore`) | grep + read |
| Blast radius of changing a symbol | `impact <symbol>` | grep references |
| Who calls / is called | `callers <symbol>` / `callees <symbol>` | grep + LSP getReferences |
| Project structure | `files` | Glob / tree |

## Caveats (do not over-trust the graph)

- **Framework-dispatch blind spot.** Call edges created by decorators / DI / routers (aiogram
  router, SwiftUI, DI containers) are under-reported. `impact` and `callers` are a **floor, not a
  ceiling** — verify entrypoints manually before assuming "no callers".
- **Source blocks are already-Read.** CodeGraph's verbatim, line-numbered source output is a Read
  you have already performed — do not re-Read those files. If you doubt freshness, run
  `codegraph sync` first (a file-watcher usually keeps the index current).

## Fallback contract

If CodeGraph is unavailable at any point (not detected, returns nothing, or errors), fall back to
grep / Glob / LSP with no behaviour change and no surfaced error. CodeGraph only ever *saves* calls;
its absence never changes correctness.
