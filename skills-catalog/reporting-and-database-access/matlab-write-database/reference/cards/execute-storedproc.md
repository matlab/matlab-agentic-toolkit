# execute & runstoredprocedure — SQL Execution

## Execute Arbitrary SQL with `execute`

Use for DDL, DML, DELETE, or any SQL the database supports:

```matlab
% Create a new table
execute(conn, "CREATE TABLE employees (ID INT PRIMARY KEY, Name VARCHAR(50), Salary DECIMAL(10,2))");

% Add a column
execute(conn, "ALTER TABLE employees ADD Department VARCHAR(50)");

% Delete rows
execute(conn, "DELETE FROM employees WHERE Salary < 30000");

% Drop a table
execute(conn, "DROP TABLE IF EXISTS tempResults");
```

### `execute` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `sqlstatement` | SQL string to execute |
| `pstmt` | (Alternative) Prepared statement object |

`execute` does not return data. For SELECT queries that return results, use `fetch`.

## Run Stored Procedures with `runstoredprocedure`

**JDBC/ODBC connections only** (`database()` connections). Not available for native connections (sqlite, postgresql, mysql, duckdb) — use `execute` with a CALL statement instead.

```matlab
% No input, no output
runstoredprocedure(conn, "updateInventory");

% With input and output arguments
inputArgs = {42, "Active"};
outputTypes = {java.sql.Types.VARCHAR, java.sql.Types.INTEGER};
results = runstoredprocedure(conn, "getEmployeeInfo", inputArgs, outputTypes);
```

### `runstoredprocedure` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `procedureName` | Name of the stored procedure |
| `inputArgs` | Cell array of input argument values |
| `outputTypes` | Cell array of `java.sql.Types` constants for output args |

## Gotchas

- `execute` does not return results. If you need query results, use `fetch`.
- `runstoredprocedure` is **JDBC/ODBC only** — not available on native connections. Use `execute("CALL myProc(...)")` for native connections.
- For JDBC connections, `runstoredprocedure` output types must use `java.sql.Types` constants (e.g., `java.sql.Types.VARCHAR`, `java.sql.Types.INTEGER`).
- Input argument count must match the stored procedure definition exactly.
- For stored procedures that return result sets, use `fetch` with a CALL statement: `fetch(conn, "CALL myProc(42)")`.

----

Copyright 2026 The MathWorks, Inc.

----
