# Troubleshooting OPC UA Connection Errors

Diagnose and resolve OPC UA client connection failures in MATLAB.

## Error-to-Fix Quick Reference

| Error Message | Root Cause | Fix |
|---------------|-----------|-----|
| "Server certificate not trusted" | Server cert not in MATLAB trust store | `opc.ua.trustServerCertificate(path)` (R2026a+) or manual copy |
| "Client certificate rejected" | MATLAB cert not in server trust store | `opc.ua.exportClientCertificate` then trust on server |
| "BadIdentityTokenRejected" | Wrong credentials or auth type not enabled | Check `uaClient.UserAuthTypes`; verify credentials |
| "BadSecurityChecksFailed" | Certificate compliance issue or policy mismatch | Inspect cert fields; check server logs |
| "Hostname mismatch" warning | Endpoint URL hostname differs from input | `UseDiscoveryHostname=true` (R2025a+) |
| "Unable to connect to endpoint" | Server down, wrong URL, or firewall | Verify server is running; check URL and port |
| "BadSecurityPolicyRejected" | Requested policy not supported by server | Query `uaClient.Endpoints` for available policies |
| "Connection timeout" | Network issue or server overloaded | Increase `uaClient.Timeout`; check network |

## Diagnostic Workflow

### Step 1: Verify server is reachable

```matlab
serverUrl = "opc.tcp://hostname:port/path";
uaClient = opcua(serverUrl);
fprintf("Status: %s\n", uaClient.Status);
fprintf("Endpoints found: %d\n", numel(uaClient.Endpoints));
```

If `opcua` itself fails, the server is unreachable — check URL, network,
and firewall before investigating security.

### Step 2: Check available security and auth types

```matlab
fprintf("Security Mode: %s\n", string(uaClient.MessageSecurityMode));
fprintf("Channel Policy: %s\n", string(uaClient.ChannelSecurityPolicy));
fprintf("Auth Types: %s\n", strjoin(string(uaClient.UserAuthTypes), ", "));
```

### Step 3: Attempt connection with timestamp

```matlab
attemptTime = datetime("now", Format="yyyy-MM-dd HH:mm:ss.SSS");
fprintf("Attempt at: %s\n", string(attemptTime));
try
    connect(uaClient);
    fprintf("Connected successfully.\n");
catch ME
    fprintf("Failed: %s\n", ME.message);
    fprintf("Search server logs near: %s\n", string(attemptTime));
end
```

### Step 4: Check server logs

Use the recorded timestamp to search server logs for the rejection
reason. The server-side message is almost always more specific than
MATLAB's client-side error.

## Server Log Locations

| Server Implementation | Log Location |
|----------------------|-------------|
| Prosys Simulation Server | `~/.prosysopc/prosys-opc-ua-simulation-server/logs/` |
| Prosys (alternative) | `C:/ProgramData/Prosys OPC UA Simulation Server/logs/` |
| Unified Automation UaGateway | `C:/ProgramData/UnifiedAutomation/UaGateway/logs/` |
| Unified Automation UaCPPServer | `C:/ProgramData/UnifiedAutomation/UaCPPServer/logs/` |
| Kepware KEPServerEX | `C:/ProgramData/Kepware/KEPServerEX/V6/Logs/` |
| open62541 (Linux) | stdout/stderr or `journalctl -u <service>` |
| Node-OPC UA | Console output (set `DEBUG=opcua*`) |

## Server Log Patterns and Fixes

| Log Pattern | Meaning | MATLAB Fix |
|-------------|---------|-----------|
| "Certificate not in trust list" | Server doesn't trust MATLAB's client cert | Export client cert, add to server's trusted store |
| "ApplicationUri mismatch" | Cert URI doesn't match session URI | Regenerate MATLAB cert: delete `fullfile(prefdir, "OPC UA", "pki", "own")` |
| "Security policy not supported" | Requested policy disabled on server | Use `setSecurityModel` with a supported policy |
| "Signature verification failed" | Corrupted key material | Delete `fullfile(prefdir, "OPC UA", "pki")` and reconnect |
| "Certificate expired" | Certificate validity period exceeded | Regenerate cert; check system clock sync |
| "User token rejected" | Bad credentials or auth type disabled | Verify credentials; check server user config |

## MATLAB OPC UA PKI Folder Structure

MATLAB stores its OPC UA client certificates and trust data in:

```
<prefdir>/OPC UA/pki/
├── own/
│   ├── certs/          <- MATLAB's client application certificates
│   └── private/        <- MATLAB's client private keys
├── trusted/
│   └── certs/          <- Server certs MATLAB trusts
└── rejected/
    └── certs/          <- Server certs MATLAB has rejected
```

Find the path with: `fullfile(prefdir, "OPC UA", "pki")`

## Common Debugging Scenarios

### Anonymous auth disabled but no credentials provided

```matlab
uaClient = opcua(serverUrl);
% Check what's available
disp(uaClient.UserAuthTypes);
% If Anonymous is not listed, must provide credentials:
connect(uaClient, "username", "password");
```

### Server only supports a specific security policy

```matlab
uaClient = opcua(serverUrl);
% Inspect available endpoints
for k = 1:numel(uaClient.Endpoints)
    ep = uaClient.Endpoints(k);
    fprintf("Endpoint %d: %s / %s\n", k, ...
        string(ep.MessageSecurityMode), string(ep.ChannelSecurityPolicy));
end
% Use a supported combination
setSecurityModel(uaClient, "Sign", "Basic256Sha256");
connect(uaClient);
```

### Certificate regeneration (nuclear option)

If nothing else works and you suspect corrupted MATLAB PKI state:

```matlab
pkiDir = fullfile(prefdir, "OPC UA", "pki");
fprintf("Removing PKI folder: %s\n", pkiDir);
rmdir(pkiDir, "s");
% MATLAB will regenerate certificates on next connection attempt
uaClient = opcua(serverUrl);
connect(uaClient);
```

This deletes all stored certificates and keys. MATLAB will generate
fresh ones on the next secure connection attempt. You will need to
re-trust the new client certificate on the server side.

----

Copyright 2026 The MathWorks, Inc.

----
