# Mixer Intermodulation Analysis

Analyze mixer spurious products using the `mixerIMT` object. Build intermodulation tables, visualize spur charts, and integrate with `rfbudget` for cascade analysis.

## `mixerIMT` vs `modulator`

Both model frequency converters, but serve different purposes:

| Feature | `modulator` | `mixerIMT` |
|---------|------------|------------|
| Gain specification | `Gain` property (direct) | `NominalOutputPower - ReferenceInputPower` |
| Nonlinearity | OIP3-based (poly model) | IMT table (arbitrary spur levels) |
| Spur visualization | No | Yes — `rfplot(m, fRF)` |
| Constructor accepts `Gain` | Yes | **No** — settable after construction but ignored by rfbudget |
| Use case | System-level cascade budgets | Spur analysis and frequency planning |

Use `modulator` for quick cascade budgets. Use `mixerIMT` when you need to model specific spurious products or visualize spur charts.

## Creating a mixerIMT

```matlab
m = mixerIMT('LO', 2.1e9, 'ConverterType', 'Down', 'NF', 10, 'Name', 'Mixer');
```

### Constructor Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `LO` | 1e8 | Local oscillator frequency (Hz) |
| `ConverterType` | `'Up'` | `'Down'` or `'Up'` conversion — **must set explicitly for down-conversion** |
| `NF` | 0 | Noise figure (dB) |
| `ReferenceInputPower` | -15 | Reference input power (dBm) |
| `NominalOutputPower` | -5 | Nominal output power (dBm) |
| `Model` | auto | `'mod'` (up) or `'demod'` (down) — set automatically from ConverterType |
| `Zin` | 50 | Input impedance (Ohm) |
| `Zout` | 50 | Output impedance (Ohm) |
| `IMT` | 3x3 default | Intermodulation table |
| `Name` | `'MixerIMT'` | Element name |

### Post-Construction Properties

These properties are read-write but **cannot be passed to the constructor**:

```matlab
m.OIP3 = 20;       % Output IP3 (dBm)
m.OIP2 = 40;       % Output IP2 (dBm)
```

**Do not set `m.Gain` manually.** Although `Gain` is a settable property, `rfbudget` ignores it — the budget gain is determined entirely by `NominalOutputPower` and `ReferenceInputPower`. Setting `m.Gain` has no effect on cascade results and can be misleading.

## Conversion Gain

Conversion gain in `rfbudget` is determined by `NominalOutputPower` and `ReferenceInputPower`. Although `Gain` is a settable property, `rfbudget` ignores it and computes gain from `NominalOutputPower - ReferenceInputPower`. Do not set `m.Gain` manually.

```
Budget gain = NominalOutputPower - ReferenceInputPower
```

```matlab
% This gives 10 dB conversion gain in rfbudget:
m = mixerIMT('ReferenceInputPower', -15, 'NominalOutputPower', -5, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');
% Budget sees: -5 - (-15) = 10 dB

% To get -6 dB conversion loss in rfbudget:
m2 = mixerIMT('ReferenceInputPower', -10, 'NominalOutputPower', -16, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');
% Budget sees: -16 - (-10) = -6 dB
```

## The IMT Table

The intermodulation table (IMT) is an MxN matrix where:
- **Rows** = RF harmonic order (row 1 = order 0, row 2 = order 1, ...)
- **Columns** = LO harmonic order (col 1 = order 0, col 2 = order 1, ...)
- **Values** = relative power in **dBc below the reference** (non-negative)
- `0` = reference level (desired output)
- `99` = fully suppressed

### Default Table

```matlab
m = mixerIMT;
disp(m.IMT);
%    99    99    99
%    99     0    99
%    99    99    99
```

The default 3x3 table has only the desired product (RF×1, LO×1) at row 2, col 2 with value 0 (reference). Everything else is suppressed (99).

### Custom IMT Table

```matlab
imt = 99*ones(5,5);       % Start with everything suppressed
imt(2,2) = 0;             % RF×1, LO×1: desired output (reference)
imt(2,1) = 20;            % RF×1, LO×0: RF feedthrough at -20 dBc
imt(1,2) = 15;            % RF×0, LO×1: LO feedthrough at -15 dBc
imt(3,2) = 30;            % RF×2, LO×1: 2RF-LO spur at -30 dBc
imt(2,3) = 25;            % RF×1, LO×2: RF-2LO spur at -25 dBc
m.IMT = imt;
```

**Gotcha:** The IMT must be a **real 2-D numeric matrix** (class `double`). Setting a cell array, 3-D array, complex matrix, or non-numeric type errors with "An Intermodulation Table must be real two dimensional matrix." Ensure `imt` is created with standard `double` operations (e.g., `99*ones(M,N)`).

**Gotcha:** IMT values must be **non-negative and <= 99** (they represent dBc below reference). Setting a negative value errors with "Value must be nonnegative." Setting a value > 99 errors with "Expected Spur table to be an array with all of the values <= 99." Using `inf` for "fully suppressed" also errors ("Value must be finite") — use `99` instead.

### Reading the IMT Table

| IMT Position | RF Order | LO Order | Spur Frequency (Down) |
|-------------|----------|----------|----------------------|
| `(1,1)` | 0 | 0 | DC |
| `(2,1)` | 1 | 0 | fRF (RF feedthrough) |
| `(1,2)` | 0 | 1 | fLO (LO feedthrough) |
| `(2,2)` | 1 | 1 | fRF - fLO (desired IF) |
| `(3,2)` | 2 | 1 | 2·fRF - fLO |
| `(2,3)` | 1 | 2 | fRF - 2·fLO |
| `(3,3)` | 2 | 2 | 2·fRF - 2·fLO |

### Image Rejection and the IMT

The IMT models spurious products from a **single RF input** mixing with the LO. It does **NOT** model image rejection. Image rejection involves a separate signal at the image frequency (fImage = 2·fLO - fRF for low-side downconversion) producing the same IF as the desired signal. This is a different-input-frequency problem, not a same-input spur problem.

To model image rejection in a system:
- Add a preselector or image-reject filter (rffilter or nport) before the mixer in your rfbudget chain
- The filter's attenuation at fImage provides the image rejection

Do not attempt to represent image rejection as an IMT entry — the IMT only describes products generated from the desired RF input.

## Spur Chart Visualization

```matlab
m = mixerIMT('LO', 2.1e9, 'ConverterType', 'Down', 'NF', 10, 'Name', 'Mixer');
figure;
rfplot(m, 2.4e9);   % Spur chart at fRF = 2.4 GHz
```

`rfplot(m, fRF)` displays a spur chart showing all intermodulation products at the specified RF input frequency, with their relative power levels.

**Gotcha:** `rfplot(m, fRF)` takes a **scalar** frequency, not a vector. Passing a frequency vector errors: "Value must be a scalar."

**Gotcha:** `rfplot(m)` with no frequency argument errors: "Not enough input arguments."

## Using in rfbudget

```matlab
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');
m = mixerIMT('ReferenceInputPower', -10, 'NominalOutputPower', -16, ...
    'NF', 10, 'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');
ifAmp = amplifier('Gain', 20, 'NF', 4, 'OIP3', 30, 'Name', 'IFAmp');

b = rfbudget([lna m ifAmp], 2.4e9, -30, 10e6);
fprintf('Total Gain: %.2f dB\n', b.TransducerGain(end));
fprintf('Output Freq: %.3f GHz\n', b.OutputFrequency(end)/1e9);
```

After the mixer, the output frequency changes to the IF: `fIF = fRF - fLO` for down-conversion.

## Using in circuit

`mixerIMT` is a 2-port (4-terminal) element compatible with `circuit`:

```matlab
ckt = circuit('MixerCircuit');
add(ckt, [1 2 0 0], m);
setports(ckt, [1 0], [2 0]);
s = sparameters(ckt, freq);
```

## S2D Data Files

Load mixer characterization from an S2D file:

```matlab
m = mixerIMT('FileName', 'mixer_data.s2d', 'UseDataFile', true, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'MeasuredMixer');
```

## OpenIF -- IF Frequency Planning

The `OpenIF` object finds spur-free intermediate frequencies in multiband receiver/transmitter architectures. Use it to identify open IF bands where no mixer spurs fall.

```matlab
hif = OpenIF(20e6);                    % 20 MHz IF bandwidth
imt1 = [99 99 99; 99 0 99; 99 99 99]; % Default 3x3 IMT
addMixer(hif, imt1, 2.4e9, 200e6, 'low', 20e6);   % RF center, RF BW, type, IF BW
addMixer(hif, imt1, 5.2e9, 200e6, 'low', 20e6);
show(hif);                             % Graphical spur-free zone display
report(hif);                           % Command-window summary
```

### `addMixer` Syntax

```matlab
addMixer(hif, imt, rfCenterFreq, rfBW, mixType, ifBW)
```

| Argument | Type | Description |
|----------|------|-------------|
| `hif` | OpenIF | The OpenIF object |
| `imt` | MxN double | Intermodulation table (same format as `mixerIMT.IMT`) |
| `rfCenterFreq` | scalar | RF center frequency (Hz) |
| `rfBW` | scalar | RF bandwidth (Hz) |
| `mixType` | char | `'low'` or `'high'` when IFLocation=`'MixerOutput'`; `'sum'` or `'diff'` when IFLocation=`'MixerInput'` |
| `ifBW` | scalar | IF bandwidth for this mixer (Hz) |

`'low'` means fIF = fRF - fLO (standard down-conversion); `'high'` means fIF = fRF + fLO.

### OpenIF Properties

| Property | Default | Description |
|----------|---------|-------------|
| `IFBW` | constructor arg | System-wide IF bandwidth (Hz) |
| `SpurFloor` | 99 | Maximum spur level to consider (dBc) |
| `IFLocation` | `'MixerOutput'` | `'MixerOutput'` or `'MixerInput'` |

`OpenIF` complements `mixerIMT`: use `mixerIMT` + `rfplot(m, fRF)` to visualize spurs at a single RF frequency; use `OpenIF` to find spur-free IF zones across an entire multiband architecture.

## Gotchas

1. **Do not set `m.Gain`** — Although `Gain` is settable, `rfbudget` ignores it and computes gain from `NominalOutputPower - ReferenceInputPower`. Setting it manually has no effect on the budget and can be misleading.
2. **Gain not in constructor** — `mixerIMT('Gain', -6)` errors. `Gain` cannot be passed as a constructor argument.
3. **IMT values must be 0-99** — They represent dBc below the reference (0 = reference, 99 = fully suppressed). Negative values error ("Value must be nonnegative"), values > 99 error ("values <= 99"), and `inf` errors ("Value must be finite"). Always use `99` for suppressed spurs, never `inf`.
4. **rfplot takes scalar frequency** — `rfplot(m, fRF)` requires a single frequency, not a vector.
5. **Default conversion gain is 10 dB** — `NominalOutputPower(-5) - ReferenceInputPower(-15) = 10 dB`. This is rarely what you want — set both explicitly.
6. **ConverterType sets Model automatically** — `'Down'` sets `Model='demod'`, `'Up'` sets `Model='mod'`.
7. **ConverterType defaults to `'Up'`** — If you omit `ConverterType`, the mixer performs up-conversion (`fOut = fRF + fLO`). Always set `'ConverterType', 'Down'` explicitly for down-conversion receivers.
8. **IMT must be a real 2-D double matrix** — Cell arrays, 3-D arrays, complex matrices, or non-numeric types error with "An Intermodulation Table must be real two dimensional matrix." Build with `99*ones(M,N)` then set individual entries.
9. **Clone elements before reusing in a second rfbudget** — An element object can only belong to one `rfbudget` at a time. Reusing it errors with "Element is already in another rfbudget." Use `clone(element)` to create an independent copy.

## Conventions

- Use `tiledlayout`/`nexttile` for multi-panel spur analysis figures
- Always label spur charts with the RF input frequency
- Set `ReferenceInputPower` and `NominalOutputPower` explicitly — do not rely on defaults
- Use `modulator` for simple cascade budgets; use `mixerIMT` when spur analysis matters

----

Copyright 2026 The MathWorks, Inc.

----
