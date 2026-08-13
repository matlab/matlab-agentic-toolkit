# sqlread & fetch — Reading Data

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
| Need column selection or deduplication | Either + `databaseImportOptions` |
| Complex SQL (CTEs, window functions, GROUP BY) | `fetch` with explicit SQL |

## `databaseImportOptions` — Column Selection & Type Control

```matlab
opts = databaseImportOptions(conn, "orders");
opts.SelectedVariableNames = ["OrderKey", "OrderStatus", "TotalPrice"];
opts.ExcludeDuplicates = true;
opts.RowFilter = opts.RowFilter.OrderPriority == "URGENT";
T = sqlread(conn, "orders", opts);
```

### Overriding Variable Types

```matlab
opts = databaseImportOptions(conn, "employees");
opts = setoptions(opts, "EmployeeID", Type="int32");
opts = setoptions(opts, "HireDate", Type="datetime");
T = sqlread(conn, "employees", opts);
```

## Supported RowFilter Operators

| Operator | Example |
|----------|---------|
| `<`, `<=`, `>`, `>=` | `rf.Price > 100` |
| `==`, `~=` | `rf.Status == "Active"` |
| `&` (AND) | `rf.Price > 10 & rf.Price < 100` |
| `\|` (OR) | `rf.Status == "A" \| rf.Status == "B"` |
| `~` (NOT) | `~(rf.Status == "Inactive")` |

Combine constraints with `&`, `|`, or `~`. The `~` operator works on individual constraints or combined expressions.

## Joins

```matlab
% Inner join
T = sqlinnerjoin(conn, "orders", "customers", Keys="CustomerID");

% Outer join
T = sqlouterjoin(conn, "orders", "customers", Keys="CustomerID");
```

Join functions do NOT accept `databaseImportOptions`. Select columns after joining.

## Gotchas

- `rowfilter` takes **column names**, not table names: `rowfilter(["Col1", "Col2"])`
- Access columns via property syntax: `rf.ColumnName == value`
- Do NOT mix `opts` and separate `RowFilter` NV arg in the same call — set `RowFilter` on `opts` instead
- `opts` is a positional 3rd argument, NOT a name-value pair
- `databaseImportOptions` executes a metadata query — SQL syntax errors fail at this step
- When layering `RowFilter` on `fetch`, the filter adds conditions on top of the SQL WHERE — don't duplicate

----

Copyright 2026 The MathWorks, Inc.

----
