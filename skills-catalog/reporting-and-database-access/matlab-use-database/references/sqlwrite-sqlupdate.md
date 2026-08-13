# sqlwrite & sqlupdate — Insert and Update Data

## Insert Data with `sqlwrite`

```matlab
data = table(["Wrench"; "Hammer"], [50; 30], [4.99; 12.50], ...
    VariableNames=["Product", "Quantity", "Price"]);

sqlwrite(conn, "inventoryTable", data);
```

### `sqlwrite` Parameters

| Parameter | Description |
|-----------|-------------|
| `conn` | Database connection object |
| `tablename` | Target table name (string) |
| `data` | MATLAB table to insert |
| `Catalog` | Database catalog name |
| `Schema` | Database schema name |
| `ColumnType` | Cell array of SQL column types for new tables |

### Bulk Insert (Chunked)

`sqlwrite` has no `BatchSize` parameter. For large data, chunk manually:

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
rf = rowfilter("Product");
data = table(5.99, VariableNames="Price");
sqlupdate(conn, "inventoryTable", data, rf.Product == "Wrench");
```

### Multi-Row Update (cell array of filters)

```matlab
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
| `filter` | `RowFilter` object (positional 4th arg) or cell array of `RowFilter` objects |
| `Catalog` | Database catalog name |
| `Schema` | Database schema name |

## Complete Example: Read, Transform, Write Back

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));

sourceData = sqlread(conn, "salesData");
summary = groupsummary(sourceData, "Region", "mean", "Revenue");
sqlwrite(conn, "salesSummary", summary);

close(conn);
```

## Gotchas

- `sqlwrite` creates the table if it doesn't exist. When appending, column names and types must match.
- `sqlupdate` requires R2023a+. For older releases, use `execute` with raw SQL UPDATE.
- **`sqlupdate` filter is positional 4th arg** — NOT a name-value pair. `sqlupdate(conn, tbl, data, filter)`.
- A single `RowFilter` with a 1-row data table broadcasts to all matching rows. For multi-row updates with different values per row, pass a cell array of filters.
- `sqlwrite` has no `BatchSize` parameter — loop over chunks manually.
- **NEVER** call `sqlwrite` row-by-row in a loop — batch rows into a single table.

----

Copyright 2026 The MathWorks, Inc.

----
