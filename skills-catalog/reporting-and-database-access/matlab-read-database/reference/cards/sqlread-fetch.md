# sqlread & fetch — Importing Data

## `sqlread` — Import from a Database Table

```matlab
% Basic: import entire table
T = sqlread(conn, "myTable");

% With RowFilter (pushes WHERE to database)
rf = rowfilter(["ProductType", "Price"]);
T = sqlread(conn, "productTable", RowFilter=rf.ProductType == "Toys" & rf.Price > 150);

% With import options (column selection + deduplication + filter)
opts = databaseImportOptions(conn, "productTable");
opts.SelectedVariableNames = ["ProductType", "Price"];
opts.ExcludeDuplicates = true;
opts.RowFilter = opts.RowFilter.Price > 100;
T = sqlread(conn, "productTable", opts);

% Limit rows
T = sqlread(conn, "myTable", MaxRows=100);
```

### `sqlread` Accepted Parameters

| Parameter | Description |
|-----------|-------------|
| `opts` (positional, 3rd arg) | `SQLImportOptions` from `databaseImportOptions` |
| `RowFilter` | `matlab.io.RowFilter` object |
| `MaxRows` | Maximum rows to return |
| `Catalog` | Database catalog name |
| `Schema` | Database schema name |
| `VariableNamingRule` | `"modify"` (default) or `"preserve"` |

## `fetch` — Import from a SQL Query

```matlab
% Basic: execute SQL query
T = fetch(conn, "SELECT * FROM myTable WHERE id > 100");

% With RowFilter on top of SQL WHERE
sqlquery = "SELECT * FROM productTable WHERE Quantity > 50";
rf = rowfilter(["ProductType", "Price"]);
T = fetch(conn, sqlquery, RowFilter=rf.ProductType == "Toys" & rf.Price > 150);

% With import options
opts = databaseImportOptions(conn, sqlquery);
opts.SelectedVariableNames = ["ProductType", "Price"];
T = fetch(conn, sqlquery, opts);

% Limit rows
T = fetch(conn, "SELECT * FROM myTable", MaxRows=50);
```

### `fetch` Accepted Parameters

| Parameter | Description |
|-----------|-------------|
| `opts` (positional, 3rd arg) | `SQLImportOptions` from `databaseImportOptions` |
| `RowFilter` | `matlab.io.RowFilter` — adds conditions ON TOP of SQL WHERE |
| `MaxRows` | Maximum rows to return |
| `DataReturnFormat` | `"table"` (default), `"cellarray"`, `"numeric"`, `"structure"` |
| `MaxTextLength` | Max characters for text columns |
| `VariableNamingRule` | `"modify"` (default) or `"preserve"` |

## When to Use Which

| Situation | Use |
|-----------|-----|
| Import from a named table | `sqlread` |
| Import from a SQL query string | `fetch` |
| Need column selection or deduplication | Either + `databaseImportOptions` (see `cards/import-options.md`) |
| Complex SQL (CTEs, window functions, GROUP BY) | `fetch` with explicit SQL |

## Gotchas

- When layering `RowFilter` on `fetch`, the filter adds conditions **on top of** the SQL WHERE clause. Don't duplicate the same condition in both.
- Do NOT mix `opts` and separate `RowFilter` name-value arg in the same call. Set `RowFilter` on `opts` instead.
- `fetch` with a prepared statement: `fetch(conn, pstmt)` — see `matlab-database-export` for prepared statements.

----

Copyright 2026 The MathWorks, Inc.

----
