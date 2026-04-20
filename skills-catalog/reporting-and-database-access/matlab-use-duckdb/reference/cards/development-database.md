# Development Database Workflows

Create portable DuckDB database files for development and testing. A `.duckdb` or `.db` file works on any machine with Database Toolbox — zero database server configuration needed. Both file extensions are supported interchangeably.

## Creating a New Development Database

```matlab
% Create a new database file (created on disk automatically)
conn = duckdb("dev_project.duckdb");

% Import MATLAB workspace data as database tables
sqlwrite(conn, "patients", readtable("patients.csv"));
sqlwrite(conn, "treatments", treatmentData);

% Verify tables were created
tables = sqlfind(conn, "%");
disp(tables);

close(conn);
% dev_project.duckdb is portable — share it with colleagues
```

## Querying Named Tables

For named database tables (created with `sqlwrite` or `CREATE TABLE`), use the standard Database Toolbox functions:

```matlab
conn = duckdb("dev_project.duckdb");

% sqlread for single table with pushdown filtering
rf = rowfilter("Age");
results = sqlread(conn, "patients", RowFilter=rf.Age > 40);

% sqlinnerjoin for two-table join
combined = sqlinnerjoin(conn, "patients", "treatments", Keys="PatientID");

% fetch for complex SQL
stats = fetch(conn, "SELECT Department, COUNT(*) as cnt, AVG(Age) as avg_age " + ...
    "FROM patients GROUP BY Department");

close(conn);
```

## Importing Data from Files into a Persistent Database

Combine file analytics with persistent storage — query files once, store results for repeated access:

```matlab
conn = duckdb("analytics.duckdb");

% Import from a large Parquet file into a named table
execute(conn, "CREATE TABLE sales AS " + ...
    "SELECT * FROM read_parquet('raw_sales_2024.parquet') " + ...
    "WHERE status = 'completed'");

% Now use standard Database Toolbox functions on the table
monthlySales = fetch(conn, ...
    "SELECT EXTRACT(MONTH FROM sale_date) as month, SUM(total) as revenue " + ...
    "FROM sales GROUP BY month ORDER BY month");

close(conn);
```

## Reopening an Existing Database

```matlab
% Later session — data persists
conn = duckdb("analytics.duckdb");
data = sqlread(conn, "sales");
close(conn);
```

## Read-Only Access to Shared Database

```matlab
% Open without risk of accidental writes
conn = duckdb("shared_data.duckdb", ReadOnly=true);
data = sqlread(conn, "reports");
close(conn);
```

## Transaction Control

```matlab
conn = duckdb("inventory.duckdb");
conn.AutoCommit = "off";

try
    sqlwrite(conn, "orders", newOrders);
    sqlwrite(conn, "order_items", newItems);
    commit(conn);
catch ME
    rollback(conn);
    rethrow(ME);
end

conn.AutoCommit = "on";
close(conn);
```

----

Copyright 2026 The MathWorks, Inc.

----

