# Reduce Large Data with DuckDB

DuckDB's role is reduction: take data that doesn't fit in memory, apply SQL operations to select, reshape, or clean it, and produce an in-memory result. Once the result is in memory, DuckDB's job is done.

## Workflow: Profile → Operate → Close

### Step 1: Profile

Query only the information needed to decide which reduction operation to apply. Do not run a generic "describe everything" query.

**Required:** Row count and column schema. Use `DESCRIBE SELECT * FROM ...` to get column names and types without reading the full file.

```matlab
conn = duckdb();
profile = fetch(conn, "SELECT COUNT(*) as row_count FROM read_parquet('orders.parquet')");
columns = fetch(conn, "DESCRIBE SELECT * FROM read_parquet('orders.parquet')");
```

**Conditional — query only if relevant to the reduction you're considering:**

| Considering | Query |
|-------------|-------|
| GROUP BY aggregation | `SELECT col, COUNT(*) FROM ... GROUP BY col` — check cardinality is much less than row count |
| WHERE filter | `SELECT MIN(col), MAX(col)` or `SELECT DISTINCT status` — check filterable range |
| Deduplication | `SELECT COUNT(*) - COUNT(DISTINCT key_col)` — check duplicate volume |
| NULL cleanup | `SELECT SUM(CASE WHEN col IS NULL THEN 1 ELSE 0 END)` — check if NULLs are prevalent |

### Step 2: Operate

Apply operations from the DO list to reduce data to in-memory size. Combine multiple operations in a single query when possible.

```matlab
reduced = fetch(conn, "SELECT " + ...
    "customer_id, " + ...
    "CAST(order_date AS DATE) as order_date, " + ...
    "SUM(total) as daily_total, " + ...
    "COUNT(*) as order_count " + ...
    "FROM read_parquet('orders.parquet') " + ...
    "WHERE status = 'completed' " + ...
    "  AND order_date >= '2024-01-01' " + ...
    "GROUP BY customer_id, CAST(order_date AS DATE)");
```

### Step 3: Close

Close the connection immediately after the last fetch. The reduced result is now an in-memory table. DuckDB's role is complete.

```matlab
close(conn);
```

Do not keep the connection open for "just in case" follow-up queries. If more reduction is needed later, open a new connection.

## SQL/MATLAB Semantic Mismatches

This table is not exhaustive. Do not assume SQL operations match MATLAB semantics exactly — verify NULL/NaN handling, sort order, and boundary behavior before claiming equivalence.

| SQL Behavior | MATLAB Behavior | Mitigation |
|-------------|-----------------|------------|
| `NULL` propagates (NULL + 1 = NULL) | `NaN` propagates; `ismissing` detects it | Use `COALESCE(col, 0)` or filter NULLs before aggregation |
| `CAST` throws on invalid data | Type conversion produces NaN/NaT | Use `TRY_CAST` — returns NULL instead of erroring |
| `DISTINCT` treats NULLs as equal (collapses to one row) | `unique` treats NaN as distinct (`NaN ~= NaN`) | Use `TreatMissingAsDistinct=false` in MATLAB to match SQL behavior, or filter NULLs before `DISTINCT` |
| `EXTRACT(DOW FROM date)` → 0=Sunday | `weekday(dt)` → 1=Sunday (default) | Document which convention; remap after close if needed |
| String comparison is case-sensitive | `matches` is case-sensitive; use `IgnoreCase=true` for insensitive | Use `LOWER(col)` in SQL for case-insensitive matching |

----

Copyright 2026 The MathWorks, Inc.

----
