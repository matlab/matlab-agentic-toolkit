# Databricks Authentication Configuration

## Authentication Provider Chain

Values are resolved in this order (first match wins):

1. Named arguments passed to the connection class or `getDatabricksSession`
2. Environment variables (`DATABRICKS_*`)
3. `.databrickscfg` profile file
4. `databricks-settings.json` in MATLAB `prefdir`

## .databrickscfg File

Location: `<HomeDirectory>/.databrickscfg`. Override with `DATABRICKS_CONFIG_FILE` environment variable.

### Format

```ini
[DEFAULT]
host = https://<workspace-url>
cluster_id = <cluster-id>

[PAT]
host = https://<workspace-url>
token = <personal-access-token>
cluster_id = <cluster-id>

[M2M]
host = https://<workspace-url>
client_id = <service-principal-client-id>
client_secret = <service-principal-secret>
cluster_id = <cluster-id>
```

### Required Fields by Auth Method

| Auth Method | host | token | client_id | client_secret | cluster_id | org_id |
|-------------|:----:|:-----:|:---------:|:-------------:|:----------:|:------:|
| PAT         | Yes  | Yes   |           |               | Optional   | Optional |
| OauthU2M    | Yes  |       |           |               | Optional   | Optional |
| OauthM2M    | Yes  |       | Yes       | Yes           | Optional   | Optional |

Note: `org_id` is required for JDBC URL construction but optional in the config file (derived from host URL on Azure).

### Profile Selection Priority

1. `profileName` argument passed to the constructor
2. `DATABRICKS_CONFIG_PROFILE` environment variable
3. `profileName` field in `databricks-settings.json`
4. Profile named `DEFAULT` if present
5. First profile in the file

Profile names are case sensitive.

## Environment Variables

| Environment Variable | Overrides |
|---------------------|-----------|
| `DATABRICKS_HOST` | `host` |
| `DATABRICKS_TOKEN` | `token` |
| `DATABRICKS_CLIENT_ID` | `client_id` |
| `DATABRICKS_CLIENT_SECRET` | `client_secret` |
| `DATABRICKS_CLUSTER_ID` | `cluster_id` |
| `DATABRICKS_ORG_ID` | `org_id` |

JDBC-specific (take precedence over `DATABRICKS_HOST`):
- `DATABRICKS_SERVER_HOSTNAME`
- `DATABRICKS_HTTP_PATH`

## Authentication Methods

### OauthU2M (Default for Interactive Use)

Opens a browser for login. Short-lived tokens cached automatically. Does not work in non-interactive contexts (scripts, batch mode, MCP tools) or when MATLAB runs on Databricks in a browser.

```matlab
% Spark
spark = getDatabricksSession(authMethod="OauthU2M");

% JDBC
j = databricks.JDBCConnection(authMethod="OauthU2M");
```

### OauthM2M (Service Principals / Automation)

Uses client credentials. Appropriate for CI/CD pipelines.

```matlab
% Spark
spark = getDatabricksSession(authMethod="OauthM2M", profileName="M2M");

% JDBC
j = databricks.JDBCConnection(authMethod="OauthM2M", profileName="M2M");
```

### PAT (Personal Access Token)

Simple token-based. May be disabled by workspace admins.

```matlab
% Spark
spark = getDatabricksSession(authMethod="PAT");

% JDBC
j = databricks.JDBCConnection(authMethod="PAT");
```

### Token Passthrough (JDBC Only)

Bypasses driver auth with an externally obtained token.

```matlab
j = databricks.JDBCConnection(passthroughAccessToken=myToken);
```

## Token Caching

### Package-Managed (OauthU2M without driver auth)

Cached in `<HomeDirectory>/.databricksOauthTokenCache` as plain text. Override with `DATABRICKS_TOKEN_CACHE_FILE`. Disable with `DISABLE_DATABRICKS_TOKEN_CACHE=true`.

### Driver-Managed (JDBC default)

The JDBC driver manages its own cache when `enableTokenCache` is set.

| Driver Version | Windows | Linux/macOS |
|---------------|---------|-------------|
| v2.7.1-2.7.2 | Supported | Not supported (bug) |
| v2.7.3+ | Supported | Supported |
| v3.0+ (OSS) | Supported | Supported |

## OAuth Service Providers

| OauthService | When to Use |
|-------------|-------------|
| `Databricks` (default) | Standard Databricks workspaces |
| `EntraID` | Azure AD / Entra ID managed authentication |

```matlab
j = databricks.JDBCConnection(authMethod="OauthU2M", OauthService="EntraID");
```

## Serverless Compute Configuration

For serverless Spark sessions, remove `cluster_id` and set `serverless_compute_id`:

```ini
[DEFAULT]
host = https://<workspace-url>
serverless_compute_id = auto
```

Or switch programmatically:

```matlab
updateClusterId("serverless");
```

## Python Version Compatibility (Spark Path)

| Runtime | Python Version | Serverless Support |
|---------|---------------|-------------------|
| 18.x | 3.12 | Yes |
| 17.3 | 3.12 | Yes |
| 16.4 LTS | 3.12 | Yes (>= 16.4.1) |
| 15.4 LTS | 3.11 | Yes (>= 15.4.10) |
| 14.3 LTS | 3.10 | Classic only |
| 13.3 LTS | 3.10 | Classic only |

----

Copyright 2026 The MathWorks, Inc.

----
