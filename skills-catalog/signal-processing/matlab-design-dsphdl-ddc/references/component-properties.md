# DDC Component Properties Reference

Property tables and step method signatures for `dsphdl` System objects used in DDC designs. For DDC-specific usage rules (which properties to set and why), see the Critical Conventions section in SKILL.md.

## dsphdl.NCO

| Property | Values | Default | Notes |
|---|---|---|---|
| `DesignMethod` | `'NCO parameter'`, `'Frequency specification'` | `'NCO parameter'` | How to specify frequency (optional — defaults to `'NCO parameter'`) |
| `PhaseIncrementSource` | `'Property'`, `'Input port'` | `'Input port'` | How phase increment is specified |
| `PhaseIncrement` | integer | `100` | Phase increment per sample (when Source='Property') |
| `Frequency` | double (Hz) | `510` | Target frequency (when DesignMethod='Frequency specification') |
| `FreqResolution` | double (Hz) | `0.05` | Resolution (when DesignMethod='Frequency specification') |
| `SamplingFreq` | double (Hz) | `4000` | Sample rate |
| `AccumulatorWL` | integer | `16` | Phase accumulator word length (sets frequency resolution) |
| `Waveform` | `'Sine'`, `'Cosine'`, `'Complex exponential'`, `'Sine and cosine'` | `'Sine'` | Output waveform type |
| `OutputWL` | integer | `16` | Output word length |
| `OutputFL` | integer | `14` | Output fractional length |
| `NumDitherBits` | integer | `4` | Dither bits for spurious reduction |
| `PhaseQuantization` | logical | `true` | Quantize phase before LUT |
| `NumQuantizerAccumulatorBits` | integer | `12` | Bits used from accumulator for LUT address |
| `LUTCompress` | logical | `false` | Sunderland compression for smaller LUT |

## dsphdl.CICDecimator

| Property | Values | Default | Notes |
|---|---|---|---|
| `DecimationFactor` | integer | `2` | Decimation ratio |
| `DifferentialDelay` | integer | `1` | Comb section delay (1 or 2) |
| `NumSections` | integer | `2` | Number of integrator-comb pairs |
| `OutputDataType` | `'Full precision'`, `'Same word length as input'`, `'Minimum section word lengths'` | `'Full precision'` | Output quantization |
| `OutputWordLength` | integer | `16` | When OutputDataType is custom |
| `GainCorrection` | logical | `false` | Normalize CIC gain |
| `ResetInputPort` | logical | `false` | Synchronous reset port |

## dsphdl.FIRDecimator

| Property | Values | Default | Notes |
|---|---|---|---|
| `DecimationFactor` | integer | `2` | Decimation ratio |
| `Numerator` | double vector | (from `dsp.CICCompensationDecimator`) | Filter coefficients |
| `FilterStructure` | `'Direct form systolic'`, `'Direct form transposed'` | `'Direct form systolic'` | HDL architecture |
| `NumCycles` | integer | `1` | Clock cycles between valid inputs (resource sharing) — see `numcycles.md` |
| `OptimizeSymmCoeff` | logical | `false` | Exploit coefficient symmetry |
| `CoefficientsDataType` | `'Same word length as input'` or custom | `'Same word length as input'` | Coefficient quantization |
| `OutputDataType` | `'Full precision'`, `'Same word length as input'`, custom | `'Full precision'` | Output quantization |
| `ResetInputPort` | logical | `false` | Synchronous reset port |

## dsphdl.FarrowRateConverter

| Property | Values | Default | Notes |
|---|---|---|---|
| `RateChangeSource` | `'Property'`, `'Input port'` | `'Property'` | Fixed or runtime-tunable rate |
| `RateChange` | double | `48/44.1` | Input/output rate ratio (fsIn/fsOut); >1 = decimation |
| `Coefficients` | double matrix | 3rd-order Lagrange (4x4) | Each row is one polynomial coefficient set. Rows = polynomial order + 1, Cols = number of filter taps per sub-filter |
| `FilterStructure` | `'Direct form systolic'`, `'Direct form transposed'` | `'Direct form systolic'` | HDL architecture |
| `NumCycles` | integer | `1` | Clock cycles between valid inputs |
| `CoefficientsDataType` | `'Same word length as input'` or custom | `'Same word length as input'` | Coefficient quantization |
| `MultiplicandDataType` | `'Full precision'` or custom | `'Full precision'` | Internal multiplicand type |
| `OutputDataType` | `'Same as first input'` or custom | `'Same as first input'` | Output quantization |
| `RateChangeDataType` | numerictype | `numerictype(0,16)` | Fixed-point type for rate value |
| `ResetInputPort` | logical | `false` | Synchronous reset port |

## dsphdl.FIRRateConverter

| Property | Values | Default | Notes |
|---|---|---|---|
| `InterpolationFactor` | integer (1-1024) | `3` | Upsampling factor (L) |
| `DecimationFactor` | integer (1-1024) | `2` | Downsampling factor (M) |
| `Numerator` | double vector | `designMultirateFIR(L, M)` | Prototype lowpass filter coefficients |
| `ReadyPort` | logical | `false` | Enable ready output for backpressure |
| `CoefficientsDataType` | numerictype | `numerictype(1,16,16)` | Coefficient quantization |
| `OutputDataType` | `'Same word length as input'`, `'Full precision'`, custom | `'Same word length as input'` | Output quantization |
| `RoundingMethod` | `'Floor'`, `'Ceiling'`, etc. | `'Floor'` | Rounding for fixed-point |
| `OverflowAction` | `'Wrap'`, `'Saturate'` | `'Wrap'` | Overflow behavior |

## Step Method Signatures

```matlab
% NCO (property-based, 'Complex exponential' waveform)
[waveOut, validOut] = nco(validIn);

% NCO (property-based, 'Sine and cosine' waveform)
[sinOut, cosOut, validOut] = nco(validIn);

% CIC Decimator
[dataOut, validOut] = cicDec(dataIn, validIn);

% FIR Decimator
[dataOut, validOut] = firDec(dataIn, validIn);

% Farrow Rate Converter (always outputs 3: data, valid, ready)
[dataOut, validOut, ready] = farrow(dataIn, validIn);

% Farrow Rate Converter (with input-port rate change)
[dataOut, validOut, ready] = farrow(dataIn, validIn, rateChange);

% FIR Rate Converter
[dataOut, validOut] = firRC(dataIn, validIn);

% FIR Rate Converter (with ready port enabled)
[dataOut, validOut, ready] = firRC(dataIn, validIn);
```

----

Copyright 2026 The MathWorks, Inc.
