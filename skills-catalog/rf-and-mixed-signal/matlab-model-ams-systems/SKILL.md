---
name: matlab-model-ams-systems
description: "Model a Phase-Locked Loop (PLL) IC from its datasheet or system specs using Mixed-Signal Blockset. Without this skill, agents universally select the wrong solver and produce non-functional PLL models — 100% of unguided attempts fail. Covers Integer-N, Fractional-N, Dual Modulus architectures, loop filter design, lock time optimization, VCO phase noise configuration, and msbPllArchitectures/msbPllFoundation block assembly. Use when: PLL modeling, frequency synthesizer design, phase noise simulation, lock time analysis, charge pump design, loop filter tuning, datasheet-to-model, Mixed-Signal Blockset PLL, msbPllArchitectures."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Skill: PLL Datasheet Modeling -- Core (Phases 1-4)

Model a PLL IC from its datasheet or system specifications using Simulink
building blocks from the Mixed-Signal Blockset (MSB) foundation library
`msbPllFoundation`.

**Companion file**: `modeling-pll-datasheet-validate.md` covers Phases 5-9
(loop filter design, validation, measurement, iteration, pitfalls).

## When to Use

- Modeling a PLL IC from its datasheet (extracting parameters, selecting architecture)
- Designing a frequency synthesizer from system specs (fVco, fRef, lock time, phase noise targets)
- Building a behavioral PLL model in Simulink using Mixed-Signal Blockset
- Validating phase noise performance against datasheet measurements
- Selecting between Integer-N, Fractional-N, or Dual Modulus PLL architectures

## When NOT to Use

- Circuit-level PLL design (transistor-level VCO, charge pump schematic)
- PLL analysis without building a Simulink model (use `estimatePLLPhaseNoise` directly)
- Clock distribution or jitter cleaning (not frequency synthesis)
- Non-MSB PLL modeling (e.g., custom Simulink blocks without the Mixed-Signal Blockset)

---

## Workflow Directives (MANDATORY)

1. **Gather specs ONE AT A TIME (MANDATORY — no exceptions)** -- For ANY
   PLL or frequency synthesizer design request (spec-driven or exploratory),
   ask exactly ONE question per response. Do NOT list multiple questions or
   present a bulleted requirements checklist. This reduces cognitive load
   and makes the interaction conversational. Sequence:
   1. Output frequency (or frequency range)
   2. Reference frequency (flag if N > 200 — high in-band noise penalty)
   3. Architecture (Integer-N / Frac-N / auto — may be predetermined by N)
   4. Lock time target
   5. Phase noise / jitter / spur targets (or confirm "none")
   6. Charge pump current (offer typical value as default)
   7. VCO requirements (Kvco, phase noise profile — offer rule-of-thumb)
   8. Loop filter preference (order, BW override)
   9. Any other requirements?
   10. Save location (folder path for .slx and results)

   **Rules:**
   - Ask ONE question, wait for answer, then ask the next.
   - Skip questions already answered in the user's initial prompt.
   - Offer a sensible default in parentheses so user can just confirm.
   - After all specs are gathered, present the Design Plan (Directive 5, Step A).

2. **Iterate autonomously ONLY when targets are NOT met** -- If the first
   attempt PASSES with >3x margin, STOP. The BW formula already gives a
   good design — do NOT sweep BW or iterate "for completeness." Only
   sweep/iterate when the first attempt FAILS or margin is < 2x.
   When iteration IS needed, sweep parameters and re-simulate until met.

3. **Report progress and generate HTML summary** -- Print brief status per
   attempt (e.g., "BW=1MHz, PM=70 -> lock=5.2us X"). After ALL targets pass,
   generate an HTML report saved alongside the model. Required sections:

   **Report contents (mandatory):**
   - Summary box: pass/fail verdict with margin
   - Model screenshot: `print(['-s' model], path, '-dpng', '-r150')`
   - Architecture diagram (text-based)
   - Design parameters grid (fVCO, fRef, N, Icp, Kvco, filter type, etc.)
   - Loop filter component table with time constants (τ_z = R2·C2, τ_p3 = R3·C3)
   - **Transfer function box**: Z(s), G(s)=Icp·Kvco·2π·Z(s)/(N·s), H(s)=G/(1+G),
     plus key values: fc, PM, zero freq, pole freqs
   - **Bode plots** (open-loop + closed-loop): export from `pllOpenLoopPlot`/
     `pllCloseLoopPlot` via `exportgraphics(fig, path, 'Resolution', 150)`.
     Find figures by Tag: `'PllOpenLoopDynamicPlot'`, `'PllCloseLoopDynamicPlot'`
   - **Vctrl transient**: plot from simOut timeseries with lock time marker
   - Simulation results table (spec vs measured)
   - Simulation config (solver, stopTime, holdOff, averages)
   - **Session metrics**: include `[COST]` and `[DURATION]` placeholders in
     the report footer. The user fills these in from the Claude Code UI after
     the task completes (visible at session end).

   **How to export plots:**
   ```matlab
   pllOpenLoopPlot(Icp, Kvco, N, 0, R2, R3, 0, C1, C2, C3, 0);
   fig = findobj('Type','figure','Tag','PllOpenLoopDynamicPlot');
   exportgraphics(fig, fullfile(outDir,'open_loop_bode.png'), 'Resolution', 150);
   ```
   Use relative `src="filename.png"` paths in HTML. Open report with
   `web(reportPath, '-browser')`.

4. **Figures must be visible** -- After simulation, call
   `set(0,'DefaultFigureVisible','on')` and ensure all plot figures
   have `'Visible','on'`. Call `drawnow` to force rendering. The MCP
   MATLAB server defaults to `Visible='off'`.

5. **Show progress on screen at each step** -- At key milestones, print status:

   - **Step A — Design plan**: ASCII block diagram + params before building
     ```
     [PLL TB]──▶[PFD]──▶[CP]──▶[Loop Filter]──▶[VCO]──┐
        ▲                                               │
        └─────────────[Divider ÷N]◀─────────────────────┘
     ```
     Include: architecture, fRef, N, Icp, Kvco, Fc, PM, filter type, solver.
     When adding impairments, show updated diagram BEFORE implementing.
   - **Step B — Filter + Bode**: component values, then `pllOpenLoopPlot`/`pllCloseLoopPlot`
   - **Step C — Sim start**: `Simulating Pass 1 (lock time)... StopTime=9µs`
   - **Step D — Results**: `Lock time = 2.1 µs (target < 3 µs) ✓ [1.4× margin]`
   - **Step E — Pass 2** (only if PN spec): offsets, measured vs target, pass/fail

---

## Prerequisites

- Access to the target PLL IC datasheet (PDF) -- OR basic specs (fVco, fRef, lock time)
- Mixed-Signal Blockset installed (provides `msbPllFoundation` library)
- Control System Toolbox (for `estimatePLLPhaseNoise` validation, R2026b+)

## Entry Points

### A. Datasheet-Driven (Full workflow, Phases 1-4)
Use when you have a PLL IC datasheet. Follow all phases below.

### B. Spec-Driven (No datasheet)
Use when you have basic PLL specs but no datasheet. Follow Directive 1 to
gather specs, then derive remaining parameters.

**Parameter derivation rules:**
```
N = fVco / fRef  (or P*N+S for dual modulus)
BW = min(12/t_lock, fPFD/10)  (capped at fPFD/10 for stability)
Kvco: fVco/50 typical if not specified (e.g., 6 GHz → 120 MHz/V)
Icp: 1-5 mA typical (higher Icp → wider achievable BW with smaller R2)
PM: 50° default (60° if adding 4th-order pole)
```

**Architecture selection:**

| Condition | Architecture |
|-----------|-------------|
| N is integer, single prescaler | Integer N PLL with Single Modulus Prescaler |
| N is integer, need P/P+1 flexibility | Integer N PLL with Dual Modulus Prescaler |
| N is fractional, low spur requirement | Fractional N PLL with Delta Sigma Modulator |
| N is fractional, simple design | Fractional N PLL with Accumulator |

**DSM order selection** (when using Frac-N DSM):
- Order 1: simplest, highest spurs at fPFD/denom
- Order 2: good balance for most designs
- Order 3-4: lowest spurs, but more quantization noise energy pushed
  to high offsets (requires adequate filter attenuation)
- Match datasheet DSM order if available; default to order 3

**R-divider tradeoff** (when fRef ≠ fComp):
- Using R-counter: fComp = fRef/R → N_eff = fVco/fComp = N×R
- In-band noise penalty: +20×log10(N_eff) — larger N hurts in-band PN
- Only use R > 1 when channel spacing requires it (fComp = channel step)

**Spec-driven steps:**
1. Gather specs (Directive 1) → present Design Plan (Directive 5, Step A)
2. If VCO PN data available: validate VCO standalone first (see below)
3. Select architecture block from `msbPllArchitectures` (Strategy A — DEFAULT)
4. Design loop filter:
   - N ≤ 50: `CompSelectionMethod='Automatic'` with `Fc` and `Phi`
   - N > 50 (P79): `thirdOrderPassiveFilterDesign` → `CompSelectionMethod='Manual'`
   - N threshold applies to effective N (including fractional part)
5. Build model, simulate, present results

**VCO standalone validation** (when PN data provided):
```matlab
% 1. Create VCO testbench model
vcoModel = 'VCO_Validation';
new_system(vcoModel); open_system(vcoModel);
set_param(vcoModel, 'Solver', 'VariableStepDiscrete');
add_block('msbPllFoundation/Ring Oscillator VCO', [vcoModel '/VCO']);
add_block('msbPllMeasurements/VCO Testbench', [vcoModel '/VCO TB']);
add_line(vcoModel, 'VCO TB/1', 'VCO/1', 'autorouting', 'smart');
add_line(vcoModel, 'VCO/1', 'VCO TB/1', 'autorouting', 'smart');

% 2. Get PeriodJitter and CornerFrequency from PN data
[pJitter, cFreq] = msblks.VCO.estimatePhaseNoiseCore(fVco, Foffset, PN_dBc);
set_param([vcoModel '/VCO'], 'Fo', num2str(fVco), ...
    'PeriodJitter', num2str(pJitter), 'CornerFrequency', num2str(cFreq));

% 3. Simulate and compare to datasheet (accept ±3 dB)
sim(vcoModel);
ud = get_param([vcoModel '/VCO TB'], 'UserData');
```

Skip to Phase 4.0 (Strategy A assembly) after deriving parameters.

### C. Tune Existing Model (Meet a new spec)
Use when the user provides an existing `.slx` model and wants to meet a target
(lock time, phase noise, spurs) without rebuilding from scratch.

**Workflow:**
1. **Probe** — extract current params: `Fc`, `Phi`, `N`, `OutputCurrent`, `Kvco`,
   `CompSelectionMethod`, filter components via `get_param`
2. **Check for PLL Testbench** — if missing or PLL input unconnected, ASK the
   user for fComp (P104). Add a PLL Testbench if needed.
3. **Baseline sim** — `sim(model)`, read `get_param(tbBlk, 'UserData')` for
   lock time, frequency, phase noise. This is the ONLY valid baseline (P103).
4. **Identify the lever:**
   - Lock time too slow → increase `Fc` (BW ≈ 12/t_lock)
   - Phase noise too high in-band → decrease `Fc`, increase Icp, or reduce N
   - Spurs too high → increase filter order or narrow `Fc`
5. **Redesign** — set new `Fc` (and `Phi` if needed), keep
   `CompSelectionMethod='Automatic'` so the block recomputes filter components
6. **Re-simulate** — read testbench UserData. Iterate until spec is met.
7. **Report** — before/after comparison with trade-off notes

**Key rules:**
- NEVER estimate lock time from Vctrl settling (P103)
- NEVER guess fComp from `Fo/N` or `RefFreq` param (P104)
- Cap `Fc` at `fPFD/10` for stability
- Use `lock_time ≈ 12/Fc` only for initial sizing, then verify with testbench

---

## Availability Check (MANDATORY)

Before using ANY function or block, verify it exists. Check `exist(func,'file')`
for key functions (`thirdOrderPassiveFilterDesign`, `estimatePLLPhaseNoise`,
`phaseNoiseMeasure`, `phaseNoiseToJitter`) and `exist(lib,'file')==4` for
libraries (`msbPllFoundation`, `msbPllMeasurements`, `msbPllArchitectures`).
If not found, do NOT use — skip dependent steps.

---

## Phase 1: Extract Datasheet Parameters

### 1.0 Reading the Datasheet PDF

Use MATLAB's `extractFileText` (never read PDFs directly with the Read tool):

```matlab
pdfPath = 'path/to/datasheet.pdf';
txtContent = extractFileText(pdfPath);
txtPath = strrep(pdfPath, '.pdf', '_extracted.txt');
fid = fopen(txtPath, 'w'); fprintf(fid, '%s', txtContent); fclose(fid);
fprintf('Extracted %d characters to: %s\n', strlength(txtContent), txtPath);
```

### 1.1 Architecture Identification

Determine the PLL topology from the functional block diagram:

| Question | Typical Options |
|----------|----------------|
| Integer-N or Fractional-N? | Integer-only, Fractional with accumulator, Fractional with DSM |
| DSM order (if fractional)? | 1st, 2nd, 3rd, 4th |
| Prescaler type? | Single modulus, Dual modulus (P/P+1) |
| Integrated VCO? | Yes / No (external) |
| Reference path? | Direct, with R counter, with doubler, with divider |
| Output dividers? | None, programmable divide chain |
| Feedback tap point? | Before output divider (VCO), after output divider |

### 1.2-1.4 Detailed Parameter Extraction

See **references/datasheet-extraction.md** for the full parameter tables:
- 1.2: Core PLL parameters (PFD, CP, dividers, VCO, output stage)
- 1.3: Noise parameters (VCO PN, PNSYNTH, flicker, jitter, spurs)
- 1.4: Frequency plan worked example

---

## Phase 2: Select Assembly Strategy

### Decision Tree (ALWAYS follow this)

```
START
  │
  ├─ Does the PLL topology match an msbPllArchitectures template?
  │   ├─ YES ──► Strategy A (Architecture block) ◄── DEFAULT
  │   └─ NO ───► Strategy B (Foundation blocks)
  │
  └─ Do you need EXTERNAL custom noise injection (BLWN, spur sources wired
     into the signal path OUTSIDE the PLL subsystem)?
      ├─ NO ───► Strategy A (Architecture block) ◄── DEFAULT
      └─ YES ──► Strategy A + editSystem (flatten, then inject)
                 OR Strategy B (if injection point is before CP or after VCO)
```

**Strategy A is the default for ALL designs** — spec-driven or datasheet-driven.
Foundation blocks (Strategy B) are only needed when topology has no matching
architecture template (e.g., dual-loop, injection-locked, external VCO with
non-standard feedback).

| Strategy | When to Use | Performance | Complexity |
|----------|-------------|-------------|------------|
| **A: Architecture block** | **Default.** Any standard Int-N, Frac-N, Dual-Modulus PLL | **3.3x faster sim** (65s vs 212s for 5 GHz PLL) | 4 blocks, 4 connections |
| **A + editSystem** | Need to inject CP broadband noise or add custom impairments | Same speed until flattened | Flatten adds ~5 internal blocks |
| **B: Foundation blocks** | Non-standard topology, external VCO, dual-loop, or educational/visualization purposes | Baseline (slowest) | 9+ blocks, 11+ connections |

### Probe-First Pattern (MANDATORY before `set_param`)

Before setting ANY block parameter, probe the mask to discover exact parameter
names. Never guess parameter names from documentation or memory.
See `references/probing-simulink-models.md` for the full probe workflow.

```matlab
blk = [model '/PLL'];
m = Simulink.Mask.get(blk);
paramNames = {m.Parameters.Name};
fprintf('Available params (%d):\n', numel(paramNames));
cellfun(@(p) fprintf('  %s\n', p), paramNames);
```

This eliminates errors like using `'Icp'` (wrong) instead of `'OutputCurrent'`
(correct), or `'DividerRatio'` (wrong) instead of `'N'` (correct).

### 2.1 `msbPllArchitectures` -- Pre-built PLL Templates (Strategy A)

| Architecture Block | Topology | Divider Params |
|--------------------|----------|----------------|
| Integer N PLL with Single Modulus Prescaler | PFD->CP->LF->VCO->Single Prescaler | `Nmin`, `N` (integer) — set N FIRST |
| Integer N PLL with Dual Modulus Prescaler | PFD->CP->LF->VCO->Dual Prescaler | `ProgramCounter`(P), `PrescalerDivider`(N), `SwallowCounter`(S) — constraints: P > S > 0 (P105) |
| Fractional N PLL with Accumulator | PFD->CP->LF->VCO->Frac Divider (Accum) | `N` (fractional), `Nmin` |
| Fractional N PLL with Delta Sigma Modulator | PFD->CP->LF->VCO->Frac Divider (DSM) | `N` (fractional), `Nmin`, `dsm` (order) |

**Key promoted parameters** (common to all):

| Category | Parameters |
|----------|-----------|
| VCO | `Kvco`, `Fo`, `Amplitude`, `AddPhaseNoise`, `Foffset`, `PhaseNoise`, `PeriodJitter`, `CornerFrequency`, `FlickerExponent` |
| Charge Pump | `OutputCurrent`, `EnableCurrentImpairments`, `CurrentImbalance`, `LeakageCurrent`, `EnableTimingImpairments` |
| Loop Filter | `CompSelectionMethod`(`Automatic`/`Manual`), `Fc`, `Phi`, `FilterType`, `C1`-`C4`, `R2`-`R4`, `LfEnableImpairments`, `Temperature` |
| PFD | `DeadbandCompensation`, `EnableImpairments` |
| Analysis | `ol_opt`, `cl_opt`, `estimatePn` |
| Probe | `pfd_up_dn`, `cp_out`, `lf_out`, `ps_out` |

**Built-in callbacks**:
- `msblks.PLL.editSystem(gcb)` -- flatten to editable subsystem
- `msblks.PLL.estimatePhaseNoise(gcb)` -- analytical PN estimation
- `msblks.VCO.plotMaskFigure(gcb)` -- plot PN fit vs data

### 2.2 `msbPllFoundation` -- Individual Building Blocks (Strategy B)

See **references/assembly-code.md** for the full block table and parameters.
Key blocks: PFD, Charge Pump, Loop Filter, Ring Oscillator VCO, Fractional Clock Divider with DSM.

### 2.3 Gap Analysis

Architecture blocks cover PFD, CP, LF, VCO, and Dividers. For R counter,
ref doubler, RF output divider, or CP broadband noise: flatten with
`editSystem`, then add custom blocks inside the subsystem.

---

## Phase 3: Create Custom Blocks / Customize Architecture

### 3.0 Flattening (`msblks.PLL.editSystem`)

Set all mask parameters FIRST, THEN flatten. After flattening, the subsystem
contains individual blocks (PFD, CP, LF, VCO, Divider) that you can modify.

```matlab
blk = [model '/PLL'];
set_param(blk, 'Kvco','40e6', 'Fo','4.225e9', 'OutputCurrent','5e-3', ...
    'N','422.52', 'CompSelectionMethod','Automatic', 'Fc','60e3', 'Phi','48');
msblks.PLL.editSystem(blk);  % Flatten AFTER setting params
```

### 3.1-3.4 Custom Block Recipes

See **references/assembly-code.md** for: CP broadband noise (3.1), reference
path (3.2), RF output divider (3.3), feedback select mux (3.4).

---

## Phase 4: Assemble the Model

> **PERFORMANCE DIRECTIVE — Batch Model Assembly**
> Execute the ENTIRE model assembly in ONE `mcp__matlab__evaluate_matlab_code` call
> (new_system, set_param, add_block, add_line, scope setup — ALL in one script).
> Each MCP round-trip = ~10-15s overhead. Batched = ~30s vs individual = 5+ min.
> Pattern: (1) compute params, (2) write assembly script to .m file in save folder,
> (3) execute via `mcp__matlab__run_matlab_file` (keeps terminal clean — no code dump),
> (4) verify. Using `run_matlab_file` instead of `evaluate_matlab_code` for large
> scripts prevents raw code from cluttering the user's screen during live demos.

### 4.0 Strategy A: Architecture Block Assembly (DEFAULT)

Architecture blocks: 3.3x faster sim, 56% fewer blocks, 64% fewer connections.
Full assembly code template in **references/assembly-code.md**. Key sequence:

1. `new_system` + solver config (`VariableStepDiscrete`, `ReturnWorkspaceOutputs='on'`)
2. `add_block` from `msbPllArchitectures/<type>`
3. Set divider: `Nmin='1'` first, then `N`, then `Nmin` to final value (P57/P92)
4. Set VCO params: `Kvco`, `Fo`, `OutputCurrent`, `AddPhaseNoise`, `RefFreq`
5. Loop filter: `thirdOrderPassiveFilterDesign` for N>50 (P79), else `Automatic`
6. PFD timing: `PropDelay = max(50e-12, min(5e-12, 1/(2*fVCO)/10))`, `MaxFreqInterest = 2*fVCO` (50ps floor — block rejects smaller values)
7. Enable `lf_out='on'` for Vctrl probe
8. Add PLL Testbench (`Fo=fPFD`, `ExpectedFreq=fVCO`, `SampleRate=8*fVCO`)
9. Set `SpectralAverages='2'` (P102: mask default is 4), `LockTimeOption='on'`, `PhaseNoiseOption='off'` (P83)
10. `StopTime = min(3*t_lock, 50e-6)`, `HoldOffTime = min(1.5*estLock, 0.8*StopTime)`
11. Set paired vectors via `Simulink.Mask.get`: `PhaseNoiseFreqOffset`, `TargetPhaseNoiseVector` (P71, P100: use `-999` if no targets — mask rejects `-inf`)
12. Connect: TB/1→PLL/1, PLL/1→TB/1, PLL/2→Scope+ToWorkspace
13. `Simulink.BlockDiagram.arrangeSystem(model); drawnow; set_param(model,'ZoomFactor','FitSystem'); drawnow;` (P95)

### 4.1 Strategy B: Foundation Blocks

Use ONLY for non-standard topologies. See **references/assembly-code.md**.

### 4.2 Stability Analysis (ALWAYS before time-domain sim)

Confirm PM > 45° and no closed-loop peaking > 1 dB before running full sim.
- `pllOpenLoopPlot(Icp,Kvco,N,Fc,R2,R3,R4,C1,C2,C3,C4)` / `pllCloseLoopPlot(...)`
- For 3rd-order passive: R4=0, C4=0. See **references/stability-analysis.md**.
- **If `pllOpenLoopPlot` crashes** (ylim error at phase <= -180°): use manual Bode
  fallback per P106 — compute Z(s), G(s) via `logspace` sweep. Do NOT use
  Control System Toolbox (`tf`, `bode`) — it is not required.

### 4.3 Simulate and Read Results

```matlab
simOut = sim(model);
delete(findall(0,'Type','figure','Tag','Msgbox_Warning'));
% Read lock time from PLL Testbench model workspace
sid = Simulink.ID.getSID([model '/PLL Testbench']);
sidParts = split(sid, ':'); sidSuffix = sidParts{2};
mdlWs = get_param(model, 'ModelWorkspace');
lockTime = evalin(mdlWs, ['LockTime_' sidSuffix]);
freq = evalin(mdlWs, ['Frequency_' sidSuffix]);

% Alternative: read from UserData (works after sim completes)
ud = get_param([model '/PLL Testbench'], 'UserData');
lockTime = ud.lockTime;  % seconds
freq = ud.freq;          % Hz
pnLevels = ud.phaseNoiseLevel; % dBc/Hz vector
```

**P103: NEVER estimate lock time from Vctrl settling.** The PLL Testbench uses
frequency-error-based detection (`FreqErrorTol`) — this is the ONLY valid lock
time measurement. Manual Vctrl analysis gives incorrect results.

**P104: If the model has NO PLL Testbench or unconnected reference input, you
CANNOT determine fComp.** The `RefFreq` parameter is for PN estimation only —
it does NOT define the actual reference clock. ASK the user for fComp before
proceeding. Do not guess or calculate it from `Fo/N`.

Probe tab ports (after VCO out port 1): pfd_up, pfd_dn, cp_out, lf_out, ps_out.
`HoldOffTime` must be < `StopTime`, otherwise no measurements.

---

## Quick Reference

```
f_PFD = f_REFIN*(1+D)/(R*(1+T))  |  f_VCO = f_PFD*(INT+FRAC/MOD)  |  f_OUT = f_VCO/RF_DIV
N_eff = INT+FRAC/MOD (from VCO)  |  N_eff = (INT+FRAC/MOD)*RF_DIV (from divider output)
In-band PN  = PNSYNTH + 10*log10(f_PFD) + 20*log10(N)
1/f PN at f = PN1_f + 10*log10(10kHz/f) + 20*log10(f_RF/1GHz)
Divider effect = -20*log10(RF_DIV) on output phase noise
```

## Happy Path Cheat Sheet (Spec → Lock Time Verified)

Most common workflow in ~20 steps:

```
1. User gives: fVCO, fRef, lock time target
2. Derive: N = fVCO/fRef, Fc = 12/t_lock (cap at fPFD/10), Kvco = fVCO/50
3. Present Design Plan (block diagram + params)
4. Build model (ONE mcp call):
   - new_system, VariableStepDiscrete solver
   - add_block msbPllArchitectures/Integer N PLL...
   - set Nmin='1', N, Nmin=N
   - set Kvco, Fo, OutputCurrent, Fc, Phi='50'
   - add PLL Testbench (Fo=fRef, ExpectedFreq=fVCO, SampleRate=8*fVCO)
   - set LockTimeOption='on', SpectralAverages='2'
   - connect TB↔PLL, enable lf_out, add scope
   - StopTime = min(3*12/Fc, 50e-6), HoldOff = 1.5*12/Fc
   - arrangeSystem + FitSystem
5. Plot Bode: pllOpenLoopPlot(...), confirm PM > 45° (if ylim crash, use manual fallback P106)
6. sim(model)
7. ud = get_param(tbBlk, 'UserData'); lockTime = ud.lockTime;
8. Report: lock_time vs target, margin, PASS/FAIL
9. If margin > 3x → DONE. If not → increase Fc by 50%, repeat from step 5.
```

**Library names (canonical):** `msbPllArchitectures`, `msbPllFoundation`,
`msbPllMeasurements`, `msbUtilities`

---

Copyright 2026 The MathWorks, Inc.
