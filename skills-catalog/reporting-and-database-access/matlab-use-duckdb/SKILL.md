---
name: matlab-use-duckdb
description: "Use DuckDB from MATLAB via Database Toolbox (R2026a+) as a non-math operations engine on large tabular files (CSV/Parquet/JSON) and as a zero-config embedded database. Use when connecting to DuckDB, querying CSV, Parquet, and JSON files directly with SQL, reducing or profiling large data before MATLAB analysis, creating portable development databases, or installing DuckDB extensions. Triggers on: DuckDB, duckdb(), large CSV/Parquet/JSON, file too large for readtable, filter/aggregate at source, deduplicate, reduce before analysis, profile large file, persistent file import, analytical engine, SQL on CSV, SQL on Parquet, SQL on JSON, query CSV with SQL, query Parquet with SQL, run SQL on files, SQL queries on files, query files directly, SQL without database, in-process SQL."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# MATLAB Database Toolbox Interface to DuckDB

Use when working with DuckDB databases from MATLAB using Database Toolbox. DuckDB is an embedded analytical database engine that ships with Database Toolbox starting in R2026a. It enables SQL-based analytics on files, out-of-memory data preprocessing, and portable development databases — all without external database server configuration.

## When to Use This Skill

- Connecting to a DuckDB database (in-memory or file-based)
- Creating a new DuckDB database file for development workflows
- Querying CSV, Parquet, or JSON files directly with SQL
- Reducing or profiling large data before analysis
- Using DuckDB as a non-math operations engine (filter, aggregate, deduplicate, string cleanup, type cast, sort, sample)
- Installing and using DuckDB extensions
- Persisting file data into a `.duckdb` file for repeated queries
- User mentions keywords: DuckDB, duckdb(), analytical engine, embedded database, large CSV, large Parquet/JSON, file too large for readtable, filter/aggregate at source, deduplicate, reduce before analysis, profile large file, persistent file import, SQL on CSV, SQL on Parquet, SQL on JSON, query CSV with SQL, query Parquet with SQL, run SQL on files, SQL queries on files, query files directly, SQL without database, in-process SQL

## When NOT to Use

- **Single file that fits in memory** — use native MATLAB I/O (`readtable`/`readmatrix`)
- **Multi-file workflows** — use `datastore`/`tall` first; DuckDB glob is the fallback, not the default
- **Data exceeds memory and no SQL reduction will make it fit** — use `datastore`/`tall` for streaming
- **Math-heavy or numerically sensitive operations** (normalize, windowed stats, outlier detection) — hand off to MATLAB after reduction
- Connecting to MySQL, PostgreSQL, SQLite, or other external databases — use their native interfaces or JDBC/ODBC
- Object-relational mapping — use ORM (`ormread`/`ormwrite` with `Mappable` classes)
- MongoDB, Cassandra, or Neo4j — use their dedicated Database Toolbox interfaces

## On-Load Protocol

When this skill is loaded into a session where code already exists:

1. **Audit the data pipeline** — Identify how data enters the workflow:
   - Is data read via MATLAB I/O (`readtable`, `readmatrix`, `readcell`, `readtimetable`, `parquetread`, `xlsread`, `csvread`)?
   - Is data then written to DuckDB with `sqlwrite` before querying?
   - If yes: this is the **load-then-query anti-pattern**. DuckDB can likely read the source file directly via `read_csv`, `read_parquet`, or `read_xlsx` (excel extension).

2. **Evaluate each data source** against the decision framework:
   - Can DuckDB read this file type directly? (CSV, Parquet, JSON, Excel via extension)
   - Can filtering/aggregation be pushed into the SQL read?
   - Is the MATLAB I/O step a performance bottleneck?

3. **Recommend architectural changes** — Do not limit review to API correctness. Propose replacing `readtable`/`xlsread` + `sqlwrite` + query chains with `fetch(conn, "SELECT ... FROM read_csv/read_parquet/read_xlsx(...)")`.

The highest-value patterns in this skill are architectural: file-analytics pushdown eliminates entire pipeline stages and can yield 10x+ speedups.

## Pre-Flight Check

Before committing to the DuckDB path, estimate the file-size-to-available-RAM ratio (accounting for in-memory expansion of the file format) and route accordingly:

| Condition | Route | Rationale |
|-----------|-------|-----------|
| Single file, ratio < 0.5 | Native MATLAB I/O | Fits in memory; DuckDB adds unnecessary complexity |
| Multi-file OR per-file processing | `datastore`/`tall` (fallback: DuckDB glob) | Streaming is the primary multi-file pattern |
| Single file, ratio ≥ 0.5, SQL-expressible reduction | DuckDB: profile → operate → close | DuckDB is warranted |
| Single file, ratio ≥ 0.5, no SQL reduction applies | `datastore`/`tall` | No reduction = no DuckDB advantage |


## Operations Menu

### DO in DuckDB SQL

| Operation | Example SQL |
|-----------|-------------|
| Filter rows | `WHERE status = 'active'` |
| Aggregate | `GROUP BY region`, `SUM(revenue)`, `COUNT(*)`, `AVG(price)` |
| Deduplicate | `SELECT DISTINCT ...` or `ROW_NUMBER() OVER (PARTITION BY ...)` |
| String cleanup | `TRIM()`, `LOWER()`, `REPLACE()`, `REGEXP_REPLACE()` |
| Type casting | `TRY_CAST(col AS DATE)`, `CAST(col AS DOUBLE)` |
| Sort | `ORDER BY timestamp` |
| Sample | `USING SAMPLE 10000` or `TABLESAMPLE RESERVOIR(10%)` |
| Profile | `COUNT(*)`, `MIN/MAX`, `APPROX_COUNT_DISTINCT` |
| Limit | `LIMIT 50000` |

### DO NOT in DuckDB SQL

| Operation | Why Not |
|-----------|---------|
| Normalize / z-score | Requires population context |
| Windowed statistics (moving avg, cumsum) | Fragile semantics, NULL handling differs |
| Outlier detection | Statistical judgment call |
| Interpolation / resampling | Domain-specific logic |
| Signal processing | Not SQL's domain |
| Machine learning features | Model-dependent |

SQL operations do not always match MATLAB semantics (NULL handling, sort order, deduplication). See `reference/cards/reduce-large-data.md` for known mismatches.

## Reduction Workflow

If the pre-flight check routes to DuckDB, follow the profile → operate → close pattern in `reference/cards/reduce-large-data.md`.

DuckDB selects, reshapes, cleans, and reduces data. Once data fits in memory and the connection is closed, DuckDB's role is complete.

## What Is DuckDB and Why Does Database Toolbox Ship It?

DuckDB is an embedded, serverless analytical database engine. Unlike MySQL or PostgreSQL, it requires no server, no configuration, and runs in-process within MATLAB.

**Why it ships with Database Toolbox (R2026a+):**
- **Zero-config database** — `conn = duckdb()` gives you a full SQL engine instantly.
- **Analytical engine for files** — Query CSV, Parquet, and JSON files directly with SQL without loading them into memory.
- **Out-of-memory preprocessing** — Filter, aggregate, join, and sort datasets larger than memory, then bring only results into MATLAB.
- **Portable development databases** — `.duckdb` or `.db` files work on any machine with Database Toolbox. No database setup needed.
- **AI agent advantage** — An agent's SQL knowledge directly translates to powerful analytical queries.

DuckDB does **NOT replace** MATLAB's file I/O (`readtable`, etc.) or `datastore`/`tall`. It is a performant alternative when data exceeds memory *and* the task reduces to a SQL-expressible operation. When no reduction applies, `datastore`/`tall` remains the correct path.

## Critical Rules

### Pre-Flight Gate
- **ALWAYS** run the pre-flight size-to-RAM check BEFORE writing any DuckDB code. If ratio < 0.5, STOP and use native MATLAB I/O instead. Do not proceed with DuckDB patterns.

### Connection
- **ALWAYS** use `duckdb()` to connect — not `database()`, not JDBC, not ODBC.
- **ALWAYS** verify with `isopen(conn)` and close with `close(conn)`.

### API Surface
- All standard functions work: `sqlread`, `fetch`, `execute`, `sqlwrite`, `sqlfind`, `sqlinnerjoin`, `sqlouterjoin`, `commit`, `rollback`.
- DuckDB does **NOT** support `databasePreparedStatement`. Use `execute` or `sqlwrite` instead.
- Use `ExcludeDuplicates` via `databaseImportOptions` when reading from database tables (with `sqlread`). For direct file queries (`read_csv`/`read_parquet` via `fetch`), use `SELECT DISTINCT` in SQL.

### Named Tables vs. File Queries
- **ALWAYS** use `sqlread` with `RowFilter` for simple row filtering on named database tables — not `fetch` with WHERE. Create a `rowfilter` object and pass it via the `RowFilter` name-value argument.
- Use `fetch` with SQL for aggregation, joins, or complex queries on named tables.
- **ALWAYS** use `fetch` (not `sqlread`) for file queries — they require SQL syntax like `SELECT * FROM read_csv('file.csv')`.
- **ALWAYS** use single quotes for file paths inside SQL: `read_csv('data.csv')`.

## Connection Modes

| Goal | Connection | Why |
|------|-----------|-----|
| Analytical queries on files | `duckdb()` | No persistence needed; query files directly |
| Temporary workspace | `duckdb()` | Fast, discarded on close |
| Portable development database | `duckdb("mydata.duckdb")` | Creates a `.duckdb` or `.db` file; works on any machine |
| Open existing database | `duckdb("existing.db")` | Read/write access to pre-existing `.db` or `.duckdb` file |
| Read-only shared database | `duckdb("shared.duckdb", ReadOnly=true)` | Prevents accidental writes |

## Common Patterns

### Pattern 1: Analytical Engine on Files

```matlab
conn = duckdb();
result = fetch(conn, "SELECT region, SUM(revenue) as total " + ...
    "FROM read_parquet('sales.parquet') " + ...
    "GROUP BY region ORDER BY total DESC");
close(conn);
```

### Pattern 2: Out-of-Memory Preprocessing

```matlab
conn = duckdb();
summary = fetch(conn, "SELECT date, AVG(value) as avg_val " + ...
    "FROM read_csv('huge_dataset.csv') " + ...
    "WHERE status = 'valid' " + ...
    "GROUP BY date ORDER BY date");
close(conn);
% summary fits in memory — continue with MATLAB analysis
```

### Pattern 3: Read Named Table with RowFilter

```matlab
conn = duckdb("inventory.duckdb", ReadOnly=true);
rf = rowfilter("quantity");
data = sqlread(conn, "products", RowFilter=rf.quantity < 10);
close(conn);
```

### Pattern 4: Development Database

```matlab
conn = duckdb("dev.duckdb");
sqlwrite(conn, "experiments", experimentData);
rf = rowfilter("score");
results = sqlread(conn, "experiments", RowFilter=rf.score > 0.8);
close(conn);
```

### Pattern 5: Multi-File Query with Glob

Use when `datastore`/`tall` is unsuitable (e.g., SQL aggregation across files). For sequential per-file processing, prefer `datastore`.

```matlab
conn = duckdb();
data = fetch(conn, "SELECT * FROM read_parquet('data/year=2024/*.parquet') " + ...
    "WHERE category = 'A'");
close(conn);
```

### Pattern 6: Extensions

```matlab
conn = duckdb();
execute(conn, "INSTALL httpfs");
execute(conn, "LOAD httpfs");
data = fetch(conn, "SELECT * FROM read_parquet('https://example.com/data.parquet') LIMIT 1000");
close(conn);
```

For **Excel files**, use the `excel` extension with `read_xlsx` (NOT `st_read` from spatial):

```matlab
conn = duckdb();
execute(conn, "INSTALL excel");
execute(conn, "LOAD excel");
data = fetch(conn, "SELECT * FROM read_xlsx('report.xlsx')");
close(conn);
```

### Pattern 7: Persistent Import from File

```matlab
conn = duckdb("analytics.duckdb");
execute(conn, "CREATE TABLE events AS SELECT * FROM read_parquet('raw_events.parquet')");
% Future sessions: query by table name (no file re-read)
result = sqlread(conn, "events");
close(conn);
```

For detailed examples, see:
- **File analytics and out-of-memory preprocessing**: `reference/cards/file-analytics.md`
- **Development database workflows**: `reference/cards/development-database.md`
- **DuckDB extensions**: `reference/cards/extensions.md`

## Common Mistakes

```matlab
% WRONG — using database() or JDBC to connect to DuckDB
conn = database("", "", "", "org.duckdb.DuckDBDriver", "jdbc:duckdb:");
% CORRECT
conn = duckdb();

% WRONG — using sqlread for file queries (expects a table name)
data = sqlread(conn, "read_csv('data.csv')");
% CORRECT — use fetch with SQL
data = fetch(conn, "SELECT * FROM read_csv('data.csv')");

% WRONG — double quotes for file paths in SQL
data = fetch(conn, "SELECT * FROM read_csv(""data.csv"")");
% CORRECT — single quotes
data = fetch(conn, "SELECT * FROM read_csv('data.csv')");

% WRONG — loading huge file into MATLAB then filtering
data = readtable("huge.parquet"); filtered = data(data.val > 100, :);
% CORRECT — let DuckDB filter on disk
conn = duckdb();
filtered = fetch(conn, "SELECT * FROM read_parquet('huge.parquet') WHERE val > 100");
close(conn);

% WRONG — using databasePreparedStatement (not supported)
pstmt = databasePreparedStatement(conn, "INSERT INTO t VALUES(?, ?)");
% CORRECT — use sqlwrite
sqlwrite(conn, "t", data);

% WRONG — using st_read from spatial extension for Excel files
data = fetch(conn, "SELECT * FROM st_read('file.xlsx')");
% CORRECT — use excel extension with read_xlsx
execute(conn, "INSTALL excel");
execute(conn, "LOAD excel");
data = fetch(conn, "SELECT * FROM read_xlsx('file.xlsx')");

% WRONG — MATLAB table column named with SQL reserved keyword
data = table(1, "A", 'VariableNames', {'id','group'});
sqlwrite(conn, "t", data);  % Parser error: "group" is reserved
% CORRECT — rename column before writing
data = renamevars(data, 'group', 'experiment_group');
sqlwrite(conn, "t", data);
```

## Checklist

Before finalizing DuckDB code, verify:
- [ ] **Pipeline check**: No unnecessary MATLAB file I/O (e.g., `readtable`, `xlsread`, `parquetread`) + `sqlwrite` chains when DuckDB can read files directly
- [ ] Connected with `duckdb()` or `duckdb("file.duckdb")` / `duckdb("file.db")` — not `database()` or JDBC
- [ ] `isopen(conn)` checked after connection
- [ ] File queries use `fetch` with SQL (not `sqlread`)
- [ ] File paths in SQL use single quotes
- [ ] Out-of-memory data preprocessed in DuckDB before importing to MATLAB
- [ ] No `databasePreparedStatement` usage (not supported)
- [ ] `close(conn)` called when done

## Troubleshooting

**Issue**: `duckdb` function not found
- **Solution**: Requires R2026a+ with Database Toolbox. Check with `ver('database')`.

**Issue**: `sqlread` errors with file query
- **Solution**: Use `fetch(conn, "SELECT * FROM read_csv('file.csv')")` — `sqlread` expects table names only.

**Issue**: Permission denied on ReadOnly connection
- **Solution**: Reconnect without `ReadOnly`: `conn = duckdb("file.duckdb")`.

**Issue**: Out of memory when querying large file
- **Solution**: Add `WHERE`, `GROUP BY`, `LIMIT`, or aggregation in SQL to reduce result size before it enters MATLAB.

**Issue**: File path not found in `read_csv`/`read_parquet`
- **Solution**: Paths are relative to `pwd`. Use absolute paths or verify with `dir('file.csv')`.

**Issue**: Extension install fails
- **Solution**: Requires internet for first install (cached afterward). See https://duckdb.org/docs/current/core_extensions/overview.

**Issue**: `sqlwrite` fails with "syntax error at or near" a column name
- **Solution**: Column name is a SQL reserved keyword (`group`, `order`, `select`, `table`, etc.). Rename with `renamevars(data, 'group', 'experiment_group')` before writing.

**Issue**: Type mismatch on `sqlwrite`
- **Solution**: DuckDB supports rich types (ARRAY, LIST, STRUCT, MAP). Use `sqlfind(conn, "tableName")` to check column types.

----

Copyright 2026 The MathWorks, Inc.

----
