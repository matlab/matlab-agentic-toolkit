# PLL Modeling Pitfalls and Lessons Learned

Reference file for `modeling-pll-datasheet-validate.md`. Organized by category.

---

## Solver & Wiring (P1-P3)
- **P1**: Always use `VariableStepDiscrete` solver
- **P2**: Use `Simulink.Mask.get` for paired vector parameters
- **P3**: Use `add_line` with `{'autorouting','smart'}` (NOT `'autoroute','on'`)

## Testbench Configuration (P4-P10)
- **P4**: VCO Testbench provides the control voltage
- **P5**: `msblks.utilities.setStopTime` is a mask callback -- compute manually: `msblks.utilities.acStopTime(avg, RBW, holdoff)`
- **P6**: Always use Ring Oscillator VCO (not plain VCO)
- **P7**: Must call `msblks.VCO.estimatePhaseNoiseCore(f0, Foffset, PN)` to get `periodJitter` & `cornerFreq`
- **P8**: Enable "Plot and log measurements" on testbench blocks
- **P9**: RBW = half the lowest offset; set via `Simulink.Mask.get`
- **P10**: PLL TB: output=ref clock, input=VCO output

## Analysis & Measurement (P11-P17)
- **P11**: `estimatePLLPhaseNoise` returns dense grid (~500pts) -- use `interp1(log10(...))` for specific offsets
- **P12**: Must pass `ChargePumpNoiseDensity` and `ChargePumpFlickerCorner` to `estimatePLLPhaseNoise`
- **P13**: Avoid phase noise offsets below 100 kHz for PLL sims (sim time explodes)
- **P14**: Model layout: forward path horizontal, feedback mirrored below
- **P15**: Enable Loop Filter thermal noise (`LfEnableImpairments='on'`)
- **P16**: Model CP broadband noise with external Band-Limited White Noise
- **P17**: PLL Testbench targets must come from datasheet, not analytical prediction

## Impairments (P21-P28)
- **P21**: CP current mismatch ON, CP timing OFF (too aggressive), LF thermal ON, PFD edge OFF
- **P22**: Dual Modulus Prescaler params: P, N, S
- **P23**: Loop Filter Temperature must match datasheet test conditions
- **P24**: Fractional Clock Divider with Accumulator has 3 output ports
- **P25**: `ReturnWorkspaceOutputs` needed for simOut access
- **P26**: Prefer `msbPllArchitectures` blocks over manual wiring
- **P27**: Baseband PLL for fast behavioral analysis
- **P28**: Clock Jitter Measurement outputs MUST be connected (Display blocks)

## Architecture Block Internals (P29-P39)
- **P29**: VCO Testbench has NO `Fo`/`Kvco`. Always probe with `Simulink.Mask.get`
- **P30**: Ring Oscillator VCO output is digital 0/1
- **P31**: To Workspace -> `simOut.<var>`; Testbench logged data -> base workspace
- **P32**: Testbench logged struct: `simStopTime`, `zcData`, `PnFOffset`, `Pn`, `phaseNoiseFreq`, `phaseNoiseLevel`, `CenterFreq`, `Avg`
- **P33**: Prefer Triggered Subsystem for zero-crossing capture
- **P34**: `editSystem` breaks link, resolves N, removes mask. Set params BEFORE calling it
- **P35**: After `editSystem`: PFD, CP, LF, VCO, divider, Constant(N), terminators
- **P36**: Do NOT manually break link + remove mask -- use `editSystem`
- **P37**: Mask callbacks (`plotButtonLoopDynamics`, `estimatePhaseNoise`) only work before `editSystem`
- **P38**: **Flattening is safe at any VCO frequency** if PFD timing is scaled (P39)
- **P39**: PFD PropDelay = `max(50e-12, min(5e-12, 1/(2*fVco)/10))`, MaxFreqInterest = `2*fVco` (50ps floor — block rejects smaller)

## Design Rules (P40-P49)
- **P40**: Cap loop BW at 500 kHz: `Fc = min(fPfd/20, 500e3)`
- **P41**: DSM quantization noise dominates in-band -- validate only at offsets >10x loop BW
- **P42**: `phaseNoiseToJitter` API: `[~,~,Jrms_s] = phaseNoiseToJitter(PNFreq, PNPow, 'Frequency', fCarrier)`
- **P43**: PLL TB: `Fo=fComp` (the PFD comparison frequency, NOT fVco and NOT fRef if R>1), `ExpectedFreq=fVco`, `SampleRate=8*fVco`. When an R-divider is used (fComp = fRef/R), Fo must equal fComp since that is the actual reference frequency seen by the PFD.
- **P44**: `phaseNoiseFreq`/`phaseNoiseLevel` = user offsets; `PnFOffset`/`Pn` = full 301-pt FFT
- **P45**: HoldOffTime must be slightly above the estimated lock time (e.g., 1.2-1.5x the estimated lock time). Do NOT use 5x the target lock time — that wastes simulation time. Example: if estimated lock = 0.4ms, use HoldOffTime = 0.5ms. The block mask shows a "Recommended min. simulation stop time" — always set StopTime to match or exceed that value.
- **P46**: PFD impairments cannot be enabled for VCO > ~4 GHz
- **P47**: `msblks.VCO.estimatePhaseNoiseCore` signature: `(f0, f, LofF)`
- **P48**: `getPllLoopResponse` returns forward-path gain (no /N). True OL = `Gofs/N`
- **P49**: `isempty(struct)` is false even for empty structs -- use `isempty(fieldnames(s))`

## Library & API (P50-P57)
- **P50**: MSB library names: `msbPllArchitectures`, `msbPllFoundation`, `msbPllMeasurements`, `msbUtilities` (NOT `msblks`)
- **P51**: `pllOpenLoopPlot(Icp, Kvco_Hz, N, Fc, R2, R3, R4, C1, C2, C3, C4)` -- unused components = 0
- **P52**: PLL TB has 1 outport (ref clock) and 1 inport (signal to measure)
- **P53**: PLL TB results are in **model workspace**: `Frequency_<SID>`, `LockTime_<SID>`
- **P54**: HoldOffTime must be > estimated lock time AND < StopTime. Use 1.2-1.5x the estimated lock time (NOT 5x the target), capped at 0.8×StopTime (P87). Always set StopTime to match the "Recommended min. simulation stop time" shown in the testbench block mask.
- **P55**: **Nonlinear lock time is 2-4x linear.** Initial BW estimate: `Fc = 12 / t_lock_target` (combines `4/t_lock` with 3x nonlinear factor). This gives a first attempt close to the final answer, minimizing design iterations. Example: 5 µs target → start at Fc = 2.4 MHz, not 500 kHz.
- **P56**: Prefer `CompSelectionMethod='Automatic'` over manual filter design
- **P57/P92**: `set_param` order: set `Nmin='1'` FIRST (to lower the floor), then `N`, then `Nmin` to final value. The old advice "set N before Nmin" fails when the mask's default Nmin > the new N (e.g., default Nmin=100, new N=65). Sequence: `set_param(blk,'Nmin','1'); set_param(blk,'N',num2str(N)); set_param(blk,'Nmin',num2str(Nmin));`

## Simulation Workflow (P58-P99)
- **P58**: `fourthOrderPassiveFilterDesign` fails at wide BW -- use 3rd-order + manual 4th pole
- **P59**: Dual Modulus: set `Nmin` low BEFORE prescaler values, then raise Nmin
- **P60**: `set_param` for StopTime doesn't take effect during active sim -- stop first
- **P61**: Default `SpectralAverages` to 2 unless user asks for more
- **P62**: Resize PLL TB block for readability: ~350x300 pixels
- **P63**: Integer-N PLLs do NOT have DSM -- don't reference DSM noise
- **P64**: In-band PN is meaningless without impairments enabled
- **P65**: "Apply or cancel unapplied changes" error -- ask user to close open dialogs
- **P66**: Dual-Modulus prescaler produces sub-harmonic spurs at fRef*k/N
- **P67**: For spur analysis, set last offset to 1.2xfRef (not exactly fRef)
- **P68**: MCP preserves only one figure -- use `tiledlayout(1,2)` for all results in one figure
- **P69**: Do NOT use `msbUtilities/Clock Generator` as the reference source in PLL models. ALWAYS use `msbPllMeasurements/PLL Testbench` — it provides both the reference clock (outport) AND phase noise/lock time measurement (inport). Clock Generator is only for standalone VCO testing.
- **P70**: PLL Testbench measurement options (Setup tab checkboxes) are OFF by default. You MUST explicitly enable them with the correct mask parameter names: `set_param(tb, 'LockTimeOption', 'on', 'PhaseNoiseOption', 'on')`. The frequency measurement is `FrequencyMeasureOption` (on by default). Without enabling these, no lock time or phase noise is measured. `PlotAndLogPhaseNoise` alone is NOT sufficient — it only controls logging/plotting after measurement is enabled.
- **P71**: PLL Testbench `PhaseNoiseFreqOffset` and `TargetPhaseNoiseVector` are PAIRED vectors — they MUST have the same length or the InitFcn callback will error on simulation. When setting custom measurement offsets, ALWAYS set BOTH vectors together via `Simulink.Mask.get(tb)`. The default `TargetPhaseNoiseVector` has 4 elements; if you change `PhaseNoiseFreqOffset` to a different length (e.g., 6 offsets), you MUST update `TargetPhaseNoiseVector` to match. Set these BEFORE enabling `PhaseNoiseOption`.
- **P72**: Do NOT use a 2nd-order approximation (`H(s) = (2*zeta*wn*s + wn^2) / (s^2 + ...)`) for phase noise prediction. Use the ACTUAL 3rd-order filter impedance from `thirdOrderPassiveFilterDesign` output (C1, C2, C3, R2, R3) to compute the real open-loop gain. The 2nd-order approximation can be 3-5 dB off at offsets near the loop bandwidth.
- **P73**: When phase noise targets are specified, the iteration in Phase 9 is MANDATORY — do not proceed with a design that fails analytical PN checks. The primary knobs are: (1) increase fRef to decrease N (most effective for in-band), (2) narrow BW (for out-of-band VCO noise), (3) increase Icp. Always verify lock time still meets target after BW changes.
- **P74**: VCO phase noise offset vector must ONLY contain values explicitly specified in the datasheet. Do NOT extrapolate or add additional offset points (e.g., 1kHz, 10kHz) that are not in the datasheet table. Using extrapolated values gives a false sense of accuracy. If the datasheet specifies PN at [100kHz, 1MHz, 3MHz, 10MHz], use exactly those 4 points.
- **P75**: PLL Testbench StopTime must always match or exceed the "Recommended min. simulation stop time" displayed in the testbench block mask. This value is computed from: `HoldOffTime + SpectralAverages / ResBandwidth + margin`. Never use an arbitrary short StopTime (like 10μs) when the testbench needs milliseconds for PN measurement. If full sim is impractical, note the limitation explicitly.
- **P76**: NEVER delete a block or line without reconnecting all affected ports. When replacing a Scope with a To Workspace (or vice versa), add the new block and connect it BEFORE deleting the old one — or use a branch so both stay connected. After ANY block deletion or line modification, run the dangling line check:
```matlab
lines = find_system(model, 'FindAll', 'on', 'Type', 'line');
for i = 1:numel(lines)
    src = get_param(lines(i), 'SrcPortHandle');
    dst = get_param(lines(i), 'DstPortHandle');
    if any(src == -1) || any(dst == -1)
        warning('Dangling line found — delete or reconnect it');
        delete_line(lines(i));
        break;
    end
end
```
- **P77**: When `ReturnWorkspaceOutputs='on'` is set on the model, To Workspace block data is accessed via `simOut.<VariableName>` (e.g., `simOut.Vctrl`), NOT from the base workspace. The result is a `timeseries` object — access time with `.Time` and values with `.Data`. Testbench logged data (e.g., `pll_phase_noise_out`) still goes to the base workspace via `evalin('base', ...)`.
- **P78**: `getPllLoopResponse` may report different crossover/PM values than the MSB architecture block's internal auto-design. This is a known gain normalization difference (P48). When the PLL locks correctly in simulation, trust the time-domain result as ground truth. Present design target values (fc, PM) alongside analytical plots and note any discrepancy in the report.
- **P79**: **`CompSelectionMethod='Automatic'` fails silently for high-N PLLs (N > ~50).** The architecture block's auto-design places the *forward-path* gain crossover at `Fc` without dividing by N. For N=288.6, requesting Fc=2 MHz gives a true loop BW of only 47 kHz with PM=5° (borderline unstable). The fix: use `thirdOrderPassiveFilterDesign(Fc, PM, Icp, Kvco, N)` which correctly includes N in the loop gain calculation, then set `CompSelectionMethod='Manual'` with the computed values. Rule of thumb: always use manual filter design when N > 50.
- **P80**: **Use scientific notation strings for high-frequency parameters.** For frequencies > 1 GHz, prefer `set_param(blk, 'Fo', '20e9')` over `set_param(blk, 'Fo', num2str(fVco))`. Scientific notation is easier to verify at a glance (`'20e9'` vs `'20000000000'`), less prone to variable-copy errors, and matches how the mask displays values. When computing from variables, use `sprintf('%g', val)` for compact scientific form.
- **P81**: **PFD block has 2 output ports (UP and DOWN) — both must connect to Charge Pump.** When building from foundation blocks (not architecture block), the PFD output port 1 = UP pulse, port 2 = DOWN pulse. The Charge Pump has 2 input ports (UP, DOWN). Connecting only the UP port causes runaway positive feedback (Vctrl ramps unbounded). The architecture block handles this internally, but if you flatten or build from foundation blocks, verify both PFD→CP connections exist.
- **P82**: **Ultra-low jitter targets (< 50 fs) require narrower BW than the lock-time formula suggests.** The `12/t_lock` formula (P55) optimizes for lock time. For parts like ADF4382 (20 fs target) or ADF4368 (29 fs target), start with BW = 500 kHz–1 MHz and verify jitter analytically (Section 5.6) before widening for lock time. A BW of 4 MHz at 20 GHz gives ~34 fs — failing a 25 fs target even though lock time passes easily.
- **P83**: **Phase noise measurement OFF by default in PLL Testbench.** PN measurement adds 2-5 minutes of sim time (requires long holdoff + spectral averaging). Set `PhaseNoiseOption='off'` and `PlotAndLogPhaseNoise='off'` during initial model build. Enable ONLY when user explicitly requests PN results. For demos/quick validation, measure lock time only — it completes in seconds.
- **P84**: **Set `TargetLockTime` on PLL Testbench to the actual user spec.** Default is too low (3 µs), causing misleading "Target" display. Use `mask.getParameter('TargetLockTime').Value = num2str(t_lock)`.
- **P85/P95**: **Model must fill the canvas without manual zoom.** After assembly, call `Simulink.BlockDiagram.arrangeSystem(model)` to auto-layout blocks optimally, then `drawnow; set_param(model, 'ZoomFactor', 'FitSystem'); drawnow;` to zoom the canvas to fit the arranged blocks. `ZoomFactor='FitSystem'` alone without `arrangeSystem` often leaves the model in a small corner of the canvas.
- **P86**: **Two-pass simulation + don't over-iterate.** (a) StopTime for lock = `min(3 × t_lock_target, 50µs)` — NOT `5 × (12/BW)` which over-allocates. At 5 GHz, every µs = ~1s wall-clock. (b) If first attempt PASSES with >3x margin, STOP — do NOT sweep BW or iterate. The BW formula already gives a good design. Only iterate when first attempt FAILS. (c) Never enable `PhaseNoiseOption` unless user explicitly asks for PN.
- **P87**: **HoldOffTime MUST be < StopTime — otherwise testbench fires a blocking warning dialog and reports no measurements.** When P86 shortens StopTime, you MUST also shorten HoldOffTime to match. Use: `holdOff = min(1.5*estLockTime, 0.8*StopTime)`. The 80% cap ensures the testbench always has measurement time.
- **P88**: **VCO consistency — validate standalone, then verify same params in PLL.** When the datasheet provides VCO phase noise data: (1) Build a standalone VCO + VCO Testbench model, call `msblks.VCO.estimatePhaseNoiseCore(f0, Foffset, PN)` to get `PeriodJitter` and `CornerFrequency`, set them on the VCO, simulate, and confirm measured PN matches datasheet within ±3 dB. (2) After assembling the full PLL, probe the internal VCO and VERIFY its `PeriodJitter` and `CornerFrequency` match the validated values.
- **P93**: **PLL Testbench reports LockTime = 0 means Vctrl ripple exceeds frequency error tolerance.** The TB mask parameter is `FreqErrorTol` (default 1 MHz). In Fractional-N PLLs, DSM quantization noise causes residual Vctrl ripple that can exceed this tolerance even when the PLL is locked. When LockTime = 0:
  1. Measure steady-state Vctrl ripple (peak-to-peak in last 50% of sim) and convert to frequency: `Δf = Kvco × Vctrl_pp`.
  2. Inform the user: explain that ripple (±X MHz) exceeds the `FreqErrorTol` (Y MHz), and ask whether to (a) increase error tolerance, or (b) keep it strict and redesign the loop filter.
  3. If user accepts relaxed tolerance: `set_param(tb, 'FreqErrorTol', num2str(newTol))` where newTol = 1.5–2× the observed ripple, re-simulate.
  4. If user demands strict tolerance: narrow loop BW (reduces DSM noise passthrough), increase filter order, or add a 4th pole to attenuate high-frequency DSM energy. Re-simulate and verify both lock time and ripple.
  Do NOT silently switch to alternative measurement methods without first diagnosing and communicating the root cause to the user.
- **P96**: **`lockTimeMeasure` expects column vectors.** When using To Workspace timeseries data, the `.Data` field may be N-D. Always squeeze and columnize: `v = squeeze(Vctrl.Data); v = v(:); t = Vctrl.Time(:);` before passing to `lockTimeMeasure(v, t, errTol)`.
- **P97**: **"Apply or cancel unapplied changes" error blocks simulation.** This occurs when a block dialog is open in the MATLAB UI. Fix: call `close_system([model '/BlockName'])` to close the dialog, then retry `set_param` and `sim`.
- **P98**: **Always use `msblks.utilities.acStopTime(avg, RBW, holdoff)` for PN measurement StopTime.** Do NOT compute manually as `holdoff + avg/RBW` — the utility adds margin for spectral windowing. Manual calculation underestimates by ~30-40%.
- **P99**: **Fractional-N DSM spurs appear at multiples of fPFD/denominator.** For N=612.5 (frac=0.5, denom=2), spurs appear at fPFD/2 = 5 MHz and its sub-harmonics. When reporting PN at offsets that coincide with spur frequencies, clearly label them as "spur level" vs "PN floor" (measured between spurs). The PN floor is the meaningful noise metric; spur levels are a separate specification.
- **P100**: **`TargetPhaseNoiseVector` does NOT accept `-inf`.** The mask validates for finite values only. When no PN targets are specified, use `-999` (dBc/Hz) as a placeholder that will never trigger a failure: `mat2str(-999*ones(1, numel(pnOffsets)))`. Update P94 accordingly — `-inf` causes a mask error.
- **P101**: **Pass 2 HoldOffTime must use the MEASURED lock time from Pass 1, not the pre-sim estimate.** After Pass 1 confirms lock at e.g. 1.0 µs, set Pass 2 HoldOffTime = 1.5 × 1.0 µs = 1.5 µs. Do NOT carry forward the initial estimate (which used `(4/Fc)*3` and may be 5-7× too large). Excessive holdoff wastes measurement window and can push StopTime requirements higher unnecessarily.
- **P102**: **`SpectralAverages` defaults to 4 on the PLL Testbench mask — explicitly set to 2 (P61).** The skill mandates starting with 2 averages for faster simulation. If you don't explicitly `set_param(tb, 'SpectralAverages', '2')`, the mask default of 4 applies, doubling PN sim time. Only increase if user requests smoother results.
- **P103**: **When tuning an existing PLL model, NEVER estimate lock time from Vctrl settling.** Run `sim(model)` and read the PLL Testbench result: `ud = get_param(tbBlk, 'UserData'); lockTime = ud.lockTime;`. The testbench uses frequency-error-based detection (`FreqErrorTol`) which is the only valid measurement. Manual Vctrl analysis gives different (incorrect) results because voltage tolerance doesn't map linearly to frequency error across the VCO tuning curve.
- **P104**: **When an existing model has NO PLL Testbench (or no connected reference source), you CANNOT determine fComp from the model.** The `RefFreq` parameter is ONLY used for `estimatePLLPhaseNoise` estimation — it does NOT define the actual reference clock. Do NOT guess or calculate fComp from `Fo/N`. Instead, ASK the user: "What is the reference frequency (fComp) for this PLL?" You cannot design, simulate, or meet any spec without knowing fComp.
- **P105**: **Dual Modulus Prescaler constraints: P > S > 0, all positive integers.** The `SwallowCounter` (S) must be strictly positive — the mask rejects S=0. The `ProgramCounter` (P) must be strictly greater than S. When choosing P, N, S for a target divide ratio (P*N+S = Ntarget), enumerate valid combinations satisfying P > S > 0 BEFORE calling `set_param`. Safe setting order: set `Nmin='1'` first (P57), then S (while default P is still large), then P (verify P > S), then `Nmin` to final value. Example for Ntarget=40: P=7, N=5, S=5 (7>5>0, 7*5+5=40).
- **P106**: **`pllOpenLoopPlot` may crash with ylim error when phase <= -180 degrees.** The MSB function `pllOpenLoopPlot` has an edge case where `ylim([-180 max(...)])` fails if the computed phase at the midpoint is <= -180. **Fallback**: compute Bode manually using the loop filter impedance Z(s) and open-loop gain G(s) = Icp*Kvco*Z(s)/(N*s). Use `logspace` frequency sweep, compute magnitude/phase, find crossover by interpolation. Do NOT reach for Control System Toolbox (`tf`, `bode`) — it is not required and may not be installed. Example fallback:
  ```matlab
  f = logspace(3, 9, 1000); s = 1j*2*pi*f;
  Z = (1 + s*R2*C2) ./ (s*(C1+C2+C3) .* (1 + s*R2*C1*C2/(C1+C2+C3)) .* (1 + s*R3*C3));
  G = Icp * Kvco * Z ./ (N * s);
  mag_dB = 20*log10(abs(G)); phase_deg = angle(G)*180/pi;
  % Find fc (0 dB crossing) and PM (180 + phase at fc) by interpolation
  ```

---

## Tuning an Existing PLL to Meet Specs

When the user has an existing model and wants to meet a new spec (lock time, phase noise, spurs):

1. **Probe first** — extract current parameters (`get_param` on PLL block: `Fc`, `Phi`, `N`, `OutputCurrent`, `Kvco`, filter components)
2. **Check for PLL Testbench** — if no testbench exists, check if the PLL input port is connected. If unconnected or no reference source, ASK the user for fComp (P104). Do not proceed without it.
3. **Baseline sim** — run `sim(model)` and read PLL Testbench `UserData` for lock time, frequency, phase noise. This is the only valid baseline.
4. **Identify the lever** — for lock time: increase `Fc`; for phase noise: decrease `Fc` or increase filter order; for spurs: increase filter order or reduce `Fc`
5. **Redesign** — set new `Fc` (and `Phi` if needed), keep `CompSelectionMethod = 'Automatic'` so the block recomputes filter components
6. **Re-simulate** — run again, read testbench `UserData`. Iterate until spec is met.
7. **Report trade-offs** — wider BW improves lock time but degrades close-in phase noise; narrower BW improves PN but slows lock

Key formula: `lock_time ≈ 12/Fc` (conservative rule of thumb). Use it only for initial Fc sizing, then verify with testbench.

---

## High-Frequency PLL Modeling (>4 GHz)

Key rules:
1. **Flattening is safe** at any VCO frequency if PFD timing is scaled
2. **Scale PFD timing**: PropDelay < VCO half-period / 10
3. **Set MaxFreqInterest** = `2*fVco`
4. **Expect long sim times**: 16.5 GHz -> ~200-260 s for 60 us stop time
5. **In-band PN dominated by DSM** -- validate only at far offsets (>10x BW)
6. **Far-offset jitter** matches datasheet well
7. **CP impairment (`EnableCurrentImpairments`) causes ~15x slowdown at 8 GHz** (measured: 17s vs 267s for 1 µs sim). For spur analysis at high VCO frequencies, use `estimatePLLPhaseNoise` instead of transient simulation with CP impairment enabled.

### Example: ADF4382 at 16.5 GHz

```matlab
set_param(blk, 'Fo', '16.5e9', 'Kvco', '100e6', ...
    'PropDelay', '3e-12', 'RiseFallTime', '3e-12', ...
    'MaxFreqInterest', '33e9', 'MaxFreqInterestCp', '33e9');
set_param(tb, 'Fo', '125e6', 'ExpectedFreq', '16.5e9', ...
    'SampleRate', '132e9');
```

---

## Noise Budget Reference (at 100 kHz, near 60 kHz loop BW)

| Source | Impact |
|--------|--------|
| CP timing impairments | +12 dB (default values too aggressive for ADF4351) |
| LF thermal noise | +4 dB (real physics, keep enabled) |
| PFD edge impairments | <0.5 dB (negligible) |
| CP broadband noise (Si_cp) | <1 dB (PNSYNTH=-220 is very low) |
| DSM/measurement gap | ~4 dB above analytical (normal, reduces with more averages) |

---

Copyright 2026 The MathWorks, Inc.
