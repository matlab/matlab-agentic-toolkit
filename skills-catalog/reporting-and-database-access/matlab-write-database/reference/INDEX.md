# Knowledge Index — Export Architect

**Cards contain detailed usage, examples, and gotchas. Read the relevant card before writing code that uses the listed functions.**

## Function-Level Routing

| Function / Pattern | Card to read |
|--------------------|--------------|
| `sqlwrite(...)` | `cards/sqlwrite-sqlupdate.md` |
| `sqlupdate(...)` | `cards/sqlwrite-sqlupdate.md` |
| `execute(...)` | `cards/execute-storedproc.md` |
| `runstoredprocedure(...)` | `cards/execute-storedproc.md` |
| `commit(...)` / `rollback(...)` | `cards/transactions.md` |
| `AutoCommit` | `cards/transactions.md` |
| `databasePreparedStatement(...)` | `cards/prepared-statements.md` |
| `bindParamValues(...)` | `cards/prepared-statements.md` |

## Task-Level Routing

| Trigger / task | Card to read |
|----------------|--------------|
| Insert MATLAB data into database | `cards/sqlwrite-sqlupdate.md` |
| Update existing rows | `cards/sqlwrite-sqlupdate.md` |
| Bulk/large insert | `cards/sqlwrite-sqlupdate.md` |
| Execute DDL (CREATE, ALTER, DROP) | `cards/execute-storedproc.md` |
| Delete rows | `cards/execute-storedproc.md` |
| Run stored procedure | `cards/execute-storedproc.md` |
| Atomic multi-statement operation | `cards/transactions.md` |
| Parameterized/repeated queries | `cards/prepared-statements.md` |

## Card Summary

| Card | Purpose | ~Lines |
|------|---------|--------|
| `cards/sqlwrite-sqlupdate.md` | Insert and update data — `sqlwrite`, `sqlupdate`, bulk insert, examples | ~90 |
| `cards/execute-storedproc.md` | Execute SQL and stored procedures — DDL, DML, `runstoredprocedure` | ~70 |
| `cards/transactions.md` | Transaction management — `commit`, `rollback`, `AutoCommit`, atomic patterns | ~70 |
| `cards/prepared-statements.md` | Prepared statements — `databasePreparedStatement`, `bindParamValues`, JDBC only | ~80 |

----

Copyright 2026 The MathWorks, Inc.

----
