---
name: matlab-access-datafeed
description: >
  Connect to Bloomberg, FRED, Haver Analytics, LSEG Datastream, NOAA Climate Data Online,
  or US government agencies (BEA, BLS, Census, EIA) from MATLAB and retrieve data. Covers
  market data (bloomberg/blp/bloombergHypermedia), economic data (fredrs, haver/haverdirect/haverview),
  historical financial data (datastreamws), weather/climate data (@noaa from GitHub), and
  government data (usbea/usbls/uscensus/useia from GitHub).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.3"
---

# Datafeed Toolbox — Bloomberg, FRED, Haver Analytics, LSEG Datastream, NOAA, and US Government Data

Access financial, economic, climate, and government data from multiple providers through the MATLAB Datafeed Toolbox and related GitHub interfaces.

## When to Use

- User wants to connect to **Bloomberg**, **FRED**, **Haver Analytics**, **LSEG Datastream**, **NOAA**, or **US government agencies (BEA, BLS, Census, EIA)** from MATLAB
- User needs to retrieve market data (prices, history, real-time, reference data) via Bloomberg
- User needs to retrieve economic time series from the St. Louis Fed (FRED)
- User needs to fetch economic/financial time series from Haver Analytics databases
- User needs to retrieve historical financial data from LSEG Datastream
- User needs help choosing between interfaces within a provider (e.g., bloomberg vs blp vs bloombergHypermedia, haver vs haverview)
- User needs to retrieve historical climate or weather data from NOAA Climate Data Online
- User needs to retrieve GDP, employment, population, or energy data from US government agencies
- User is writing MATLAB code involving securities, economic indicators, climate data, government data, or data provider connectivity

## When NOT to Use

- General financial modeling or portfolio optimization that doesn't involve data provider connectivity
- Bloomberg Terminal keyboard shortcuts or Excel add-in questions (not MATLAB)
- Datastream Excel add-in (not MATLAB)
- Real-time streaming from LSEG (datastreamws is historical only)
- NOAA forecast API (weather.gov) or NOAA CO-OPS tidal data (different services from CDO)
- Direct REST/HTTP calls to US government agency APIs without MATLAB
- Agency-specific data interpretation (what BLS series IDs mean, Census variable codes, etc.)
- Data sources not covered here (e.g., Yahoo Finance)
- Installing MATLAB, Datafeed Toolbox, or toolbox products → use `matlab-install-products`
- Querying relational databases via SQL, JDBC, or ODBC → use `matlab-use-database`
- Debugging generic MATLAB runtime errors not specific to a data provider → use `matlab-debug-code`

## Provider Overview

| Provider | Data Type | Interfaces | Reference |
|----------|-----------|------------|-----------|
| Bloomberg | Market data (equities, fixed income, derivatives, indices) | `bloomberg`, `blp`, `bloombergHypermedia`, `bloombergEMSX` | `references/bloomberg.md` |
| FRED | U.S. economic data (GDP, unemployment, CPI, interest rates) | `fredrs` (replaces obsolete `fred`) | `references/fred.md` |
| Haver Analytics | Global economic & financial data (macro, industry, surveys) | `haver`, `haverdirect`, `haverview` | `references/haver.md` |
| LSEG Datastream | Historical financial data (equities, indices, economics, expressions) | `datastreamws` | `references/datastreamws.md` |
| NOAA CDO | Historical climate/weather data (temperature, precipitation, snowfall) | `noaa` (GitHub) | `references/noaa.md` |
| US Government Data | GDP, employment, population, energy (BEA, BLS, Census, EIA) | `usbea`, `usbls`, `uscensus`, `useia` (GitHub) | `references/us-govt-data.md` |

## Quick Interface Selection

### Bloomberg — see `references/bloomberg.md` for full API patterns
- **Windows Desktop/Terminal user** → `bloomberg` (C++)
- **Need platform independence (Data License)** → `bloombergHypermedia`
- **Server/cloud, no Terminal (BPIPE)** → `bloombergBPIPE`
- **Existing `blp` users** → migrate to `bloomberg` (same API, no Java needed)

### FRED — see `references/fred.md` for full API patterns
- **Any platform** → `fredrs` (requires R2026a+, API key)
- **`fred` is obsolete** — do NOT use it

### Haver Analytics — see `references/haver.md` for full API patterns
- **Windows with local data files** → `haver`
- **Windows needing remote access** → `haverdirect`
- **Non-Windows / server / cloud** → `haverview` (REST API)

### LSEG Datastream — see `references/datastreamws.md` for full API patterns
- **Any platform** → `datastreamws` (REST API, requires Datastream credentials)

### NOAA Climate Data Online — see `references/noaa.md` for full API patterns
- **Any platform** → `noaa` (GitHub interface, requires free CDO API token)
- Clone from `github.com/mathworks/noaa` and `addpath` — not part of Datafeed Toolbox

### US Government Data — see `references/us-govt-data.md` for full API patterns
- **BEA** → `usbea` (GDP, national/regional/international economic accounts)
- **BLS** → `usbls` (employment, unemployment, CPI, wages)
- **Census Bureau** → `uscensus` (population, ACS, economic census)
- **EIA** → `useia` (electricity, petroleum, natural gas, coal)
- Clone from `github.com/mathworks/Access-Public-US-Government-Data-from-MATLAB` and `addpath` — not part of Datafeed Toolbox

## How to Use References

Before generating code for a specific provider, read the corresponding reference file for detailed API patterns, function signatures, gotchas, and examples:
- Working with Bloomberg data → read `references/bloomberg.md`
- Working with FRED economic data → read `references/fred.md`
- Working with Haver Analytics data → read `references/haver.md`
- Working with LSEG Datastream data → read `references/datastreamws.md`
- Working with NOAA climate/weather data → read `references/noaa.md`
- Working with BEA, BLS, Census, or EIA data → read `references/us-govt-data.md`

## Common Rules

- Always use `getSecret()` for credentials and API keys — never hardcode secrets
- Bloomberg, FRED, Haver, and Datastream require the **Datafeed Toolbox**. 
- `fredrs` additionally requires **R2026a** or later
- `datastreamws` available since **R2018b**
- NOAA is a standalone GitHub interface requiring MATLAB only.
- US government data interfaces (`usbea`, `usbls`, `uscensus`, `useia`) are available on GitHub only and require **MATLAB R2026b+** and **Datafeed Toolbox R2026b+**
- Bloomberg and Haver local interfaces (`bloomberg`, `blp`, `haver`, `haverdirect`) are Windows-only; cloud/REST variants (`bloombergHypermedia`, `bpipe`, `haverview`, `fredrs`, `datastreamws`) are platform-independent

----

Copyright 2026 The MathWorks, Inc.

----
