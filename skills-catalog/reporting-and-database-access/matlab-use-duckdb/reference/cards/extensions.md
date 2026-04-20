# DuckDB Extensions

DuckDB supports extensions for additional functionality. Install and load them using `execute`. See https://duckdb.org/docs/current/core_extensions/overview for the full list.

## Installing and Loading Extensions

```matlab
conn = duckdb();

% Two-step process: install (downloads), then load (activates)
execute(conn, "INSTALL httpfs");
execute(conn, "LOAD httpfs");

close(conn);
```

## Common Extensions

| Extension | Purpose | Example Use Case |
|-----------|---------|-----------------|
| `httpfs` | Read files over HTTP/S3 | Query remote Parquet files |
| `spatial` | Geospatial functions | ST_Distance, ST_Contains queries |
| `json` | Advanced JSON processing | Nested JSON extraction |
| `excel` | Read Excel files | `read_xlsx('file.xlsx')` |
| `sqlite_scanner` | Attach SQLite databases | Cross-database queries |

## Example: Query Remote Parquet Files

```matlab
conn = duckdb();

execute(conn, "INSTALL httpfs");
execute(conn, "LOAD httpfs");

% Query a remote Parquet file over HTTPS
data = fetch(conn, "SELECT * FROM read_parquet('https://example.com/data.parquet') LIMIT 1000");

close(conn);
```

## Example: Attach a SQLite Database

```matlab
conn = duckdb();

execute(conn, "INSTALL sqlite_scanner");
execute(conn, "LOAD sqlite_scanner");

% Attach an existing SQLite file and query it through DuckDB
execute(conn, "ATTACH 'legacy.db' AS legacy (TYPE sqlite)");
data = fetch(conn, "SELECT * FROM legacy.main.customers WHERE active = true");

close(conn);
```

## Notes

- Extension installation requires internet access (first time only — cached afterward).
- Not all extensions are available on all platforms.
- Extensions persist in the DuckDB extension directory — subsequent `LOAD` calls don't re-download.

----

Copyright 2026 The MathWorks, Inc.

----

