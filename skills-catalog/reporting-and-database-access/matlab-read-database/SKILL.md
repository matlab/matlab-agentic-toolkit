---
name: matlab-read-database
description: "Reads data from relational databases using MATLAB Database Toolbox pushdown capabilities. Use when importing data from JDBC/ODBC databases, filtering rows, selecting columns, excluding duplicates, joining database tables, using sqlread, fetch, sqlinnerjoin, sqlouterjoin, databaseImportOptions, or rowfilter."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Database Toolbox Pushdown Architect

Use when importing data from relational databases with MATLAB Database Toolbox's pushdown capabilities — offloading row filtering, column selection, duplicate exclusion, and joins to the database instead of processing in MATLAB.

## When to Use This Skill

- Importing data from a database table or an SQL query as a MATLAB table
- Filtering rows from a database table or an SQL query
- Selecting specific columns from a database table or an SQL query
- Excluding duplicate rows in a database table or an SQL query
- Joining two database tables
- Combining joins with filtering or column selection
- User mentions keywords: import, sqlread, fetch, filter, rowfilter, join, sqlinnerjoin, sqlouterjoin, duplicates, databaseImportOptions, pushdown

## When NOT to Use

- Writing/inserting data into a database — use `sqlwrite`/`sqlupdate`/`execute` patterns instead
- Data too large to fit in memory — use `DatabaseDatastore` + tall arrays or `splitsqlquery`
- Object-oriented reads with class mapping — use ORM (`ormread` with `Mappable` classes)
- MongoDB, Cassandra, or Neo4j queries — pushdown functions only work with relational databases

## Critical Rules

### Pushdown Strategy
- **ALWAYS** use `sqlread` for tables, `fetch` for SQL queries.
- **ALWAYS** use `RowFilter` to push row filtering to the database. **NEVER** import all rows and filter in MATLAB.
- **ALWAYS** use `databaseImportOptions` with `SelectedVariableNames` when only a subset of columns is needed.
- **ALWAYS** verify the connection with `isopen(conn)` before operations and call `close(conn)` when done.

### Joins
- **ALWAYS** use `sqlinnerjoin`/`sqlouterjoin` for joining exactly 2 database tables.
- **NEVER** pass `databaseImportOptions` (`opts`) to `sqlinnerjoin` or `sqlouterjoin` — they do not accept it. Select columns in MATLAB after the join, or use `fetch` with explicit SQL.
- **NEVER** use pushdown joins for 3+ tables or joins with aggregation — use `fetch` with explicit SQL instead.


## Function Reference

### What Each Function Accepts

| Function | Accepts `opts`? | Accepts `RowFilter`? | Accepts `MaxRows`? | Column Selection |
|----------|:-:|:-:|:-:|---|
| `sqlread` | Yes | Yes | Yes | Via `opts.SelectedVariableNames` |
| `fetch` | Yes | Yes | Yes | Via `opts.SelectedVariableNames` |
| `sqlinnerjoin` | **No** | Yes | Yes | **Not supported** — select columns after join |
| `sqlouterjoin` | **No** | Yes | Yes | **Not supported** — select columns after join |

For full parameter details, see `reference/cards/pushdown-joins.md` and `reference/cards/import-options.md`.

## Decision Framework

> Which function should I use?

| Situation | Use | Why |
|-----------|-----|-----|
| Import from a single table | `sqlread` | Pushes filters/column selection to DB |
| Import from a SQL query | `fetch` | Executes arbitrary SQL on DB |
| Join exactly 2 tables (no column selection needed) | `sqlinnerjoin` / `sqlouterjoin` | Join executes on DB |
| Join 2 tables + select specific columns | `sqlinnerjoin` + MATLAB column selection | Join functions don't accept `opts` |
| Join 2 tables + column selection + deduplication | `fetch` with explicit SQL | Pushdown joins can't handle `opts` or `DISTINCT` |
| Join 3+ tables or use aggregation | `fetch` with explicit SQL | Pushdown joins limited to 2 tables |
| Need `ExcludeDuplicates` | `sqlread`/`fetch` with `opts` | Only these accept `databaseImportOptions` |

## Complete Examples

See knowledge cards for detailed examples:
- **Single table import with filtering**: `reference/cards/sqlread-fetch.md`
- **Column selection and deduplication**: `reference/cards/import-options.md`
- **Two-table joins with filtering**: `reference/cards/pushdown-joins.md`
- **Complex multi-table joins**: `reference/cards/pushdown-joins.md` (Fall Back to SQL section)

### Common Mistakes

```matlab
% INCORRECT — passing import options to join functions (error!)
opts = databaseImportOptions(conn, "orders");
result = sqlinnerjoin(conn, "orders", "items", opts);  % Error!

% CORRECT — join first, then select columns from the result
result = sqlinnerjoin(conn, "orders", "items", Keys="order_id");
result = result(:, ["order_id", "product", "quantity", "total"]);

% INCORRECT — using fetch without pushdown (pulls all data, filters in MATLAB)
data = fetch(conn, "SELECT * FROM orders");
filtered = data(data.total > 100, :);

% CORRECT — push the filter to the database
opts = databaseImportOptions(conn, "orders");
opts.RowFilter = opts.RowFilter.total > 100;
data = sqlread(conn, "orders", opts);
```

## Best Practices

- Use `RowFilter` as a name-value argument directly on `sqlread`/`fetch`/`sqlinnerjoin`/`sqlouterjoin` for simple filtering. Use `opts.RowFilter` when you also need column selection or deduplication.
- When layering `RowFilter` on a SQL query in `fetch`, the `RowFilter` adds conditions **on top of** the SQL `WHERE` clause. Avoid duplicating the same condition in both.
- Prefer `sqlinnerjoin`/`sqlouterjoin` over writing JOIN SQL manually when working with exactly 2 tables and no column selection or aggregation is needed.
- For join + column selection, choose based on data volume: if the extra columns are small, join then select in MATLAB. If the table is wide and data is large, use `fetch` with explicit SQL to select columns on the database.
- For tables with >50 columns, always use `SelectedVariableNames` to limit columns. For result sets >100K rows that don't fit in memory, use `DatabaseDatastore` with tall arrays or `splitsqlquery` for out-of-memory processing.

## Common Patterns

### Pattern 1: Single Table — Filter + Select Columns

```matlab
opts = databaseImportOptions(conn, "orders");
opts.SelectedVariableNames = ["OrderKey", "OrderStatus"];
opts.RowFilter = opts.RowFilter.OrderPriority == "URGENT";
T = sqlread(conn, "orders", opts);
```

### Pattern 2: Two Table Join — Filter Only

```matlab
rf = rowfilter("ShipMode");
T = sqlinnerjoin(conn, "orders", "lineitem", Keys="OrderKey", RowFilter=rf.ShipMode == "AIR");
```

### Pattern 3: Two Table Join — Filter + Select Columns (Post-Join)

```matlab
rf = rowfilter(["OrderPriority", "ShipMode"]);
T = sqlinnerjoin(conn, "orders", "lineitem", Keys="OrderKey", ...
    RowFilter=rf.OrderPriority == "URGENT" & rf.ShipMode == "AIR");
result = T(:, ["OrderKey", "OrderStatus"]);
```

### Pattern 4: Fall Back to SQL for Complex Queries

```matlab
sqlquery = "SELECT o.OrderKey, o.OrderStatus " + ...
    "FROM orders o INNER JOIN lineitem l ON o.OrderKey = l.OrderKey " + ...
    "WHERE o.OrderPriority = 'URGENT' AND l.ShipMode = 'AIR'";
T = fetch(conn, sqlquery);
```

### Pattern 5: Safe Import with Error Handling

```matlab
try
    opts = databaseImportOptions(conn, "orders");
    opts.SelectedVariableNames = ["id", "total", "status"];
    opts.RowFilter = opts.RowFilter.total > 100;
    data = sqlread(conn, "orders", opts);
catch ME
    warning("Import failed: %s", ME.message);
    data = table.empty;
end
```

## Checklist

Before finalizing pushdown import code, verify:
- [ ] `sqlread` used for database tables, `fetch` used for SQL queries
- [ ] Row filters use `RowFilter` parameter (pushed to database), not client-side filtering
- [ ] Only needed columns selected via `databaseImportOptions` with `SelectedVariableNames`
- [ ] `databaseImportOptions` is **NOT** passed to `sqlinnerjoin` or `sqlouterjoin`
- [ ] `ExcludeDuplicates` used instead of MATLAB `unique()` for deduplication
- [ ] Joins use `sqlinnerjoin`/`sqlouterjoin` (limited to 2 tables, no `opts`)
- [ ] Complex queries (3+ tables, aggregation, join + column selection) use `fetch` with SQL
- [ ] `isopen(conn)` checked after connection attempt
- [ ] `close(conn)` called at the end

## Troubleshooting

**Issue**: `sqlinnerjoin` errors when passing `databaseImportOptions`
- **Solution**: `sqlinnerjoin` and `sqlouterjoin` do not accept `databaseImportOptions`. Remove `opts` from the call. Select columns in MATLAB after the join, or use `fetch` with explicit SQL.

**Issue**: `RowFilter` has no effect — all rows are still returned
- **Solution**: Verify the column name in `rowfilter("ColName")` matches the database column exactly (case-sensitive for some databases).

**Issue**: `sqlinnerjoin` errors with "Key variable not found"
- **Solution**: The `Keys` value must match a column name that exists in both tables. Use `sqlfind(conn, "tableName")` to inspect column names.

**Issue**: `databaseImportOptions` errors on a SQL query
- **Solution**: Ensure the SQL query is valid and returns results. `databaseImportOptions` executes a metadata query — if the base query has syntax errors, it will fail.

**Issue**: `ExcludeDuplicates` doesn't remove duplicates as expected
- **Solution**: `ExcludeDuplicates` applies to the combination of all selected variables. Use `SelectedVariableNames` to narrow the columns first, then set `ExcludeDuplicates = true`.

**Issue**: `sqlouterjoin` returns unexpected NULLs
- **Solution**: Outer joins include non-matching rows filled with NULLs. This is expected SQL behavior. Use `RowFilter` to exclude rows post-join, or switch to `sqlinnerjoin` if you only want matching rows.


----

Copyright 2026 The MathWorks, Inc.

----
