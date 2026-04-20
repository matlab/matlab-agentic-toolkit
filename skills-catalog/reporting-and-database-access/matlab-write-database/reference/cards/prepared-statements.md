# SQL Prepared Statements — databasePreparedStatement & bindParamValues

**JDBC connections only.** Not available for ODBC or native connections.

## Creating and Using Prepared Statements

```matlab
% Create prepared statement
query = "INSERT INTO products (Name, Price) VALUES (?, ?)";
pstmt = databasePreparedStatement(conn, query);

% Bind values and execute in a loop
products = ["Widget", "Gadget", "Gizmo"];
prices = [9.99, 19.99, 29.99];

for i = 1:numel(products)
    pstmt = bindParamValues(pstmt, [1 2], {products(i), prices(i)});
    execute(conn, pstmt);
end

close(pstmt);
```

## Prepared Statements for SELECT Queries

```matlab
query = "SELECT * FROM products WHERE productDescription = ?";
pstmt = databasePreparedStatement(conn, query);

values = ["Train Set", "Engine Kit", "Slinky"];
results = cell(numel(values), 1);
for i = 1:numel(values)
    pstmt = bindParamValues(pstmt, 1, values(i));
    results{i} = fetch(conn, pstmt);
end
results = vertcat(results{:});

close(pstmt);
```

## Parameters

### `databasePreparedStatement`

| Parameter | Description |
|-----------|-------------|
| `conn` | JDBC database connection object |
| `sqlquery` | SQL string with `?` placeholders |

### `bindParamValues`

| Parameter | Description |
|-----------|-------------|
| `pstmt` | Prepared statement object |
| `indices` | 1-based parameter indices (scalar or vector) |
| `values` | Cell array of values to bind |

## Complete Example: Parameterized Batch Insert

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));

query = "INSERT INTO sensorReadings (SensorID, Timestamp, Value) VALUES (?, ?, ?)";
pstmt = databasePreparedStatement(conn, query);

for i = 1:100
    pstmt = bindParamValues(pstmt, [1 2 3], {i, datetime("now"), rand()});
    execute(conn, pstmt);
end

close(pstmt);
close(conn);
```

## Gotchas

- **JDBC only** — prepared statements are not available for ODBC or native (mysql, postgresql, sqlite) connections.
- **ALWAYS** close prepared statements with `close(pstmt)` when done.
- Parameter indices are **1-based** and must match the number of `?` placeholders.
- `bindParamValues` returns a new pstmt — you must reassign: `pstmt = bindParamValues(pstmt, ...)`.
- For non-JDBC connections, use `sqlwrite` for inserts or `execute` with string-formatted SQL.

----

Copyright 2026 The MathWorks, Inc.

----
