# Constant‑Rate Multistage FIR Card (IFIR method)

Use this card when:
- the transition is narrow (`trans_pct < 2%`), and
- you want **FIR-like phase behavior** (often linear phase), and
- you **cannot** (or don’t want to) change the sample rate internally.

MATLAB’s standard tool for this is **IFIR** (Interpolated FIR): a sparse “model” filter plus an image‑suppressor, in cascade.

## Two workflows (pick based on what you need)

### A) Filter Analyzer / streaming-friendly (recommended)

This returns a `dsp.FilterCascade` that Filter Analyzer understands.

```matlab
Fs = 44100;
Fn = Fs/2;

Hf = fdesign.lowpass(Fpass/Fn, Fstop/Fn, Rp, Rs);

% Returns dsp.FilterCascade
ifirSys = ifir(Hf, SystemObject=true);
% (equivalent) ifirSys = design(Hf, "ifir", SystemObject=true);

filterAnalyzer(ifirSys, FilterNames="IFIR", SampleRates=Fs);

% Apply (streaming/casual)
y = ifirSys(x);
reset(ifirSys);
```

### B) Offline zero‑phase with coefficient access

Raw coefficients are convenient for `filtfilt()`, but they don’t drop cleanly into Filter Analyzer.

```matlab
Fs = 44100;
Fn = Fs/2;

dev_p = (10^(Rp/20)-1)/(10^(Rp/20)+1);
dev_s = 10^(-Rs/20);

L = 4;  % interpolation factor (try 2–8)
[b_ifir, b_model, b_image] = ifir(L, "low", [Fpass Fstop]/Fn, [dev_p dev_s]);

y = filtfilt(b_ifir, 1, x);  % zero-phase (offline only)
```

## Gotchas

### IFIR + Filter Analyzer / filtord

**Problem**: Raw `ifir()` coefficient outputs don't work with `filterAnalyzer` or `filtord`:

```matlab
% Anti-pattern
% These will ERROR or give wrong results
[b_ifir, b_model, b_image] = ifir(L, "low", [Fpass Fstop]/Fn, [dev_p dev_s]);
filterAnalyzer(b_ifir, SampleRates=Fs);  % ERROR
filtord(b_ifir);  % Works but gives wrong answer (overall, not per-stage)

% design() returns dfilt objects, not digitalFilter
d_ifir = design(fdesign.lowpass(...), 'ifir');
filtord(d_ifir.Stage(1));  % ERROR: dfilt.dffir not supported
```

**Solution**: Use `SystemObject=true` to get a `dsp.FilterCascade`:

```matlab
Hf = fdesign.lowpass(Fpass/Fn, Fstop/Fn, Rp, Rs);
ifirSys = ifir(Hf, SystemObject=true);

% Works with Filter Analyzer
filterAnalyzer(ifirSys, FilterNames="IFIR", SampleRates=Fs);

% Get tap counts via cost()
c = cost(ifirSys);
fprintf("Total multiplications per sample: %d\n", c.MultiplicationsPerInputSample);
```

### Getting stage coefficients for filtfilt

If you need raw coefficients (e.g., for `filtfilt`), use workflow B and apply directly:

```matlab
[b_ifir, ~, ~] = ifir(L, "low", [Fpass Fstop]/Fn, [dev_p dev_s]);
y = filtfilt(b_ifir, 1, x);  % OK - raw coefficients work here
```

## When to prefer multirate instead

If internal rate change *is* acceptable, multirate dec→filter→interp can be even cheaper.  
Use the multirate-streaming or multirate-offline quick-ref (via INDEX.md) depending on Mode.


----

Copyright 2026 The MathWorks, Inc.

----
