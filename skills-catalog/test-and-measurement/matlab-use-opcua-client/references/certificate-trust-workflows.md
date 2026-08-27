# Certificate Trust Workflows

Detailed procedures for resolving certificate trust issues in OPC UA
client connections.

## Server Certificate Not Trusted by MATLAB Client

### Symptoms

- Error: "The server certificate is not trusted by the client"
- Error: "BadSecurityChecksFailed" during `connect`

### Locate the Server's Application Instance Certificate

The server's own certificate (NOT the LDS certificate) lives in the
server's PKI folder under `own/certs/`:

| Server | Certificate Location |
|--------|---------------------|
| Prosys Simulation Server | `~/.prosysopc/prosys-opc-ua-simulation-server/PKI/own/certs/` |
| Unified Automation | `C:/ProgramData/UnifiedAutomation/<Server>/PKI/own/certs/` |
| Kepware KEPServerEX | `C:/ProgramData/Kepware/KEPServerEX/V6/UA/PKI/own/certs/` |
| open62541 | Configured at build time; check server config |

The certificate is typically a `.der` file named after the server
application (e.g., `SimulationServer@hostname_2048.der`).

**Do NOT confuse with:**
- `C:/ProgramData/OPC Foundation/UA/pki/` — this is the **LDS** trust
  store, not the server's own certificate
- `<ServerPKI>/trusted/certs/` — these are certs the server trusts, not
  the server's own cert

### Fix: Trust the Server Certificate (R2026a+)

```matlab
serverCertPath = "C:/path/to/server_certificate.der";
opc.ua.trustServerCertificate(serverCertPath);
```

This copies the certificate into MATLAB's internal trusted store. It is
a one-time operation — subsequent connections will succeed.

### Fix: Trust the Server Certificate (pre-R2026a)

Manually copy the server's `.der` certificate to MATLAB's trusted store:

```matlab
matlabTrustStore = fullfile(prefdir, "OPC UA", "pki", "trusted", "certs");
if ~isfolder(matlabTrustStore)
    mkdir(matlabTrustStore);
end
copyfile("C:/path/to/server_certificate.der", matlabTrustStore);
```

After copying, reconnect — no MATLAB restart required.

## MATLAB Client Certificate Not Trusted by Server

### Symptoms

- Error: "BadIdentityTokenRejected"
- Error: "The user identity token is not valid" (when Anonymous is
  disabled and cert-based is required)
- Server logs show "Certificate rejected" with MATLAB/MathWorks in the
  subject

### Scenario A: Server Has the Cert in Its Rejected Folder

After a failed connection attempt, most servers store the rejected
client certificate in `<ServerPKI>/rejected/certs/`.

**Fix:** Move the file from `rejected/certs/` to `trusted/certs/` on the
server:

| Server | Rejected Path | Trusted Path |
|--------|--------------|--------------|
| Prosys | `~/.prosysopc/.../PKI/rejected/certs/` | `~/.prosysopc/.../PKI/trusted/certs/` |
| UA CPP | `.../PKI/rejected/certs/` | `.../PKI/trusted/certs/` |
| Kepware | `.../UA/PKI/rejected/certs/` | `.../UA/PKI/trusted/certs/` |

**Note:** Servers maintain separate stores for application instance
certificates and user identity certificates:

| Server | Application Instance Cert Store | User Identity Cert Store |
|--------|-------------------------------|--------------------------|
| Prosys | `~/.prosysopc/.../PKI/CA/` | `~/.prosysopc/.../USERS_PKI/CA/` |
| UA CPP | `C:/ProgramData/UnifiedAutomation/<Server>/pkiserver/` | `.../pkiuser/` |

When connecting with `connect(uaClient, publicKey, privateKey, password)`,
the user certificate must be trusted in the **user cert store**, not the
application instance cert store.

### Scenario B: Server Does NOT Have the Cert

If the server never received the certificate (first connection attempt
with security disabled, or server was reconfigured):

```matlab
certFile = opc.ua.exportClientCertificate("SHA256", "matlab_client.der");
fprintf("Exported to: %s\n", certFile);
```

Then manually copy the exported `.der` file to the server's
`<ServerPKI>/trusted/certs/` folder.

**Note:** Use `"SHA256"` for modern servers. Use `"SHA1"` only for
legacy servers that don't support SHA-256 certificates.

## Certificate Inspection

When connection fails with `BadSecurityChecksFailed` and the cause is
unclear, inspect the certificate for OPC UA compliance issues.

**Script:** [`scripts/inspectOpcUaCertificate.m`](../scripts/inspectOpcUaCertificate.m)

Run it directly via `mcp__matlab__run_matlab_file` — no need to
regenerate or copy the code:

```matlab
inspectOpcUaCertificate("C:/path/to/server_cert.der")
```

The script dispatches to `openssl` when available and falls back to
the Java X.509 API otherwise. If neither backend is available, it
raises a clear `inspectOpcUaCertificate:NoBackend` error with
installation guidance.

**Reports PASS/FAIL on:**
- RSA key length (>= 2048 bits)
- Signature algorithm (SHA-256+)
- Key Usage (DigitalSignature, NonRepudiation, KeyEncipherment, DataEncipherment)
- Subject Alternative Name (URI with ApplicationUri)
- Validity (not expired, not future-dated)
- Basic Constraints (CA=false, end-entity)

**SAN type codes** (Java fallback): `0=otherName`, `1=rfc822Name`,
`2=dNSName`, `4=directoryName`, `6=uniformResourceIdentifier`,
`7=iPAddress`. OPC UA application certs require type `6`
(`urn:<host>:OPCUA:<AppName>`). The openssl path prints the SAN line
verbatim (`URI:urn:..., DNS:...`).

## OPC UA Certificate Requirements (Part 6, Section 6.2.2)

| Field | Requirement |
|-------|-------------|
| RSA Key Length | >= 2048 bits (Basic256Sha256); >= 4096 (Aes256_Sha256_RsaPss) |
| Signature Algorithm | SHA-256 or stronger |
| Key Usage | digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment |
| Extended Key Usage | serverAuth (servers), clientAuth (clients) |
| Subject Alternative Name | URI matching ApplicationUri; DNS matching endpoint hostname |
| Basic Constraints | CA=false (end-entity certificate) |
| Validity | Not expired, not future-dated |

----

Copyright 2026 The MathWorks, Inc.

----
