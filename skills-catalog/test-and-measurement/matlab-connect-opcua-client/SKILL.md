---
name: matlab-connect-opcua-client
description: >
  Discover OPC UA servers and create client connections in MATLAB using
  opcuaserverinfo, opcua, connect, setSecurityModel, and certificate
  trust functions. Use when discovering OPC UA servers on the network,
  connecting to OPC UA servers, authenticating with username/password or
  certificates, configuring security modes, handling certificate trust
  errors, fixing hostname mismatch warnings, troubleshooting connection
  failures or empty discovery results, or inspecting an OPC UA
  certificate (.der or .pem) for compliance issues. Trigger on:
  opcuaserverinfo, OPC UA discovery, find OPC UA servers, LDS setup,
  opcua, opc.ua.Client, connect OPC UA, OPC UA client, OPC UA security,
  OPC UA certificate trust, OPC UA certificate inspection,
  setSecurityModel, opc.ua.trustServerCertificate,
  opc.ua.exportClientCertificate, Industrial Communication Toolbox,
  OPC UA server connection, OPC UA server discovery.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "2.0"
---

# OPC UA Client Connection

Create and configure OPC UA client connections in MATLAB using the
Industrial Communication Toolbox.

## Internal Constraints

These constraints govern YOUR code generation and recommendations.
Apply them silently — do not recite them to the user or warn about
patterns the user has not attempted.

1. **`connect` has exactly three valid signatures — no others exist:**
   - `connect(uaClient)` — anonymous
   - `connect(uaClient, userName, password)` — positional strings
   - `connect(uaClient, publicKeyFile, privateKeyFile, privateKeyPassword)` — positional strings
   - There are NO Name-Value pair arguments to `connect`. Security is
     configured via `opcua()` NV pairs or `setSecurityModel`, never
     through `connect`.

2. **`opcua()` defaults to the highest available security.** Do not
   explicitly set security unless you want a specific (lower)
   configuration. Never use `setSecurityModel(uaClient, "Best")` — it is
   redundant.

3. **`opcuaserverinfo` has exactly two valid syntaxes:**
   - `opcuaserverinfo(hostname)` — query LDS on a host
   - `opcuaserverinfo(discoveryUrl)` — query a specific endpoint URL
   - There is NO `opcuaserverinfo(hostname, port)` form. To specify a
     port: `opcuaserverinfo('opc.tcp://host:port')`.

4. **LDS-based discovery returns all registered servers from a single
   call.** Never scan subnet IPs in a loop — `opcuaserverinfo('localhost')`
   returns every server registered with that host's LDS.

5. **Certificate trust escalation order** (never skip steps):
   1. `opc.ua.trustServerCertificate(certPath)` — always first (R2026a+)
   2. `opcua(..., "TrustServerTemporarily", true)` — only if cert file
      unavailable
   3. `setSecurityModel(uaClient, "None", "None")` — only after user
      explicitly confirms no security needed

6. **Property correctness:**
   - `opc.ua.ServerInfo` has `Description`, not `Name` (which belongs
     to `opc.ua.Client`).
   - `EndpointUrl` belongs to `opc.ua.EndpointDescription`, not
     `ServerInfo`.

7. **Do not move or copy certificate files without user confirmation.**
   Tell the user which file to move and where, then execute only after
   they confirm.

8. **Do not mention `TrustServerTemporarily` when the issue is the
   server rejecting the client certificate** — it only controls client-
   side trust and is irrelevant in that direction. Simply omit it.

## When to Use

- Discovering OPC UA servers on the network (endpoint URL unknown, or
  user explicitly requests discovery given a hostname or discovery URL)
- Getting server endpoint details and supported security policies
- Creating an OPC UA client connection to a server
- Authenticating with username/password or user certificates
- Configuring message security mode and channel security policy
- Handling "server certificate not trusted" errors
- Handling "client certificate rejected by server" errors
- Fixing hostname mismatch warnings
- Troubleshooting OPC UA connection failures or empty discovery results
- Inspecting an OPC UA certificate (`.der`/`.pem`) for compliance issues

## When NOT to Use

- Browsing OPC UA server namespaces or nodes
- Reading, writing, or subscribing to OPC UA node values
- Working with OPC Classic (DA/HDA) connections
- Non-OPC UA protocols (Modbus, MQTT)
- OPC UA server-side development

## References

Load the relevant reference file for detailed procedures:

| Task | Reference |
|------|-----------|
| Server discovery, LDS setup, empty discovery results | [references/lds-setup-and-troubleshooting.md](references/lds-setup-and-troubleshooting.md) |
| Server cert trust, client cert export, cert inspection | [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md) |
| Connection errors, server logs, diagnostic workflow | [references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md) |
| Syntax pitfalls and invalid API patterns | [references/common-mistakes.md](references/common-mistakes.md) |

## Workflow

### 0. Discover servers (optional)

Use this step when the endpoint URL is not known, or when the user
explicitly asks to discover servers given a hostname or discovery URL.
Skip this step if the endpoint URL is already known.

**Prerequisites** — before calling `opcuaserverinfo`, ensure:
1. The OPC UA Local Discovery Service (LDS) is installed and running
2. The target server is registered with the LDS
3. The server's certificate is trusted by the LDS certificate store at
   `C:\ProgramData\OPC Foundation\UA\pki\trusted\certs\`

See [references/lds-setup-and-troubleshooting.md](references/lds-setup-and-troubleshooting.md) for details.

```matlab
% LDS-based discovery (preferred — finds all registered servers)
serverInfo = opcuaserverinfo('localhost');

% Direct endpoint discovery (when you know the server URL)
serverInfo = opcuaserverinfo('opc.tcp://myserver:53530/OPCUA/SimulationServer');

% Pass discovery result directly to opcua()
uaClient = opcua(serverInfo(1));
connect(uaClient);
```

### 1. Create the OPC UA client

```matlab
serverUrl = "opc.tcp://hostname:port/path";
uaClient = opcua(serverUrl);
```

The `opcua` function also accepts a `ServerInfo` object directly from
`opcuaserverinfo`.

### 2. Configure security (only if non-default needed)

```matlab
% R2025a+ (preferred) — Name-Value pairs in constructor
uaClient = opcua(serverUrl, ...
    MessageSecurityMode="Sign", ...
    ChannelSecurityPolicy="Basic256Sha256");

% R2020a+ (backward-compatible) — setSecurityModel after construction
uaClient = opcua(serverUrl);
setSecurityModel(uaClient, "Sign", "Basic256Sha256");
```

### 3. Handle certificate trust (if needed)

If the server's certificate is not yet trusted by MATLAB, the
connection will fail. Follow the escalation order in Must-Follow
Rules. Load [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md) for details.

### 4. Connect

```matlab
connect(uaClient);                                        % anonymous
connect(uaClient, "myuser", "mypassword");               % username/password
connect(uaClient, "cert.der", "key.pem", "keypass");     % certificate
```

### 5. Verify and disconnect

```matlab
if isConnected(uaClient)
    fprintf("Connected to %s\n", uaClient.EndpointUrl);
end
disconnect(uaClient);
```

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `opcuaserverinfo` | Discover OPC UA servers via LDS or direct URL | R2015b |
| `opcua` | Create OPC UA client (from URL or ServerInfo) | R2015b |
| `connect` | Connect to server | R2015b |
| `disconnect` | Disconnect from server | R2015b |
| `isConnected` | Check connection status | R2015b |
| `setSecurityModel` | Configure security mode/policy | R2020a |
| `opc.ua.exportClientCertificate` | Export MATLAB client cert to file | R2020a |
| `opc.ua.trustServerCertificate` | Trust a server cert (file path) | R2026a |
| `opc.ua.rejectServerCertificate` | Reject a server cert (file path) | R2026a |
| `findDescription` | Filter ServerInfo array by description text | R2015b |
| `findAuthentication` | Filter ServerInfo array by auth type | R2015b |

## Properties Quick Reference

### `opc.ua.Client`

| Property | Type | Description |
|----------|------|-------------|
| `Hostname` | string | Server hostname |
| `Port` | double | Server port |
| `Name` | string | Client name |
| `EndpointUrl` | string | Selected endpoint URL |
| `Status` | string | Connection status |
| `Timeout` | double | Connection timeout (seconds) |
| `MessageSecurityMode` | enum | Active security mode |
| `ChannelSecurityPolicy` | enum | Active channel policy |
| `UserAuthTypes` | cell | Available auth types on server |
| `Endpoints` | array | Available endpoint descriptions |

**Does NOT have:** `UserName`, `Password`, `IsConnected`, `Security`,
`SecurityMode`, `SecurityPolicy`, `Certificate`, `PrivateKey`.

Use `isConnected(uaClient)` (method) to check connection status.

### `opc.ua.ServerInfo`

| Property | Type | Description |
|----------|------|-------------|
| `Hostname` | char | Host name |
| `Port` | double | TCP port |
| `Description` | char | Human-readable server description |
| `UserTokenTypes` | cell | Supported auth types |
| `BestMessageSecurity` | enum | Highest message security |
| `BestChannelSecurity` | enum | Highest channel security policy |
| `Endpoints` | array | `opc.ua.EndpointDescription` objects |

### `opc.ua.EndpointDescription`

| Property | Type | Description |
|----------|------|-------------|
| `EndpointUrl` | char | Full endpoint URL |
| `MessageSecurityMode` | enum | Security mode for this endpoint |
| `ChannelSecurityPolicy` | enum | Channel security policy |
| `UserAuthTypes` | cell | Auth types on this endpoint |

## Patterns

### Discovery

```matlab
% Discover all servers via LDS
serverInfo = opcuaserverinfo('localhost');

% Discover and connect
serverInfo = opcuaserverinfo('localhost');
uaClient = opcua(serverInfo(1));
connect(uaClient);
```

### Connection with authentication

```matlab
% Default (highest) security, anonymous
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer");
connect(uaClient);

% Username/password
connect(uaClient, "myuser", "mypassword");

% User certificate
connect(uaClient, "C:/certs/user.der", "C:/certs/user.key", "keypassword");
```

### Hostname mismatch fix

```matlab
% R2025a+
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer", ...
    UseDiscoveryHostname=true);

% Pre-R2025a — resolve via discovery
serverInfo = opcuaserverinfo("myserver");
uaClient = opcua(serverInfo(1));
connect(uaClient);
```

### Certificate inspection

Load [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md), then run:

```matlab
inspectOpcUaCertificate("path/to/server_cert.der");
```

## Troubleshooting Quick Reference

| Error | Fix |
|-------|-----|
| `opcuaserverinfo` returns empty | Check LDS prerequisites; see [references/lds-setup-and-troubleshooting.md](references/lds-setup-and-troubleshooting.md) |
| "Server certificate not trusted" | `opc.ua.trustServerCertificate(certPath)` |
| "Client certificate rejected" | Export via `opc.ua.exportClientCertificate`, add to server |
| "BadIdentityTokenRejected" | Check `uaClient.UserAuthTypes` |
| "Hostname mismatch" warning | `UseDiscoveryHostname=true` (R2025a+) |
| "BadSecurityChecksFailed" | Run `inspectOpcUaCertificate`; see [references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md) |

For detailed error-to-fix mapping, load [references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md).

----

Copyright 2026 The MathWorks, Inc.

----
