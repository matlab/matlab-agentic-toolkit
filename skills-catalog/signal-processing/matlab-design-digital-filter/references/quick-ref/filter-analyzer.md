# Filter Analyzer Card

Open this card **before** you write any code that uses:
`filterAnalyzer`, `addFilters`, `addDisplays`, `replaceFilters`, `newSession`, or `filterAnalysisOptions`.

## Non‑negotiables

- Always pass `SampleRates=Fs` so plots are in **Hz** (not normalized).
- `FilterNames` must be valid MATLAB identifiers:
  - ✅ `["FIR_Equiripple","IIR_Ellip"]`
  - ❌ `["FIR Equiripple","IIR-ellip"]`
- Overlay rules:
  - frequency-domain overlays only with frequency-domain
  - time-domain overlays only with time-domain
- Avoid duplicate filters on re-runs:
  - prefer `newSession(fa)` (fresh start), or
  - `replaceFilters(fa, ...)` (update-in-place)

## Canonical “compare two filters” pattern

```matlab
Fs = 44100;

% d1, d2 can be digitalFilter objects or supported System objects
names = ["FIR_Equiripple","IIR_Ellip"];

[fa, dispMag] = filterAnalyzer(d1, d2, ...
    FilterNames=names, ...
    SampleRates=Fs, ...
    Analysis="magnitude", ...
    OverlayAnalysis="phase");

dispGD = addDisplays(fa, Analysis="groupdelay");
showFilters(fa, true, FilterNames=names, DisplayNums=dispGD);

dispImp = addDisplays(fa, Analysis="impulse");
showFilters(fa, true, FilterNames=names, DisplayNums=dispImp);
```

## Robust session pattern (no duplicates across reruns)

```matlab
Fs = 44100;
names = ["LP_A","LP_B"];

if exist("fa","var") && isvalid(fa)
    newSession(fa);
else
    fa = filterAnalyzer();  % open empty app
end

addFilters(fa, dA, dB, FilterNames=names, SampleRates=Fs);
addDisplays(fa, Analysis="magnitude", OverlayAnalysis="phase");
addDisplays(fa, Analysis="groupdelay");
```

## Update a filter without duplicating it

```matlab
% Replace existing filters by name (keeps displays intact)
replaceFilters(fa, dA_new, dB_new, ...
    FilterNames=["LP_A","LP_B"], ...
    SampleRates=Fs);
```

## Visualize a multirate pipeline as one “filter”

When comparing a decimate→filter→interpolate pipeline against a single-stage filter, wrap the full chain in `dsp.FilterCascade`.

```matlab
Fs = 44100; M = 4;

% Streaming-friendly components (System objects)
dec_sys = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=60, SystemObject=true);

d_core = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3100, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs/M, DesignMethod="equiripple");

core_sys = dsp.FIRFilter("Numerator", d_core.Numerator);

interp_sys = designMultirateFIR(InterpolationFactor=M, StopbandAttenuation=60, SystemObject=true);

pipe = dsp.FilterCascade(dec_sys, core_sys, interp_sys);

% Add alongside other filters
addFilters(fa, pipe, FilterNames="Multirate_Pipeline", SampleRates=Fs);
```

## When to open the full guide

Open `../filter-analyzer.md` when you need:
- `filterAnalysisOptions` (log scale, NFFT, normalization, etc.)
- display management (`duplicateDisplays`, `deleteDisplays`, …)
- session save/load (`saveSession`)
- version-specific notes


----

Copyright 2026 The MathWorks, Inc.

----
