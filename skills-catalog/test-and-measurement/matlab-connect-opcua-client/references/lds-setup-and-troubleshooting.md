# LDS Setup and Troubleshooting

## OPC UA Local Discovery Service (LDS)

The LDS is a Windows service that aggregates information about all OPC UA
servers registered on a machine. Servers register themselves with the LDS,
and clients query the LDS to find all available servers via a single call.

### Windows Service

| Item | Value |
|------|-------|
| Service name | `UALDS` |
| Display name | OPC UA Local Discovery Server |
| Default port | 4840 |
| Executable | `C:\Program Files (x86)\Common Files\OPC Foundation\UA\Discovery\bin\opcualds.exe` |
| Config file | `C:\ProgramData\OPC Foundation\UA\Discovery\ualds.ini` |

### Service management commands (run as Administrator)

```
sc query UALDS          -- check status
net start UALDS         -- start service
net stop UALDS          -- stop service
net stop UALDS && net start UALDS  -- restart
```

## Filesystem Paths (Windows)

### LDS Log

| Item | Path |
|------|------|
| Log file | `C:\ProgramData\OPC Foundation\UA\Discovery\opcualds.log` |
| Log level | Configured in `ualds.ini` under `[Log]` section |
| Max size | 100 MB (rotates to 2 files) |

**Important:** The log is directly at `C:\ProgramData\OPC Foundation\UA\Discovery\opcualds.log`.
There is no `Logs\` subdirectory.

### LDS Certificate Store

| Store | Path |
|-------|------|
| Trusted certificates | `C:\ProgramData\OPC Foundation\UA\pki\trusted\certs\` |
| Trusted CRLs | `C:\ProgramData\OPC Foundation\UA\pki\trusted\crl\` |
| Rejected certificates | `C:\ProgramData\OPC Foundation\UA\pki\rejected\certs\` |
| Own certificate | `C:\ProgramData\OPC Foundation\UA\pki\own\certs\ualdscert.der` |
| Own private key | `C:\ProgramData\OPC Foundation\UA\pki\own\private\ualdskey.nopass.pem` |
| Issuer certificates | `C:\ProgramData\OPC Foundation\UA\pki\issuer\certs\` |

**Important:** The primary PKI store is at `C:\ProgramData\OPC Foundation\UA\pki\`
(has both `trusted\` and `rejected\` folders). A `pki\` folder may also exist under
`UA\Discovery\` — this is a backward-compatibility fallback from older LDS deployments
and only contains a `trusted\` folder. Always place certificates in `UA\pki\trusted\certs\`.

## Prerequisites for LDS-Based Discovery

All three must be satisfied for `opcuaserverinfo(hostname)` to return results:

### 1. LDS is installed and running

```
sc query UALDS
```

If not installed, download from the OPC Foundation website or install with your
OPC UA server software (many servers include LDS as an optional component).

### 2. Server is registered with the LDS

The OPC UA server must be configured to register with the LDS on
`opc.tcp://localhost:4840`. Most servers have a "Register with Local
Discovery Server" or "Enable LDS Registration" setting in their
configuration UI.

Registration expires every 10 minutes (600 seconds) — the server must
periodically re-register.

### 3. Server certificate is trusted by the LDS

The LDS validates the server's certificate during registration. If the
certificate is not trusted, registration is silently rejected and the
server will not appear in discovery results.

## Troubleshooting Empty Discovery Results

When `opcuaserverinfo('localhost')` returns empty:

### Step 1: Verify LDS is running

```matlab
[status, result] = system('sc query UALDS');
if contains(result, 'RUNNING')
    disp('LDS is running.');
else
    disp('LDS is NOT running. Start with: net start UALDS');
end
```

### Step 2: Check LDS log for errors

```matlab
logPath = 'C:\ProgramData\OPC Foundation\UA\Discovery\opcualds.log';
if isfile(logPath)
    logContent = fileread(logPath);
    if contains(logContent, 'CertificateUntrusted')
        disp('Certificate trust issue found in LDS log.');
    end
end
```

Look for `CertificateUntrusted` errors — this means the server's certificate
is not in the LDS trusted store.

### Step 3: Trust the server certificate

1. Find the rejected certificate in `C:\ProgramData\OPC Foundation\UA\pki\rejected\certs\`
2. Copy the `.der` file to `C:\ProgramData\OPC Foundation\UA\pki\trusted\certs\`
3. Restart the LDS service: `net stop UALDS && net start UALDS`
4. Wait 10 seconds for the server to re-register
5. Retry: `opcuaserverinfo('localhost')`

### Step 4: Verify server registration

If the certificate is trusted but discovery is still empty:
- Confirm the server is configured to register with LDS
- Check that the server is actually running
- Verify the LDS config allows registration (`AllowLocalRegistration = yes`
  in `ualds.ini` for development environments)

### Alternative: Bypass LDS with direct discovery

If LDS setup is not feasible, query the server directly using its endpoint URL:

```matlab
serverInfo = opcuaserverinfo('opc.tcp://hostname:port/path');
```

This works only when the server implements its own discovery service and you
know the exact endpoint URL.

----

Copyright 2026 The MathWorks, Inc.

----
