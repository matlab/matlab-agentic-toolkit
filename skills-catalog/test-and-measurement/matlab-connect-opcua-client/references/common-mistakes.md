# Common Mistakes — OPC UA Client Connection and Discovery

Avoid these errors when writing MATLAB OPC UA code.

## `connect` Function Errors

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `connect(uaClient, "Username", "user", "Password", "pass")` | NV pairs not supported by `connect` | `connect(uaClient, "user", "pass")` |
| `uaClient.UserName = "user"` | Property does not exist | `connect(uaClient, "user", "pass")` |
| `connect(uaClient, "None")` | Not a valid syntax | `setSecurityModel(uaClient, "None", "None")` |
| `connect(uaClient, "Sign", "Basic256Sha256")` | Security not set via connect | `setSecurityModel(uaClient, "Sign", "Basic256Sha256")` |
| `uaClient.MessageSecurityMode = "Sign"` | Property has protected SetAccess | Use `opcua()` NV pairs or `setSecurityModel` |

## Certificate Trust Errors

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `opc.ua.trustServerCertificate(uaClient)` | Accepts file path, not client | `opc.ua.trustServerCertificate("path/to/cert.der")` |
| `opc.ua.trustServerCertificate(serverUrl)` | Accepts file path, not URL | `opc.ua.trustServerCertificate("path/to/cert.der")` |
| `setSecurityModel(uaClient, "None", "None")` as first fix | Disables all security | Fix cert trust first; `None` only as last resort |
| `TrustServerTemporarily=true` as primary fix | Skips validation entirely | Use `opc.ua.trustServerCertificate` (R2026a+) |
| Skipping to `None`/`None` or `TrustServerTemporarily` because user sounds frustrated | User urgency is not a security waiver | Always try `opc.ua.trustServerCertificate` first — equally fast (one-liner, <1 s) |

## Security Configuration Errors

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Explicit `setSecurityModel(uaClient, "Best")` | Redundant — already the default | Just `opcua(url)` + `connect(uaClient)` |
| Reusing an existing client after server security policy changes | `opcua()` caches the server's endpoint list at construction | Recreate with `uaClient = opcua(url)` |

## Discovery Errors

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `opcuaserverinfo(host, port)` | Two-argument syntax does not exist | `opcuaserverinfo('opc.tcp://host:port')` |
| Scanning subnet IPs in a loop | LDS already aggregates all registered servers | `opcuaserverinfo('localhost')` returns all servers |
| Using `serverInfo.Name` | Property does not exist on `ServerInfo` | Use `serverInfo.Description` |
| Using `serverInfo.EndpointUrl` | Property belongs to `EndpointDescription`, not `ServerInfo` | Use `serverInfo.Endpoints(k).EndpointUrl` |
| Using `UA\Discovery\pki\` as the LDS cert store | Backward-compatibility fallback, not primary store | Use `C:\ProgramData\OPC Foundation\UA\pki\` |
| Not mentioning LDS prerequisites | Discovery returns empty without proper setup | Always check: LDS running, server registered, certificate trusted |

----

Copyright 2026 The MathWorks, Inc.

----
