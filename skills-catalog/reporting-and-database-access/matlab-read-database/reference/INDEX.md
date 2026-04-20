# Knowledge Index — Pushdown Architect

**Cards contain detailed usage, examples, and gotchas. Read the relevant card before writing code that uses the listed functions.**

## Function-Level Routing

| Function / Pattern | Card to read |
|--------------------|--------------|
| `sqlread(...)` | `cards/sqlread-fetch.md` |
| `fetch(...)` | `cards/sqlread-fetch.md` |
| `databaseImportOptions(...)` | `cards/import-options.md` |
| `rowfilter(...)` | `cards/import-options.md` |
| `sqlinnerjoin(...)` | `cards/pushdown-joins.md` |
| `sqlouterjoin(...)` | `cards/pushdown-joins.md` |

## Task-Level Routing

| Trigger / task | Card to read |
|----------------|--------------|
| Import from a single table | `cards/sqlread-fetch.md` |
| Import from a SQL query | `cards/sqlread-fetch.md` |
| Filter rows, select columns, exclude duplicates | `cards/import-options.md` |
| Join two database tables | `cards/pushdown-joins.md` |
| Complex join (3+ tables, aggregation) | `cards/sqlread-fetch.md` (use `fetch` with SQL) |

## Card Summary

| Card | Purpose | ~Lines |
|------|---------|--------|
| `cards/sqlread-fetch.md` | `sqlread` and `fetch` usage — table import, SQL query import, RowFilter as NV arg | ~80 |
| `cards/import-options.md` | `databaseImportOptions` — SelectedVariableNames, ExcludeDuplicates, RowFilter, VariableTypes | ~80 |
| `cards/pushdown-joins.md` | `sqlinnerjoin`/`sqlouterjoin` — parameters, gotchas, column selection workaround | ~90 |

----

Copyright 2026 The MathWorks, Inc.

----
