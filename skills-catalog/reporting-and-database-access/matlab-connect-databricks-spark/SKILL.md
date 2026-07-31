---
name: matlab-connect-databricks-spark
description: >
  Set up the MATLAB Interface for Databricks and read data via Databricks Connect (Spark).
  Use when connecting MATLAB to Databricks for the first time, configuring authentication
  (OauthU2M, OauthM2M, PAT), creating Spark sessions with getDatabricksSession(), reading
  Unity Catalog tables, filtering DataFrames server-side, or converting results to MATLAB
  tables. Triggers on: Databricks Connect, Spark from MATLAB, getDatabricksSession,
  .databrickscfg, large table server-side filtering.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Interface for Databricks — Spark (Databricks Connect)

Read data from Databricks into MATLAB via Databricks Connect. This skill covers first-time setup, authentication, and using Spark DataFrames from desktop MATLAB.

## When to Use

- First-time setup of the MATLAB Interface for Databricks package
- Configuring `.databrickscfg` and authentication (OauthU2M, OauthM2M, PAT)
- Reading large tables via Spark with server-side filtering before pulling data locally
- Creating a Spark session from desktop MATLAB (`getDatabricksSession`)
- Converting Spark DataFrames to MATLAB tables or writing MATLAB tables back to Spark

## When NOT to Use

- SQL queries on small-to-medium datasets via JDBC/ODBC — use `/matlab-connect-databricks-jdbc`
- Deploying compiled MATLAB code to Databricks clusters (Job workflow)
- Databricks Files API operations
- REST API management (Clusters, Jobs, Unity Catalog admin)

## Workflow

0. **Obtain the package** — Ask the user if they already have the MATLAB Interface for Databricks downloaded locally. If not, direct them to download it from https://www.mathworks.com/solutions/partners/databricks.html
1. **Setup** — Run `setup` from the package directory to configure settings, `.databrickscfg`, and install the Databricks Connect library via pip
2. **Verify** — Create a Spark session and run `spark.range(1)` to confirm connectivity
3. **Read** — Use `spark.read().table()` to get a DataFrame handle (data stays on cluster)
4. **Filter** — Apply `.filter()`, `.withColumn()`, `.select()` server-side
5. **Collect** — Convert to MATLAB table with `T = table(DF)` only after reducing data

## Key Functions

| Function | Purpose |
|----------|---------|
| `setup` | Interactive first-time configuration: settings, `.databrickscfg`, and Databricks Connect library download |
| `startup` | Adds package paths to MATLAB (run once per session, required after setup) |
| `matlab.databricks.setup.configureDBC()` | Re-run Databricks Connect library download independently (supports `alternativeRepo` for internal Artifactory) |
| `getDatabricksSession()` | Creates a `databricks.PySparkSession` connected to Databricks (classic compute) |
| `getDatabricksSession(serverless=true)` | Creates a serverless session (no cluster needed, 10-min timeout) |
| `updateClusterId(id)` | Updates the cluster ID in `.databrickscfg` (pass `"serverless"` to switch to serverless mode) |
| `spark.range(n)` | Creates a DataFrame with n rows (useful for testing) |
| `spark.read().table("catalog.schema.table")` | Reads a Unity Catalog table as a DataFrame |
| `DF.filter(expr)` | Server-side row filtering |
| `DF.withColumn(name, col)` | Adds/transforms a column server-side (col must be a `matlab.pyspark.sql.column.Column`) |
| `DF.limit(n)` | Server-side row limiting (returns first n rows as a new DataFrame) |
| `matlab.pyspark.sql.functions.col(name)` | Creates a Column reference by name |
| `matlab.pyspark.sql.functions.lit(value)` | Creates a Column containing a literal constant |
| `DF.select(cols)` | Server-side column selection |
| `DF.show(n)` | Displays n rows (stays on cluster) |
| `DF.printSchema` | Prints DataFrame schema |
| `table(DF)` | Converts DataFrame to a MATLAB table (pulls data locally) |
| `spark.sql(query)` | Executes a SQL query and returns a DataFrame |
| `spark.table("catalog.schema.table")` | Shortcut for `spark.read().table()` |
| `matlab.sparkutils.table2dataset(T, spark)` | Converts a MATLAB table back to a Spark DataFrame |
| `DF.write.mode(m).format(f).save(path)` | Writes DataFrame to a file path |
| `DF.write.mode(m).format(f).saveAsTable(name)` | Writes DataFrame to a Unity Catalog table |

## Patterns

### First-Time Setup

Run `setup` from the package's `Software/MATLAB` directory. It is interactive — follow the prompts to configure the host URL, authentication method, cluster ID, and Databricks Connect library installation.

The Databricks Connect library is not shipped with the package — `setup` downloads it via pip (from PyPI or an internal Artifactory) into a Python virtual environment under `Software/MATLAB/Connect/<version>/venv/`. This requires Python 3.10–3.12 and pip to be available.

If the Databricks Connect library download fails repeatedly, do not retry with modified arguments — ask the user to check with their IT team whether the required version of `databricks-connect` is available in their organization's Python package repository.

```matlab
cd('/path/to/databricks-package/Software/MATLAB')
setup
```

After setup completes, MATLAB's `pyenv` must point to the venv Python — not the system Python. If `getDatabricksSession` fails with "databricks.connect package is not installed", switch `pyenv`:

```matlab
terminate(pyenv);
pyenv(Version="/path/to/databricks-package/Software/MATLAB/Connect/17.3/venv/bin/python");
```

**Warning:** If Python has already been loaded in-process (ExecutionMode is "InProcess"), `terminate(pyenv)` will fail. A full MATLAB restart is required to switch `pyenv` in this case. Do not attempt to switch `pyenv` mid-session after Python has been used — it will not work and may disconnect the MCP server. Instead, ask the user to restart MATLAB, then set `pyenv` to the venv path before calling any Python-dependent functions.

Then run `startup` to add the package paths to MATLAB. This must also be run at the beginning of each new MATLAB session:

```matlab
startup
```

Then verify connectivity:

```matlab
spark = getDatabricksSession();
T = table(spark.range(1));
disp(T)
```

If this returns a 1-row table with column `id = 0`, authentication and compute are working.

### Authentication Configuration

Authentication uses the `.databrickscfg` file — an INI-format configuration file located in the user's home directory (`~/.databrickscfg`). It stores the Databricks workspace URL, authentication credentials, and cluster ID. The file supports multiple named profiles so you can switch between workspaces or auth methods.

**OauthU2M** (recommended for interactive use) — requires only `host`. Note: OauthU2M opens a browser for login and requires pasting a redirect URL back into MATLAB. It does not work in non-interactive contexts (scripts, batch mode, MCP tools). Use OauthM2M or PAT for automation:

```ini
[DEFAULT]
host = https://<workspace-url>
cluster_id = <cluster-id>
```

**OauthM2M** (for service principals / automation) — requires `host`, `client_id`, `client_secret`:

```ini
[M2M]
host = https://<workspace-url>
client_id = <service-principal-client-id>
client_secret = <service-principal-secret>
cluster_id = <cluster-id>
```

**PAT** (simple but may be disabled by admins) — requires `host` and `token`:

```ini
[PAT]
host = https://<workspace-url>
token = <personal-access-token>
cluster_id = <cluster-id>
```

**Specifying the auth method:** When `authMethod` is not passed, `getDatabricksSession` uses a chain that tries methods in order until one succeeds — this may not pick what the user expects (e.g., it may trigger an OauthU2M browser prompt even if a PAT token is configured). Always ask the user which auth method they want and pass it explicitly:

```matlab
spark = getDatabricksSession(authMethod="PAT");
spark = getDatabricksSession(authMethod="OauthU2M");
spark = getDatabricksSession(authMethod="OauthM2M");
```

To use a named profile other than `[DEFAULT]`:

```matlab
spark = getDatabricksSession(profileName="M2M", authMethod="OauthM2M");
```

Environment variables override config file values:

| Variable | Overrides |
|----------|-----------|
| `DATABRICKS_HOST` | `host` |
| `DATABRICKS_TOKEN` | `token` |
| `DATABRICKS_CLUSTER_ID` | `cluster_id` |
| `DATABRICKS_CLIENT_ID` | `client_id` |
| `DATABRICKS_CLIENT_SECRET` | `client_secret` |

### Create a Spark Session (Classic Compute)

```matlab
spark = getDatabricksSession();
```

Uses the default profile's `cluster_id`. The cluster starts automatically if stopped (takes 3-5 minutes for a cold start).

To target a specific cluster:

```matlab
spark = getDatabricksSession(cluster="0812-091301-zntwkr4b");
```

### Create a Spark Session (Serverless Compute)

Serverless sessions don't require a `cluster_id` — they start instantly with a 10-minute inactivity timeout:

```matlab
spark = getDatabricksSession(serverless=true);
```

To make serverless the default for a profile, remove the `cluster_id` and set `serverless_compute_id`:

```matlab
updateClusterId("serverless");
```

Or configure `.databrickscfg` directly:

```ini
[DEFAULT]
host = https://<workspace-url>
serverless_compute_id = auto
```

Serverless requires Python 3.11–3.12 and Databricks Connect client >= 15.4.

### Read and Filter a Table

Data stays on the cluster until explicitly collected. Filter server-side first, then collect.

```matlab
spark = getDatabricksSession();

DF = spark.read().table("catalog.schema.sensor_readings");

filtered = DF.filter("temperature > 100 AND event_date > '2024-01-01'");

filtered.printSchema;
filtered.show(5);

T = table(filtered);
```

### Filter and Limit Rows

Use `.filter()` for conditional filtering and `.limit()` for taking the first N rows:

```matlab
spark = getDatabricksSession();
DF = spark.read().table("catalog.schema.large_table");

filtered = DF.filter("status = 'active' AND created_date > '2024-01-01'");
limited = filtered.limit(1000);
T = table(limited);
```

### Add Computed Columns with withColumn

`withColumn` requires a `matlab.pyspark.sql.column.Column` object — not a scalar or string. Use `col()` to reference existing columns and `lit()` for constants:

```matlab
import matlab.pyspark.sql.functions.col
import matlab.pyspark.sql.functions.lit

DF = spark.read().table("catalog.schema.measurements");

DF2 = DF.withColumn("temp_fahrenheit", col("temp_celsius") * lit(9/5) + lit(32));
DF3 = DF2.withColumn("source", lit("sensor_array"));
```

Do not pass raw MATLAB scalars or strings to `withColumn` — it will error. Always wrap values in `lit()`.

### Read Files from Unity Catalog Volumes

Use `spark.read.format().load()` for CSV, Parquet, or JSON files stored on Volumes:

```matlab
spark = getDatabricksSession();

% CSV with header
DF = spark.read.format("csv").option("header", "true").load("/Volumes/catalog/schema/volume/data.csv");

% Parquet
DF = spark.read.format("parquet").load("/Volumes/catalog/schema/volume/data.parquet");

% JSON
DF = spark.read.format("json").load("/Volumes/catalog/schema/volume/data.json");
```

After loading, use the same filter/select/collect workflow as with tables.

### Convert MATLAB Table Back to Spark DataFrame

```matlab
DF_new = matlab.sparkutils.table2dataset(T, spark);
```

Write to a Volumes path as Parquet:

```matlab
DF_new.write.mode("overwrite").format("parquet").save("/Volumes/catalog/schema/volume/output_data");
```

Write to a Unity Catalog table:

```matlab
DF_new.write.mode("overwrite").format("delta").saveAsTable("catalog.schema.output_table");
```

Always specify `.mode()` — without it, writes fail if the target already exists. Options: `"overwrite"`, `"append"`, `"ignore"`, `"error"` (default).

### Handle Stale Sessions

If a session becomes unresponsive after inactivity:

```matlab
clear spark
spark = getDatabricksSession(forceNewSession=true);
```

### Python Version Compatibility

The local Python version must match the Databricks runtime's Python version:

| Runtime | Python Version | Notes |
|---------|---------------|-------|
| 18.x | 3.12 | Supports serverless and classic |
| 17.3 | 3.12 | Supports serverless and classic |
| 16.4 LTS | 3.12 | Supports serverless (>= 16.4.1) and classic |
| 15.4 LTS | 3.11 | Supports serverless (>= 15.4.10) and classic |
| 14.3 LTS | 3.10 | Classic only |
| 13.3 LTS | 3.10 | Classic only |

Check with:

```matlab
pe = pyenv;
disp(pe.Version)
```

## Conventions

- Always filter DataFrames server-side before calling `table(DF)` — pulling millions of unfiltered rows wastes bandwidth and memory
- Use three-level names for Unity Catalog tables: `"catalog.schema.table"`
- Use `getDatabricksSession()` — never construct Spark sessions manually or mimic PySpark builder patterns
- Use `forceNewSession=true` when a session becomes stale, not `clear all`
- Never hardcode tokens or secrets in MATLAB code — use `.databrickscfg` or environment variables
- Only Databricks Connect v2 is supported (v1 is not supported)

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Manually building JDBC URLs with Simba driver params | Bypasses the package entirely; fragile and insecure | Use `getDatabricksSession()` for Spark or `databricks.JDBCConnection` for SQL |
| Inventing PySpark-like builder: `databricks.spark.Session.builder().remote()` | These classes do not exist in MATLAB | Use `getDatabricksSession()` which returns `databricks.PySparkSession` |
| Hardcoding tokens in source code | Security risk; tokens expire and rotate | Store credentials in `.databrickscfg` or environment variables |
| Calling `table(DF)` on unfiltered large tables | Transfers entire dataset to local MATLAB memory | Apply `.filter()` / `.select()` / `.limit()` first, then collect |
| Passing scalars to `withColumn`: `DF.withColumn("x", 2)` | Second argument must be a Column object | Use `DF.withColumn("x", lit(2))` or `DF.withColumn("x", col("y") * lit(2))` |
| Writing without `.mode()`: `DF.write.save(path)` | Fails if target exists (default mode is "error") | Use `.mode("overwrite")` or `.mode("append")` before `.save()` or `.saveAsTable()` |
| Using `databricks.SCIM.me` to verify auth | Deprecated API | Verify with `spark = getDatabricksSession(); table(spark.range(1))` |
| Calling `getDatabricksSession()` without `authMethod` when user has PAT configured | Default chain tries methods in order and may trigger OauthU2M browser prompt instead of using PAT | Ask the user which auth method they want and pass `authMethod="PAT"` explicitly |
| Passing a DataFrame as an argument to a chained method: `DF.unionAll(DF2)` | The MATLAB Spark wrapper's bracket method only supports dot-chaining, not methods that take DataFrame arguments | Use `spark.sql()` with a SQL UNION ALL query instead, or if the data is small enough, collect both DataFrames to MATLAB tables, manipulate locally, and push back with `table2dataset` |
| Mismatched Python version | Session creation fails with version error | Match local Python to runtime version (e.g., 3.12 for runtime 17.3) |
| PAT token missing scopes | 403 "does not have required scopes: clusters" | Regenerate the PAT with **All access** or at minimum the `clusters` scope enabled |
| `cluster_id` not set error | `.databrickscfg` has no `cluster_id` for the active profile | Run `updateClusterId("your-cluster-id")` or add `cluster_id` to the profile manually |

----

Copyright 2026 The MathWorks, Inc.

----
