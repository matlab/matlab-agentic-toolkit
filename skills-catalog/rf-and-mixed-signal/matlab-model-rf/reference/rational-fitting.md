# Rational Fitting and Time-Domain Analysis

Fit S-parameter data to rational function models, compute time-domain responses (TDR, impulse, step), and export to SPICE/Verilog-A.

## The `rational` Object (R2020a+, AAA algorithm)

Prefer `rational` over `rationalfit` (vector fitting). Both provide the same analysis methods (`impulse`, `stepresp`, `timeresp`, `zpk`, `generateSPICE`, `pwlresp`, `iscausal`, `ispassive`, `makepassive`, `passivity`, `freqresp`, `abcd`, `writeva`). The advantage of `rational` is that it tends to converge more robustly and faster. The advantage of `rationalfit` is that it enables delay removal.

**Note:** `rationalfit` still ships and uses the vector-fitting algorithm. It returns the legacy `rfmodel.rational` object. Use `rational` (without the "fit" suffix) for new code unless you specifically need vector fitting or delay extraction.

## Input Forms

| Input | Returns | Time-domain output |
|-------|---------|-------------------|
| `rational(sparametersObj)` | N-port fit | Cell arrays `{N,N}` -- access as `y{i,j}`, `t{i,j}` |
| `rational(freq, dataVector)` | 1-port fit | Plain vectors -- use directly as `y`, `t` |

**Critical:** For single-parameter fits (`rational(freq, s21)`), `impulse`/`stepresp`/`timeresp` return **plain vectors**. Cell arrays `{N,N}` are returned ONLY when fitting an entire `sparameters` object.

## Quick Recipes

Use these complete blocks directly. Do NOT assemble from individual pieces.

### Impulse Response

```matlab
s = sparameters('channel.s2p');
s21 = rfparam(s, 2, 1);
[fit21, errdb] = rational(s.Frequencies, s21);
fprintf('Fit: %d poles, %.1f dB error\n', fit21.NumPoles, errdb);
% Single-parameter fit returns plain vectors (NOT cell arrays)
[yImp, tImp] = impulse(fit21, 1e-12, 5000);  % (fit, sampleTime, numPoints)
figure; plot(tImp*1e9, real(yImp));
xlabel('Time (ns)'); ylabel('Amplitude'); title('Channel Impulse Response');
```

### TDR with Impedance Profile

```matlab
s = sparameters('dut.s2p');
s11 = rfparam(s, 1, 1);
tdrFreqData = (s11 + 1) / 2;               % Voltage TDR in frequency domain
tdrFit = rational(s.Frequencies, tdrFreqData, 'Qlimit', inf, 'TendsToZero', false);

% stepresp: simplest TDR computation
velocity = 2e8;                              % m/s (adjust for your medium)
fmax = s.Frequencies(end);
tRise = 1 / fmax;                            % Rise time from measurement bandwidth
Ts = 1e-11; N = 10000;
[tdr, tOut] = stepresp(tdrFit, Ts, N, tRise);

% Convert TDR voltage to impedance
s11_recovered = 2*real(tdr) - 1;
Z = 50 * (1 + s11_recovered) ./ (1 - s11_recovered);

% Convert time to distance (one-way)
distance = tOut * velocity / 2;
minFeature = velocity * tRise / 2;
fprintf('Bandwidth: %.1f GHz, Rise time: %.1f ps, Spatial resolution: %.1f mm\n', ...
    fmax/1e9, tRise*1e12, minFeature*1e3);

% Detect discontinuities: find where impedance deviates from Z0
Z0 = 50; threshold = 5;
discontinuityIdx = find(abs(Z - Z0) > threshold);
if ~isempty(discontinuityIdx)
    fprintf('discontinuity at %.1f cm (Z = %.1f ohms)\n', ...
        distance(discontinuityIdx(1))*100, Z(discontinuityIdx(1)));
end

figure; plot(distance*100, Z);
xlabel('Distance (cm)'); ylabel('Impedance (\Omega)'); title('TDR Impedance Profile');
yline(Z0, '--k', 'Z_0'); yline(Z0+threshold, ':r'); yline(Z0-threshold, ':r');
```

**Spatial resolution:** TDR cannot resolve features smaller than `velocity * tRise / 2`. The rise time is limited by measurement bandwidth -- a 10 GHz measurement gives ~1 cm resolution. Features smaller than this appear smeared. Do not interpret ringing artifacts as discontinuities. See `reference/ifft-step-response.md` for the pure-iFFT alternative when rational fitting is not needed.

### Fit, Verify, Export

```matlab
s = sparameters('measured.s2p');
[fit, errdb] = rational(s, 'Tolerance', -60);
fprintf('Poles: %d, Error: %.1f dB, Passive: %d\n', ...
    fit.NumPoles, errdb, ispassive(fit));
if ~ispassive(fit), fit = makepassive(fit); end
% Verify in frequency domain -- include intermediate and out-of-band points
fVerify = linspace(0, 2*s.Frequencies(end), 10001)';
resp = freqresp(fit, fVerify);
figure; tiledlayout(1,2);
nexttile; plot(s.Frequencies/1e9, 20*log10(abs(rfparam(s,2,1))), '-o', ...
    fVerify/1e9, 20*log10(abs(squeeze(resp(2,1,:)))), '--');
xlabel('Frequency (GHz)'); ylabel('|S21| (dB)'); legend('Original','Fit');
nexttile; plot(s.Frequencies/1e9, 20*log10(abs(rfparam(s,1,1))), '-o', ...
    fVerify/1e9, 20*log10(abs(squeeze(resp(1,1,:)))), '--');
xlabel('Frequency (GHz)'); ylabel('|S11| (dB)'); legend('Original','Fit');
% Export
generateSPICE(fit, 'model.sp');
writeva(fit, 'model.va', 'in', 'out', 'electrical');
```

### Recipe: Extrapolate to DC or Beyond Measured Range

```matlab
s = sparameters('measured.s2p');  % e.g., 10 MHz to 20 GHz
[fit, errdb] = rational(s);
% Evaluate at any frequencies -- freqresp takes Hz
freqExtended = linspace(0, 40e9, 401)';     % DC to 40 GHz
resp = freqresp(fit, freqExtended);          % N-by-N-by-K array
s21_extrap = squeeze(resp(2,1,:));
figure; plot(freqExtended/1e9, 20*log10(abs(s21_extrap)));
xlabel('Frequency (GHz)'); ylabel('|S21| (dB)'); title('Extrapolated Response');
```

### Recipe: Extract Channel Delay

```matlab
s = sparameters('channel.s2p');
s21 = rfparam(s, 2, 1);
% Use rationalfit (not rational) for delay extraction
fit = rationalfit(s.Frequencies, s21, 'DelayFactor', 1);
fprintf('Channel delay: %.3f ns\n', fit.Delay * 1e9);
```

### Recipe: Synthetic Cable with Discontinuity (for TDR Testing)

```matlab
% Create S-parameters for cable with impedance discontinuity
freq = linspace(1e6, 10e9, 501)';
Z0 = 50; Zdiscontinuity = 75; vel = 2e8;
len1 = 1.5; len2 = 0.3; len3 = 1.2;  % meters (discontinuity at 1.5m, 0.3m long)
ckt = circuit('discontinuityCable');
tl1 = txlineDelayLossless('Name', 'Pre', 'Z0', Z0, 'TimeDelay', len1/vel);
tl2 = txlineDelayLossless('Name', 'Discontinuity', 'Z0', Zdiscontinuity, 'TimeDelay', len2/vel);
tl3 = txlineDelayLossless('Name', 'Post', 'Z0', Z0, 'TimeDelay', len3/vel);
add(ckt, [1 2 3 4], tl1); add(ckt, [3 4 5 6], tl2); add(ckt, [5 6 7 8], tl3);
setports(ckt, [1 2], [7 8]);
s = sparameters(ckt, freq);
% Now apply TDR recipe from above
```

**Building synthetic circuits for test data:** For node mapping rules (4-node for 2-port RF elements, 8-node for 4-port), `clone()` for element reuse, and multi-port `setports` patterns, see `matlab-compose-rf-circuit`.

### Recipe: Synthetic Lossy Channel (No Circuit Construction)

```matlab
freq = linspace(1e9, 20e9, 201)';
delay = 500e-12;                              % propagation delay
s21 = reshape(10.^(-0.5*(freq/1e9)/20) .* exp(-1j*2*pi*freq*delay), 1, 1, []);
s11 = reshape(0.05 * exp(-1j*2*pi*freq*delay*0.1), 1, 1, []);
data = [s11 s21; s21 s11];                   % 2-by-2-by-K linear complex
s = sparameters(data, freq, 50);
```

**Critical:** `sparameters(data, freq, Z0)` expects `data` as **linear complex** (not dB). Setting `s11 = -20` gives |S11| = 20 (non-physical), not -20 dB. Convert first: `10^(-20/20) = 0.1`.

### Recipe: Synthetic 4-Port Coupled Channel (No Circuit Construction)

```matlab
% Port convention: 1,2 near-end; 3,4 far-end
% Through = S31/S42, NEXT = S21/S43, FEXT = S41/S23
freq = linspace(1e9, 20e9, 201)';
delay = 500e-12;
sThru = reshape(10.^(-0.5*(freq/1e9)/20) .* exp(-1j*2*pi*freq*delay), 1, 1, []);
sRefl = reshape(0.05 * ones(size(freq)), 1, 1, []);
sNEXT = reshape(0.02 * exp(-1j*2*pi*freq*delay*0.3), 1, 1, []);
sFEXT = reshape(0.01 * exp(-1j*2*pi*freq*delay*1.2), 1, 1, []);
data = [sRefl sNEXT sThru sFEXT; ...
        sNEXT sRefl sFEXT sThru; ...
        sThru sFEXT sRefl sNEXT; ...
        sFEXT sThru sNEXT sRefl];    % 4-by-4-by-K
s = sparameters(data, freq, 50);
```

### Recipe: Lossy Trace with txlineWRLGC (for SI Channel Testing)

```matlab
freq = linspace(1e6, 20e9, 201)';
tw = txlineWRLGC('Ro', 2, 'Lo', 350e-9, 'Co', 130e-12, 'Go', 0, ...
    'Gd', 1e-11, 'LineLength', 0.15, 'Name', 'Trace');
ckt = circuit('channel');
add(ckt, [1 2 0 0], tw);
setports(ckt, [1 0], [2 0]);
s = sparameters(ckt, freq);
```

**Gotcha:** `txlineWRLGC` properties are `Ro`, `Lo`, `Co`, `Go`, `Gd` -- short forms `R`, `L`, `G`, `C` error as ambiguous. All txline constructors require name-value pairs (no positional arguments).

---

## Tuning Options

| Option | Default | Purpose |
|--------|---------|---------|
| `Tolerance` | -40 | Target error in dB (recommend -60) |
| `MaxPoles` | 1000 | Upper bound on poles |
| `Causal` | true | Enforce causal (stable) poles |
| `TendsToZero` | true | Force fit to decay to zero as frequency -> infinity |
| `NoiseFloor` | -Inf | Ignore data below this level (dB) |
| `Qlimit` | (finite) | Max pole Q-factor retained; set to `inf` for filters |
| `Display` | `'off'` | Set to `'plot'` to visualize fit progress |

**Fitting philosophy:** A single call to `rational` with a `'Tolerance'` on the tighter side, e.g. `-60` (3 digits), is sufficient -- there is no advantage to sweeping multiple tolerance values. The returned `errdb` indicates the achievable accuracy. If accuracy is insufficient: (1) set `'NoiseFloor'` to mask low-level noise, (2) try `'Causal', false` as a diagnostic (if accuracy improves significantly, the data has measurement quality issues), or (3) accept the achievable accuracy.

**Controlling model order:** Use `'MaxPoles'` to set a hard upper bound on pole count -- useful when simulator cost scales with poles (e.g., SPICE export). `'Tolerance'` is the preferred knob for controlling accuracy, and adjusting `'Tolerance'` may or may not affect the number of poles.

**`TendsToZero`:** When `true` (default), the rational model has strictly proper form (numerator order < denominator order), so the response decays to zero at high frequencies. This is appropriate for bandpass or lowpass responses (e.g., insertion loss S21 of a lossy channel, TDT). Set `TendsToZero=false` for responses that do not vanish at infinity (e.g., reflection coefficients, allpass networks, TDR, or broadband matched loads where S11 plateaus). The `false` setting produces a more general model with a nonzero direct-feedthrough term (D matrix nonzero).

**`Qlimit`:** By default, `rational` screens out high-Q poles (similar to how it discards unstable poles). This is appropriate for broadband channel data where high-Q poles indicate fitting noise. However, filters and other low-order electrical components have high-Q poles by design. Set `'Qlimit', inf` when fitting filter S-parameters to preserve these physically meaningful resonances.

---

## Verification

Two complementary verification approaches:

### Approach 1: RF Toolbox Rational Fit Verification

Operates directly on the fit object. Checks the *model* quality.

```matlab
% Error metric (returned from rational())
[fit, errdb] = rational(s, 'Tolerance', -60);
fprintf('Poles: %d, Error: %.1f dB, Passive: %d\n', ...
    fit.NumPoles, errdb, ispassive(fit));

% Visual: compare fit vs original -- evaluate at intermediate and out-of-band frequencies
% freqresp is inexpensive, so use a dense grid extending beyond the data range
fVerify = linspace(0, 2*s.Frequencies(end), 10001)';
resp = freqresp(fit, fVerify);         % Returns N-by-N-by-K for N-port fit
figure; tiledlayout(1,2);
nexttile; plot(s.Frequencies/1e9, 20*log10(abs(rfparam(s,2,1))), '-o', ...
    fVerify/1e9, 20*log10(abs(squeeze(resp(2,1,:)))), '--');
xlabel('Frequency (GHz)'); ylabel('|S21| (dB)'); legend('Original','Fit');
nexttile; passivity(fit);              % H-inf norm plot (passive where <= 1)
```

**This covers complete verification.** The `errdb` + overlay plot + `passivity(fit)` are the full set of checks needed. Phase plots, pole-zero diagrams, and per-frequency error plots are optional extras -- not required.

**`passivity(fit)`** -- Call without arguments for reliable results across releases.

### Approach 2: IEEE P370 Quality Check (R2023b+)

Operates on the raw `sparameters` object. Checks the *measurement data* quality before fitting.

```matlab
[cm, rm, pm] = ieee370QualityCheckFrequencyDomain(s);
% cm = causality metric, rm = reciprocity metric, pm = passivity metric
% All return per-frequency vectors. Closer to 0 = better.
```

**When to use which:**
- **RF Toolbox** (`passivity`, `errdb`): Verify the fit model itself. Always do this.
- **IEEE P370** (`ieee370QualityCheckFrequencyDomain`): Verify raw measurement data *before* fitting. Use when you suspect measurement artifacts (cable flex, calibration drift). Diagnoses whether poor fit accuracy is caused by data quality vs. fitting issues.

### Enforce Passivity

```matlab
if ~ispassive(fit)
    fit = makepassive(fit);            % Perturbs residues (may reduce accuracy)
    fprintf('Post-makepassive error check needed\n');
end
```

**`makepassive(fitObj)`** runs residue optimization -- different from `makepassive(sparametersObj)` which modifies data point-by-point. Always re-check `errdb` after calling it.

### Extract Poles, Zeros, and State-Space

```matlab
[z, p, k] = zpk(fit);                 % Zeros, poles, gain
nPoles = fit.NumPoles;                 % Number of poles
[A, B, C, D] = abcd(fit);             % State-space matrices
```

---

## Multi-Port Cell Array Handling

```matlab
s = sparameters('channel.s2p');
fit = rational(s);
[yStep, tStep] = stepresp(fit, 1e-11, 10000, 1e-10);
if iscell(yStep)
    y21 = yStep{2,1};    % S21 step response
    t21 = tStep{2,1};    % Corresponding time vector
else
    y21 = yStep;          % Single-parameter fit: plain vectors
    t21 = tStep;
end
figure; plot(t21*1e9, real(y21));
xlabel('Time (ns)'); ylabel('Amplitude'); title('S21 Step Response (TDT)');
```

**Gotcha:** For multi-port fits, `stepresp`, `impulse`, and `timeresp` return `{N,N}` cell arrays for **both** the response and the time vector. Access element (i,j) as `resp{i,j}` and `t{i,j}` -- do not index `t` as a plain vector. Always verify with `iscell(result)` before indexing.

---

## Time-Domain Responses

### Impulse Response

```matlab
[yImp, tImp] = impulse(fit21, 1e-12, 5000);   % (fit, ts, nPts)
```

### Step Response

```matlab
[yStep, tStep] = stepresp(fit21, 1e-11, 10000, 1e-10);  % (fit, Ts_seconds, N_samples, tRise)
```

### Arbitrary Waveform via `timeresp`

```matlab
u = zeros(1, 5001); u(1) = 1/1e-12;   % Impulse input
[yTime, tTime] = timeresp(fit21, u, 1e-12);
```

### `pwlresp` -- Piece-Wise Linear Transient

For periodic or arbitrary piece-wise linear excitation:

```matlab
tfData = s2tf(s);
fitTF = rational(s.Frequencies, tfData);
sigTime = [0, 0.1, 0.6, 0.7]*1e-9;    % Waveform breakpoints
sigValue = [0, 5, 5, 0];               % Values at breakpoints
tPer = 1.5e-9;                         % Period
tSim = 0:2e-11:3*tPer;
[tran, tPwl] = pwlresp(fitTF, sigTime, sigValue, tSim, tPer);
```

### Advanced TDR: `pwlresp` with Raised Cosine

For better resolution (zero-derivative transitions -- no excitation ringing):

```matlab
s11 = rfparam(s, 1, 1);
tdrFreqData = (s11 + 1) / 2;           % Voltage TDR response in frequency domain
tdrFit = rational(s.Frequencies, tdrFreqData, 'Qlimit', inf, 'TendsToZero', false);

% Raised cosine excitation: bandwidth-limited with zero-derivative transitions
tRise = 1 / s.Frequencies(end);         % 20%-80% rise time from measurement bandwidth
Ts = 1e-11;
tSim = (0:10000)' * Ts;
T = 2.44 * tRise;                        % Full cosine duration (~2.44x rise time)
nRise = ceil(T / Ts);
tPulse = (0:nRise)' * Ts;
pulse = 0.5 * (1 - cos(pi * tPulse / T));
[tdr, tOut] = pwlresp(tdrFit, [tPulse; tSim(end)], [pulse; 1], tSim);

% Convert to impedance profile
s11_recovered = 2*real(tdr) - 1;        % Recover reflection coefficient
Z = 50 * (1 + s11_recovered) ./ (1 - s11_recovered);  % Impedance in ohms
```

**Resolution:** TDR spatial resolution is `velocity * tRise / 2`. With 10 GHz bandwidth and velocity 2e8 m/s, minimum resolvable feature is ~1 cm. Do not interpret ringing artifacts (from limited bandwidth) as physical discontinuities.

---

## Choosing: Rational Fit vs. Direct iFFT

Two approaches exist for computing time-domain responses from frequency-domain data:

| Approach | Best for | Requirements |
|----------|----------|--------------|
| **Rational fit** + `pwlresp`/`stepresp`/`impulse` | Reusable model (SPICE export, repeated excitations, pole/zero analysis). Handles non-uniform grids and missing DC natively. | Fitting step (this skill) |
| **Direct iFFT** with raised cosine pulse | One-shot answer from uniform-grid data. No fitting or model order decisions. Essential for impedance/admittance step responses (Z(f), Y(f)). | Uniform frequency grid + known DC point |

**When iFFT cannot be used:** The iFFT approach requires a DC point (H(0)). If DC cannot be measured or accurately extrapolated -- common with VNA data that starts at a nonzero frequency -- use rational fitting instead. The rational fit implicitly handles DC extrapolation through its pole/residue model.

---

## Delay Extraction (rationalfit only)

```matlab
s = sparameters('channel.s2p');
s21 = rfparam(s, 2, 1);
% Use rationalfit (not rational) for delay extraction
fit = rationalfit(s.Frequencies, s21, 'DelayFactor', 1);
fprintf('Channel delay: %.3f ns\n', fit.Delay * 1e9);
```

---

## SPICE and Verilog-A Export

```matlab
generateSPICE(fit, 'model.sp');        % Export to SPICE subcircuit
writeva(fit, 'model.va', 'in', 'out', 'electrical');  % Verilog-A
```

---

## Gotchas

1. **`rfwrite` blocks on existing files** -- `rfwrite` opens an interactive "Overwrite?" dialog if the output file already exists, halting unattended execution. Always pass `'ForceOverwrite', true` to suppress the dialog.
2. **`rational` vs `rationalfit`** -- Use `rational` for new code (AAA, converges better). Use `rationalfit` ONLY when you need delay extraction (`'DelayFactor'` option + `fit.Delay` property).
3. **Single-param vs multi-port return types** -- `rational(freq, s21)` returns plain vectors from `impulse`/`stepresp`. `rational(sparametersObj)` returns `{N,N}` cell arrays -- access as `resp{i,j}`, `t{i,j}`.
4. **`freqresp` takes Hz** -- `freqresp(fit, freqInHz)` -- NOT rad/s. Pass `s.Frequencies` directly.
5. **`makepassive(fitObj)` can reduce accuracy** -- It optimizes residues. Always re-verify `errdb` after calling it.
6. **`passivity(fit)`** -- Call without arguments for reliable results across releases.
7. **Poor fit despite tightening Tolerance** -- If `errdb` plateaus, the raw data has quality issues (non-causal measurement artifacts, noise, insufficient bandwidth). Try `'Causal', false` as a diagnostic -- if accuracy improves dramatically, the data is non-causal. Set `'NoiseFloor'` to mask low-level noise, or accept the achievable accuracy.
8. **`MaxPoles` for hard upper bounds** -- Use when you need to cap pole count (e.g., SPICE export). `'Tolerance'` is the preferred accuracy knob.
9. **Non-causality from cascading S-parameters** -- Cascading causal S-parameters can produce non-causal results when frequency spacing is too coarse relative to the electrical length. The "reverse Nyquist criterion": any time-domain feature longer than `1/(2*df)` aliases into negative time. If a device has electrical length `tau` with significant reflections, the effective time-domain duration is `2*tau`. Cascading N copies gives `N*2*tau` -- once this exceeds `1/(2*df)`, the cascade becomes non-causal. The fix is finer frequency spacing (smaller `df`) before cascading, or accept reduced accuracy in the rational fit (`'Causal', false` diagnostic will confirm this mechanism).
10. **`sparameters(data, freq, Z0)` expects linear complex** -- Setting `s11 = -20` gives |S11| = 20 (non-physical), not -20 dB. Convert first: `10^(-20/20) = 0.1`.

## Conventions

- Use `tiledlayout`/`nexttile` for multi-panel fit verification figures
- Always label axes with units (GHz, dB, ns) and include figure titles
- Plot original and fit data together for visual verification (overlaid on same axes)
- Prefer `rational` (AAA algorithm) over `rationalfit` (vector fitting) for new code
- Use `'Display', 'off'` (default) for unattended runs; `'Display', 'plot'` for interactive visualization of fit progress

----

Copyright 2026 The MathWorks, Inc.

----
