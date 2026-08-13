# execute, Stored Procedures & Prepared Statements

## `execute` — Run SQL Statements

Use for DDL, DML, or any non-SELECT SQL that does not return a result set.

```matlab
% Create a table
execute(conn, "CREATE TABLE metrics (ID int, Value double, Timestamp timestamp)");

% Insert with SQL
execute(conn, "INSERT INTO metrics VALUES (1, 3.14, CURRENT_TIMESTAMP)");

% Update with arithmetic (not possible with sqlupdate alone)
execute(conn, "UPDATE inventory SET Quantity = Quantity - 10 WHERE ProductID = 42");

% Delete rows (confirm with user first!)
execute(conn, "DELETE FROM tempData WHERE CreatedDate < '2024-01-01'");
```

### `execute` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `sqlquery` | SQL statement string |

`execute` returns no output. Use `fetch` if you need a result set.

## Stored Procedures (JDBC only)

`runstoredprocedure` requires a JDBC connection — it is not supported on ODBC, native PostgreSQL, MySQL, SQLite, or DuckDB connections.

```matlab
% No input, no output
results = runstoredprocedure(conn, "refreshViews");

% With input parameters
results = runstoredprocedure(conn, "getOrdersByCustomer", 42);

% With input and output
[results, outputParams] = runstoredprocedure(conn, "calculateTotal", ...
    {42, "2024-01-01"}, {"totalAmount"});
```

### `runstoredprocedure` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `procedureName` | Name of the stored procedure |
| `inputArgs` | Cell array of input parameter values (optional) |
| `outputNames` | Cell array of output parameter names (optional) |

## Prepared Statements (JDBC only)

Use for parameterized queries to prevent SQL injection and improve performance on repeated queries. `databasePreparedStatement` requires a JDBC connection — it is not supported on native PostgreSQL, MySQL, or SQLite connections.

```matlab
% Create prepared statement
pstmt = databasePreparedStatement(conn, ...
    "SELECT * FROM orders WHERE CustomerID = ? AND Status = ?");

% Bind parameters and execute
pstmt = bindParamValues(pstmt, 1, 42);
pstmt = bindParamValues(pstmt, 2, "Active");
results = fetch(conn, pstmt);

% Reuse with different values
pstmt = bindParamValues(pstmt, 1, 99);
pstmt = bindParamValues(pstmt, 2, "Pending");
results2 = fetch(conn, pstmt);

% Close when done
close(pstmt);
```

### When to Use Prepared Statements

| Scenario | Use Prepared Statement |
|----------|----------------------|
| Same query with different parameter values | Yes |
| User-provided values in WHERE clauses | Yes (prevents SQL injection) |
| Single ad-hoc query | No (use `fetch` directly) |
| DDL statements | No (use `execute`) |

## Gotchas

- `execute` does NOT return data — use `fetch` for SELECT queries
- Always confirm destructive SQL (DELETE, DROP, TRUNCATE) with the user before executing
- `runstoredprocedure` only works on JDBC connections — not ODBC, native PostgreSQL, MySQL, SQLite, or DuckDB
- `runstoredprocedure` output depends on what the stored procedure returns — check database documentation
- Close prepared statements with `close(pstmt)` when finished to release database resources
- Parameter indices in `bindParamValues` are 1-based (matching MATLAB convention)
- `databasePreparedStatement` only works on JDBC connections — not native PostgreSQL, MySQL, or SQLite

----

Copyright 2026 The MathWorks, Inc.

----
