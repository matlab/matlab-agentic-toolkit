# File Analytics with DuckDB

Query CSV, Parquet, and JSON files directly with SQL — no import step needed. DuckDB processes files on disk, so data larger than MATLAB memory can be filtered, aggregated, and joined before results enter the workspace.

## DuckDB SQL Functions for File Access

| SQL Function | File Type | Example |
|-------------|-----------|---------|
| `read_csv('path')` | CSV | `fetch(conn, "SELECT * FROM read_csv('data.csv')")` |
| `read_parquet('path')` | Parquet | `fetch(conn, "SELECT * FROM read_parquet('data.parquet')")` |
| `read_json('path')` | JSON | `fetch(conn, "SELECT * FROM read_json('events.json')")` |
| `read_parquet('dir/*.parquet')` | Multiple Parquet | Glob patterns for multiple files |
| `read_csv('dir/*.csv')` | Multiple CSV | Glob patterns for multiple files |

**Rules:**
- **ALWAYS** use `fetch` (not `sqlread`) for file queries — file queries require SQL syntax.
- **ALWAYS** use single quotes for file paths inside SQL: `read_csv('file.csv')`.
- File paths are relative to the MATLAB current directory (`pwd`). Use absolute paths if needed.

## Example: Query a CSV File

```matlab
conn = duckdb();

orders = fetch(conn, "SELECT customer_id, SUM(total) as revenue " + ...
    "FROM read_csv('sales_2024.csv') " + ...
    "GROUP BY customer_id " + ...
    "HAVING SUM(total) > 10000 " + ...
    "ORDER BY revenue DESC");

close(conn);
```

## Example: Query a Parquet File

```matlab
conn = duckdb();

sensors = fetch(conn, "SELECT sensor_id, AVG(temperature) as avg_temp " + ...
    "FROM read_parquet('iot_readings.parquet') " + ...
    "WHERE timestamp >= '2024-01-01' " + ...
    "GROUP BY sensor_id");

close(conn);
```

## Example: Query Multiple Files with Glob Patterns

```matlab
conn = duckdb();

% All Parquet files in a directory
allSales = fetch(conn, "SELECT * FROM read_parquet('data/sales_*.parquet') " + ...
    "WHERE region = 'North America'");

% All CSV files matching a pattern
logs = fetch(conn, "SELECT type, COUNT(*) as cnt " + ...
    "FROM read_csv('logs/app_*.csv') " + ...
    "GROUP BY type ORDER BY cnt DESC");

close(conn);
```

## Example: Out-of-Memory Data Preprocessing

When data is too large for MATLAB memory, use DuckDB to preprocess on disk and bring only the results into MATLAB.

```matlab
conn = duckdb();

% A 50GB Parquet file — cannot fit in memory
% DuckDB preprocesses on disk: filter + aggregate + sort
dailySummary = fetch(conn, ...
    "SELECT date, region, " + ...
    "       SUM(revenue) as total_revenue, " + ...
    "       COUNT(*) as num_transactions, " + ...
    "       AVG(unit_price) as avg_price " + ...
    "FROM read_parquet('transactions_2024.parquet') " + ...
    "WHERE status = 'completed' " + ...
    "GROUP BY date, region " + ...
    "ORDER BY date");

% Result fits in memory — use MATLAB for advanced analysis
dailySummary.date = datetime(dailySummary.date);
figure;
stackedplot(dailySummary, ["total_revenue", "num_transactions", "avg_price"]);
title("Daily Sales Summary");

close(conn);
```

## Example: Join Two Large Files

```matlab
conn = duckdb();

% Join a large orders file with a customers file
result = fetch(conn, ...
    "SELECT c.name, c.region, SUM(o.total) as lifetime_value " + ...
    "FROM read_parquet('orders.parquet') o " + ...
    "JOIN read_csv('customers.csv') c ON o.customer_id = c.id " + ...
    "GROUP BY c.name, c.region " + ...
    "ORDER BY lifetime_value DESC " + ...
    "LIMIT 100");

close(conn);
```

----

Copyright 2026 The MathWorks, Inc.

----

