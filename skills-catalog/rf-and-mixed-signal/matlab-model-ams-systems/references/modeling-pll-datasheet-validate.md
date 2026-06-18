# PLL Datasheet Modeling — Validate & Measure (Phases 5-9)

> PLL modeling validation and measurement (Phases 5-9): loop filter design, estimatePLLPhaseNoise, post-sim measurement, measurement blocks, iteration, and pitfalls. Companion to SKILL.md.

**Companion file**: `modeling-pll-datasheet-core.md` covers Phases 1-4
(extract params, map blocks, assemble model).

---

## Availability Check (MANDATORY)

Before executing any phase below, the availability probe from
`modeling-pll-datasheet-core.md` MUST have been run. If a function or block
printed `[SKIP]`, skip the entire step that depends on it.

**Key release requirements**:

| Function / Block | Available From |
|---|---|
| `estimatePLLPhaseNoise` | R2026b |
| `phaseNoiseMeasure` | R2021a |
| `clockJitterMeasure` | R2021a |
| `phaseNoiseToJitter` | R2021a |
| `lockTimeMeasure` | R2021a |
| `secondOrderPassiveFilterDesign` | R2021a |
| `thirdOrderPassiveFilterDesign` | R2021a |
| `fourthOrderPassiveFilterDesign` | R2021a |
| `msbPllFoundation` library | R2021a |
| `msbPllMeasurements` library | R2021a |

If `estimatePLLPhaseNoise` is unavailable (pre-R2026b), skip Phase 6
entirely and rely on Phase 7/8 post-simulation measurements instead.

---

## Phase 4.5: Baseband PLL — Fast Exploration (ON REQUEST ONLY)

**Trigger**: User explicitly asks for rapid BW/PM sweeps or fast loop exploration.

The `msbPllArchitectures/Baseband PLL` block is a linearized phase-domain model
(100-1000x faster). Use it to sweep BW/PM rapidly, then build full model with
the chosen parameters.

```matlab
fastModel = 'PLL_FastExplore';
new_system(fastModel); open_system(fastModel);
set_param(fastModel, 'Solver', 'VariableStepDiscrete');
add_block('msbPllArchitectures/Baseband PLL', [fastModel '/BB_PLL']);
set_param([fastModel '/BB_PLL'], ...
    'Fo', num2str(fVco), 'ReferenceFrequency', num2str(fRef), ...
    'DividerRatio', num2str(N), 'ChargePumpCurrent', num2str(Icp), ...
    'VCOSensitivity', num2str(Kvco), 'FilterType', '3rd order passive', ...
    'CompSelectionMethod', 'Automatic', 'Fc', num2str(Fc), 'Phi', num2str(Phi));

% Sweep BW (completes in seconds)
Fc_sweep = linspace(Fc/3, Fc*3, 10);
for k = 1:numel(Fc_sweep)
    set_param([fastModel '/BB_PLL'], 'Fc', num2str(Fc_sweep(k)));
    sim(fastModel, 'StopTime', num2str(20/Fc_sweep(k)));
end
close_system(fastModel, 0);
```

**Limitations**: No spurs, no PN measurement, no nonlinear effects (cycle slip).
Use ONLY for loop dynamics. Build full event-driven model for final validation.

---

## Phase 5: Design the Loop Filter

### 5.1 Key Relationships

```
Open-loop gain:     L(s) = (ICP / 2pi) * Z_LF(s) * (2pi * Kvco / s) * (1/N)
Loop bandwidth:     f_BW  (where |L(j*2pi*f_BW)| = 1)
Phase margin:       PM = 180 + angle(L(j*2pi*f_BW))
```

### 5.2 MSB Loop Filter Design Functions

All three share the same five input arguments:

| Argument | Description | Guideline |
|----------|-------------|-----------|
| `Fc` | Loop bandwidth (Hz) | Start at 1/10th of f_PFD |
| `Phi` | Phase margin (degrees) | 40 < Phi < 60 recommended |
| `Icp` | Charge pump current (A) | From datasheet |
| `Kvco` | VCO sensitivity (Hz/V) | From datasheet |
| `Nmin` | Minimum divider ratio | Worst-case N for stability |

```matlab
% 2nd order
[C1, C2, R2] = secondOrderPassiveFilterDesign(Fc, Phi, Icp, Kvco, Nmin)

% 3rd order (most common)
[C1, C2, C3, R2, R3] = thirdOrderPassiveFilterDesign(Fc, Phi, Icp, Kvco, Nmin)

% 4th order (maximum spur rejection)
[C1, C2, C3, C4, R2, R3, R4] = fourthOrderPassiveFilterDesign(Fc, Phi, Icp, Kvco, Nmin)
```

### 5.3 Automatic Mode (Preferred)

```matlab
set_param(blk, 'CompSelectionMethod', 'Automatic', ...
    'Fc', num2str(Fc), 'Phi', num2str(Phi));
```

### 5.4 4th-Order Filter: Manual Design Workaround

`fourthOrderPassiveFilterDesign` often fails at wide BW (P58). Workaround:

```matlab
Phi_base = 60;  % elevated PM to compensate for 4th pole
[C1, C2, C3, R2, R3] = thirdOrderPassiveFilterDesign(Fc, Phi_base, Icp, Kvco, Nmin);
f4 = 50*Fc; T4 = 1/(2*pi*f4); C4 = C3; R4 = T4/C4;
set_param(blk, 'CompSelectionMethod', 'Manual', ...
    'FilterType', '4th order passive', ...
    'C1',num2str(C1),'R2',num2str(R2),'C2',num2str(C2), ...
    'R3',num2str(R3),'C3',num2str(C3),'R4',num2str(R4),'C4',num2str(C4));
```

4th pole at 50x BW erodes ~8-10 deg of PM.

### 5.5 Active Loop Filter (ON REQUEST ONLY)

**Trigger**: User asks for active filter, or supply < 1.8V, or BW > fPFD/20.

```matlab
set_param(lfBlk, 'FilterType', '3rd order active', ...
    'CompSelectionMethod', 'Automatic', 'Fc', num2str(Fc), 'Phi', num2str(Phi));
```

**Use when**: supply < 1.8V, BW > fPFD/20, or Icp limited.
**Avoid when**: standard 2.5-3.3V supply (passive is simpler, less noise).

### 5.6 Design Guidelines

- **Bandwidth**: Fc <= f_PFD / 10 for loop stability
- **Phase margin**: 45-60 degrees typical; higher = more stable but slower
- **Nmin**: Use the smallest N the PLL will operate at (worst-case gain)
- **Nonlinear lock time**: 2-4x longer than linear prediction (P55 in pitfalls)

### 5.7 Filter Realizability Check (MANDATORY)

After computing filter components, verify they are physically realizable:

```matlab
% Bounds: C in [0.1pF, 100µF], R in [1Ω, 10MΩ]
comps = [C1 C2 C3 R2 R3];
names = {'C1','C2','C3','R2','R3'};
for k=1:numel(comps)
    if startsWith(names{k},'C') && (comps(k)<0.1e-12 || comps(k)>100e-6)
        fprintf('WARNING: %s=%.3g out of range\n', names{k}, comps(k));
    elseif startsWith(names{k},'R') && (comps(k)<1 || comps(k)>10e6)
        fprintf('WARNING: %s=%.3g out of range\n', names{k}, comps(k));
    end
end
```

**Fix**: C too small → decrease Icp. R too large → increase Icp.
Doubling Icp roughly halves R and doubles C for same BW/PM.

### 5.8 Jitter-Aware BW Selection (Lock Time vs. Phase Noise Tradeoff)

The `12/t_lock` formula (P55) optimizes for **lock time only**. When a
jitter or phase noise target is also specified, wider BW lets more VCO
noise through. Use this decision tree:

1. **Lock time is the binding constraint** (no jitter spec, or jitter is easy):
   ```
   Fc = min(12/t_lock, fPFD/10)
   ```

2. **Jitter is the binding constraint** (lock time is relaxed):
   ```
   Fc = BW where analytical jitter ≈ target × 0.7 (30% margin)
   ```
   Use `phaseNoiseToJitter` or `estimatePLLPhaseNoise` to sweep BW
   analytically before committing to simulation.

3. **Both are tight** (most common in real datasheets):
   ```
   Fc_lock = 12/t_lock          % BW needed for lock time
   Fc_jitter = (find from sweep) % BW needed for jitter
   if Fc_jitter >= Fc_lock
       Fc = Fc_lock              % lock time dominates, jitter met easily
   elseif Fc_jitter < Fc_lock
       Fc = Fc_jitter            % start narrow for jitter, verify lock time
       if lock_time > target
           flag tradeoff conflict to user
       end
   end
   ```

**Rule of thumb**: For ultra-low jitter parts (< 50 fs target), start
with BW = 500 kHz–1 MHz regardless of lock time formula, verify
jitter analytically, then widen only if lock time fails.

---

## Phase 6: Validate with `estimatePLLPhaseNoise`

### 6.1 From the Simulink Block

```matlab
[out, cfg] = estimatePLLPhaseNoise(gcb);
```

### 6.2 Standalone (No Block Required)

```matlab
VCOpn.f_Hz         = [10e3, 100e3, 1e6, 5e6];
VCOpn.L_dBc_per_Hz = [-86,  -111,  -134, -145];

% Derive charge pump noise from datasheet PNSYNTH and PN1_f
Icp = 5e-3; fPFD = 10e6; PNSYNTH = -220; PN1_f = -116;
Si_cp = 10^((PNSYNTH + 10*log10(fPFD) - 10*log10(2*pi^2) + 20*log10(Icp)) / 10);
fc_cp = 10e3 / 10^((PNSYNTH - PN1_f - 10*log10(fPFD) + 180) / 10);

[out, cfg] = estimatePLLPhaseNoise( ...
    Architecture            = "frac-dsm", ...
    ReferenceFrequency      = fPFD, ...
    ChargePumpCurrent       = Icp, ...
    VCOSensitivity          = 40e6, ...
    FractionalDividerRatio  = 422.52, ...
    UseDSMDividerNoise      = true, ...
    DSMOrder                = 3, ...
    C1 = 1.31e-12, C2 = 1.44e-11, C3 = 9.41e-14, ...
    R2 = 1.33e4,   R3 = 1.7e5, ...
    VCOPhaseNoise           = VCOpn, ...
    ChargePumpNoiseDensity  = Si_cp, ...
    ChargePumpFlickerCorner = fc_cp, ...
    Temperature             = 25, ...
    FrequencyOffset         = [1e3 10e3 100e3 1e6 10e6]);
```

### 6.3 Validation Checklist

Compare model output against **datasheet specs only**:
```
[ ] Phase noise at key offsets matches datasheet values
[ ] RMS jitter matches datasheet spec
[ ] PFD spur level at fPFD offset meets spec
```

---

## Phase 7: Post-Simulation Measurement (MSB Utilities)

### 7.1 Phase Noise Measurement

```matlab
[PnAtOffsets, freqAxis, pnProfile] = phaseNoiseMeasure( ...
    time, vcoSignal, Rbw, FrOffset, PlotOption, Tag, PnTarget);
```

### 7.2 Lock Time Measurement

```matlab
LockTime = lockTimeMeasure(Vctrl, Time, ErrorTol)
```

### 7.3 Clock Jitter Measurement

```matlab
[periodJitter, c2cJitter] = clockJitterMeasure(t, v, threshold, clockFreq)
```

### 7.4 Phase Noise to Jitter Conversion

```matlab
Jrms_sec = phaseNoiseToJitter(freqOffset, phaseNoise, carrierFreq, intBandLow, intBandHigh)
```

### 7.5 Reference Spur Measurement (ON REQUEST ONLY)

**Trigger**: User asks for spur level or has a spur spec (e.g., "spurs < -60 dBc").

```matlab
% From PLL Testbench logged PN profile
ud = get_param(tbBlk, 'UserData');
pnFreq = ud.PnFOffset; pnLevel = ud.Pn;
fPFD = fRef / R;  % comparison frequency

% Find peak near fPFD (+/- 5 bins)
[~, spurIdx] = min(abs(pnFreq - fPFD));
searchRange = max(1,spurIdx-5) : min(numel(pnLevel),spurIdx+5);
spurPeak_dBc = max(pnLevel(searchRange));

% Floor from neighboring region
floorIdx = [searchRange(1)-10:searchRange(1)-3, searchRange(end)+3:searchRange(end)+10];
floorIdx = floorIdx(floorIdx>0 & floorIdx<=numel(pnLevel));
pnFloor_dBc = mean(pnLevel(floorIdx));

% Spur in dBc (integrate over RBW)
spurLevel_dBc = spurPeak_dBc + 10*log10(Rbw);
fprintf('Ref spur @ %.0f MHz: %.1f dBc\n', fPFD/1e6, spurLevel_dBc);
```

**Fractional spurs** (Frac-N): appear at fPFD/denom multiples. Higher DSM order
suppresses but pushes quantization noise to high offsets.

**If spur fails**: narrow BW, increase filter order (3rd→4th), check CP mismatch.

---

## Phase 8: Validate with Measurement Blocks (`msbPllMeasurements`)

Key points:
- PLL Testbench output port provides the **reference clock stimulus**
- PLL Testbench input port receives VCO output for measurement
- Enable `PlotAndLogPhaseNoise` = `'on'` on testbench blocks
- Set RBW = min(FreqOffset)/2 and SpectralAverages=2 for faster sims
- TB targets must come from **datasheet**, not analytical prediction

### VCO Testbench Mask Parameters (P29)

```matlab
mask = Simulink.Mask.get([model '/VCO Testbench']);
mask.getParameter('PhaseNoiseFreqOffset').Value = mat2str(Foffset);
mask.getParameter('PhaseNoiseVector').Value = mat2str(phaseNoise);
mask.getParameter('ResBandwidth').Value = num2str(min(Foffset)/2);

set_param([model '/VCO Testbench'], ...
    'ControlVoltage', '2', ...
    'SpectralAverages', '2', ...
    'PlotAndLogPhaseNoise', 'on');
```

### Stop Time Calculation (P5)

```matlab
simStopTime = msblks.utilities.acStopTime(avg, RBW, holdoff);
set_param(model, 'StopTime', num2str(simStopTime));
```

### Testbench Logged Data (`pll_phase_noise_out`)

- `PnFOffset`/`Pn` -- full spectral profile (301 pts)
- `phaseNoiseFreq`/`phaseNoiseLevel` -- discrete measurement offsets
- `zcData` -- zero-crossing timestamps (for spur analysis)
- `CenterFreq`, `Avg`, `simStopTime`

### Zero-Crossing Capture (P30, P33)

**Preferred**: Triggered Subsystem with Digital Clock inside.
See **references/validate.md** for full code.

**Fallback**: `rising_idx = find(diff(v) > 0.5); zc_times = t(rising_idx + 1);`

---

## Phase 9: Iterate and Refine

### 9.1 Iteration Decision Table

| Observation | Adjustment |
|-------------|-----------|
| In-band noise too high | Increase f_PFD (use doubler), decrease N |
| VCO noise dominates at high offset | Choose lower-noise VCO operating point |
| CP noise dominates in-band | Increase ICP (wider BW helps too) |
| Spurs too high | Narrow loop BW, increase filter order |
| Lock time too slow | Widen loop BW (nonlinear = 2-4x linear) |
| Phase margin too low | Adjust filter components (increase R2) |

### 9.2 Autonomous Iteration Algorithm (MANDATORY when targets specified)

When PN or lock time targets are specified, iterate BEFORE simulation until
analytical checks pass. Key logic:

1. Compute analytical PN using actual 3rd-order filter TF (NOT 2nd-order approx)
2. Check ALL target offsets
3. Corrective action by failure location:
   - **In-band fail**: increase fRef (decrease N) or increase Icp
   - **Out-of-band fail**: narrow BW (check lock time tradeoff)
4. Recompute filter, update model, repeat

**Termination criteria:**
- **Success**: ALL targets met with ≥ 2 dB margin → STOP, proceed to sim
- **Max iterations**: 10 attempts → STOP, report best result and ask user
- **Conflicting targets**: lock time requires wider BW but PN requires narrower
  → STOP, inform user of tradeoff and ask for priority
- **Diminishing returns**: improvement < 0.5 dB between iterations → STOP

**Step-size rules:**
- Lock time lever (Fc): increase by 50% per iteration (e.g., 500k → 750k → 1.1M)
- Phase noise lever (Fc): decrease by 30% per iteration
- Icp lever: double per iteration (1mA → 2mA → 4mA), cap at 10 mA
- Filter order: try 3rd → 4th only once (not iterative)
- PM adjustment: ±5° per iteration (range 45°–65°)

**When to switch levers:**
- If 3 iterations of Fc adjustment don't converge → try Icp
- If Icp at max and still failing → inform user (may need different architecture)

### 9.3 Accurate Phase Noise Calculation

Use actual 3rd-order filter impedance Z(s) = parallel(C1, series(R2,C2), series(R3,C3)).
See **references/iteration-algorithm.md** for `accuratePhaseNoise()` function.
Never use 2nd-order approximation (P72: can be 3-5 dB off near loop BW).

### 9.4 Two-Pass Simulation Strategy (P86 — MANDATORY)

- **Pass 1 (ALWAYS):** Lock time only. `StopTime = min(3*t_lock_target, 50µs)`.
  If PASSES with >3x margin → DONE. Do NOT sweep or iterate.
- **Pass 2 (ONLY if user specified PN/jitter/spur targets or asks for PN):**
  1. Set `SpectralAverages='2'` explicitly (P102: mask default is 4)
  2. Set `HoldOffTime` = 1.5× *measured* lock time from Pass 1 (P101), NOT the pre-sim estimate
  3. `StopTime = msblks.utilities.acStopTime(2, RBW, measuredHoldoff)` (P98)
  4. Verify StopTime >= "Recommended min. simulation stop time" shown in TB mask (P75)
  5. Enable `PhaseNoiseOption='on'`, `PlotAndLogPhaseNoise='on'`

**Critical rules:**
1. >3x margin on first attempt → STOP. No sweeps "for completeness."
2. No PN/jitter spec → NEVER run Pass 2.
3. Use `acStopTime` for PN StopTime (P98), not manual calculation.

### 9.5 Testbench Parameter Ordering (P71)

PLL Testbench mask callbacks validate vector lengths when enabling measurement
options. You MUST set vectors BEFORE enabling the corresponding option:

```matlab
% CORRECT ORDER:
% 1. Set offset and target vectors (via Simulink.Mask.get)
tbMask = Simulink.Mask.get(tb);
tbMask.getParameter('PhaseNoiseFreqOffset').Value = mat2str(pnOffsets);
tbMask.getParameter('TargetPhaseNoiseVector').Value = mat2str(pnTargets);  % SAME LENGTH as pnOffsets!
tbMask.getParameter('ResBandwidth').Value = num2str(min(pnOffsets)/2);

% 2. Set scalar params
set_param(tb, 'TargetLockTime', num2str(lockTimeTarget));

% 3. THEN enable measurement options (triggers validation callbacks)
set_param(tb, 'FrequencyMeasureOption', 'on');
set_param(tb, 'LockTimeOption', 'on');
set_param(tb, 'PhaseNoiseOption', 'on');
set_param(tb, 'PlotAndLogPhaseNoise', 'on');
```

---

## Phase 10: Simulation Troubleshooting

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| "Algebraic loop" | Zero-delay feedback | Check `PropDelay` > 0 on PFD/divider |
| "Step size too small" / hangs | Filter component = 0 | Verify all C, R > 0 |
| NaN in Vctrl | Unstable (PM<0 or BW>fPFD/5) | Reduce Fc, increase PM |
| Sim very slow | High fVco + wrong solver | Use VariableStepDiscrete |
| Lock time = 0 from TB | Ripple > FreqErrorTol | `Kvco*peak2peak(Vctrl)` — relax tol or narrow BW |
| PN shows flat line | HoldOffTime >= StopTime | Fix holdoff; check VCO toggling |
| "Apply or cancel" dialog | Block dialog open | `close_system(blk)` first (P97) |

**Pre-sim check** (always run before `sim()`):
```matlab
assert(strcmp(get_param(model,'Solver'),'VariableStepDiscrete'));
assert(str2double(get_param(model,'StopTime')) > 0);
```

---

## Pitfalls Quick Reference

See **references/pitfalls.md** for the full catalog (P1-P103).

**Simulation failures:** P39 (PFD timing), P57/P92 (Nmin ordering), P71 (vector length), P79 (manual filter N>50), P87 (HoldOff<StopTime), P93 (LockTime=0), P97 (close dialog), P105 (dual modulus P>S>0)

**Wrong results:** P43 (Fo=fComp), P48 (OL=Gofs/N), P74 (no PN extrapolation), P94/P100 (-999 not -inf), P98 (acStopTime), P99 (DSM spurs), P101 (measured holdoff), P102 (SpectralAverages=2), P103 (UserData lock time)

**Plotting/analysis:** P106 (pllOpenLoopPlot ylim crash — manual Bode fallback, no CST needed)

**Performance:** P83 (PN off by default), P85/P95 (arrangeSystem), P86 (two-pass, no over-iteration)

---

Copyright 2026 The MathWorks, Inc.
