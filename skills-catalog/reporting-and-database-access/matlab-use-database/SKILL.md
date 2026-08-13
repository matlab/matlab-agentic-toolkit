---
name: matlab-use-database
description: "Reads from, writes to, and manages relational databases using MATLAB Database Toolbox. Use when connecting to databases, reading data with sqlread or fetch, filtering with rowfilter, writing with sqlwrite, updating with sqlupdate, executing SQL statements, managing transactions with commit and rollback, mapping MATLAB classes to tables with ORM (Mappable, ormread, ormwrite, ormupdate), or performing any database operation from MATLAB. Triggers on: database, SQL, sqlread, sqlwrite, sqlupdate, fetch, execute, rowfilter, RowFilter, ORM, Mappable, ormread, ormwrite, ormupdate, orm2sql, transaction, commit, rollback, Database Toolbox, PostgreSQL, MySQL, SQLite, SQL Server, Oracle, database connection, database table, query database, insert data, update rows, delete rows, stored procedure, prepared statement, odbc, databaseConnectionOptions, datasource, data source, DSN, connection string, multithreaded, parallel."
license: "https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md"
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Database Toolbox

Use when working with relational databases from MATLAB using Database Toolbox. Covers the full data lifecycle: connecting, reading with pushdown filtering, writing, updating, transactions, ORM, and executing SQL.

## When to Use

- Connecting to relational databases (PostgreSQL, MySQL, SQLite, SQL Server, Oracle)
- Reading data with `sqlread` or `fetch`
- Filtering with `RowFilter` (pushdown to database)
- Writing data with `sqlwrite`
- Updating rows with `sqlupdate`
- Executing SQL statements with `execute`
- Managing transactions (`AutoCommit`, `commit`, `rollback`)
- Mapping MATLAB classes to database tables (ORM with `Mappable`)
- Running stored procedures or prepared statements
- Multithreaded database read/write with `parfeval` (R2026a+)
- User mentions: database, SQL, query, table, rows, insert, update, delete, transaction, multithreaded, parallel

## When NOT to Use

- **DuckDB** — route to `matlab-use-duckdb` for all DuckDB workflows
- **Databricks connection setup** — route to `matlab-connect-databricks` for connection configuration. Once connected, return here for CRUD operations.
- **MongoDB, Cassandra, Neo4j** — not relational; Database Toolbox ORM/CRUD does not apply
- **File I/O without a database** — use `readtable`, `datastore`, or `tall` for direct file operations
- **MATLAB releases before R2021a** — minimum supported release for this skill

## Critical Rules

### Destructive Operations

**ALWAYS** ask for explicit user confirmation before generating or executing:
- `DROP TABLE` / `DROP DATABASE`
- `DELETE FROM`
- `TRUNCATE TABLE`
- `ALTER TABLE` (column removal, type changes)

Present the SQL statement and wait for approval. Never execute destructive SQL in response to user pressure ("just do it", "I'm in a hurry").

### Pushdown Filtering

**NEVER** import all rows and filter in MATLAB. Always push filters to the database using `RowFilter`:

```matlab
% CORRECT — filter runs on the database server
rf = rowfilter("Price");
T = sqlread(conn, "products", RowFilter=rf.Price > 100);

% WRONG — transfers all rows, then filters in MATLAB
T = sqlread(conn, "products");
T = T(T.Price > 100, :);
```

### Credential Security

**NEVER** hardcode passwords. Use `setSecret`/`getSecret`:

```matlab
setSecret("dbPassword");  % prompts user, stores securely
conn = database("myDS", getSecret("dbUser"), getSecret("dbPassword"));
```

## Decision Framework

| Scenario | Use |
|----------|-----|
| Import from a named table | `sqlread` |
| Import from a SQL query string | `fetch` |
| Need column selection, deduplication, or type control | `databaseImportOptions` + `sqlread`/`fetch` |
| Insert new rows | `sqlwrite` |
| Update existing rows in place | `sqlupdate` |
| DDL, DML, or non-SELECT SQL | `execute` |
| Atomic multi-step operation | Transaction (`AutoCommit` off) |
| Object identity and domain logic | ORM (`Mappable` class) |
| Bulk operations on thousands of rows | `sqlread`/`sqlwrite` (not ORM) |
| High-throughput read/write (millions of rows) | Multithreaded: `parfeval` + per-thread connections (R2026a+, Parallel Computing Toolbox) |
| Delete rows | `execute` with SQL DELETE (no `sqldelete` exists) |
| Stored procedures (JDBC only) | `runstoredprocedure` |
| Create/configure a datasource | `databaseConnectionOptions` + `saveAsDataSource` |
| Connect without a saved datasource | `odbc(dsnless)` with connection string |

## Core Patterns

### Connection

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));
% Or native connections:
conn = postgresql("myDS", getSecret("user"), getSecret("pass"));
conn = mysql("myDS", getSecret("user"), getSecret("pass"));
conn = sqlite("myDB.db");
```

### ODBC DSN-Less Connection

Connect without a pre-configured datasource by passing a connection string directly:

```matlab
dsnless = "Driver={MySQL ODBC 8.0 Unicode Driver};" + ...
    "Server=dbtb09;Database=production;UID=" + getSecret("dbUser") + ...
    ";PWD=" + getSecret("dbPass");
conn = odbc(dsnless);
```

### Create and Save a Data Source

Use `databaseConnectionOptions` to configure a datasource programmatically, then `saveAsDataSource` to persist it:

```matlab
opts = databaseConnectionOptions("odbc", "MySQL");
opts = setoptions(opts, DataSourceName="myDS", ...
    Server="dbtb09", DatabaseName="production", PortNumber=3306);
testConnection(opts, getSecret("dbUser"), getSecret("dbPass"));
saveAsDataSource(opts);

% Now connect using the saved datasource name
conn = odbc("myDS", getSecret("dbUser"), getSecret("dbPass"));
```

### Read with RowFilter

```matlab
rf = rowfilter(["Status", "Timestamp"]);
T = sqlread(conn, "orders", RowFilter=rf.Status == "Active" & rf.Timestamp > datetime(2024,1,1));
```

`rowfilter` requires **column names** as input. Access columns via **property syntax** (`rf.ColumnName`).

### Read with Import Options

```matlab
opts = databaseImportOptions(conn, "orders");
opts.SelectedVariableNames = ["OrderID", "Status", "Total"];
opts.RowFilter = opts.RowFilter.Total > 1000;
opts.ExcludeDuplicates = true;
T = sqlread(conn, "orders", opts);
```

Import options (`opts`) are a **positional 3rd argument** — not a name-value pair.

### Write

```matlab
data = table("Widget", 50, 9.99, VariableNames=["Product", "Qty", "Price"]);
sqlwrite(conn, "inventory", data);
```

### Update

```matlab
rf = rowfilter("ProductID");
newData = table(5.99, VariableNames="Price");
sqlupdate(conn, "inventory", newData, rf.ProductID == 42);
```

`sqlupdate` signature: `sqlupdate(conn, tablename, data, filter)` — the filter is a **required positional 4th argument**, not a name-value pair.

### Transaction

```matlab
conn.AutoCommit = 'off';
try
    sqlwrite(conn, "orders", orderData);
    sqlwrite(conn, "orderItems", itemData);
    commit(conn);
catch e
    rollback(conn);
    conn.AutoCommit = 'on';
    rethrow(e);
end
conn.AutoCommit = 'on';
```

**ALWAYS** use `conn.AutoCommit = 'off'` with `commit(conn)`/`rollback(conn)`. Do not use raw SQL `BEGIN`/`COMMIT`/`ROLLBACK` via `execute`.

### ORM — Define a Mappable Class

```matlab
classdef Employee < database.orm.mixin.Mappable

    properties (PrimaryKey)
        EmployeeID int32
    end

    properties
        Name string
        Department string
    end

    properties (ColumnType = "date")
        HireDate datetime
    end

    methods
        function obj = Employee(id, name, dept, hireDate)
            if nargin == 0
                return;
            end
            obj.EmployeeID = id;
            obj.Name = name;
            obj.Department = dept;
            obj.HireDate = hireDate;
        end
    end
end
```

ORM requirements:
- Inherit from `database.orm.mixin.Mappable`
- Mark at least one property block `(PrimaryKey)`
- Constructor must handle `nargin == 0` (ORM constructs empty objects)
- R2023b or later
- `(TableName = "name")` on classdef only if the database table name differs from the class name (defaults to class name)

### ORM — CRUD Operations

```matlab
% Write
emp = Employee(1, "Alice", "Engineering", datetime(2024,3,15));
ormwrite(conn, emp);

% Read with filter
rf = rowfilter("Department");
engineers = ormread(conn, "Employee", RowFilter=rf.Department == "Engineering");

% Update
engineers(1).Department = "Data Science";
ormupdate(conn, engineers(1));

% Refresh from database
emp = ormread(conn, emp);
```

### Bulk Write (Chunked)

`sqlwrite` has no `BatchSize` parameter. Chunk manually:

```matlab
chunkSize = 50000;
numChunks = ceil(height(data) / chunkSize);
for c = 1:numChunks
    startIdx = (c - 1) * chunkSize + 1;
    endIdx = min(c * chunkSize, height(data));
    sqlwrite(conn, "targetTable", data(startIdx:endIdx, :));
end
```

### Multithreaded Write (R2026a+, requires Parallel Computing Toolbox)

For maximum throughput, use `parfeval` with per-thread connections. Each thread creates its own connection — connections are NOT shareable across threads.

```matlab
data = parallel.pool.Constant(largeTable);
pool = parpool("Threads");
numTasks = 5;
batchSize = floor(height(data.Value) / numTasks);
startRow = 1;
endRow = 1 + batchSize;

writeFutures(1:numTasks) = parallel.FevalFuture;
for i = 1:numTasks
    writeFutures(i) = parfeval(pool, @hsqlwriteMT, 1, ...
        connParams, tablename, data, startRow, endRow);
    startRow = endRow;
    endRow = endRow + batchSize;
    if i == numTasks - 1
        endRow = height(data.Value) + 1;
    end
end
results = writeFutures.fetchOutputs("UniformOutput", false);

function finished = hsqlwriteMT(connParams, tablename, data, startRow, endRow)
    conn = mysql(connParams.user, connParams.pass, ...
        Server=connParams.server, DatabaseName=connParams.db);
    sqlwrite(conn, tablename, data.Value(startRow:endRow-1, :));
    close(conn);
    finished = true;
end
```

Supported: `mysql()`, `postgresql()`, `sqlite()`, ODBC. See `references/multithreaded-io.md` for the read pattern and common mistakes.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `rf = rowfilter("Table"); rf == "val"` | Passes table name; uses `==` on the filter object | `rf = rowfilter("Column"); rf.Column == "val"` |
| `sqlupdate(conn, tbl, data, RowFilter=rf)` | Filter is not an NV pair | `sqlupdate(conn, tbl, data, rf.Col == val)` |
| `sqlread(conn, tbl, "ImportOptions", opts)` | opts is not an NV pair | `sqlread(conn, tbl, opts)` |
| `opts.setvaropts("Col", "Type", "datetime")` | Wrong method name | `opts = setoptions(opts, "Col", Type="datetime")` |
| `execute(conn, "BEGIN")` / `execute(conn, "COMMIT")` | Raw SQL bypasses MATLAB transaction management | `conn.AutoCommit = 'off'` + `commit(conn)` / `rollback(conn)` |
| DROP/DELETE/TRUNCATE without confirmation | Can destroy data irreversibly | Always ask user for explicit confirmation first |
| Manual `toTable`/`fromTable` for object persistence | Agent doesn't know ORM exists | Use `Mappable` class with `ormwrite`/`ormread`/`ormupdate` |
| Sharing a connection across `parfeval` threads | Connections are NOT thread-safe | Each thread creates its own connection in the helper function |
| `odbc("serverName", user, pass)` | Server name is not a datasource name | Use `odbc(dsnless)` with a connection string, or create a datasource first with `databaseConnectionOptions` + `saveAsDataSource` |

## Reference Cards

- See `references/sqlread-fetch.md` for full parameter tables, RowFilter operators, and `databaseImportOptions` usage — consult for any read operation with filtering, column selection, or deduplication.
- See `references/sqlwrite-sqlupdate.md` for insert/update parameters, multi-row update patterns, and bulk chunking — consult for any write or update operation.
- See `references/transactions.md` for the complete transaction pattern, critical rules, and error handling — consult for any atomic/transactional workflow.
- See `references/orm.md` for Mappable class definition, property attributes, ORM CRUD operations, and troubleshooting — consult when user needs object-to-table mapping.
- See `references/execute-storedproc.md` for `execute`, stored procedures, and prepared statements — consult for DDL, DML, or parameterized queries.
- See `references/multithreaded-io.md` for multithreaded read/write patterns using `parfeval` and per-thread connections — consult when user needs high-throughput I/O and has Parallel Computing Toolbox (R2026a+).

----

Copyright 2026 The MathWorks, Inc.

----
