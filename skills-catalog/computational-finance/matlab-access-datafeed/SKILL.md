---
name: matlab-access-datafeed
description: >
  Guide for accessing financial and economic data in MATLAB using the Datafeed Toolbox.
  Covers Bloomberg (market data via bloomberg/blp/bloombergHypermedia), FRED (Federal Reserve
  economic data via fredrs), and Haver Analytics (economic data via haver/haverdirect/haverview).
  Use when connecting to any of these data providers from MATLAB.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# Datafeed Toolbox — Bloomberg, FRED, and Haver Analytics

Access financial and economic data from three major providers through the MATLAB Datafeed Toolbox.

## When to Use

- User wants to connect to **Bloomberg**, **FRED**, or **Haver Analytics** from MATLAB
- User needs to retrieve market data (prices, history, real-time, reference data) via Bloomberg
- User needs to retrieve economic time series from the St. Louis Fed (FRED)
- User needs to fetch economic/financial time series from Haver Analytics databases
- User needs help choosing between interfaces within a provider (e.g., bloomberg vs blp vs bloombergHypermedia, haver vs haverview)
- User is writing MATLAB code involving securities, economic indicators, or data provider connectivity

## When NOT to Use

- General financial modeling or portfolio optimization that doesn't involve data provider connectivity
- Bloomberg Terminal keyboard shortcuts or Excel add-in questions (not MATLAB)
- Data sources not covered here (e.g., Yahoo Finance, Reuters/Refinitiv)

## Provider Overview

| Provider | Data Type | Interfaces | Reference |
|----------|-----------|------------|-----------|
| Bloomberg | Market data (equities, fixed income, derivatives, indices) | `bloomberg`, `blp`, `bloombergHypermedia`, `bloombergEMSX` | `references/bloomberg.md` |
| FRED | U.S. economic data (GDP, unemployment, CPI, interest rates) | `fredrs` (replaces obsolete `fred`) | `references/fred.md` |
| Haver Analytics | Global economic & financial data (macro, industry, surveys) | `haver`, `haverdirect`, `haverview` | `references/haver.md` |

## Quick Interface Selection

### Bloomberg — see `references/bloomberg.md` for full API patterns
- **Windows Desktop/Terminal user** → `bloomberg` (C++)
- **Need platform independence (BPIPE)** → `bloombergBPIPE`
- **Server/cloud, no Terminal (Data License)** → `bloombergHypermedia`
- **Existing `blp` users** → migrate to `bloomberg` (same API, no Java needed)

### FRED — see `references/fred.md` for full API patterns
- **Any platform** → `fredrs` (requires R2026a+, API key)
- **`fred` is obsolete** — do NOT use it

### Haver Analytics — see `references/haver.md` for full API patterns
- **Windows with local data files** → `haver`
- **Windows needing remote access** → `haverdirect`
- **Non-Windows / server / cloud** → `haverview` (REST API)

## How to Use References

Before generating code for a specific provider, read the corresponding reference file for detailed API patterns, function signatures, gotchas, and examples:
- Working with Bloomberg data → read `references/bloomberg.md`
- Working with FRED economic data → read `references/fred.md`
- Working with Haver Analytics data → read `references/haver.md`

## Common Rules

- Always use `getSecret()` for credentials and API keys — never hardcode secrets
- All three providers require the **Datafeed Toolbox**
- `fredrs` additionally requires **R2026a** or later
- Bloomberg and Haver local interfaces (`bloomberg`, `blp`, `haver`, `haverdirect`) are Windows-only; cloud/REST variants (`bloombergHypermedia`, `bpipe`, `haverview`, `fredrs`) are platform-independent

---

Copyright 2026 The MathWorks, Inc.
