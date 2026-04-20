# sqlinnerjoin & sqlouterjoin — Pushdown Joins

Join exactly 2 database tables with the join executed on the database engine.

## Basic Usage

```matlab
% Inner join on shared column
T = sqlinnerjoin(conn, "orders", "lineitem", Keys="OrderKey");

% Outer join (left)
T = sqlouterjoin(conn, "orders", "customers", Keys="CustKey", Type="left");

% Full outer join
T = sqlouterjoin(conn, "orders", "customers", Keys="CustKey", Type="full");
```

## Accepted Parameters

| Parameter | Description |
|-----------|-------------|
| `Keys` | Shared column name(s) between both tables |
| `LeftKeys` / `RightKeys` | Column names when join keys differ between tables |
| `LeftCatalog` / `RightCatalog` | Database catalog for each table |
| `LeftSchema` / `RightSchema` | Database schema for each table |
| `MaxRows` | Maximum rows to return |
| `RowFilter` | `matlab.io.RowFilter` object for filtering joined rows |
| `VariableNamingRule` | `"modify"` or `"preserve"` |
| `Type` | (`sqlouterjoin` only) `'full'`, `'left'`, or `'right'` |

## Join + Row Filter

```matlab
% Filter applied to the joined result on the database
rf = rowfilter("inventoryDate");
rf = rf.inventoryDate > datetime("today") - calmonths(1);
T = sqlinnerjoin(conn, "inventoryTable", "productTable", ...
    Keys="productNumber", RowFilter=rf);
```

```matlab
% Multi-column filter on joined tables
rf = rowfilter(["OrderPriority", "ShipMode"]);
T = sqlinnerjoin(conn, "orders", "lineitem", ...
    Keys="OrderKey", ...
    RowFilter=rf.OrderPriority == "URGENT" & rf.ShipMode == "AIR");
```

## Join + Column Selection (Post-Join in MATLAB)

`sqlinnerjoin`/`sqlouterjoin` do **NOT** accept `databaseImportOptions`. Select columns after the join:

```matlab
T = sqlinnerjoin(conn, "orders", "lineitem", ...
    Keys="OrderKey", ...
    RowFilter=rf.OrderPriority == "URGENT" & rf.ShipMode == "AIR");

% Select columns in MATLAB
result = T(:, ["OrderKey", "OrderStatus"]);
```

## When to Fall Back to `fetch` with SQL

Use `fetch` with explicit SQL instead of pushdown joins when:

- **3+ tables** — pushdown joins only support exactly 2 tables
- **Aggregation** — GROUP BY, SUM, COUNT, etc. not supported
- **Column selection + deduplication** — can't combine `opts` with join functions
- **Complex conditions** — subqueries, HAVING, UNION

```matlab
% 3-table join with aggregation — must use fetch with SQL
sqlquery = "SELECT c.CustomerName, SUM(l.ExtendedPrice) AS TotalSpend " + ...
    "FROM customer c " + ...
    "INNER JOIN orders o ON c.CustKey = o.CustKey " + ...
    "INNER JOIN lineitem l ON o.OrderKey = l.OrderKey " + ...
    "WHERE o.OrderPriority = 'URGENT' " + ...
    "GROUP BY c.CustomerName";
T = fetch(conn, sqlquery);
```

## Critical Gotchas

1. **NEVER pass `databaseImportOptions` to `sqlinnerjoin`/`sqlouterjoin`** — they don't accept it. This is the #1 mistake.
2. **`Keys` must exist in BOTH tables** — use `sqlfind(conn, "tableName")` to verify column names.
3. **Outer joins include NULLs** — non-matching rows are filled with NULL. Use `RowFilter` post-join or switch to `sqlinnerjoin` if you only want matches.
4. **`LeftKeys`/`RightKeys`** — use these when the join columns have different names in each table.

----

Copyright 2026 The MathWorks, Inc.

----
