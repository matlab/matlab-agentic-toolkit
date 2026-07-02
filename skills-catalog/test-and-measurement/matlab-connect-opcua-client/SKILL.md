---
name: matlab-connect-opcua-client
description: >
  Create OPC UA client connections in MATLAB and inspect OPC UA
  certificates using opcua, connect, setSecurityModel, and certificate
  trust functions. Use when connecting to OPC UA servers, authenticating
  with username/password or certificates, configuring security modes,
  handling certificate trust errors, fixing hostname mismatch warnings,
  troubleshooting connection failures, or inspecting/checking/validating
  an OPC UA server or client certificate (.der or .pem) for compliance
  issues such as key length, signature algorithm, key usage,
  ApplicationUri, or expiry. Trigger on: opcua, opc.ua.Client,
  connect OPC UA, OPC UA client, OPC UA security, OPC UA certificate
  trust, OPC UA certificate inspection, check OPC UA certificate,
  validate OPC UA certificate, OPC UA cert compliance, .der certificate,
  setSecurityModel, opc.ua.trustServerCertificate,
  opc.ua.exportClientCertificate, Industrial Communication Toolbox
  connection.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# OPC UA Client Connection

Create and configure OPC UA client connections in MATLAB using the
Industrial Communication Toolbox.

## When to Use

- Creating an OPC UA client connection to a server
- Authenticating with username/password or user certificates
- Configuring message security mode and channel security policy
- Handling "server certificate not trusted" errors
- Handling "client certificate rejected by server" errors
- Fixing hostname mismatch warnings
- Troubleshooting OPC UA connection failures
- Inspecting an OPC UA server or client certificate (`.der`/`.pem`)
  for compliance issues — key length, signature algorithm, key usage,
  ApplicationUri, validity, end-entity status

## When NOT to Use

- Discovering OPC UA servers on the network (use `matlab-discover-opcua-servers`)
- Browsing OPC UA server namespaces or nodes
- Reading, writing, or subscribing to OPC UA node values
- Working with OPC Classic (DA/HDA) connections
- Non-OPC UA protocols (Modbus, MQTT)

## Workflow

### 1. Create the OPC UA client

```matlab
serverUrl = "opc.tcp://hostname:port/path";
uaClient = opcua(serverUrl);
```

The `opcua` function contacts the server's discovery endpoint and
**automatically selects the highest available security configuration**.
You do NOT need to explicitly set security unless you want a specific
(lower) configuration.

### 2. Configure security (only if non-default needed)

**R2025a+ (preferred) — Name-Value pairs in constructor:**

```matlab
uaClient = opcua(serverUrl, ...
    MessageSecurityMode="Sign", ...
    ChannelSecurityPolicy="Basic256Sha256");
```

**R2020a+ (backward-compatible) — setSecurityModel after construction:**

```matlab
uaClient = opcua(serverUrl);
setSecurityModel(uaClient, "Sign", "Basic256Sha256");
```

### 3. Handle certificate trust (if needed)

If the server's certificate is not yet trusted by MATLAB, the connection
will fail. See the Certificate Trust Workflows section below.

### 4. Connect

```matlab
connect(uaClient);
```

### 5. Verify

```matlab
if isConnected(uaClient)
    fprintf("Connected to %s\n", uaClient.EndpointUrl);
end
```

### 6. Disconnect when done

```matlab
disconnect(uaClient);
```

## `connect` Function — Valid Signatures

There are exactly **three** valid forms. No other syntax exists.

| Form | Syntax | Authentication |
|------|--------|---------------|
| Anonymous | `connect(uaClient)` | No credentials |
| Username/Password | `connect(uaClient, userName, password)` | Positional strings |
| Certificate | `connect(uaClient, publicKeyFile, privateKeyFile, privateKeyPassword)` | Positional strings |

**There are NO Name-Value pair arguments to `connect`.** Security
configuration is done via `opcua()` NV pairs or `setSecurityModel` —
never through `connect`.

```matlab
% CORRECT: username/password as positional arguments
connect(uaClient, "opctest", "tester");

% CORRECT: certificate as positional arguments
connect(uaClient, "C:/certs/user.der", "C:/certs/user.key", "keypass");

% WRONG — these do NOT exist:
% connect(uaClient, Username="opctest", Password="tester")
% connect(uaClient, "None")
% connect(uaClient, "Sign", "Basic256Sha256")
```

## `opc.ua.Client` Properties

| Property | Type | Description |
|----------|------|-------------|
| `Hostname` | string | Server hostname |
| `Port` | double | Server port |
| `Name` | string | Client name |
| `EndpointUrl` | string | Selected endpoint URL |
| `DiscoveryURL` | string | Discovery URL used |
| `Status` | string | Connection status |
| `ServerState` | string | Server state |
| `Timeout` | double | Connection timeout (seconds) |
| `MessageSecurityMode` | enum | Active security mode |
| `ChannelSecurityPolicy` | enum | Active channel policy |
| `UserAuthTypes` | cell | Available auth types on server |
| `Endpoints` | array | Available endpoint descriptions |
| `Namespace` | cell | Server namespace table |

**`opc.ua.Client` does NOT have these properties (commonly hallucinated):**
`UserName`, `Password`, `IsConnected`, `Security`, `SecurityMode`,
`SecurityPolicy`, `Certificate`, `PrivateKey`.

Use `isConnected(uaClient)` (method) to check connection status.

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `opcua` | Create OPC UA client | R2015b |
| `connect` | Connect to server | R2015b |
| `disconnect` | Disconnect from server | R2015b |
| `isConnected` | Check connection status | R2015b |
| `setSecurityModel` | Configure security mode/policy | R2020a |
| `opc.ua.exportClientCertificate` | Export MATLAB client cert to file | R2020a |
| `opc.ua.trustServerCertificate` | Trust a server cert (file path) | R2026a |
| `opc.ua.rejectServerCertificate` | Reject a server cert (file path) | R2026a |

## Certificate Trust Workflows

### Server certificate not trusted by MATLAB client

**R2026a+ (preferred):**

```matlab
serverCertPath = "C:/OPCUAServer/PKI/own/certs/server_cert.der";
opc.ua.trustServerCertificate(serverCertPath);
```

`opc.ua.trustServerCertificate` takes exactly **one argument**: the full
file path to the server's `.der` certificate. NOT a client object, NOT a
URL, NOT a hostname.

**Pre-R2026a:** Manually copy the server's `.der` certificate into
MATLAB's OPC UA client trusted certificate store. The store location is
platform-dependent; use `fullfile(prefdir, "OPC UA", "pki", "trusted",
"certs")` to find it.

### MATLAB client certificate not trusted by server

1. Export the MATLAB client certificate:

```matlab
certFile = opc.ua.exportClientCertificate("SHA256", "matlab_client.der");
```

2. Copy the exported `.der` file to the server's trusted cert store:
   - If the server put it in its **rejected** folder: move from
     `<ServerPKI>/rejected/certs/` to `<ServerPKI>/trusted/certs/`
   - If the server has **no rejected cert**: manually copy the exported
     file to `<ServerPKI>/trusted/certs/`

See [references/certificate-trust-workflows.md](references/certificate-trust-workflows.md)
for detailed procedures, common server PKI paths, and certificate
inspection techniques.

## Patterns

### Connect with default (highest) security

```matlab
serverUrl = "opc.tcp://myserver:53530/OPCUA/SimulationServer";
uaClient = opcua(serverUrl);
connect(uaClient);
```

No explicit security configuration needed — `opcua` auto-selects the
highest available security mode and channel policy.

### Connect with username and password

```matlab
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer");
connect(uaClient, "myuser", "mypassword");
```

### Connect with user certificate

```matlab
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer");
connect(uaClient, "C:/certs/user.der", "C:/certs/user.key", "keypassword");
```

### Fix hostname mismatch warning (R2025a+)

When the server advertises an endpoint with a different hostname (e.g.,
FQDN) than what you provided:

```matlab
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer", ...
    UseDiscoveryHostname=true);
connect(uaClient);
```

**Pre-R2025a:** Use the FQDN directly, or resolve via `opcuaserverinfo`:

```matlab
serverInfo = opcuaserverinfo("myserver");
uaClient = opcua(serverInfo(1));
connect(uaClient);
```

### Configure specific security (R2025a+ preferred)

```matlab
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer", ...
    MessageSecurityMode="SignAndEncrypt", ...
    ChannelSecurityPolicy="Aes256_Sha256_RsaPss");
connect(uaClient);
```

### Configure specific security (R2020a+ backward-compatible)

```matlab
uaClient = opcua("opc.tcp://myserver:53530/OPCUA/SimulationServer");
setSecurityModel(uaClient, "SignAndEncrypt", "Aes256_Sha256_RsaPss");
connect(uaClient);
```

## Security Conventions

- **`opcua()` defaults to the highest available security.** Do not
  explicitly set "Best" or the highest mode unless documenting intent.
- **Do not move or copy certificate files without user confirmation.**
  Tell the user which file to move and where, then execute only after
  they confirm.

### Resolving Certificate Trust Issues

Always follow this order of preference. Do not skip steps.

**MATLAB client does not trust the server certificate (R2026a+):**

Prior to R2026a, MATLAB does not validate server certificates, so this
trust-failure scenario does not arise.

**Default fix:** `opc.ua.trustServerCertificate(certPath)` — permanently
trusts the server certificate on the MATLAB client side. This is a
one-liner that runs in under a second. It is always the correct first
action.

**Only if the cert file is unavailable** (cannot locate the `.der` file
and it cannot be obtained): `opcua(..., "TrustServerTemporarily", true)`.
Applies only to the MATLAB client trusting the server certificate, not
vice versa.

**Only after user explicitly confirms they want no security:**
`setSecurityModel(uaClient, "None", "None")` or the equivalent NV pair
form. Suggest this option and execute only after user confirmation that
the environment is trusted.

Do NOT infer that user urgency, frustration, demo deadlines, or
statements like "I don't care about security" authorize skipping to the
fallback options. `opc.ua.trustServerCertificate` is equally fast — it
is a single one-liner and takes less than one second. Present it first
and complete it. Only escalate when it is technically infeasible (the
cert file cannot be found), not because the user sounds impatient.

**Server does not trust the MATLAB client certificate:**

1. Ask the user to copy the MATLAB client certificate from the server's
   `rejected/certs/` to `trusted/certs/`. Execute file operations only
   after user confirmation.
2. Disable security — same as step 3 above, only after user confirms.

Do not offer `TrustServerTemporarily` for the server-trusting-client
direction — it only controls whether the MATLAB client trusts the
server, so it is irrelevant here and must not be mentioned to the user
in this scenario.

**Do not skip to the disable-security option.** Always present the
secure approach first and proceed to the next step only if it is not
feasible.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `connect(uaClient, "Username", "user", "Password", "pass")` | NV pairs not supported by `connect` | `connect(uaClient, "user", "pass")` |
| `uaClient.UserName = "user"` | Property does not exist | `connect(uaClient, "user", "pass")` |
| `connect(uaClient, "None")` | Not a valid syntax | `setSecurityModel(uaClient, "None", "None")` |
| `connect(uaClient, "Sign", "Basic256Sha256")` | Security not set via connect | `setSecurityModel(uaClient, "Sign", "Basic256Sha256")` |
| `opc.ua.trustServerCertificate(uaClient)` | Accepts file path, not client | `opc.ua.trustServerCertificate("path/to/cert.der")` |
| `opc.ua.trustServerCertificate(serverUrl)` | Accepts file path, not URL | `opc.ua.trustServerCertificate("path/to/cert.der")` |
| `setSecurityModel(uaClient, "None", "None")` as first fix | Disables all security | Fix cert trust first; `None` only as last resort |
| `TrustServerTemporarily=true` as primary fix | Skips validation entirely | Use `opc.ua.trustServerCertificate` (R2026a+) |
| Skipping to `None`/`None` or `TrustServerTemporarily` because user sounds frustrated | User urgency is not a security waiver | Always try `opc.ua.trustServerCertificate` (R2026a+) first — it is equally fast (one-liner, <1 s) |
| `uaClient.MessageSecurityMode = "Sign"` | Property has protected SetAccess | Use `opcua()` NV pairs or `setSecurityModel` |
| Explicit `setSecurityModel(uaClient, "Best")` | Redundant — already the default | Just `opcua(url)` + `connect(uaClient)` |
| Reusing an existing client after server security policy changes | `opcua()` caches the server's endpoint list at construction; policy changes on the server are not reflected in the existing object | Recreate the client with `uaClient = opcua(url)` to discover the updated policies |

## Troubleshooting

For detailed error-to-fix mapping see
[references/troubleshooting-connection-errors.md](references/troubleshooting-connection-errors.md).

Quick reference for common errors:

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| "Server certificate not trusted" | Server cert not in MATLAB trust store | `opc.ua.trustServerCertificate(certPath)` |
| "Client certificate rejected" | MATLAB cert not in server trust store | Export via `opc.ua.exportClientCertificate`, add to server |
| "BadIdentityTokenRejected" | Wrong credentials or auth type disabled | Check `uaClient.UserAuthTypes` for available types |
| "Hostname mismatch" warning | Short name vs FQDN | `UseDiscoveryHostname=true` (R2025a+) |
| "BadSecurityChecksFailed" | Cert compliance / policy mismatch | Run `inspectOpcUaCertificate` (see Certificate Inspection below) |

### Certificate Inspection

Whenever you need to read fields from an OPC UA `.der` certificate —
checking key length, signature algorithm, key usage, ApplicationUri,
validity, end-entity status, or any other compliance attribute — run
the [`scripts/inspectOpcUaCertificate.m`](scripts/inspectOpcUaCertificate.m)
script directly. Do **not** write ad-hoc cert parsing or shell out to
system tools directly.

```matlab
inspectOpcUaCertificate("path/to/server_cert.der");
```

The script reports PASS/FAIL on the OPC UA Part 6 §6.2.2 fields:
RSA key length (≥2048), signature algorithm (SHA-256+),
key usage (DigitalSignature, NonRepudiation, KeyEncipherment,
DataEncipherment), Subject Alternative Name (URI ApplicationUri),
validity, and Basic Constraints (end-entity). See
[references/certificate-trust-workflows.md](references/certificate-trust-workflows.md)
for backend details and SAN type codes.

----

Copyright 2026 The MathWorks, Inc.

----
