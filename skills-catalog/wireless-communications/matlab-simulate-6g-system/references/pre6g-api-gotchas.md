# pre6G API Gotchas

These fail silently or contradict the 5G Toolbox conventions.

- **These names do not exist:** `pre6GWaveformGenerator`, `pre6GDLCarrierConfig`, `nr6G*`. Build
  from `pre6GCarrierConfig`, `pre6GResourceGrid`, `pre6GOFDMModulate`, ...
- **RS: one column per CDM group.** `pre6GReferenceSignalConfig` silently accepts a row vector for
  `SubcarrierLocations`/`SymbolLocations` and reads it as several CDM groups, which changes the
  pilot count. Max ports = `FrequencyDomainCDM × TimeDomainCDM × columns`.
- **`ReservedRE` is 0-based.** With 1-based indices the count is the same but the REs are wrong.
- **`OutputDataType` defaults to `"single"`** in `pre6GResourceGrid`, `pre6GSymbolModulate`, ...
- **`pre6GSymbolModulate(chConfig, cw)` takes the config first**, the reverse of
  `nrSymbolModulate(cw, mod)`.

----

Copyright 2026 The MathWorks, Inc.

----
