# sqlwrite & sqlupdate — Insert and Update Data

## Insert Data with `sqlwrite`

```matlab
% Create data to insert
data = table(["Wrench"; "Hammer"], [50; 30], [4.99; 12.50], ...
    VariableNames=["Product", "Quantity", "Price"]);

% Insert into database table (creates table if it doesn't exist)
sqlwrite(conn, "inventoryTable", data);
```

### `sqlwrite` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `tablename` | Target table name (string) |
| `data` | MATLAB table to insert |
| `Catalog` | Database catalog name (for databases that support catalogs, e.g., PostgreSQL, SQL Server) |
| `Schema` | Database schema name (use when the table is not in the default schema, e.g., `Schema="analytics"`) |
| `ColumnType` | Cell array of SQL column types for new tables |

### Bulk Insert

**Note:** `sqlwrite` has no `BatchSize` parameter. For large data, chunk manually in a loop:

```matlab
chunkSize = 50000;
numChunks = ceil(height(data) / chunkSize);
for c = 1:numChunks
    startIdx = (c - 1) * chunkSize + 1;
    endIdx = min(c * chunkSize, height(data));
    sqlwrite(conn, "largeTable", data(startIdx:endIdx, :));
    fprintf("Wrote chunk %d/%d\n", c, numChunks);
end
```

## Update Rows with `sqlupdate` (R2023a+)

```matlab
% Update the price of "Wrench" to 5.99
rf = rowfilter("Product");
rf = rf.Product == "Wrench";
data = table(5.99, VariableNames="Price");
sqlupdate(conn, "inventoryTable", data, rf);
```

### `sqlupdate` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `tablename` | Target table name |
| `data` | MATLAB table with new values |
| `filter` | `RowFilter` object or cell array of `RowFilter` objects |
| `Catalog` | Database catalog name (for databases that support catalogs) |
| `Schema` | Database schema name (use when the table is not in the default schema) |

## Complete Example: Insert Computed Results

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));

sourceData = sqlread(conn, "salesData");
summary = groupsummary(sourceData, "Region", "mean", "Revenue");
sqlwrite(conn, "salesSummary", summary);

close(conn);
```

## Gotchas

- `sqlwrite` creates the table if it doesn't exist. If appending to an existing table, column names and types must match.
- `sqlupdate` requires R2023a+. For older releases, use `update` (legacy) or `execute` with raw SQL UPDATE.
- **`sqlupdate` row count**: The `data` table must have exactly 1 row (broadcasts to all matches) or exactly as many rows as the filter matches. Mismatched counts produce unpredictable results. Verify match count first with `sqlread` + the same `RowFilter`.
- `sqlwrite` has no `BatchSize` parameter. For very large data, loop over chunks of the MATLAB table manually.
- **NEVER** call `sqlwrite` row-by-row in a loop — batch rows into a single table.

----

Copyright 2026 The MathWorks, Inc.

----
