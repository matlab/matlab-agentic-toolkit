---
name: python-spkg-install-troubleshooting
description: Diagnose and fix install-time / first-run failures for Python-backed Scenario Builder support packages (RVLD lane detector via laneBoundaryDetector(Model="RVLD"), TripoSR via imageAssetGenerator). Covers the three customer-reported failure modes — proxy block, SSL connection error, PyTorch read timeout — and the documented fixes. REACTIVE: load this only when MATLAB reports a recognizable install symptom.
---

# Python Support Package Install Troubleshooting

> **Parent skill:** [`SKILL.md`](../SKILL.md). **Reactive reference** — load this when the user reports a Python-SPKG install failure or first-run download failure on:
> - `laneBoundaryDetector(Model="RVLD")` — Workflow 8 (lane localization)
> - `imageAssetGenerator` (TripoSR) — Workflow 12 (3D asset generation)
> - Any other Python-backed Scenario Builder support package that downloads PyTorch / 3P Python wheels at install or first run.
>
> **Do NOT** preemptively dump this content. Only surface the relevant row when the symptom appears in MATLAB's error/log output.

## Why these failures happen

RVLD and `imageAssetGenerator` (TripoSR) are **Python-backed** models. Installing or first-running them downloads third-party Python packages (notably PyTorch) from PyPI / `download.pytorch.org`. That download is what fails on customer networks.

## Symptom → Fix matrix

Match the **literal substring** in the customer's MATLAB error output or SPKG install log to one of these rows. If multiple rows match, fix in the order listed.

| Symptom (substring in error / log) | Root cause | Fix |
|---|---|---|
| `proxyError`, `ProxyError`, `Cannot connect to proxy`, or any 407 / proxy-related connection failure during pip / SPKG install | Customer's corporate network blocks direct outbound HTTPS; pip cannot reach PyPI / `download.pytorch.org`. | Set `http_proxy` and `https_proxy` environment variables to the customer's proxy URL **before** retrying the SPKG install. See "Setting proxy env vars" below. |
| `SSL: CERTIFICATE_VERIFY_FAILED`, `SSLError`, `SSLConnectionError`, or any TLS / certificate handshake failure | Same root cause as the proxy case — the customer's network intercepts TLS and pip rejects the substituted cert. The proxy variables route pip through the corporate gateway that owns the cert chain. | Same fix as the proxy row: set `http_proxy` and `https_proxy`. Reinstall the SPKG. |
| `ReadTimeoutError: HTTPSConnectionPool(host='download.pytorch.org', port=443): Read timed out` (or any PyTorch / PyPI read timeout) | PyPI or `download.pytorch.org` is slow or transiently unavailable. Default pip timeout is too short for the PyTorch wheel on a slow link. | **Reinstall the SPKG.** The retry usually succeeds because the slow / unavailable mirror has caught up. Customers have resolved this by simply re-running the SPKG install. |

## Setting proxy environment variables

Set these **before** launching MATLAB (or before re-running the SPKG installer), in the same shell that will execute pip:

**Windows (cmd.exe / PowerShell):**
```cmd
set http_proxy=http://<proxy-host>:<port>
set https_proxy=http://<proxy-host>:<port>
```
PowerShell:
```powershell
$env:http_proxy  = "http://<proxy-host>:<port>"
$env:https_proxy = "http://<proxy-host>:<port>"
```

**macOS / Linux (bash / zsh):**
```bash
export http_proxy=http://<proxy-host>:<port>
export https_proxy=http://<proxy-host>:<port>
```

If the proxy needs authentication, use `http://<user>:<password>@<proxy-host>:<port>`. Get the proxy URL from the customer's IT / network team — do not guess.

After setting, **re-run the SPKG install** from the Add-Ons explorer or the install command shown in the original error.

## What to ASK the user

If you do not yet have enough info to pick a row, ASK one direct question:

> "The Python support package install failed. Can you paste the **full error message** from MATLAB (or the path to the SPKG install log)? I am looking for one of three patterns: a proxy/SSL connection error (corporate-network gateway), or a `ReadTimeoutError` from `download.pytorch.org` (slow PyPI mirror)."

Do NOT recommend a fix until you have matched the literal symptom. Guessing wastes a 10–30 minute reinstall cycle.

## Verification after the fix

After applying the fix and reinstalling the SPKG, verify the model works before continuing the user's actual scenario task:

```matlab
% Verify RVLD installed (Workflow 8)
try
    detector = laneBoundaryDetector(Model="RVLD");
    fprintf("RVLD installed.\n");
catch ME
    fprintf("RVLD still failing: %s\n", ME.message);
end
```

```matlab
% Verify imageAssetGenerator installed (Workflow 12)
try
    assetGen = imageAssetGenerator;
    fprintf("imageAssetGenerator (TripoSR) installed.\n");
catch ME
    fprintf("imageAssetGenerator still failing: %s\n", ME.message);
end
```

If the verification still fails after the fix, escalate — there is a customer-network specific issue that needs IT involvement, not a generic retry.

## When this is the wrong reference

| Situation | Where to go instead |
|---|---|
| User has not even attempted to install — they are asking generally about RVLD | Workflow 8 (RVLD section). |
| User has not even attempted to install — they are asking generally about `imageAssetGenerator` / TripoSR | Workflow 12. |
| The error is a MATLAB-side runtime error (e.g., `imageToVehicle` out-of-bounds) AFTER the model loaded successfully | The relevant workflow file's "Pitfalls" section, not this reference. |
| Customer cannot get the proxy URL from IT, or the proxy requires NTLM / SSO authentication that pip cannot handle | This is beyond the documented fixes — escalate to MathWorks support with the customer's network details. Do NOT recommend disabling SSL verification or pinning fake certs. |

----

Copyright 2026 The MathWorks, Inc.

----
