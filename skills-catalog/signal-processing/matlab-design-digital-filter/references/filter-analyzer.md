# Filter Analyzer App Workflows

Comprehensive guide for using the MATLAB Filter Analyzer app programmatically via `filterAnalyzer`.

**Prefer Filter Analyzer over manual plotting** for filter visualization whenever comparing filters, iterating on designs, or needing interactive exploration.
---

## Table of Contents
- [Analysis Types Quick Reference](#analysis-types-quick-reference)
- [When to Use Filter Analyzer vs Manual Plots](#when-to-use-filter-analyzer-vs-manual-plots)
- [Object Methods Quick Reference](#object-methods-quick-reference)
- [Session Management](#session-management)
- [Working with Analysis Options](#working-with-analysis-options)
- [Workflow Examples](#workflow-examples)
- [Getting Existing Filter Names](#getting-existing-filter-names-undocumented)
- [Visualizing Multirate Filters](#visualizing-multirate-filters)
- [Tips and Gotchas](#tips-and-gotchas)
- [Version Info](#version-info)

## Analysis Types Quick Reference

| Analysis | Domain | Overlay? | Key Options |
|----------|--------|----------|-------------|
| `"magnitude"` | Freq | Yes | `MagnitudeMode`, `NormalizeMagnitude` |
| `"phase"` | Freq | Yes | `PhaseUnits`, `ContinuousPhase` |
| `"groupdelay"` | Freq | Yes | `GroupDelayUnits` |
| `"phasedelay"` | Freq | Yes | `PhaseUnits` |
| `"magestimate"` | Freq | Yes | `MagnitudeEstimateNumTrials` |
| `"noisepsd"` | Freq | Yes | `NoisePSDNumTrials` |
| `"impulse"` | Time | Yes | `ResponseLengthMode`, `ResponseLength` |
| `"step"` | Time | Yes | `ResponseLengthMode`, `ResponseLength` |
| `"polezero"` | Other | No | — |
| `"info"` | Other | No | — |
| `"coefficients"` | Other | No | `CoefficientsFormat` |

**Overlay rules**: Frequency-domain analyses can overlay with other frequency-domain. Time-domain with time-domain. `polezero`, `info`, `coefficients` do not support overlays.

---

## When to Use Filter Analyzer vs Manual Plots

### Use Filter Analyzer when:
- Comparing multiple filters side-by-side
- Need interactive exploration (zoom, pan)
- Want overlay analysis (magnitude + phase, impulse + step)
- Need specification mask visualization
- Working iteratively (app stays open, update filters in place)
- Need multiple analysis displays simultaneously

### Use manual `freqz`/`grpdelay` when:
- Simple single-filter quick check
- Need to customize plot appearance beyond app options
- Generating figures for export/publication (more control over formatting)
- Scripting batch analysis without GUI

---

## Object Methods Quick Reference

| Method | Syntax | Purpose |
|--------|--------|---------|
| `addFilters` | `addFilters(fa, filt1, filt2, ..., FilterNames=, SampleRates=)` | Add filters |
| `addDisplays` | `dispNum = addDisplays(fa, Analysis=, OverlayAnalysis=)` | Add analysis display |
| `deleteFilters` | `deleteFilters(fa, FilterNames=names)` | Remove filters by name |
| `deleteDisplays` | `deleteDisplays(fa, DisplayNums=num)` | Remove display by number |
| `duplicateDisplays` | `dupNum = duplicateDisplays(fa, DisplayNums=num)` | Clone a display |
| `showFilters` | `showFilters(fa, true/false, FilterNames=, DisplayNums=)` | Show/hide filters |
| `showLegend` | `showLegend(fa, true/false, DisplayNums=)` | Toggle legend |
| `renameFilters` | `renameFilters(fa, oldNames, newNames)` | Rename filters |
| `replaceFilters` | `replaceFilters(fa, filt1, ..., FilterNames=, SampleRates=)` | Update existing filters |
| `getAnalysisOptions` | `opts = getAnalysisOptions(fa, DisplayNums=)` | Get display options |
| `setAnalysisOptions` | `setAnalysisOptions(fa, opts, DisplayNums=)` | Set display options |
| `zoom` | `zoom(fa, "passband"/"default", DisplayNums=)` | Zoom presets |
| `saveSession` | `saveSession(fa, 'file.mat')` | Save session to file |
| `newSession` | `newSession(fa)` | Clear all filters/displays |
| `close` | `close(fa)` | Close the app |

---

## Session Management

### Problem: Duplicate Filters Accumulating

When repeatedly running code that adds filters to Filter Analyzer, you get:
```
FIR_Equiripple
FIR_Equiripple_1
FIR_Equiripple_2
...
```

This happens because `filterAnalyzer()` or `addFilters()` appends to existing session.

### Solution 1: Fresh Session (Recommended)

Use `newSession(fa)` to clear all filters before adding new ones:

```matlab
% Get or create Filter Analyzer handle
if exist('fa', 'var') && isvalid(fa)
    newSession(fa);  % Clear all existing filters
else
    fa = filterAnalyzer();
end

% Now add filters - no duplicates
addFilters(fa, d1, d2, d3, ...
    FilterNames=["FIR_Equiripple", "FIR_Kaiser", "FIR_Hamming"], ...
    SampleRates=Fs);
```

### Solution 2: Replace Existing Filters

Use `replaceFilters()` to update filters by name (keeps app state, displays):

```matlab
fa = getFilterAnalyzerHandle;

% Replace filters with same names
replaceFilters(fa, d1_new, d2_new, d3_new, ...
    FilterNames=["FIR_Equiripple", "FIR_Kaiser", "FIR_Hamming"], ...
    SampleRates=Fs);
```

**Note**: `FilterNames` specifies WHICH existing filters to replace.

### Solution 3: Delete Specific Filters

Remove specific filters by name:

```matlab
% Template
fa = getFilterAnalyzerHandle;
deleteFilters(fa, FilterNames=["FIR_Equiripple_1", "FIR_Kaiser_2"]);
```

---

## Working with Analysis Options

### Creating and Applying Options

```matlab
% Template
% Create options for specific analysis (with overlay)
opts = filterAnalysisOptions("magnitude", "phase");
opts.NFFT = 4096;
opts.FrequencyScale = "log";
opts.MagnitudeMode = "db";

% Apply to specific display
setAnalysisOptions(fa, opts, DisplayNums=2);

% Get current options from a display
currentOpts = getAnalysisOptions(fa, DisplayNums=2);
```

### Common filterAnalysisOptions Properties

**All Frequency-Domain Analyses:**
| Property | Values | Default |
|----------|--------|---------|
| `FrequencyNormalizationMode` | `"auto"`, `"normalized"`, `"unnormalized"` | `"auto"` |
| `FrequencyRange` | `"auto"`, `"onesided"`, `"twosided"`, `"centered"` | `"auto"` |
| `FrequencyScale` | `"linear"`, `"log"` | `"linear"` |
| `NFFT` | positive integer | `8192` |
| `ReferenceSampleRateMode` | `"max"`, `"specify"` | `"max"` |

**Magnitude-Specific:**
| Property | Values | Default |
|----------|--------|---------|
| `MagnitudeMode` | `"db"`, `"linear"`, `"squared"`, `"zerophase"` | `"db"` |
| `NormalizeMagnitude` | `true`, `false` | `false` |

**Phase-Specific:**
| Property | Values | Default |
|----------|--------|---------|
| `PhaseUnits` | `"radians"`, `"degrees"` | `"radians"` |
| `ContinuousPhase` | `true`, `false` | `false` |

**Group Delay:**
| Property | Values | Default |
|----------|--------|---------|
| `GroupDelayUnits` | `"samples"`, `"time"` | `"samples"` |

**Time-Domain (impulse/step):**
| Property | Values | Default |
|----------|--------|---------|
| `ResponseLengthMode` | `"auto"`, `"specify"` | `"auto"` |
| `ResponseLength` | positive integer | (auto-computed) |

**Coefficients Display:**
| Property | Values | Default |
|----------|--------|---------|
| `CoefficientsFormat` | `"decimal"`, `"hex"`, `"binary"` | `"decimal"` |

**CTF View (cascaded transfer functions):**
| Property | Values | Default |
|----------|--------|---------|
| `CTFAnalysisMode` | `"complete"`, `"individual"`, `"cumulative"`, `"specify"` | `"complete"` |

---

## Workflow Examples

### Example 1: Multi-Display Filter Comparison

```matlab
%% Compare Butterworth, Elliptic, and FIR filters
Fs = 44100;

% Design filters
d_butter = designfilt("lowpassiir", ...
    PassbandFrequency=2000, StopbandFrequency=2500, ...
    PassbandRipple=1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="butter");

d_ellip = designfilt("lowpassiir", ...
    PassbandFrequency=2000, StopbandFrequency=2500, ...
    PassbandRipple=1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="ellip");

d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=2000, StopbandFrequency=2500, ...
    PassbandRipple=1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="equiripple");

filterNames = ["Butterworth", "Elliptic", "FIR_Equiripple"];

% Open with magnitude + phase overlay
[fa, disp1] = filterAnalyzer(d_butter, d_ellip, d_fir, ...
    FilterNames=filterNames, ...
    SampleRates=Fs, ...
    Analysis="magnitude", OverlayAnalysis="phase");

% Add group delay display
disp2 = addDisplays(fa, Analysis="groupdelay");
showFilters(fa, true, FilterNames=filterNames, DisplayNums=disp2);

% Add impulse + step response display
disp3 = addDisplays(fa, Analysis="impulse", OverlayAnalysis="step");
showFilters(fa, true, FilterNames=filterNames, DisplayNums=disp3);

% Add pole-zero plot
disp4 = addDisplays(fa, Analysis="polezero");
showFilters(fa, true, FilterNames=filterNames, DisplayNums=disp4);

% Customize magnitude display for log frequency scale
opts = getAnalysisOptions(fa, DisplayNums=disp1);
opts.FrequencyScale = "log";
setAnalysisOptions(fa, opts, DisplayNums=disp1);
```

### Example 2: Iterative Design with Live Updates

```matlab
%% Iterative filter design - update without duplicates
Fs = 48000;

% Initial design
d = designfilt("lowpassfir", ...
    PassbandFrequency=1000, StopbandFrequency=1200, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="equiripple");

fa = filterAnalyzer(d, FilterNames="LP_Design", SampleRates=Fs, ...
    Analysis="magnitude", OverlayAnalysis="phase");

% ... user reviews, wants tighter transition band ...

% Update design - replaceFilters keeps same name, no duplicates
d_v2 = designfilt("lowpassfir", ...
    PassbandFrequency=1000, StopbandFrequency=1100, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="equiripple");

replaceFilters(fa, d_v2, FilterNames="LP_Design", SampleRates=Fs);
% Display updates in-place, no "LP_Design_1" created
```

### Example 3: Complete Session Management Pattern

```matlab
%% Robust pattern for repeated runs
Fs = 44100;
filterNames = ["FIR_Equiripple", "FIR_Kaiser", "FIR_Hamming"];

% Design filters
d_eq = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3100, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="equiripple");

d_kaiser = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3100, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="kaiserwin");

d_hamming = designfilt("lowpassfir", ...
    FilterOrder=200, CutoffFrequency=2950, ...
    SampleRate=Fs, DesignMethod="window", Window=hamming(201));

%% Visualize in Filter Analyzer (no duplicates on re-run)
if exist('fa', 'var') && isvalid(fa)
    % App already open - fresh start
    newSession(fa);
    addFilters(fa, d_eq, d_kaiser, d_hamming, ...
        FilterNames=filterNames, SampleRates=Fs);
else
    % First run - create new session
    fa = filterAnalyzer(d_eq, d_kaiser, d_hamming, ...
        FilterNames=filterNames, SampleRates=Fs, ...
        Analysis="magnitude", OverlayAnalysis="phase");
end

% Add more displays
addDisplays(fa, Analysis="groupdelay");
showFilters(fa, true, FilterNames=filterNames);

addDisplays(fa, Analysis="impulse", OverlayAnalysis="step");
showFilters(fa, true, FilterNames=filterNames);
```

---

## Getting Existing Filter Names (Undocumented)

No official API exists, but this helper function works:

```matlab
function names = getFilterAnalyzerFilterNames(fa)
    % Get filter names from an open Filter Analyzer session
    % Usage: names = getFilterAnalyzerFilterNames(fa)
    %        names = getFilterAnalyzerFilterNames()  % auto-gets handle

    if nargin < 1
        fa = getFilterAnalyzerHandle;
    end

    warning('off', 'MATLAB:structOnObject');
    try
        s = struct(fa);
        impl = s.FilterAnalyzerImpl;
        implStruct = struct(impl);
        faModel = struct(struct(implStruct.MainModel).FilterAnalyzerModel);
        filterInfoMap = faModel.FilterInfoMap;

        k = keys(filterInfoMap);
        names = strings(1, length(k));

        for i = 1:length(k)
            fwa = struct(struct(filterInfoMap(k(i))).FilterWithAnalysis);
            names(i) = string(fwa.Name);
        end
    catch ME
        names = strings(0);
        warning('Could not get filter names: %s', ME.message);
    end
    warning('on', 'MATLAB:structOnObject');
end
```

**Example usage**:
```matlab
% Template
fa = getFilterAnalyzerHandle;
existingNames = getFilterAnalyzerFilterNames(fa);
disp(existingNames);  % ["FIR_Equiripple", "FIR_Kaiser", "FIR_Hamming"]
```

---

## Visualizing Multirate Filters

Filter Analyzer fully supports multirate System objects including `dsp.FIRDecimator`, `dsp.FIRInterpolator`, and `dsp.FilterCascade` (from multistage designs).

### Example 1: Compare Decimator Designs

```matlab
%% Compare single-stage vs multistage decimators
Fs = 44100;

% Single-stage decimators
dec4 = designMultirateFIR(DecimationFactor=4, SystemObject=true);
dec8 = designMultirateFIR(DecimationFactor=8, SystemObject=true);

% Multistage decimator (automatic cascade optimization)
decMultistage = designMultistageDecimator(8);

% Compare all three in Filter Analyzer
filterAnalyzer(dec4, dec8, decMultistage, ...
    SampleRates=Fs, ...
    FilterNames=["Decim4_Single", "Decim8_Single", "Decim8_Multistage"], ...
    Analysis="magnitude");
```

### Example 2: Compare Interpolator Designs

```matlab
%% Compare interpolators with different attenuation specs
Fs = 48000;

interp_60dB = designMultirateFIR(InterpolationFactor=4, ...
    StopbandAttenuation=60, SystemObject=true);
interp_80dB = designMultirateFIR(InterpolationFactor=4, ...
    StopbandAttenuation=80, SystemObject=true);

filterAnalyzer(interp_60dB, interp_80dB, ...
    SampleRates=Fs, ...
    FilterNames=["Interp_60dB", "Interp_80dB"], ...
    Analysis="magnitude", OverlayAnalysis="phase");
```

### Example 3: Analyze Multistage Cascade Structure

```matlab
%% Visualize a multistage decimator cascade
Fs = 44100;
decCascade = designMultistageDecimator(16);

% View overall response
filterAnalyzer(decCascade, SampleRates=Fs, FilterNames="Multistage16x");

% Check cascade structure
info(decCascade)
```

### Supported Multirate Types

| System Object | Created By | Filter Analyzer Support |
|---------------|------------|------------------------|
| `dsp.FIRDecimator` | `designMultirateFIR(..., SystemObject=true)` | ✓ Full support |
| `dsp.FIRInterpolator` | `designMultirateFIR(..., SystemObject=true)` | ✓ Full support |
| `dsp.FIRRateConverter` | `designMultirateFIR(..., SystemObject=true)` | ✓ Full support |
| `dsp.FilterCascade` | `designMultistageDecimator()` | ✓ Full support |
| `dsp.FilterCascade` | `designMultistageInterpolator()` | ✓ Full support |
| `dsp.FilterCascade` | Manual cascade (see below) | ✓ Full support |

### Example 4: Visualizing Multirate Pipelines (dec→filter→interp)

When comparing multirate pipelines against single-stage filters, wrap the complete pipeline in `dsp.FilterCascade`:

```matlab
%% Compare FIR, IFIR, and Multirate Pipeline side-by-side
Fs = 44100;
M = 4;

% Approach 1: Single-stage FIR
d_fir = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3000, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs, DesignMethod="equiripple");
fir_sys = dsp.FIRFilter('Numerator', d_fir.Numerator);

% Approach 2: IFIR
Hf = fdesign.lowpass(2800/(Fs/2), 3000/(Fs/2), 0.1, 60);
ifir_sys = ifir(Hf, 'SystemObject', true);

% Approach 3: Multirate pipeline (dec → filter → interp)
dec_sys = designMultirateFIR(DecimationFactor=M, StopbandAttenuation=60, SystemObject=true);
d_core = designfilt("lowpassfir", ...
    PassbandFrequency=2800, StopbandFrequency=3000, ...
    PassbandRipple=0.1, StopbandAttenuation=60, ...
    SampleRate=Fs/M, DesignMethod="equiripple");
core_sys = dsp.FIRFilter('Numerator', d_core.Numerator);  % Wrap for cascade
interp_sys = designMultirateFIR(InterpolationFactor=M, StopbandAttenuation=60, SystemObject=true);

% Create cascade from pipeline
multirate_cascade = dsp.FilterCascade(dec_sys, core_sys, interp_sys);

% Compare ALL THREE in Filter Analyzer
fa = filterAnalyzer(fir_sys, ifir_sys, multirate_cascade, ...
    FilterNames=["FIR_SingleStage", "IFIR_Cascade", "Multirate_Pipeline"], ...
    SampleRates=Fs, Analysis="magnitude");

% Add group delay for latency comparison
addDisplays(fa, Analysis="groupdelay");
showFilters(fa, true, FilterNames=["FIR_SingleStage", "IFIR_Cascade", "Multirate_Pipeline"]);

% Compare MPIS
fprintf('MPIS: FIR=%.0f, IFIR=%.0f, Multirate=%.0f\n', ...
    cost(fir_sys).MultiplicationsPerInputSample, ...
    cost(ifir_sys).MultiplicationsPerInputSample, ...
    cost(multirate_cascade).MultiplicationsPerInputSample);
```

**Key points:**
- Wrap `digitalFilter` in `dsp.FIRFilter` before adding to cascade
- Use `dsp.FilterCascade(dec, filter, interp)` to create a single object
- Filter Analyzer shows the **overall** frequency response of the cascade
- Use same `SampleRates=Fs` for all (multirate rates are handled internally)

---

## Tips and Gotchas

1. **Match FilterNames to variable names**: Use the same name as your workspace variable so you can easily identify filters. Example: `filterAnalyzer(d_butter, d_ellip, FilterNames=["d_butter", "d_ellip"])` — not `["Butterworth", "Elliptic"]`
2. **Always store the handle**: Keep `fa` in your workspace to manage the session
3. **Check validity**: Use `isvalid(fa)` before calling methods
4. **Lost your handle?**: Use `fa = getFilterAnalyzerHandle` to recover it
5. **Persist across sessions**: Use `saveSession(fa, 'myfilters.mat')` and load later
6. **FilterNames must be valid MATLAB identifiers**: No spaces, hyphens, or special characters. Use underscores: `"d_butter"` not `"d-butter"` or `"d butter"`
7. **Overlay rules are strict**: Frequency-domain only overlays with frequency-domain; time-domain with time-domain. `polezero`, `info`, `coefficients` don't support overlays.
8. **Name-value syntax required**: Most methods use `DisplayNums=`, `FilterNames=` syntax, not positional arguments
9. **Zoom presets**: `"passband"`, `"default"`, `"x"`, `"y"`, `"xy"` — custom axis limits require using the app UI
10. **`filterAnalyzer` returns display number**: `[fa, dispNum] = filterAnalyzer(...)` — only the initial call returns both

---

## Version Info

- `filterAnalyzer` function: **R2024a+**
- `replaceFilters` method: **R2024a+**
- `getAnalysisOptions` / `setAnalysisOptions`: **R2024a+**
- `LegendStrings` argument: **R2025a+**
- Tested on: **R2024b**


----

Copyright 2026 The MathWorks, Inc.

----
