---
name: matlab-use-duckdb
description: "Generates MATLAB code for DuckDB database operations using Database Toolbox. Use when connecting to DuckDB (in-memory or file-based), querying CSV/Parquet/JSON files with SQL, creating development databases, preprocessing out-of-memory data, using duckdb(), installing DuckDB extensions, or using DuckDB as an analytical engine in MATLAB."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Database Toolbox Interface to DuckDB

Use when working with DuckDB databases from MATLAB using Database Toolbox. DuckDB is an embedded analytical database engine that ships with Database Toolbox starting in R2026a. It enables SQL-based analytics on files, out-of-memory data preprocessing, and portable development databases — all without external database server configuration.

## When to Use This Skill

- Connecting to a DuckDB database (in-memory or file-based)
- Creating a new DuckDB database file for development workflows
- Querying CSV, Parquet, or JSON files directly with SQL
- Preprocessing large data that doesn't fit in memory before importing into MATLAB
- Using DuckDB as an analytical engine for filtering, aggregation, joins, or sorting
- Installing and using DuckDB extensions
- User mentions keywords: DuckDB, duckdb, analytical engine, embedded database, parquet, CSV analytics, in-memory database, portable database, development database, out-of-memory preprocessing

## When NOT to Use

- Connecting to MySQL, PostgreSQL, SQLite, or other external databases — use their native interfaces or JDBC/ODBC
- Data fits in memory and only needs standard MATLAB operations — use `readtable`/`readmatrix` directly
- Object-relational mapping — use ORM (`ormread`/`ormwrite` with `Mappable` classes)
- MongoDB, Cassandra, or Neo4j — use their dedicated Database Toolbox interfaces

## What Is DuckDB and Why Does Database Toolbox Ship It?

DuckDB is an embedded, serverless analytical database engine. Unlike MySQL or PostgreSQL, it requires no server, no configuration, and runs in-process within MATLAB.

**Why it ships with Database Toolbox (R2026a+):**
- **Zero-config database** — `conn = duckdb()` gives you a full SQL engine instantly.
- **Analytical engine for files** — Query CSV, Parquet, and JSON files directly with SQL without loading them into memory.
- **Out-of-memory preprocessing** — Filter, aggregate, join, and sort datasets larger than memory, then bring only results into MATLAB.
- **Portable development databases** — `.duckdb` or `.db` files work on any machine with Database Toolbox. No database setup needed.
- **AI agent advantage** — An agent's SQL knowledge directly translates to powerful analytical queries.

DuckDB does **NOT replace** MATLAB's file I/O (`readtable`, etc.). It is a performant alternative when data exceeds memory or SQL operations are more natural than MATLAB table operations.

## Critical Rules

### Connection
- **ALWAYS** use `duckdb()` to connect — not `database()`, not JDBC, not ODBC.
- **ALWAYS** verify with `isopen(conn)` and close with `close(conn)`.

### API Surface
- All standard functions work: `sqlread`, `fetch`, `execute`, `sqlwrite`, `sqlfind`, `sqlinnerjoin`, `sqlouterjoin`, `commit`, `rollback`.
- DuckDB does **NOT** support `databasePreparedStatement`. Use `execute` or `sqlwrite` instead.
- Use `ExcludeDuplicates` via `databaseImportOptions` when reading from database tables (with `sqlread`). For direct file queries (`read_csv`/`read_parquet` via `fetch`), use `SELECT DISTINCT` in SQL.

### File Queries
- **ALWAYS** use `fetch` (not `sqlread`) for file queries — they require SQL syntax like `SELECT * FROM read_csv('file.csv')`.
- **ALWAYS** use single quotes for file paths inside SQL: `read_csv('data.csv')`.

## Decision Framework

> Which connection mode should I use?

| Goal | Connection | Why |
|------|-----------|-----|
| Analytical queries on files | `duckdb()` | No persistence needed; query files directly |
| Temporary workspace | `duckdb()` | Fast, discarded on close |
| Portable development database | `duckdb("mydata.duckdb")` | Creates a `.duckdb` or `.db` file; works on any machine |
| Open existing database | `duckdb("existing.db")` | Read/write access to pre-existing `.db` or `.duckdb` file |
| Read-only shared database | `duckdb("shared.duckdb", ReadOnly=true)` | Prevents accidental writes |

> When should I use DuckDB vs. MATLAB file I/O?

| Scenario | Recommendation |
|----------|---------------|
| Small data, simple operations | `readtable` / `readmatrix` |
| Data exceeds memory, needs filtering/aggregation | DuckDB (preprocess in SQL, analyze in MATLAB) |
| Query across multiple CSV/Parquet files | DuckDB with glob patterns |
| Portable development database | DuckDB file-based connection |
| MATLAB-specific analysis (signal processing, ML) | Preprocess in DuckDB, analyze in MATLAB |

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

### Pattern 3: Development Database

```matlab
conn = duckdb("dev.duckdb");
sqlwrite(conn, "experiments", experimentData);
rf = rowfilter("score");
results = sqlread(conn, "experiments", RowFilter=rf.score > 0.8);
close(conn);
```

### Pattern 4: Multi-File Query with Glob

```matlab
conn = duckdb();
data = fetch(conn, "SELECT * FROM read_parquet('data/year=2024/*.parquet') " + ...
    "WHERE category = 'A'");
close(conn);
```

### Pattern 5: Extensions

```matlab
conn = duckdb();
execute(conn, "INSTALL httpfs");
execute(conn, "LOAD httpfs");
data = fetch(conn, "SELECT * FROM read_parquet('https://example.com/data.parquet') LIMIT 1000");
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
```

## Checklist

Before finalizing DuckDB code, verify:
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

**Issue**: Type mismatch on `sqlwrite`
- **Solution**: DuckDB supports rich types (ARRAY, LIST, STRUCT, MAP). Use `sqlfind(conn, "tableName")` to check column types.

----

Copyright 2026 The MathWorks, Inc.

----

