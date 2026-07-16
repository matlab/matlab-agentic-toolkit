---
name: matlab-write-database
description: "Writes data from MATLAB to relational databases and performs database operations. Use when writing data with sqlwrite, updating rows with sqlupdate, executing SQL with execute, running stored procedures, managing transactions with commit/rollback, creating tables, or using SQL prepared statements."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Database Export Architect

Use when writing data to relational databases, executing SQL statements, managing transactions, running stored procedures, or using SQL prepared statements. Covers all Database Toolbox operations that modify the database.

## When to Use This Skill

- Writing/inserting MATLAB data into a database table
- Updating existing rows in a database table
- Deleting data from a database
- Executing arbitrary SQL statements (DDL, DML)
- Running stored procedures or custom database functions
- Managing transactions (commit/rollback)
- Using SQL prepared statements for parameterized queries
- Creating or altering database table structures
- User mentions keywords: write, export, insert, sqlwrite, sqlupdate, update, delete, execute, stored procedure, runstoredprocedure, transaction, commit, rollback, DDL, CREATE TABLE, ALTER, prepared statement, bulk insert

## When NOT to Use

- Reading/importing data from a database — use `sqlread`/`fetch` with `RowFilter` and `databaseImportOptions`
- Object-oriented writes with class mapping — use ORM (`ormwrite`/`ormupdate` with `Mappable` classes)
- MongoDB, Cassandra, or Neo4j writes — these have their own document/graph-specific write interfaces
- Large data that doesn't fit in memory — use `DatabaseDatastore` + chunked processing for reads, or chunked `sqlwrite` loops for writes

## Critical Rules

### Credential Security
- **NEVER** hardcode passwords or credentials in generated code.
- **ALWAYS** use `setSecret` / `getSecret` (R2024a+) for credential storage.

### Database Connection
- **ALWAYS** establish and verify a connection before any export operation. Check `isopen(conn)` after connecting.
- **ALWAYS** close connections with `close(conn)` when done.

### Transaction Safety
- **ALWAYS** set `AutoCommit` to `off` when using `commit` / `rollback` for transaction control.
- **ALWAYS** wrap multi-statement operations in a transaction when atomicity is required.
- **ALWAYS** use `rollback` in error-handling blocks to undo partial changes on failure.

### Destructive Operations
- **ALWAYS** ask the user for explicit confirmation before executing any SQL that could irreversibly destroy or alter data. This includes: `DROP`, `TRUNCATE`, `DELETE`, and `ALTER` statements that remove columns or modify constraints.
- **NEVER** execute a destructive SQL statement via `execute()` without first presenting the exact SQL to the user and receiving explicit approval.
- The confirmation prompt must include the exact SQL statement or a clear description of what will be affected (e.g., "This will drop table `employees`. All data will be permanently lost. Proceed?").


## Decision Framework

| Goal | Function | When to Use |
|------|----------|-------------|
| Write MATLAB table to DB table | `sqlwrite` | Bulk insert of tabular data; creates table if needed |
| Modify existing rows | `sqlupdate` | Update specific rows matching a filter (R2023a+) |
| Run DDL or raw SQL | `execute` | CREATE TABLE, DROP, ALTER, simple CALL statements |
| Repeated parameterized inserts | `databasePreparedStatement` | High-frequency inserts with varying values |
| Stored procedure with typed outputs | `runstoredprocedure` | Need typed output arguments from stored procedure (JDBC/ODBC only) |
| Simple stored procedure call | `execute` with CALL | No typed output args needed; result sets returned |

> **`execute` vs `runstoredprocedure`:** Use `runstoredprocedure` when you need typed output arguments. Use `execute` with CALL for simple invocation or when you only need result sets.

## Function Reference

| Function | Purpose | Since |
|----------|---------|-------|
| `sqlwrite` | Insert MATLAB table into database table | R2018a |
| `sqlupdate` | Update rows in database table matching a filter | R2023a |
| `update` | Replace data in database table (legacy) | R2006a |
| `execute` | Execute any SQL statement (DDL, DML, stored procs) | R2018b |
| `runstoredprocedure` | Call stored procedure with input/output arguments (JDBC/ODBC only) | R2006b |
| `commit` | Make database changes permanent | R2006a |
| `rollback` | Undo database changes | R2006a |
| `databasePreparedStatement` | Create SQL prepared statement (JDBC only) | R2019b |
| `bindParamValues` | Bind values to prepared statement parameters | R2019b |

### Edge Cases

- **NULL values:** MATLAB `missing`, `NaN`, or empty `""` map to SQL NULL in `sqlwrite`
- **Type mismatches:** Ensure MATLAB column types match DB column types (e.g., `int32` not `double` for INTEGER columns)
- **Auto-increment PKs:** Omit the auto-increment column from the MATLAB table before calling `sqlwrite`

## Core Concepts

See knowledge cards for detailed usage and examples:
- **Insert and update data**: `reference/cards/sqlwrite-sqlupdate.md`
- **Execute SQL and stored procedures**: `reference/cards/execute-storedproc.md`
- **Transaction management**: `reference/cards/transactions.md`
- **Prepared statements (JDBC only)**: `reference/cards/prepared-statements.md`

## Complete Examples

See knowledge cards for complete examples:
- **Insert computed results**: `reference/cards/sqlwrite-sqlupdate.md`
- **Atomic multi-table update with transaction**: `reference/cards/transactions.md`
- **Parameterized insert with prepared statement**: `reference/cards/prepared-statements.md`

### Common Mistakes

```matlab
% INCORRECT — inserting rows one at a time in a loop (very slow)
for i = 1:height(data)
    sqlwrite(conn, "orders", data(i,:));
end

% CORRECT — batch insert the entire table at once
sqlwrite(conn, "orders", data);

% INCORRECT — no transaction control for multi-table writes
sqlwrite(conn, "orders", orderData);
sqlwrite(conn, "order_items", itemData);  % if this fails, orders are orphaned

% CORRECT — use transaction control for atomic multi-table writes
conn.AutoCommit = 'off';
try
    sqlwrite(conn, "orders", orderData);
    sqlwrite(conn, "order_items", itemData);
    commit(conn);
catch ME
    rollback(conn);
    conn.AutoCommit = 'on'; %#ok<NASGU> restore before rethrowing
    rethrow(ME);
end
conn.AutoCommit = 'on';

% INCORRECT — including auto-increment column in sqlwrite
data = table(1, "Widget", 9.99, VariableNames=["ID", "Name", "Price"]);
sqlwrite(conn, "products", data);  % Error if ID is auto-increment

% CORRECT — omit auto-increment column
data = table("Widget", 9.99, VariableNames=["Name", "Price"]);
sqlwrite(conn, "products", data);

% INCORRECT — single filter with multi-row data table
rf = rowfilter("Category");
filter = rf.Category == "Widgets";  % matches 2 rows
data = table([8.99; 12.99], VariableNames="Price");  % 2 rows
sqlupdate(conn, "products", data, filter);  % Error: filters must match table height

% CORRECT — cell array of filters for multi-row update
rf = rowfilter("ProductID");
filters = {rf.ProductID == 1; rf.ProductID == 2};
data = table([8.99; 12.99], VariableNames="Price");
sqlupdate(conn, "products", data, filters);
```

## Best Practices

- **ALWAYS** use `sqlwrite` for inserting MATLAB tables — it handles type mapping automatically.
- **ALWAYS** prefer `sqlupdate` (R2023a+) over raw SQL UPDATE — it uses `rowfilter` for type-safe filtering.
- **ALWAYS** close connections with `close(conn)` when done.
- Prefer transactions (`commit`/`rollback`) for multi-statement operations requiring atomicity.
- For very large inserts, chunk the MATLAB table manually in a loop to avoid memory issues.
- Use prepared statements for repeated parameterized operations — they improve performance and prevent SQL injection.
- Prepared statements are **JDBC only** — not available for ODBC or native connections.
- `runstoredprocedure` is **JDBC/ODBC only** (`database()` connections) — not available for native connections (sqlite, postgresql, mysql, duckdb). Use `execute` with a CALL statement instead.
- **ALWAYS** confirm destructive intent with the user before running `DROP`, `TRUNCATE`, `DELETE`, or column-dropping `ALTER` — present the SQL and wait for explicit approval, even if the user's request implied the operation.

## Common Patterns

### Pattern 1: Insert-Verify

```matlab
sqlwrite(conn, "myTable", data);
result = sqlread(conn, "myTable");
disp("Rows after insert: " + height(result));
```

### Pattern 2: Transaction-Protected Update

```matlab
conn.AutoCommit = 'off';
try
    execute(conn, sqlStatement);
    commit(conn);
catch e
    rollback(conn);
    conn.AutoCommit = 'on'; %#ok<NASGU> restore before rethrowing
    rethrow(e);
end
conn.AutoCommit = 'on';
```

### Pattern 3: DDL-then-Insert

```matlab
execute(conn, "CREATE TABLE IF NOT EXISTS results (ID INT, Value DOUBLE)");
sqlwrite(conn, "results", data);
```

## Checklist

Before finalizing, verify:
- [ ] Database connection established and verified (`isopen(conn)`)
- [ ] No hardcoded credentials — uses `getSecret` or placeholders
- [ ] `sqlwrite` used for table inserts (not raw SQL INSERT for MATLAB data)
- [ ] Transactions used for multi-statement atomic operations
- [ ] `AutoCommit` restored to `'on'` after transaction blocks
- [ ] Prepared statements closed with `close(pstmt)`
- [ ] Connection closed with `close(conn)` at the end
- [ ] Destructive SQL (`DROP`, `TRUNCATE`, `DELETE`, `ALTER`) confirmed with user before execution

## Troubleshooting

**Issue**: `sqlwrite` fails with "table already exists"
- **Solution**: `sqlwrite` creates the table if it doesn't exist but errors if the table exists with a different schema. Use `sqlwrite` to append to an existing table — column names and types must match.

**Issue**: `sqlupdate` not recognized
- **Solution**: `sqlupdate` requires R2023a or later. For older releases, use `update` or execute a raw SQL UPDATE statement with `execute`.

**Issue**: `sqlupdate` errors with "Number of filters must match the height of the table"
- **Solution**: For multi-row updates, pass a **cell array of RowFilter objects** (one filter per data row). A single `RowFilter` only works with a 1-row data table (broadcasts to all matching rows). Do not pass a single filter that matches N rows with an N-row data table — this errors.

**Issue**: Transaction changes not visible after `commit`
- **Solution**: Verify `AutoCommit` was set to `'off'` before the transaction. If `AutoCommit` is `'on'`, each statement auto-commits immediately.

**Issue**: Prepared statement errors with "parameter index out of range"
- **Solution**: Verify the parameter indices in `bindParamValues` match the number of `?` placeholders in the SQL statement. Indices are 1-based.

**Issue**: Bulk insert runs out of memory
- **Solution**: `sqlwrite` has no `BatchSize` parameter. Chunk the MATLAB table manually in a loop — split `data` into slices of 5,000–50,000 rows and call `sqlwrite` on each slice.

**Issue**: `runstoredprocedure` fails with "wrong number of arguments"
- **Solution**: Verify the input argument count matches the stored procedure definition. For JDBC connections, output types must use `java.sql.Types` constants.


----

Copyright 2026 The MathWorks, Inc.

----
