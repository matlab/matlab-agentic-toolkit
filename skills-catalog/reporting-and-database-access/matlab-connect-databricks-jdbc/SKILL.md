---
name: matlab-connect-databricks-jdbc
description: "Connects MATLAB to Databricks using JDBC drivers via Database Toolbox. Use when creating a JDBC connection to a Databricks cluster or SQL Warehouse, configuring Databricks authentication (PAT, OauthU2M, OauthM2M), selecting between Simba and OSS JDBC drivers, using databricks.JDBCConnection, StandaloneJDBCConnection, databricks.SQLWarehouse.connect(), or optimizing Databricks write performance."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Connect MATLAB to Databricks via JDBC

Use when establishing a JDBC connection from MATLAB to Databricks using Database Toolbox and the [MATLAB Interface for Databricks](https://www.mathworks.com/solutions/partners/databricks.html) package. This skill covers connection class selection, authentication configuration, driver setup, and connection optimization. Once connected, use standard Database Toolbox functions (`sqlread`, `fetch`, `sqlwrite`, `execute`) on the `j.Connection` object for data operations.

## Prerequisites

- [MATLAB Interface for Databricks](https://www.mathworks.com/solutions/partners/databricks.html) package installed and on the MATLAB path
- Database Toolbox installed
## When to Use

- Connecting MATLAB to a Databricks cluster via JDBC
- Connecting MATLAB to a Databricks SQL Warehouse via JDBC
- Configuring Databricks authentication (PAT, OauthU2M, OauthM2M)
- Setting up the Databricks JDBC driver (Simba or OSS)
- Creating a standalone JDBC connection without the full Databricks package
- Running MATLAB on a Databricks cluster and connecting back via JDBC
- Optimizing write performance for large data transfers to Databricks
- User mentions keywords: Databricks, JDBCConnection, SQL Warehouse, databricks.JDBCConnection, StandaloneJDBCConnection, Databricks JDBC, Databricks connect, Databricks cluster, Databricks authentication

## When NOT to Use

- Connecting via ODBC (use `databricks.ODBCConnection` directly)
- Using Databricks Connect (Python-based Spark API, not Database Toolbox)
- Using the Databricks REST APIs (Clusters, Jobs, DBFS, etc.)
- Using MLflow from MATLAB (separate module in the package)
- Executing SQL via the Statement Execution REST API (not JDBC)

## Critical Rules

### Connection
- **ALWAYS** prefer `databricks.JDBCConnection` or `StandaloneJDBCConnection` over manually constructing a JDBC URL with `database()`. Manual URL construction is not wrong, but the URL format is complex and error-prone, and may expose connection details in source code. The connection classes handle URL construction, driver classpath, and authentication automatically.
- **ALWAYS** use `StandaloneJDBCConnection` when the user does not have the MATLAB Interface for Databricks package installed. Never fall back to manual `database()` with JDBC URL construction.
- **ALWAYS** call `close(j)` or `close(j.Connection)` when the connection is no longer needed.
- **ALWAYS** verify a connection succeeded by checking that `j.Connection.Message` is empty. A non-empty message indicates a driver error.

### Authentication
- **ALWAYS** let the connection class handle authentication via the unified provider chain. The default method is OauthU2M. Do not hardcode tokens in source code.
- **NEVER** use the JDBC driver's built-in OauthU2M when running MATLAB on Databricks in a browser. The driver attempts to open a browser window, which fails. Use `useDriverAuth=false` instead.

### Drivers
- The **Simba driver** (non-OSS, v2.7.3 to <3.0.0) is the default and ships with the package. It works with MATLAB's default Java 8 environment.
- The **OSS driver** (v3.0.3+) requires Java 11 or greater. Set MATLAB's Java environment with `jenv` before using it. The OSS driver uses Arrow for faster large data transfers.
- `StandaloneJDBCConnection` supports the Simba driver only. Do not use `useDriverType="oss"` with standalone connections.

## Function Reference

| Function / Class | Purpose | When to Use |
|-----------------|---------|-------------|
| `databricks.JDBCConnection` | Creates a JDBC connection with full package support | Default choice when the MATLAB Interface for Databricks package is installed |
| `StandaloneJDBCConnection` | Creates a JDBC connection with zero package dependencies | When embedding Databricks connectivity in a standalone codebase |
| `databricks.SQLWarehouse.connect()` | Connects to a SQL Warehouse by ID; returns a `database.jdbc.connection` directly | When targeting a SQL Warehouse instead of a cluster |
| `j.Connection` | The underlying `database.jdbc.connection` object from `JDBCConnection` or `StandaloneJDBCConnection` | Pass this to `sqlread`, `fetch`, `sqlwrite`, `execute`, etc. Equivalent to `conn` created using `database()` in Database Toolbox |
| `databricks.internal.isOnDatabricks()` | Returns `true` if MATLAB is running on a Databricks cluster | Use to branch connection logic for on-cluster vs off-cluster scenarios |
| `j.testConnection()` | Verifies the connection is working | After creating a connection to confirm success |
| `j.saveSource()` | Saves connection as a Database Toolbox data source | When using Database Explorer app for interactive exploration |
| `j.copyToken()` | Copies the auth token to clipboard | When Database Explorer prompts for credentials |
| `close(j)` | Closes the connection and releases resources | When done with the connection |

## Decision Framework

### Which class should I use?

| Scenario | Class | Why |
|----------|-------|-----|
| Full package installed, targeting a cluster | `databricks.JDBCConnection` | Handles auth, URL, driver classpath automatically |
| Targeting a specific compute endpoint by HTTP path | `databricks.JDBCConnection(httpPath="/sql/1.0/warehouses/abc")` | Overrides the default cluster routing |
| Full package installed, targeting a SQL Warehouse | `databricks.SQLWarehouse.connect()` | Builds connection from warehouse metadata via REST API |
| No package installed or standalone integration | `StandaloneJDBCConnection` | Zero dependencies on the Databricks package |
| Already have a `databricks.Cluster` object | `databricks.JDBCConnection(cluster=myCluster)` | Routes connection to a specific cluster object |
| MATLAB running on a Databricks cluster | `databricks.JDBCConnection(authMethod="OauthU2M", useDriverAuth=false)` | Driver browser auth does not work in-browser MATLAB |

### Which JDBC driver should I use?

| Scenario | Driver | Notes |
|----------|--------|-------|
| Java 8 (MATLAB default) | Simba (default) | Ships with the package, no setup needed |
| Java 11+ available, both drivers present | OSS (auto-selected) | Uses Arrow for better large-transfer performance |
| Need explicit control | `useDriverType='oss'` or `'simba'` | Overrides auto-selection |

For driver installation and Java configuration details, see `references/driver-selection.md`.

### Which authentication method should I use?

| Scenario | Auth Method | Required Config |
|----------|-------------|-----------------|
| Individual interactive use (default) | OauthU2M | `host` in `.databrickscfg` |
| Automated services or CI/CD pipelines | OauthM2M | `host`, `client_id`, `client_secret` in `.databrickscfg` |
| Simple token-based access | PAT | `host`, `token` in `.databrickscfg` |
| Multiple workspaces in `.databrickscfg` | Any + `profileName="myprofile"` | Named profile in `.databrickscfg` via `profileName` argument |
| Running on Databricks cluster | OauthU2M + `useDriverAuth=false` | Package-managed auth (not driver-managed) |
| Opaque token from external source | Token passthrough | `passthroughAccessToken` argument |
| Azure Entra ID managed workspace | OauthU2M + `OauthService="EntraID"` | Sets scope resolution to Azure AD instead of Databricks-native |

For authentication configuration details including `.databrickscfg` format and environment variables, see `references/authentication.md`.

## Common Patterns

### Pattern 1: Cluster Connection (Default)

```matlab
% Connect to a Databricks cluster using default authentication
j = databricks.JDBCConnection();

% Use Database Toolbox functions on the connection
data = sqlread(j.Connection, "mycatalog.myschema.mytable");

% Close when done
close(j);
```

### Pattern 2: Cluster Connection with Catalog and Schema

```matlab
% Set default catalog and schema to simplify table references
j = databricks.JDBCConnection(catalog="mycatalog", schema="myschema");

% Now table names do not need full qualification
data = sqlread(j.Connection, "mytable");

close(j);
```

### Pattern 3: SQL Warehouse Connection

```matlab
% Create a warehouse object and set its ID
warehouse = databricks.SQLWarehouse;
warehouse.id = "abc123def456";

% Connect (defaults to JDBC mode)
conn = warehouse.connect();

% Query data
data = fetch(conn, "SELECT * FROM mycatalog.myschema.mytable LIMIT 10");

% Close when done
close(conn);
```

### Pattern 4: Write-Optimized Connection (Simba Driver)

Simba driver write performance improves significantly with native query mode. This is enabled by default when connections are created, but can be controlled explicitly.

```matlab
% Default behavior: UseNativeQuery=1, EnableNativeParameterizedQuery=0
j = databricks.JDBCConnection();
sqlwrite(j.Connection, "mycatalog.myschema.mytable", data);
close(j);

% To disable the optimization (not recommended for writes)
j = databricks.JDBCConnection(useNativeQuery=false, enableNativeParameterizedQuery=true);
```

SQL Warehouse variant:

```matlab
warehouse = databricks.SQLWarehouse;
warehouse.id = "abc123def456";
conn = warehouse.connect(useNativeQuery=true, enableNativeParameterizedQuery=false);
sqlwrite(conn, "mycatalog.myschema.mytable", data);
close(conn);
```

### Pattern 5: On-Databricks Connection

When running MATLAB directly on a Databricks cluster (browser-based), the JDBC driver's OAuth flow cannot open a browser. Use package-managed auth instead. Detect the environment with `databricks.internal.isOnDatabricks()`.

```matlab
% Detect if running on Databricks
if databricks.internal.isOnDatabricks()
    j = databricks.JDBCConnection(authMethod="OauthU2M", useDriverAuth=false);
else
    j = databricks.JDBCConnection();
end

data = fetch(j.Connection, "SELECT * FROM mycatalog.myschema.mytable LIMIT 10");
close(j);
```

### Pattern 6: Standalone Connection (No Package)

When the user does NOT have the MATLAB Interface for Databricks package installed, use `StandaloneJDBCConnection`. This class requires only Database Toolbox and the Simba JDBC driver jar -- no Databricks package dependencies.

Setup:
1. Place `StandaloneJDBCConnection.m` and `databricks_standalone_jdbc_settings.json` on the MATLAB path
2. Edit the JSON file with host, orgId, clusterId, and auth settings
3. Construct the connection:

```matlab
% Add standalone class folder to path (if not already)
addpath("path/to/standalone/folder");

% StandaloneJDBCConnection reads config from databricks_standalone_jdbc_settings.json
j = StandaloneJDBCConnection(schema="myschema", catalog="mycatalog");
data = fetch(j.Connection, "SELECT * FROM mytable LIMIT 10");
close(j);
```

The JSON settings file (`databricks_standalone_jdbc_settings.json`) must contain:
- `host`: Databricks workspace URL (e.g., `"https://adb-123.1.azuredatabricks.net"`)
- `orgId`: Workspace org ID
- `clusterId`: Cluster or SQL Warehouse ID
- `jarFilePath`: Path to the Simba JDBC driver jar

For the full JSON template and all fields, see `references/standalone-jdbc.md`.

### Pattern 7: Database Explorer Integration

```matlab
% Create and save a connection as a data source
j = databricks.JDBCConnection();
j.saveSource();

% Copy the token to clipboard for pasting into Database Explorer
j.copyToken();

% Open Database Explorer, select the saved data source,
% enter "token" as username, paste the token as password
databaseExplorer
```

### Pattern 8: Error-Safe Connection Cleanup

Use `onCleanup` or `try/catch` to guarantee the connection closes even when queries fail.

```matlab
j = databricks.JDBCConnection(catalog="main", schema="analytics");
cleanup = onCleanup(@() close(j));

% If this errors, cleanup still runs
data = fetch(j.Connection, "SELECT * FROM large_table WHERE id > 1000");
```

## Common Mistakes

```matlab
% NOT RECOMMENDED: manually constructing a JDBC URL with database()
% This works but is error-prone and may expose connection details in code
conn = database("default", "token", myToken, ...
    "com.databricks.client.jdbc.Driver", ...
    "jdbc:databricks://myhost:443/default;transportMode=http;ssl=1;...");
% RECOMMENDED: let JDBCConnection handle URL construction
j = databricks.JDBCConnection();
conn = j.Connection;

% WRONG: using driver auth when running MATLAB on Databricks
j = databricks.JDBCConnection();  % Driver tries to open a browser, fails
% CORRECT: disable driver auth in browser environment
j = databricks.JDBCConnection(authMethod="OauthU2M", useDriverAuth=false);

% WRONG: hardcoding a PAT token in source code
j = databricks.JDBCConnection(token="dapi1234567890abcdef");
% CORRECT: store token in .databrickscfg and let the auth chain find it
j = databricks.JDBCConnection(authMethod="PAT");

% WRONG: using the OSS driver with Java 8
j = databricks.JDBCConnection(useDriverType="oss");  % Error: Java 11+ required
% CORRECT: set Java version first, then use OSS driver
jenv("/path/to/java11");  % Requires MATLAB restart
j = databricks.JDBCConnection(useDriverType="oss");

% WRONG: forgetting to close the connection
j = databricks.JDBCConnection();
data = sqlread(j.Connection, "mytable");
% Connection left open, resources leaked
% CORRECT: always close
close(j);
```

## Unity Catalog Naming

When accessing resources governed by Unity Catalog, names containing hyphens must be enclosed in backticks within SQL queries:

```matlab
% Schema name contains a hyphen
data = fetch(j.Connection, "SELECT * FROM mycatalog.`my-schema`.mytable");
```

For `sqlread` and `sqlwrite`, set the catalog and schema on the connection instead:

```matlab
j = databricks.JDBCConnection(catalog="mycatalog", schema="my-schema");
data = sqlread(j.Connection, "mytable");
```

## Checklist

Before finalizing Databricks JDBC connection code, verify:
- [ ] Using `databricks.JDBCConnection`, `StandaloneJDBCConnection`, or `SQLWarehouse.connect()` (preferred over manual `database()` URL construction)
- [ ] Authentication method appropriate for the scenario (OauthU2M for interactive, OauthM2M for services, PAT for simple access)
- [ ] No tokens or secrets hardcoded in source code
- [ ] `close(j)` or `close(conn)` called when done
- [ ] If on Databricks: `useDriverAuth=false` is set
- [ ] If using OSS driver: Java 11+ configured via `jenv`
- [ ] If writing large data with Simba: `UseNativeQuery` optimization is active (default)
- [ ] Connection verified via empty `j.Connection.Message` or `j.testConnection()`

## Troubleshooting

**Issue**: Connection returns empty `database.jdbc.connection` with a message
- **Solution**: Check the `j.Connection.Message` property. Common causes: incorrect host, expired token, cluster not running, wrong driver on classpath.

**Issue**: "Driver class not found on Java class path"
- **Solution**: The JDBC driver jar is not on MATLAB's dynamic Java class path. `databricks.JDBCConnection` adds it automatically. For `StandaloneJDBCConnection`, call `javaaddpath("path/to/Shaded-Databricks-JDBC-Driver-0.0.2.jar")` first.

**Issue**: OSS driver fails with Java version error
- **Solution**: The OSS driver requires Java 11+. Check with `jenv` and set a compatible JDK: `jenv("/path/to/java11")`. Restart MATLAB after changing.

**Issue**: "An ODBC/JDBC datasource exists with the same name as the database"
- **Solution**: A saved data source has the same name as the schema. Rename the data source or use a different `dataSourceName` argument.

**Issue**: Connection takes a long time to establish
- **Solution**: A Databricks cluster or SQL Warehouse may be starting from a stopped state (cold start). This can take several minutes. Check the cluster/warehouse status in the Databricks UI or via `warehouse.refresh()`. MATLAB blocks until the compute resource is ready.

**Issue**: Connection hangs or times out
- **Solution**: Verify the cluster or SQL Warehouse is running. For SQL Warehouses, `warehouse.refresh()` shows the current state. MATLAB blocks while a stopped warehouse starts.

**Issue**: Token cache errors on Linux/macOS with driver v2.7.x
- **Solution**: Known driver bug. Upgrade to driver v2.7.3+ or disable caching: `enableTokenCache=false`. See the `JDBCWorkflow.md` documentation in the package for version-specific details.

**Issue**: OauthU2M fails when running MATLAB on Databricks
- **Solution**: The JDBC driver's OAuth flow tries to open a browser, which fails in browser-based MATLAB. Use `databricks.JDBCConnection(authMethod="OauthU2M", useDriverAuth=false)`.

**Still stuck?** Consult the shipping documentation for detailed guidance:
```matlab
doc databricks.JDBCConnection                          % Class reference
edit(databricksRoot(-2, "Documentation", "JDBCWorkflow.md"))  % JDBC workflow guide
edit(databricksRoot("Standalone", "README.md"))         % Standalone setup guide
```
If none of the above resolves your issue, email databricks@mathworks.com for direct support from the MATLAB-Databricks team.

----

Copyright 2026 The MathWorks, Inc.
