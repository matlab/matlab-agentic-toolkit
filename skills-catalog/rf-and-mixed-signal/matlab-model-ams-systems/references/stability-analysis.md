# Stability Analysis: Open/Closed Loop Plots

Compute and plot PLL loop response using `msblks.PLL.getPllLoopResponse`.
Call this **before** running a full time-domain simulation to verify
stability (phase margin, peaking, bandwidth).

## API

```matlab
[frequency, Zofs, Gofs, Hofs, Eofs, phStep] = ...
    msblks.PLL.getPllLoopResponse(R, C, Icp, Kvco, N);
```

**Inputs:**
| Parameter | Description |
|-----------|-------------|
| `R` | `[0, R2, R3, R4]` — passive filter resistances (Ohms). Enter 0 for unused. |
| `C` | `[C1, C2, C3, C4]` — passive filter capacitances (F). Enter 0 for unused. |
| `Icp` | Charge pump current (A) |
| `Kvco` | VCO sensitivity (Hz/V) |
| `N` | Feedback divider ratio (any positive real scalar) |

**Outputs:**
| Output | Description |
|--------|-------------|
| `frequency` | Frequency vector (Hz) |
| `Gofs` | Open-loop gain G(f) — use for Bode magnitude/phase |
| `Hofs` | Closed-loop TF (Ref → Output) — low-pass shape |
| `Eofs` | Error TF (VCO → Output) — high-pass shape |
| `Zofs` | Loop filter impedance Z(f) |
| `phStep` | Phase step transient response (time series) |

## Full Plotting Code

```matlab
% Extract filter component values (after Automatic design computes them)
C1 = str2double(get_param(blk, 'C1'));
C2 = str2double(get_param(blk, 'C2'));
C3 = str2double(get_param(blk, 'C3'));
C4 = str2double(get_param(blk, 'C4'));
R2 = str2double(get_param(blk, 'R2'));
R3 = str2double(get_param(blk, 'R3'));
R4 = str2double(get_param(blk, 'R4'));
R = [0, R2, R3, R4];
C = [C1, C2, C3, C4];

% Compute loop response
[frequency, Zofs, Gofs, Hofs, Eofs, phStep] = ...
    msblks.PLL.getPllLoopResponse(R, C, Icp, Kvco, N_eff);

% Find crossover and phase margin
magOL = 20*log10(abs(Gofs));
phaseOL = angle(Gofs) * 180/pi;
idx = find(magOL(1:end-1) > 0 & magOL(2:end) <= 0, 1);
fc_actual = frequency(idx);
pm_actual = 180 + phaseOL(idx);
fprintf('Loop BW = %.1f kHz, Phase Margin = %.1f deg\n', fc_actual/1e3, pm_actual);

% Plot stability analysis (4-panel figure)
set(0, 'DefaultFigureVisible', 'on');
figure('Name', 'PLL Stability', 'Position', [100 100 1000 700], 'Visible', 'on');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
semilogx(frequency, magOL, 'b-', 'LineWidth', 1.5);
yline(0, 'r--'); grid on;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Open-Loop Gain');

nexttile;
semilogx(frequency, phaseOL, 'b-', 'LineWidth', 1.5);
yline(-180, 'r--'); grid on;
xlabel('Frequency (Hz)'); ylabel('Phase (deg)');
title(sprintf('Open-Loop Phase (PM = %.1f°)', pm_actual));

nexttile;
semilogx(frequency, 20*log10(abs(Hofs)), 'b-', 'LineWidth', 1.5);
yline(-3, 'r--', '-3 dB'); grid on;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Closed-Loop TF (Ref \rightarrow Output)');

nexttile;
semilogx(frequency, 20*log10(abs(Eofs)), 'b-', 'LineWidth', 1.5);
yline(0, 'k--'); grid on;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Error TF (VCO \rightarrow Output)');

sgtitle(sprintf('PLL Stability — fc = %.1f kHz, PM = %.1f°', ...
    fc_actual/1e3, pm_actual), 'FontWeight', 'bold');
drawnow;
```

## Interpretation Guide

| What to Look For | Good | Bad |
|------------------|------|-----|
| Phase margin (PM) | 45-60° | < 40° (oscillation risk) or > 70° (sluggish) |
| Gain margin | > 10 dB | < 6 dB |
| Closed-loop peaking | < 1 dB | > 3 dB (ringing in transient) |
| CL -3 dB BW | Near target Fc | >> Fc (filter not attenuating) |
| Error TF 0-dB crossing | Near target Fc | Much higher (VCO noise leaks) |

## Presenting Transfer Functions in the Report

After computing the loop response, extract and display key metrics for the
HTML report:

```matlab
% Closed-loop -3 dB bandwidth
clMag = 20*log10(abs(Hofs));
idx3dB = find(clMag(1:end-1) > -3 & clMag(2:end) <= -3, 1);
bw3dB = frequency(idx3dB);
fprintf('Closed-loop -3 dB BW = %.1f kHz\n', bw3dB/1e3);

% Transfer function summary table for report
fprintf('\n=== PLL Transfer Function Summary ===\n');
fprintf('Open-loop crossover (fc): %.2f kHz\n', fc_actual/1e3);
fprintf('Phase margin (PM):        %.1f deg\n', pm_actual);
fprintf('Closed-loop -3 dB BW:     %.2f kHz\n', bw3dB/1e3);
fprintf('Loop filter type:         %s\n', get_param(blk, 'FilterType'));
fprintf('\nFilter Components:\n');
fprintf('  C1 = %.3g F,  C2 = %.3g F,  C3 = %.3g F,  C4 = %.3g F\n', C1, C2, C3, C4);
fprintf('  R2 = %.3g Ohm, R3 = %.3g Ohm, R4 = %.3g Ohm\n', R2, R3, R4);

% Transfer functions at key offsets
evalOffsets = [1e3, 10e3, 100e3, 1e6, 10e6];
fprintf('\nTransfer Functions at Key Offsets:\n');
fprintf('%-12s  %-12s  %-12s  %-12s\n', 'Offset', '|G(f)| dB', '|H(f)| dB', '|E(f)| dB');
for k = 1:numel(evalOffsets)
    [~, ik] = min(abs(frequency - evalOffsets(k)));
    fprintf('%-12s  %-12.1f  %-12.1f  %-12.1f\n', ...
        sprintf('%.0e Hz', evalOffsets(k)), ...
        20*log10(abs(Gofs(ik))), ...
        20*log10(abs(Hofs(ik))), ...
        20*log10(abs(Eofs(ik))));
end
```

Include this table in the HTML report under a "Stability & Transfer Functions"
section. The key insights for a designer:
- `|G(f)|` shows loop gain at each offset (positive = controlled by loop)
- `|H(f)|` shows reference noise amplification (flat in-band, rolls off)
- `|E(f)|` shows VCO noise suppression (suppressed in-band, passes out-of-band)

## When to Use Option A vs Option B

| Scenario | Use |
|----------|-----|
| Interactive design (GUI) | Option A — `ol_opt`/`cl_opt` checkboxes |
| Scripted automation | Option B — `getPllLoopResponse` |
| Iteration/sweeps | Option B — call in a loop over BW/PM values |
| Quick sanity check | Option A — one click on model update |

## Notes

- `getPllLoopResponse` works for passive filters only (1st through 4th order)
- For active filter topologies, compute the transfer function manually
- The function uses the Banerjee formulation (PLL Performance, Simulation
  and Design, 4th edition, chapters 9 and 20)
- Filter component values from `CompSelectionMethod='Automatic'` are
  available only after model update — call `set_param(model,
  'SimulationCommand', 'update')` first if reading programmatically
- **Gain normalization caveat**: `getPllLoopResponse` may report crossover
  frequency and phase margin values that differ from the MSB architecture
  block's internal auto-design computation (P48: it returns forward-path gain
  without /N). When the simulation locks correctly and settles to the expected
  frequency, trust the time-domain simulation as ground truth. Present the
  design target values (fc, PM) alongside the analytical plots and note any
  discrepancy.

---

Copyright 2026 The MathWorks, Inc.
