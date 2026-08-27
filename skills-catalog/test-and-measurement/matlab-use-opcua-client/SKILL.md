---
name: matlab-use-opcua-client
description: >
  Discover OPC UA servers, connect MATLAB clients, and browse/navigate
  server nodes using opcuaserverinfo, the Local Discovery Service (LDS),
  opcua, connect, setSecurityModel, certificate-trust functions,
  findNodeById, opcuanode, and Namespace/Children traversal. Use when
  finding OPC UA servers on the network, querying endpoints and security
  policies, connecting to a server, authenticating with username/password
  or certificates, configuring security modes, handling certificate-trust
  or hostname-mismatch errors, troubleshooting failed connections or empty
  discovery, inspecting an OPC UA certificate (.der/.pem), browsing an
  address space, finding nodes by name or NodeId, navigating node
  hierarchies, invoking method nodes, or batch-processing large
  namespaces. Trigger on: opcuaserverinfo, LDS, opcua, opc.ua.Client,
  setSecurityModel, opc.ua.trustServerCertificate, OPC UA certificate,
  findNodeById, opcuanode, browse OPC UA, find node, OPC UA namespace,
  OPC UA method node, Industrial Communication Toolbox.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "3.0"
---

# OPC UA Discovery, Connection, and Node Navigation

Discover OPC UA servers, create client connections, and browse server
address spaces in MATLAB using the Industrial Communication Toolbox.

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

9. **`browseNamespace` is GUI-only — never call it in scripts or agent
   workflows.** It opens an interactive dialog that blocks the MATLAB
   session. Use `uaClient.Namespace` and `.Children` traversal instead.

10. **`opcuanode` does NOT accept browse paths.** Passing a slash-
    separated string (e.g., `'Demo/Mass/Nested/7'`) silently creates a
    node with `NodeType: 'Unknown'`. Use `.Children` level-by-level.

11. **Check a method node's `Parent` property and signature before
    `invoke()`.** If `Parent` is empty, `invoke()` fails with "Specified
    node has no parent information" — re-resolve the node via
    `findNodeById`, which retains parent info. If `Parent` is non-empty,
    invoke it directly. Do not unconditionally avoid `opcuanode` for
    method nodes; branch on whether the node has a parent. Before
    calling `invoke`, inspect `NumInputs` and `NumOutputs` to verify
    the argument count matches your intended call.

12. **Before iterating any `.Children` array, issue a separate tool call
    that only counts nodes.** Never combine counting and processing in
    the same tool call. Process in batches of 200 with progress reporting.

13. **Never search the entire namespace.** If the user does not provide
    a path or parent folder, ask them to specify one. List top-level
    nodes to help them narrow scope. Skip the `Server` folder (ns=0
    infrastructure nodes) unless the user explicitly asks about server
    properties.

14. **`opcua()` caches endpoints at construction time.** If the server's
    available policies change after client creation, the existing client
    object will not reflect them. Recreate the client with `opcua(url)`
    to re-discover endpoints. Explain this to the user when they ask
    about switching to a newly-available policy.

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
- Browsing an OPC UA server's address space programmatically
- Searching for nodes by name, partial name, or NodeId
- Navigating a node hierarchy to reach a specific node
- Accessing a node directly by namespace index and identifier
- Goal-driven node discovery (e.g., "find all temperature sensors")
- Discovering nodes before reading, writing, invoking, or subscribing

## When NOT to Use

- OPC Classic (OPC DA / OPC HDA) connections
- PI Data Archive / PI AF / OSIsoft / AVEVA PI systems
- Non-OPC UA protocols (Modbus, MQTT)
- OPC UA server-side development

## References

Load the relevant reference file for detailed procedures:

| Task | Reference |
|------|-----------|
| Server discovery, LDS setup, empty discovery results | [references/lds-setup-and-troubleshooting.md](references/lds-setup-and-troubleshooting.md) |
| Server cert trust, client cert export, cert inspection | [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md) |
| Connection errors, server logs, diagnostic workflow | [references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md) |
| Node navigation patterns, batch processing, method invocation | [references/node-navigation.md](references/node-navigation.md) |
| Function syntax for findNodeById, opcuanode, getNamespace | [references/node-functions-reference.md](references/node-functions-reference.md) |
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
% TEMPLATE — not executable (shows alternative discovery forms)
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
% TEMPLATE — not executable (shows two alternative security-config forms)
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
connection will fail. Follow the escalation order in Internal
Constraints. Load [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md) for details.

### 4. Connect

```matlab
connect(uaClient);                                        % anonymous
connect(uaClient, "myuser", "mypassword");               % username/password
connect(uaClient, "cert.der", "key.pem", "keypass");     % certificate
```

### 5. Verify connection

```matlab
if isConnected(uaClient)
    fprintf("Connected to %s\n", uaClient.EndpointUrl);
end
```

### 6. Find nodes (once connected)

Load [references/node-navigation.md](references/node-navigation.md) for full decision
logic, workflows, batch processing, and method invocation patterns.

### 7. Disconnect

```matlab
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
| `findNodeById` | Find node by namespace index and identifier (retains parent) | R2015b |
| `opcuanode` | Create node directly from known NodeId (check `Parent` before `invoke`) | R2015b |
| `getNamespace` | Get one layer of namespace tree (or use `uaClient.Namespace`) | R2015b |

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

### `opc.ua.Node`

| Property | Type | Description |
|----------|------|-------------|
| `Name` | char | Node display name |
| `NodeType` | char | `'Object'`, `'Variable'`, `'Method'`, or `'Unknown'` |
| `NamespaceIndex` | double | Namespace index |
| `Identifier` | varies | Node identifier (numeric or string) |
| `Children` | array | Child nodes (lazy-loaded from server) |
| `Parent` | node | Parent node (may be empty for `opcuanode`-created nodes; check before `invoke`) |
| `ServerDataType` | char | Data type for Variable nodes |
| `NumInputs` | double | Number of input arguments (Method nodes) |
| `NumOutputs` | double | Number of output arguments (Method nodes) |

## Patterns

### Discovery

```matlab
% TEMPLATE — not executable (shows discover-only vs discover-and-connect)
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
% TEMPLATE — not executable (shows R2025a+ vs pre-R2025a forms)
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

### Navigate a browse path

```matlab
ns = uaClient.Namespace;
idx = arrayfun(@(n) strcmp(n.Name, 'Demo'), ns);
level1 = ns(idx);

children = level1.Children;
idx = arrayfun(@(n) strcmp(n.Name, 'Mass'), children);
level2 = children(idx);
```

### Direct node lookup by NodeId

```matlab
% TEMPLATE — not executable (shows two alternative lookup forms)
% Quick access from a known NodeId
node = opcuanode(3, 1002, uaClient);

% Always retains parent info
node = findNodeById(uaClient.Namespace, 3, 1002);
```

### Find and invoke a method node

`invoke` requires parent information. Before invoking, check the node's
`Parent` property — if it is empty, re-resolve the node via
`findNodeById` (or `.Children` navigation) so parent info is populated;
if it is non-empty, invoke directly.

```matlab
methodNode = opcuanode(6, 'MyMethod', uaClient);

% Ensure parent info is present before invoking
if isempty(methodNode.Parent)
    methodNode = findNodeById(uaClient.Namespace, 6, 'MyMethod');
end

% Verify argument count before calling invoke
fprintf("Inputs: %d, Outputs: %d\n", methodNode.NumInputs, methodNode.NumOutputs);

[result, timestamp, quality] = invoke(uaClient, methodNode, arg1, arg2);
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
| `NodeType: 'Unknown'` after `opcuanode` | Node doesn't exist or path passed as id; use `.Children` traversal |
| "Specified node has no parent information" | Node's `Parent` is empty; re-resolve via `findNodeById` (or `.Children`) before `invoke` |
| `browseNamespace` blocks session | Never use; replace with `uaClient.Namespace` + `.Children` |

For detailed error-to-fix mapping, load [references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md).

----

Copyright 2026 The MathWorks, Inc.

----
