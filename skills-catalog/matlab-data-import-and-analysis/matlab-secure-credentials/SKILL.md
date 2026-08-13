---
name: matlab-secure-credentials
description: >
  Store, retrieve, and pass credentials securely in MATLAB using the built-in
  MATLAB Vault (setSecret, getSecret, importSecrets, secretID) instead of hardcoding.
  Handles connections to any authenticated service: REST APIs, databases, cloud
  storage (S3/Azure/GCS), SFTP, and others.
  Covers API keys, tokens, passwords, SSH passphrases, CI/batch/scheduled jobs,
  and "keep credentials out of code" requests.
  Does NOT cover third-party secret managers (HashiCorp Vault, AWS Secrets Manager),
  OS-level key management, or the connection/query logic itself.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Secure Credentials in MATLAB

Handle API keys, tokens, passwords, and passphrases with the **MATLAB Vault**, an
encrypted store built into MATLAB, instead of hardcoding them. This skill covers
*the credential* — storing it, retrieving it, and passing it into a connection to
any authenticated service.

## When to Use

- Connecting to any authenticated service or connection from MATLAB — a REST API,
  database, cloud storage, SFTP/FTP server, message queue, or any other.
- Any code that handles an API key, bearer token, password, or SSH key passphrase.
- Writing CI / batch / scheduled MATLAB that needs credentials with no user present.
- Refactoring credential-handling code, or persisting a config that includes a secret.
- A request to "keep credentials out of code," "don't commit secrets," or "do this
  the secure way."

## When NOT to Use

- Writing the connection/query/transfer logic itself when no credential is involved
  (e.g. a public API, a local file), or cleaning/transforming/aggregating data once it is
  in a table or timetable — use the relevant data-import skill (e.g. `matlab-analyze-data`,
  `matlab-use-database`).
- Integrating a third-party secret manager (HashiCorp Vault, AWS Secrets Manager,
  Azure Key Vault) — out of scope.
- OS-level or non-MATLAB key management.

## Decision Guide: Which Mechanism

Pick the mechanism by how the credential is supplied, not by habit.

| Situation | Use | Not |
|-----------|-----|-----|
| Credential is stored and reused across sessions | `setSecret` once, then `getSecret` at use | Hardcoding; a hand-rolled config file |
| You need to load a set of credentials at once (interactive setup, or non-interactive / CI / headless / scheduled) | `importSecrets` to populate the vault from a secrets file, then `getSecret`; or, in CI, `getenv` for a runner-injected value | `setSecret` in a headless job — it is only supported interactively |
| A function accepts credentials from a caller | `secretID` (a reference to the secret, not its value) | Storing the value in a struct field or argument |
| Credential is genuinely a process environment variable — a CI-injected secret, or a cloud SDK convention like `AWS_ACCESS_KEY_ID` | `getenv` — this is correct | Duplicating it into the vault for no reason |

The rule is **don't hardcode secrets** — not "never use environment variables." `getenv` is
the right tool when the secret is already a process env var; the vault is the right default
for credentials *you* store.

## Workflow

1. **Decide the mechanism** using the Decision Guide above.
2. **Store or populate** the credential:
   - Single secret, interactively: `setSecret("MyApiToken")` (MATLAB prompts for the value —
     never pass it as an argument; it takes only the name).
   - A set of secrets at once: `importSecrets("secrets.env")` loads names+values into the
     vault with no prompt — handy both for interactive setup and for non-interactive/CI.
3. **Retrieve at point of use** with `getSecret("MyApiToken")`, or hand a
   `secretID("MyApiToken")` to APIs that accept one (they resolve it at call time, so the
   value never lives in a variable).
4. **Wire it into the connection** — see Patterns below.
5. **Verify** with `isSecret("MyApiToken")` before reading or removing, and confirm no
   secret value appears in the script, logs, or any saved file.

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `setSecret` | Add a secret to the vault; **interactive** — prompts for the value, takes only the name (`Overwrite=true` to update) | R2024a |
| `getSecret` | Retrieve a secret value (returns a string scalar) | R2024a |
| `isSecret` | Check whether a named secret exists | R2024a |
| `listSecrets` | List the names of stored secrets | R2024a |
| `removeSecret` | Delete a secret from the vault (there is **no** `deleteSecret`) | R2024a |
| `setSecretMetadata` | Attach metadata (e.g. an expiry date, owner) to a secret | R2024a |
| `getSecretMetadata` | Read a secret's metadata as a dictionary | R2024a |
| `secretID` | A reference object carrying a secret's *name*, not its value; accepted by `weboptions` and `matlab.net.http.Credentials` | R2025a |
| `importSecrets` | Load a set of secrets from a file into the vault (no prompt) | R2026a |

## Patterns

### Store once, retrieve at use

```matlab
% One-time, at the MATLAB prompt (prompts for the value — do NOT type the secret in code):
setSecret("MyApiToken");

% In your script, read it only where needed:
token = getSecret("MyApiToken");
```

Optionally record metadata such as an expiry so callers can check freshness before use:

```matlab
% Metadata values are stored in a dictionary; wrap each value in a cell:
setSecretMetadata("MyApiToken", dictionary("Expires", {datetime(2026,12,31)}));

md = getSecretMetadata("MyApiToken");
expiry = md{"Expires"};            % {} indexing returns the stored value
if expiry < datetime("today")
    error("MyApiToken expired on %s — rotate it with setSecret(...,Overwrite=true).", expiry);
end
token = getSecret("MyApiToken");
```

### Rotate or update a secret

`setSecret(...,Overwrite=true)` replaces the value of an existing secret — the normal way to
rotate a credential (replace it with a new value, e.g. periodically or after expiry). Without
`Overwrite`, `setSecret` errors on a name that already exists.

```matlab
setSecret("MyApiToken", Overwrite=true);   % prompts for the new value
```

### REST call with a bearer token

Fetch the token from the vault and set it in the `Authorization` header.

```matlab
token = getSecret("MyApiToken");
opts = weboptions( ...
    HeaderFields = ["Authorization", "Bearer " + token], ...
    ContentType  = "json");
data = webread("https://api.example.com/v1/data", opts);
```

For basic auth, hand `weboptions` a `secretID` so the value is resolved at request time
and never sits in a variable:

```matlab
username = getenv("API_USER");   % REPLACE: your service-account user name
opts = weboptions(Username=username, Password=secretID("MyApiPassword"));
data = webread("https://api.example.com/v1/data", opts);
```

For lower-level requests, `matlab.net.http.Credentials` also accepts a `secretID`:

```matlab
cred = matlab.net.http.Credentials(Password=secretID("MyApiPassword"));
```

### SFTP with a passphrase-protected key

```matlab
keyFile = fullfile(userpath, "id_rsa");   % REPLACE: path to your private key
s = sftp("sftp.example.com", "reportuser", ...
    PrivateKeyFile       = keyFile, ...
    PrivateKeyPassphrase = getSecret("SftpKeyPassphrase"));
c = onCleanup(@() close(s));
localPaths  = mget(s, "/reports/nightly.csv", tempdir);
reportTable = readtable(localPaths{1});
```

Password auth instead of a key:

```matlab
s = sftp("sftp.example.com", "reportuser", Password=getSecret("SftpPassword"));
```

### Database connection

Store the password in the vault and read it at connect time. Keep host/port/database in
code; keep the credential out.

```matlab
conn = postgresql("svc-account", getSecret("PgPassword"), ...
    Server       = "db-prod-01", ...
    PortNumber   = 5432, ...
    DatabaseName = "analytics");
c = onCleanup(@() close(conn));
tables = sqlfind(conn, "");
```

For a reusable, shareable setup, save a data source once (via the Database Explorer app or
`databaseConnectionOptions` + `saveAsDataSource`) and connect by name, supplying the
password from the vault:

```matlab
conn = postgresql("analyticsDataSource", "svc-account", getSecret("PgPassword"));
```

### Cloud storage (S3 / Azure Blob / GCS)

MATLAB's file I/O (`readtable`, `datastore`, etc.) reads cloud URIs directly and picks up
credentials from the SDK's environment variables. When you hold explicit keys, source them
from the vault and set the env vars the SDK expects; when running on cloud infrastructure,
prefer an attached IAM role and set nothing.

```matlab
% Explicit keys held in the vault -> set the SDK env vars from getSecret:
setenv("AWS_ACCESS_KEY_ID",     getSecret("AwsAccessKeyId"));
setenv("AWS_SECRET_ACCESS_KEY", getSecret("AwsSecretAccessKey"));
setenv("AWS_DEFAULT_REGION",    "us-east-1");   % REPLACE: bucket region
T = readtable("s3://acme-data/prices/latest.csv");
```

If the code runs on an EC2 instance / role-enabled environment, skip the keys entirely —
the IAM role supplies credentials and no secret needs to live anywhere.

### Passing a credential into a function

When a function accepts credentials from its caller, carry a `secretID` (a reference), never
the value. It resolves to the secret only where `getSecret` is called.

Build the config — it carries a reference, not the token:

```matlab
config = struct( ...
    "BaseUrl", "https://api.example.com/v1", ...
    "Token",   secretID("MyApiToken"));
```

Use the config inside the function — resolve the secret only at the point of use:

```matlab
function report = fetchReport(config)
    arguments
        config (1,1) struct
    end
    token = getSecret(config.Token.Name);
    opts  = weboptions(HeaderFields = ["Authorization", "Bearer " + token]);
    report = webread(config.BaseUrl + "/report", opts);
end
```

### Load a set of secrets at once (setup or CI)

`importSecrets` loads names+values from a secrets file into the vault with no prompt — useful
both for one-shot interactive setup and for headless jobs (where `setSecret` cannot be used,
since it is interactive-only).

```matlab
% secrets.env — a dotenv file (e.g. from CI secret storage), never committed — with lines like:
%   MyApiToken=abc123
%   PgPassword=hunter2
importSecrets("secrets.env");     % FileType="auto" (default) detects the dotenv format
token = getSecret("MyApiToken");
```

If the runner injects a credential directly as a process environment variable rather than a
file, `getenv("MY_TOKEN")` is the correct read — no vault needed.

## Conventions

- Always: reach for the vault (`setSecret`/`getSecret`) as the default for credentials you
  store; guard `removeSecret` with `isSecret`.
- Always: to load several secrets at once, or in any headless/CI context, use
  `importSecrets`, not `setSecret`.
- Never: hardcode a secret in a `.m` file, or write a secret *value* into a struct or a
  log — pass a `secretID` reference instead.
- Prefer: passing `secretID(...)` to `weboptions`/`Credentials` over materializing the
  value with `getSecret` when the API accepts a reference.
- Env vars are fine when the credential is genuinely a process env var (CI secret, cloud
  SDK convention) — don't over-correct into the vault where it adds nothing.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|------------------|
| Hardcoding a token/password in the `.m` file | Leaks into version control; rotates badly | `getSecret("Name")` from the vault |
| Writing a secret *value* into a struct field or argument a function passes around | Plaintext secret leaves the vault | Carry a `secretID` reference; resolve with `getSecret` at use |
| `setSecret` in a CI/batch/scheduled job | It is only supported interactively — no value can be entered | `importSecrets` populates the vault non-interactively |
| Calling `deleteSecret` | No such function exists | `removeSecret("Name")`, guarded by `isSecret` |
| Saving a credential to a `.mat` file with `save()` and reading it back with `load()` | Writes the plaintext secret to disk, unencrypted and often committed | Keep the value in the vault; persist only a `secretID` reference and resolve with `getSecret` at use |

## Errors and What They Mean

| Error identifier | When it occurs | Fix |
|------------------|----------------|-----|
| `MATLAB:authnz:secretapis:KeyAlreadyExists` — *"A secret named 'X' already exists. Set 'Overwrite' to true…"* | `setSecret("X")` when `X` is already in the vault | To rotate/update, call `setSecret("X", Overwrite=true)`; otherwise pick a new name |
| `MATLAB:authnz:secretapis:SecretValueNotFound` — *"No secret value found for secret name 'X'…"* | `getSecret("X")` when `X` was never stored (or the name is misspelled/wrong case) | Store it first (`setSecret`/`importSecrets`); guard reads with `isSecret("X")`. Secret names are case-sensitive |
| `MATLAB:authnz:secretapis:RemoveSecretFailed` — *"…No secret found for secret name 'X'."* | `removeSecret("X")` when `X` is not in the vault | Guard with `if isSecret("X"); removeSecret("X"); end` |

----

Copyright 2026 The MathWorks, Inc.

----
