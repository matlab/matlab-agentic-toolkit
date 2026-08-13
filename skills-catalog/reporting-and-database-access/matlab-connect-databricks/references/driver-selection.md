# JDBC Driver Selection

## Supported Drivers

| Driver | Version Range | Java Requirement | Included in Package | Key Feature |
|--------|--------------|------------------|:-------------------:|-------------|
| Simba (non-OSS) | >= 2.7.3, < 3.0.0 | Java 8+ (MATLAB default) | Yes | Write optimization via `UseNativeQuery` |
| OSS | >= 3.0.3 | Java 11+ | No | Arrow-based data transfer for faster large reads |

## Auto-Selection Logic

When neither `useDriverType` nor `jarFilePath` is specified:

| Java Version | Simba Present | OSS Present | Driver Selected |
|:------------:|:------------:|:-----------:|:---------------:|
| > 8 | Yes | Yes | OSS |
| > 8 | Yes | No | Simba |
| 8 | Yes | Any | Simba (default) |

Explicit override:

```matlab
j = databricks.JDBCConnection(useDriverType="oss");   % Force OSS
j = databricks.JDBCConnection(useDriverType="simba"); % Force Simba
j = databricks.JDBCConnection(jarFilePath="path/to/specific.jar"); % Specific jar
```

## Simba Driver (Default)

Ships with the package at: `Software/MATLAB/lib/jar/Shaded-Databricks-JDBC-Driver-0.0.2.jar`

The driver is shaded (relocated dependencies) to avoid classpath conflicts. Using the unshaded driver from Databricks directly produces spurious logging.

### Write Optimization

`UseNativeQuery=1` and `EnableNativeParameterizedQuery=0` significantly improve `sqlwrite` performance. Enabled by default via `databricks.JDBCConnection` and `SQLWarehouse.connect()`.

```matlab
% Disable optimization (not recommended for writes)
j = databricks.JDBCConnection(useNativeQuery=false, enableNativeParameterizedQuery=true);
```

### Custom Build

To build from a newer Databricks driver:
1. Install Apache Maven and a JDK
2. From `Software/Java/JDBCDriver/`, run: `mvn clean package`
3. Output: `Software/MATLAB/lib/jar/Shaded-Databricks-JDBC-Driver-0.0.2.jar`

## OSS Driver

### Setup

Build using Maven from `Software/Java/JDBCDriver/`:
```
mvn clean package -f pomOSS.xml
```
Output: `Software/MATLAB/lib/jar/Databricks-JDBC-OSS-Driver-0.0.1.jar`

### Java Configuration

```matlab
jenv                          % Check current version
jenv("/usr/local/jre-11")     % Set Java 11+ (requires MATLAB restart)
jenv("factory")               % Reset to default
```

**Avoid Java 16** — requires JVM startup arguments in `java.opts`. Use Java 11, 17, or 21.

### Limitations

- `UseNativeQuery` / `EnableNativeParameterizedQuery` are Simba-specific, ignored by OSS
- `thriftTransport` parameter is ignored
- Logging output not suppressed (driver jar is not shaded)

## Classpath Management

`databricks.JDBCConnection` adds the driver jar automatically. For `StandaloneJDBCConnection`, add manually:

```matlab
javaaddpath("path/to/Shaded-Databricks-JDBC-Driver-0.0.2.jar");
```

## Proxy Support

JDBC driver supports SOCKS proxies only. Use `connectionURLAppend`:

```matlab
j = databricks.JDBCConnection(connectionURLAppend="ProxyHost=myproxy;ProxyPort=1080;");
```

## StandaloneJDBCConnection Constraints

`StandaloneJDBCConnection` supports the Simba driver only. Do not use `useDriverType="oss"` with standalone connections.

----

Copyright 2026 The MathWorks, Inc.

----
