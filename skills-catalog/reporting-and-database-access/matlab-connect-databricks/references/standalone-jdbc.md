# StandaloneJDBCConnection Setup

## Overview

`StandaloneJDBCConnection` provides JDBC connectivity to Databricks with zero dependencies on the MATLAB Interface for Databricks package.

Requirements:
- MATLAB R2022b or later
- Database Toolbox
- Databricks Simba JDBC driver (OSS driver not supported)

## Setup

1. Place `StandaloneJDBCConnection.m` and `databricks_standalone_jdbc_settings.json` on the MATLAB path
2. Edit the JSON file with host, orgId, clusterId, and auth settings
3. Construct the connection

Source location in the package: `Software/MATLAB/Standalone/source/StandaloneJDBCConnection.m`

## JSON Settings Template

```json
{
    "host": "https://adb-1234567890123456.1.azuredatabricks.net",
    "port": "443",
    "orgId": "1234567890123456",
    "clusterId": "1234-123456-abcdefgh",
    "schema": "myschema",
    "catalog": "mycatalog",

    "authMethod": "OauthU2M",
    "token": "",
    "clientId": "",
    "clientSecret": "",
    "passthroughAccessToken": "",
    "passthroughRefreshToken": "",
    "enableTokenCache": "",
    "tokenCachePassPhrase": "",

    "scope": "",
    "oauthService": "Databricks",
    "oauth2ClientId": "databricks-sql-jdbc",
    "vendor": "",

    "driverClass": "com.databricks.client.jdbc.Driver",
    "jarFilePath": "Shaded-Databricks-JDBC-Driver-0.0.2.jar",

    "connectionURL": "",
    "connectionURLAppend": "",
    "httpPath": "",
    "ssl": "1",
    "thriftTransport": "",

    "logLevel": "0",
    "verbose": "1"
}
```

Values set to `""` are ignored. On Windows, escape backslashes in `jarFilePath`.

## Settings Precedence

1. Constructor arguments (highest priority)
2. JSON settings file values
3. Built-in defaults (lowest priority)

Built-in defaults: `authMethod="OauthU2M"`, `port="443"`, `driverClass="com.databricks.client.jdbc.Driver"`, `ssl="1"`, `logLevel="0"`.

## Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `host` | Workspace URL | `"https://adb-123.1.azuredatabricks.net"` |
| `port` | Driver port | `"443"` |
| `orgId` | Workspace org ID | `"1234567890123456"` |
| `clusterId` | Cluster or SQL Warehouse ID | `"0912-173539-zf4ob0md"` |
| `schema` | Database/schema name | `"myschema"` |
| `catalog` | Unity Catalog catalog | `"mycatalog"` |

## Authentication

| Auth Method | Required Fields |
|-------------|----------------|
| PAT | `token` |
| OauthU2M | None (browser flow) |
| OauthM2M | `clientId`, `clientSecret` |

Token passthrough via `passthroughAccessToken` bypasses driver auth entirely.

## Usage

```matlab
% Basic usage with JSON defaults
j = StandaloneJDBCConnection();
data = fetch(j.Connection, "SELECT * FROM mytable LIMIT 10");
close(j);

% Override schema and catalog
j = StandaloneJDBCConnection(schema="analytics", catalog="main");
data = sqlread(j.Connection, "mytable");
close(j);

% PAT authentication
j = StandaloneJDBCConnection(authMethod="PAT", token=myToken);

% Custom settings file
j = StandaloneJDBCConnection(settingsFile="my_databricks_settings.json");
```

## On-Databricks

When running on a Databricks cluster, use `passthroughAccessToken` (OauthU2M browser flow fails):

```matlab
j = StandaloneJDBCConnection(passthroughAccessToken=accessToken);
```

## Datasource Name Conflict

If a saved ODBC/JDBC datasource has the same name as the schema, the connection fails. Rename the datasource or use a different `dataSourceName` argument.

----

Copyright 2026 The MathWorks, Inc.

----
