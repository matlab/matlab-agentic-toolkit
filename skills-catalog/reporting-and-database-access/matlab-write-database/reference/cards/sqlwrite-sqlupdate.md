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

### Multi-Row Update (cell array of filters)

```matlab
% Update multiple rows with different values — one filter per row
rf = rowfilter("ProductID");
filters = {rf.ProductID == 1; rf.ProductID == 2};
data = table([5.99; 13.99], VariableNames="Price");
sqlupdate(conn, "inventoryTable", data, filters);
```

### `sqlupdate` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `tablename` | Target table name |
| `data` | MATLAB table with new values |
| `filter` | `RowFilter` object (single, broadcasts 1-row data) or cell array of `RowFilter` objects (one per data row) |
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
- **`sqlupdate` row count**: A single `RowFilter` works only with a 1-row data table (broadcasts to all matches). For multi-row updates, pass a **cell array of RowFilter objects** — one filter per data row. A single filter matching N rows with an N-row data table errors.
- `sqlwrite` has no `BatchSize` parameter. For very large data, loop over chunks of the MATLAB table manually.
- **NEVER** call `sqlwrite` row-by-row in a loop — batch rows into a single table.

----

Copyright 2026 The MathWorks, Inc.

----
