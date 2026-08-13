---
name: matlab-connect-databricks
description: >
  Connect MATLAB to Databricks via Spark (Databricks Connect) or JDBC (Database Toolbox).
  Use when setting up the MATLAB Interface for Databricks, configuring authentication
  (OauthU2M, OauthM2M, PAT), creating Spark sessions with getDatabricksSession(), reading
  Unity Catalog tables with server-side filtering, creating JDBC connections with
  databricks.JDBCConnection or StandaloneJDBCConnection, connecting to SQL Warehouses,
  selecting JDBC drivers (Simba/OSS), or writing data back to Databricks. Triggers on:
  Databricks Connect, Spark from MATLAB, getDatabricksSession, .databrickscfg,
  databricks.JDBCConnection, StandaloneJDBCConnection, SQLWarehouse, Databricks JDBC,
  Databricks cluster, large table server-side filtering.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Connect MATLAB to Databricks

Connect MATLAB to Databricks via Spark (Databricks Connect) or JDBC (Database Toolbox). This skill covers first-time setup, authentication, path selection, session/connection creation, and data operations through both paths.

## When to Use

- First-time setup of the MATLAB Interface for Databricks package
- Configuring `.databrickscfg` and authentication (OauthU2M, OauthM2M, PAT)
- Choosing between Spark and JDBC for a Databricks workflow
- Reading large tables via Spark with server-side filtering (`getDatabricksSession`)
- Creating JDBC connections to clusters or SQL Warehouses (`databricks.JDBCConnection`, `SQLWarehouse.connect()`)
- Standalone JDBC connectivity without the full package (`StandaloneJDBCConnection`)
- Writing data back to Databricks (via Spark DataFrames or JDBC `sqlwrite`)
- Selecting and configuring JDBC drivers (Simba vs. OSS)

## When NOT to Use

- Generic Database Toolbox operations after connection is established — use `matlab-use-database`
- ODBC connections (`databricks.ODBCConnection`)
- Databricks REST APIs (Clusters, Jobs, DBFS, Unity Catalog admin)
- MLflow from MATLAB
- Statement Execution REST API
- Deploying compiled MATLAB code to Databricks clusters (Job workflow)
- DuckDB — use `matlab-use-duckdb`
- Databricks notebooks, Databricks CLI, or `databricks-sdk` Python workflows
- PySpark without MATLAB context (pure Python Spark usage)

## Decision Framework: Spark vs. JDBC

| Scenario | Path | Why |
|----------|------|-----|
| Large table (millions of rows), need server-side filtering before pulling locally | **Spark** | DataFrame operations run on cluster; only filtered results transfer |
| SQL queries on small-to-medium datasets | **JDBC** | Direct SQL via Database Toolbox; simpler setup |
| Need DataFrame transformations (withColumn, select, filter chains) | **Spark** | Native DataFrame API; operations stay on cluster |
| Writing large data with performance optimization | **JDBC** | Simba driver's `UseNativeQuery` optimizes `sqlwrite` |
| No MATLAB Interface for Databricks package installed | **JDBC** | `StandaloneJDBCConnection` works with just Database Toolbox + driver jar |
| Need to use Database Explorer app | **JDBC** | `saveSource()` + `copyToken()` integration |
| Reading files from Unity Catalog Volumes (CSV, Parquet, JSON) | **Spark** | `spark.read.format().load()` with Volumes paths |
| Interactive exploration with `sqlread`/`fetch` | **JDBC** | Standard Database Toolbox workflow on `j.Connection` |

**Default:** Use Spark when the user mentions large data, server-side filtering, or DataFrames. Use JDBC when the user mentions SQL queries, Database Toolbox, or small/medium datasets. If unclear, ask the user about their data size and preferred workflow.

## Workflow

0. **Obtain the package** — Ask if the user has the MATLAB Interface for Databricks. If not, direct them to https://www.mathworks.com/solutions/partners/databricks.html (or use `StandaloneJDBCConnection` for JDBC-only without the package)
1. **Setup** — Run `setup` from the package's `Software/MATLAB` directory. It configures settings, `.databrickscfg`, and installs the Databricks Connect library via pip into a venv
2. **Startup** — Run `startup` to add package paths (required once per MATLAB session)
3. **Choose path** — Use the Decision Framework above to select Spark or JDBC
4. **Connect** — Create a session (`getDatabricksSession`) or connection (`databricks.JDBCConnection`)
5. **Verify** — Spark: `table(spark.range(1))`. JDBC: check `j.Connection.Message` is empty
6. **Operate** — Read, filter, write data using the appropriate path's API
7. **Close** — JDBC: `close(j)`. Spark: sessions are managed automatically

## Key Functions

### Spark Path

| Function | Purpose |
|----------|---------|
| `getDatabricksSession()` | Creates a Spark session (classic compute) |
| `getDatabricksSession(serverless=true)` | Creates a serverless session (no cluster, 10-min timeout) |
| `spark.read().table("catalog.schema.table")` | Reads a Unity Catalog table as a DataFrame |
| `spark.read.format(fmt).load(path)` | Reads files from Volumes (csv, parquet, json) |
| `DF.filter(expr)` | Server-side row filtering |
| `DF.select(cols)` | Server-side column selection |
| `DF.limit(n)` | Server-side row limiting |
| `DF.withColumn(name, col)` | Adds/transforms a column (requires Column objects) |
| `table(DF)` | Converts DataFrame to MATLAB table (pulls data locally) |
| `matlab.sparkutils.table2dataset(T, spark)` | Converts MATLAB table back to Spark DataFrame |
| `DF.write.mode(m).format(f).saveAsTable(name)` | Writes DataFrame to Unity Catalog table |
| `matlab.pyspark.sql.functions.col(name)` | Creates a Column reference |
| `matlab.pyspark.sql.functions.lit(value)` | Creates a literal Column constant |

### JDBC Path

| Function | Purpose |
|----------|---------|
| `databricks.JDBCConnection()` | Creates a JDBC connection (full package) |
| `StandaloneJDBCConnection()` | Creates a JDBC connection (no package dependencies) |
| `databricks.SQLWarehouse.connect()` | Connects to a SQL Warehouse by ID |
| `j.Connection` | The `database.jdbc.connection` object for Database Toolbox functions |
| `j.testConnection()` | Verifies connection is working |
| `j.saveSource()` | Saves connection as a Database Toolbox data source |
| `close(j)` | Closes connection and releases resources |

## Patterns

### First-Time Setup

Run `setup` from the package's `Software/MATLAB` directory. It is interactive — follow prompts for host URL, auth method, cluster ID, and Databricks Connect library installation.

The Databricks Connect library is downloaded via pip into `Software/MATLAB/Connect/<version>/venv/`. Requires Python 3.10-3.12. If the download fails repeatedly, ask the user to check with their IT team — do not retry with modified arguments.

```matlab
cd('/path/to/databricks-package/Software/MATLAB')
setup
startup
```

After setup, MATLAB's `pyenv` must point to the venv Python. If `getDatabricksSession` fails with "databricks.connect package is not installed":

```matlab
terminate(pyenv);
pyenv(Version="/path/to/databricks-package/Software/MATLAB/Connect/17.3/venv/bin/python");
```

**Warning:** If Python is already loaded InProcess, `terminate(pyenv)` fails. A full MATLAB restart is required. Do not attempt to switch `pyenv` mid-session after Python has been used.

For authentication configuration details (`.databrickscfg` format, profiles, environment variables, token caching), see [`references/authentication.md`](references/authentication.md) — consult when configuring auth methods or troubleshooting credential issues.

### Spark: Read and Filter a Table

Data stays on the cluster until explicitly collected. Filter server-side first, then collect.

```matlab
spark = getDatabricksSession(authMethod="PAT");
DF = spark.read().table("catalog.schema.sensor_readings");
filtered = DF.filter("temperature > 100 AND event_date > '2024-01-01'");
T = table(filtered);
```

### Spark: Serverless Session

No cluster needed. Starts instantly with 10-minute inactivity timeout. Requires Python 3.11-3.12 and Databricks Connect >= 15.4.

```matlab
spark = getDatabricksSession(serverless=true);
DF = spark.read().table("catalog.schema.events");
T = table(DF.limit(50));
```

### Spark: Add Computed Columns

`withColumn` requires Column objects — not raw scalars. Use `col()` for references and `lit()` for constants.

```matlab
import matlab.pyspark.sql.functions.col
import matlab.pyspark.sql.functions.lit

DF = spark.read().table("catalog.schema.measurements");
DF2 = DF.withColumn("temp_fahrenheit", col("temp_celsius") * lit(9/5) + lit(32));
```

### Spark: Write Back to Databricks

Always specify `.mode()` — without it, writes fail if the target exists.

```matlab
DF_new = matlab.sparkutils.table2dataset(T, spark);
DF_new.write.mode("overwrite").format("delta").saveAsTable("catalog.schema.output_table");
```

### Spark: Read Files from Volumes

```matlab
DF = spark.read.format("csv").option("header", "true").load("/Volumes/catalog/schema/volume/data.csv");
T = table(DF.limit(1000));
```

### JDBC: Cluster Connection

```matlab
j = databricks.JDBCConnection(catalog="mycatalog", schema="myschema");
data = sqlread(j.Connection, "mytable");
close(j);
```

### JDBC: SQL Warehouse Connection

`warehouse.connect()` returns a `database.jdbc.connection` directly — pass it to `sqlread`/`fetch` without `.Connection`.

```matlab
warehouse = databricks.SQLWarehouse;
warehouse.id = "abc123def456";
conn = warehouse.connect();
data = fetch(conn, "SELECT * FROM mycatalog.myschema.mytable LIMIT 10");
close(conn);
```

### JDBC: Standalone (No Package)

When the user does NOT have the MATLAB Interface for Databricks, use `StandaloneJDBCConnection`. Requires Database Toolbox and the Simba driver jar only. See [`references/standalone-jdbc.md`](references/standalone-jdbc.md) for setup and JSON template.

```matlab
j = StandaloneJDBCConnection(schema="myschema", catalog="mycatalog");
data = fetch(j.Connection, "SELECT * FROM mytable LIMIT 10");
close(j);
```

### JDBC: On-Databricks (Browser MATLAB)

The JDBC driver's OAuth flow cannot open a browser when MATLAB runs on a Databricks cluster. Use package-managed auth instead.

```matlab
if databricks.internal.isOnDatabricks()
    j = databricks.JDBCConnection(authMethod="OauthU2M", useDriverAuth=false);
else
    j = databricks.JDBCConnection();
end
data = fetch(j.Connection, "SELECT * FROM mycatalog.myschema.mytable LIMIT 10");
close(j);
```

### JDBC: Write-Optimized Connection

Simba driver write performance improves with native query mode (enabled by default).

```matlab
j = databricks.JDBCConnection(catalog="main", schema="telemetry");
sqlwrite(j.Connection, "measurements", data);
close(j);
```

### Connection Cleanup

Use `onCleanup` to guarantee closure even when operations fail.

```matlab
j = databricks.JDBCConnection(catalog="main", schema="analytics");
cleanup = onCleanup(@() close(j));
data = fetch(j.Connection, "SELECT * FROM large_table WHERE id > 1000");
```

For Spark stale sessions:

```matlab
clear spark
spark = getDatabricksSession(forceNewSession=true);
```

## Conventions

- Always filter DataFrames server-side before calling `table(DF)` — pulling millions of unfiltered rows wastes bandwidth and memory
- Use three-level names for Unity Catalog tables: `"catalog.schema.table"`
- Use `getDatabricksSession()` for Spark — never construct sessions manually or mimic PySpark builder patterns
- Use `databricks.JDBCConnection` or `StandaloneJDBCConnection` for JDBC — never manually construct JDBC URLs with `database()`
- Always pass `authMethod` explicitly — the default chain may trigger unexpected browser prompts
- Never hardcode tokens or secrets in MATLAB code — use `.databrickscfg` or environment variables
- Always call `close(j)` when done with JDBC connections
- Use `forceNewSession=true` for stale Spark sessions, not `clear all`
- For JDBC driver selection details, see [`references/driver-selection.md`](references/driver-selection.md) — consult when choosing between Simba and OSS drivers or configuring Java

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Manually building JDBC URLs with `database()` | Fragile, error-prone, exposes secrets, misses automatic URL construction, driver classpath management, unified auth chain, and write optimization | Use `databricks.JDBCConnection()` or `StandaloneJDBCConnection()` |
| Inventing PySpark builder: `databricks.spark.Session.builder().remote()` | Does not exist in MATLAB | Use `getDatabricksSession()` |
| Calling `table(DF)` on unfiltered large tables | Transfers entire dataset locally | Apply `.filter()` / `.select()` / `.limit()` first |
| Passing scalars to `withColumn`: `DF.withColumn("x", 2)` | Second argument must be a Column object | Use `DF.withColumn("x", lit(2))` |
| Writing without `.mode()`: `DF.write.save(path)` | Fails if target exists | Use `.mode("overwrite")` or `.mode("append")` |
| Using driver auth on-cluster | Browser OAuth fails in browser-based MATLAB | Use `useDriverAuth=false` |
| Hardcoding tokens in source code | Security risk; tokens expire | Store in `.databrickscfg` or environment variables |
| Calling `getDatabricksSession()` without `authMethod` | Default chain may trigger unwanted browser prompt | Pass `authMethod="PAT"` or other method explicitly |
| Mismatched Python version for Spark | Session creation fails | Match local Python to runtime (e.g., 3.12 for runtime 17.3) |
| Using OSS driver with Java 8 | OSS requires Java 11+ | Set Java 11+ via `jenv` first (requires MATLAB restart) |
| Passing DataFrame args to chained methods: `DF.unionAll(DF2)` | MATLAB Spark wrapper doesn't support DataFrame method arguments | Use `spark.sql()` with SQL UNION ALL instead |

----

Copyright 2026 The MathWorks, Inc.

----
