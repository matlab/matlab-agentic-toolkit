---
name: matlab-dsphdl-ddc-design
description: Use when designing a Digital Down Converter (DDC) using dsphdl System objects. Triggers on requests involving DDC design, frequency down-conversion for FPGA/ASIC, NCO + mixer + decimation filter chains, fractional/non-integer sample rate conversion, or HDL-optimized receiver front-end signal processing.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# dsphdl DDC: Design, Simulate, Generate HDL

## Overview

End-to-end MATLAB workflow for designing a Digital Down Converter (DDC) using `dsphdl` System objects — combining an NCO (local oscillator), complex mixer, and multi-stage decimation filter chain — then simulating the streaming HDL-optimized design and generating synthesizable HDL via HDL Coder.

**Integer decimation (all stages have integer rate change):**
```
RF Input → [Mixer] → [CIC Decimator] → [Compensation FIR Decimator] → Baseband Output
              ↑
           [NCO] (generates cos + jsin at carrier frequency)
```

**Non-integer decimation (uses Farrow for fine rate adjustment):**
```
RF Input → [Mixer] → [CIC Dec (xR)] → [Farrow (L/M)] → [FIR Dec (xD)] → Baseband Output
              ↑
           [NCO]
```

## When to Use

- Designing a DDC or receiver front-end for FPGA/ASIC
- Building an NCO + mixer + decimation chain with `dsphdl` objects
- **Non-integer decimation** — when the target output rate doesn't divide evenly into the input rate
- Converting a floating-point DDC algorithm to HDL-ready streaming architecture
- Generating Verilog/VHDL for a complete DDC subsystem

## When Not To Use

- Non-HDL workflows, e.g. embedded C code generation

## Critical Conventions

### NCO Phase Increment

**ALWAYS compute as:** `phaseInc = round((-Fc * 2^AccumulatorWL) / Fs)` where `Fc` is the carrier frequency, `Fs` is the input sample frequency, and `AccumulatorWL` is the NCO accumulator word length. This produces a negative integer. Never omit the negation or compute `round(Fc / Fs * 2^AccumulatorWL)` — the negative sign is required for correct down-conversion.

### Mixer: direct multiply with `fi()` arithmetic — NO conjugate

The mixer multiplies the input by the NCO output directly. **ALWAYS write it as a single `fi()` expression with NO `conj()`:**

```matlab
% DO — correct, concise, HDL-synthesizable:
mixed = fi(dataIn * ncoSample, 1, 16, 14);

% DON'T — conjugate the NCO (wrong convention for this toolbox):
% mixed = fi(dataIn * conj(ncoSample), 1, 16, 14);

% DON'T — manual I/Q decomposition (verbose, error-prone):
% cosVal = real(ncoOut); sinVal = imag(ncoOut);
% iMixed = fi(dataIn * cosVal, 1, 16, 14);
% qMixed = fi(dataIn * sinVal, 1, 16, 14);

% DON'T — double() arithmetic (NOT synthesizable for HDL):
% mixed = fi(double(dataIn) * double(ncoOut), 1, 16, 14);
```

### OutputDataType — ALWAYS use "Same word length as input"

**ALWAYS set `OutputDataType` to `'Same word length as input'`** on CIC and FIR stages. For Farrow, use `'Same as first input'` (equivalent property value). Never use `'Full precision'` — it causes excessive bit growth through the chain.

### FIR NumCycles for resource sharing

**ALWAYS set `NumCycles`** on FIR stages — see `references/numcycles.md` for full details.

### NCO PhaseIncrementSource

**ALWAYS set `PhaseIncrementSource` to `'Property'`** for fixed-frequency DDC designs. The default is `'Input port'`, which changes the step method signature from `nco(validIn)` to `nco(phaseInc, validIn)`.

### Valid signal piping — NEVER use if-statements on valid

**ALWAYS call every stage every clock cycle and pipe valid outputs to downstream valid inputs.** This matches the actual HDL hardware behavior where all stages run every clock cycle and valid propagates as a signal.

```matlab
% DO — pipe valid through the chain:
[ncoSample, ncoValid] = nco(validIn);
mixed = fi(dataIn * ncoSample, 1, 16, 14);
[cicSample, cicValid] = cicDec(mixed, ncoValid);
[dataOut, validOut] = firDec(cicSample, cicValid);

% DON'T — conditionally call downstream stages:
% [cicSample, cicV] = cicDec(mixed, true);
% if cicV
%     [firSample, firV] = firDec(cicSample, true);
% end
```

### Data-valid pairing — ALWAYS gate data with its corresponding valid

**Data outputs are only meaningful when the corresponding valid signal is true.** Always use `dataOut` together with `validOut` from the same stage. Never read, store, or process data samples without checking the valid that was returned alongside them.

```matlab
% DO — collect only valid output samples:
outputData = dataOut(validOut);

% DO — gate downstream processing on the valid from the same step call:
[dataOut, validOut] = firDec(cicSample, cicValid);
if validOut
    outputBuffer(idx) = dataOut;
    idx = idx + 1;
end

% DON'T — use dataOut without checking validOut:
% outputBuffer(ii) = dataOut;  % dataOut is garbage when validOut is false

% DON'T — mix valid from one stage with data from another:
% goodSamples = cicSample(validOut);  % validOut is from firDec, not cicDec
```

This applies to all stages: NCO, CIC, FIR, and Farrow. When a stage returns `[data, valid]`, those two outputs are paired — `data` is undefined when `valid` is false.

### Test signals — sinusoid modulated onto complex carrier

DDC inputs represent a baseband signal modulated onto a complex carrier. **ALWAYS construct the test signal as a real baseband waveform multiplied by a complex carrier exponential:**

```matlab
% DO — sinusoid modulated onto complex carrier:
inputSignal = cos(2*pi*Fsig*t) .* exp(1j*2*pi*Fc*t);
dataIn = fi(inputSignal, 1, 16, 14);  % fi() of complex input stays complex

% DO — complex codegen input type:
dataType = complex(fi(0, 1, 16, 14));

% DON'T — pure complex exponential at offset frequency (not a modulated signal):
% inputSignal = exp(1j*2*pi*(Fc + Fsig)*t);

% DON'T — real cos() signal (loses negative frequency content, wrong DDC behavior):
% inputSignal = cos(2*pi*(Fc + Fsig)*t);
```

After down-conversion, the expected baseband output is the original modulating waveform: `cos(2*pi*Fsig*t)`.

Do NOT pre-allocate `dataOut` or `validOut` in testbenches — let MATLAB grow them dynamically so the data type propagates from the DDC function output.

This applies to **all** generated code: design scripts, testbenches, and HDL codegen argument types.

### All System objects MUST be `persistent`

In the HDL function wrapper, declare all `dsphdl` objects as `persistent` and initialize inside `if isempty(...)`.

## Interactive Requirements Gathering (REQUIRED)

**Before generating any code, ALWAYS use AskUserQuestion to gather the user's DDC specifications. Ask exactly ONE question per AskUserQuestion call.** Do not assume defaults.

### Questions to ask (one at a time, in order):

1. **Sample rate and carrier:** "What is the input sampling frequency (Fs) and the carrier/IF frequency to down-convert?"
2. **Output rate:** "How would you like to specify the output rate?" (decimation factor or output sample rate in Hz). Compute `totalDecim = Fs / Fs_out`. **Check whether `totalDecim` is an integer** (i.e., `mod(Fs, Fs_out) == 0`). Only flag as non-integer if it truly is (e.g., 8.2, 12.5). Integer values like 25, 100, etc. are integer even if they are not powers of 2.
3. **Signal bandwidth:** "What is the desired passband bandwidth at the output?"
4. **Input data type:** "What is the input word length and format?" (e.g., 16-bit signed, 14 fractional)
5. **Decimation staging:** Present factorization options based on whether `totalDecim` is integer:
   - **If integer:** Only offer integer staging options (CIC+FIR, CIC+FIR+FIR, All FIR). Compute valid integer factor pairs/triples of `totalDecim` and present them. Do NOT offer Farrow-based options. **Every stage must actually change the sample rate (decimation factor >= 2). Never offer non-decimating FIR stages (factor = 1).**
   - **If non-integer:** Offer Farrow-based options (CIC+FIR+Farrow) alongside integer approximations. Explain the Farrow handles the fractional remainder. **The Farrow must always decimate (RateChange > 1, since RateChange = fsIn/fsOut).** Choose integer stages so that CIC_R * FIR_R <= total_decimation. Never offer staging where CIC_R * FIR_R > total_decimation (that would require Farrow interpolation).
6. **CIC parameters** (if CIC used): "How many CIC sections?"
7. **HDL language:** "Verilog or VHDL?" — just present the two options; do NOT offer commentary on what each language is good for or when to choose one over the other.

### After gathering requirements — compute derived parameters:

- Phase increment = `round((-Fc * 2^AccumulatorWL) / Fs)`
- CIC/FIR decimation factors (must be integer per stage)
- FIR `NumCycles` = cumulative decimation at that FIR's input (see `references/numcycles.md`)
- For non-integer: `total_decimation = CIC_R * FIR_R * farrowRateChange`, where `farrowRateChange = total_decimation / (CIC_R * FIR_R)` (close to 1, specified as fsIn/fsOut)
- **Validate:** `signalBandwidth/2 < Fs_out/2` — if not, the desired signal exceeds the output Nyquist rate and the specs are inconsistent. Tell the user to reduce bandwidth or increase output rate.

## Complete Workflow

### Step 1: Compute DDC Parameters

```matlab
%% DDC System Parameters
Fs = 100e6;           % Input sample rate (Hz)
Fc = 25e6;            % Carrier/IF frequency (Hz)
totalDecim = 16;      % Total decimation factor
Fs_out = Fs / totalDecim;  % Output sample rate

% Decimation staging: CIC handles bulk, FIR refines
cicDecimFactor = 8;   % CIC decimation
firDecimFactor = totalDecim / cicDecimFactor;  % FIR decimation = 2

% NCO phase increment for carrier frequency
accWL = 32;           % Accumulator word length (32-bit gives ~0.023 Hz resolution at 100 MHz)
phaseInc = round((-Fc * 2^accWL) / Fs);
fprintf('Phase increment: %d\n', phaseInc);
fprintf('Actual frequency: %.6f MHz\n', abs(phaseInc) * Fs / 2^accWL / 1e6);
```

### Step 2: Design CIC Compensation FIR

**ALWAYS use `dsp.CICCompensationDecimator` to design the compensation filter.** This designs a filter that inverts the CIC's passband droop (sinc^N rolloff) while providing the stopband rejection needed for the FIR decimation. Never use `fir1()` — it produces a generic lowpass that does not compensate CIC droop.

```matlab
%% Design CIC compensation filter using dsp.CICCompensationDecimator
cicNumSections = 4;
cicDiffDelay = 1;

Fs_afterCIC = Fs / cicDecimFactor;         % Sample rate after CIC (= FIR input rate)
Fpass = signalBandwidth / 2;               % Passband edge (half of desired signal BW)
Fstop = Fs_out / 2;                        % Stopband edge (output Nyquist)

cicDroopComp = dsp.CICCompensationDecimator(firDecimFactor, ...
    'SampleRate',          Fs_afterCIC, ...
    'CICRateChangeFactor', cicDecimFactor, ...
    'CICNumSections',      cicNumSections, ...
    'PassbandFrequency',   Fpass, ...
    'StopbandFrequency',   Fstop, ...
    'PassbandRipple',      0.1, ...
    'StopbandAttenuation', 50);
compCoeffs = cicDroopComp.coeffs.Numerator;
```

### Step 3: Instantiate dsphdl System Objects

```matlab
%% Create the DDC components

% NCO — generates complex exponential at carrier frequency
nco = dsphdl.NCO( ...
    'DesignMethod', 'NCO parameter', ...
    'PhaseIncrementSource', 'Property', ...
    'PhaseIncrement', phaseInc, ...
    'Waveform', 'Complex exponential', ...
    'AccumulatorWL', accWL, ...
    'OutputWL', 16, ...
    'OutputFL', 14, ...
    'NumDitherBits', 4, ...
    'PhaseQuantization', true, ...
    'NumQuantizerAccumulatorBits', 12);

% CIC Decimator — bulk decimation (efficient, no multipliers)
cicDec = dsphdl.CICDecimator( ...
    'DecimationFactor', cicDecimFactor, ...
    'DifferentialDelay', cicDiffDelay, ...
    'NumSections', cicNumSections, ...
    'OutputDataType', 'Same word length as input', ...
    'GainCorrection', true);

% FIR Decimator — compensation + final decimation
% NumCycles = cicDecimFactor: FIR input arrives every 8 clocks, so reuse multipliers
firDec = dsphdl.FIRDecimator( ...
    'DecimationFactor', firDecimFactor, ...
    'Numerator', compCoeffs, ...
    'NumCycles', cicDecimFactor, ...
    'OutputDataType', 'Same word length as input', ...
    'FilterStructure', 'Direct form systolic');
```

### Step 4: Simulate the DDC

```matlab
%% Simulate DDC end-to-end
numSamples = 1000 * totalDecim;
t = (0:numSamples-1)' / Fs;
Fsig = 1e6;
inputSignal = cos(2*pi*Fsig*t) .* exp(1j*2*pi*Fc*t);
dataIn = fi(inputSignal, 1, inputWL, inputFL);

for ii = 1:numSamples
    [ncoSample, ncoValid] = nco(true);
    mixed = fi(dataIn(ii) * ncoSample, 1, inputWL, inputFL);
    [cicSample, cicValid] = cicDec(mixed, ncoValid);
    [ddcOut(ii), ddcValid(ii)] = firDec(cicSample, cicValid);
end
outputData = ddcOut(ddcValid);
fprintf('DDC produced %d output samples from %d input samples\n', numel(outputData), numSamples);
```

### Step 5: Generate HDL

#### 5a. Create the Design Function

**IMPORTANT:** `dsp.CICCompensationDecimator` is NOT supported for HDL code generation. You MUST pre-compute the FIR coefficients by running the design script (Step 2) in MATLAB first, then hardcode the resulting numeric vector in the HDL function. Never call `dsp.CICCompensationDecimator` inside an HDL function — it will fail at `codegen` time.

```matlab
function [dataOut, validOut] = myDDC(dataIn, validIn)
%myDDC HDL-optimized Digital Down Converter

    persistent nco cicDec firDec;
    if isempty(nco)
        phaseInc = round((-25e6 * 2^32) / 100e6);
        nco = dsphdl.NCO( ...
            'DesignMethod', 'NCO parameter', ...
            'PhaseIncrementSource', 'Property', ...
            'PhaseIncrement', phaseInc, ...
            'Waveform', 'Complex exponential', ...
            'AccumulatorWL', 32, ...
            'OutputWL', 16, ...
            'OutputFL', 14, ...
            'NumDitherBits', 4, ...
            'PhaseQuantization', true, ...
            'NumQuantizerAccumulatorBits', 12);

        cicDec = dsphdl.CICDecimator( ...
            'DecimationFactor', 8, ...
            'DifferentialDelay', 1, ...
            'NumSections', 4, ...
            'OutputDataType', 'Same word length as input', ...
            'GainCorrection', true);

        % Coefficients pre-computed from dsp.CICCompensationDecimator in design script
        compCoeffs = [ ... ]; % <-- paste numeric vector from Step 2
        firDec = dsphdl.FIRDecimator( ...
            'DecimationFactor', 2, ...
            'Numerator', compCoeffs, ...
            'NumCycles', 8, ...
            'OutputDataType', 'Same word length as input', ...
            'FilterStructure', 'Direct form systolic');
    end

    [ncoSample, ncoValid] = nco(validIn);
    mixed = fi(dataIn * ncoSample, 1, 16, 14);
    [cicSample, cicValid] = cicDec(mixed, ncoValid);
    [dataOut, validOut] = firDec(cicSample, cicValid);
end
```

**Workflow for obtaining coefficients:** After running the design script (Step 2), execute `fprintf('%.15g, ', compCoeffs)` in MATLAB to get the numeric values, then paste them into the `compCoeffs` vector in the HDL function.

#### 5b. Create the Testbench

The testbench should run the DDC, print sample counts, and plot time-domain I/Q and frequency-domain output. Do NOT include correlation checks, normalization, or numeric pass/fail verification — just plot and let the user visually inspect.

**After running the testbench:** Print the sample counts and the rough decimation factor (`numInputSamples / numOutputSamples`). Do NOT add commentary or interpretation about the decimation factor — just print the numbers.

```matlab
%% DDC Testbench
clear myDDC;
totalDecim = 16; numSamples = 1000 * totalDecim;
Fs = 100e6; Fc = 25e6; Fs_out = Fs / totalDecim;
t = (0:numSamples-1)' / Fs;
Fsig = 1e6;
inputSignal = cos(2*pi*Fsig*t) .* exp(1j*2*pi*Fc*t);
dataIn = fi(inputSignal, 1, 16, 14);

for ii = 1:numSamples
    [dataOut(ii), validOut(ii)] = myDDC(dataIn(ii), true);
end
outputData = dataOut(validOut);
fprintf('DDC produced %d output samples from %d input samples\n', numel(outputData), numSamples);

%% Plot — time-domain I/Q and frequency-domain PSD
tOut = (0:numel(outputData)-1)' / Fs_out;
figure; subplot(2,1,1);
plot(tOut*1e6, real(double(outputData)), tOut*1e6, imag(double(outputData)));
xlabel('Time (\mus)'); ylabel('Amplitude'); title('DDC Output (I/Q)'); legend('I','Q'); grid on;
subplot(2,1,2); nfft = min(256, numel(outputData));
[psd, f] = pwelch(double(outputData), hanning(nfft), floor(nfft/2), nfft, Fs_out, 'centered');
plot(f/1e6, 10*log10(psd)); xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)'); title('Output Spectrum'); grid on;
```

#### 5c. Generate HDL Code

```matlab
%% Generate HDL for DDC
hdlcfg = coder.config("hdl");
hdlcfg.TargetLanguage = 'Verilog';        % or 'VHDL'
hdlcfg.GenerateHDLTestBench = true;
hdlcfg.TestBenchName = 'myDDC_tb';

dataType = complex(fi(0, 1, 16, 14));  % scalar complex fixed-point input
codegen -config hdlcfg myDDC -args {dataType, false} -d hdl_output
```

**After HDL generation:** Do not display the resource utilization report or resource summary to the user. Just confirm that HDL generation succeeded (number of files, conformance errors) and list the key generated file paths.

## Non-Integer Decimation with Farrow Rate Converter

For non-integer decimation factors (e.g., 8.2, 12.5, 7.68), use integer CIC + FIR stages for bulk decimation and a `dsphdl.FarrowRateConverter` for the fractional fine adjustment.

**Staging strategy (DDC — Farrow must always decimate, RateChange > 1):**
1. Choose integer CIC_R and FIR_R such that CIC_R * FIR_R <= total_decimation (integer stages under-decimate; Farrow handles the remainder). **Never** choose CIC_R * FIR_R > total_decimation — that would require Farrow interpolation (RateChange < 1), which is wrong for a DDC.
2. Compute farrowRateChange = total_decimation / (CIC_R * FIR_R) (must be > 1 for DDC, since RateChange = fsIn/fsOut)
3. Verify: CIC_R * FIR_R * farrowRateChange = total_decimation

**Example: 8.2x decimation** — CIC(x4) + FIR(x2) + Farrow(RateChange=41/40) = 4 * 2 * (41/40) = 8.2

```matlab
function [dataOut, validOut] = myDDC_fractional(dataIn, validIn)
%myDDC_fractional DDC with non-integer 8.2x decimation

    persistent nco cicDec firDec farrow;
    if isempty(nco)
        phaseInc = round((-25e6 * 2^32) / 100e6);
        nco = dsphdl.NCO( ...
            'DesignMethod', 'NCO parameter', ...
            'PhaseIncrementSource', 'Property', ...
            'PhaseIncrement', phaseInc, ...
            'Waveform', 'Complex exponential', ...
            'AccumulatorWL', 32, ...
            'OutputWL', 16, 'OutputFL', 14, ...
            'NumDitherBits', 4, ...
            'PhaseQuantization', true, ...
            'NumQuantizerAccumulatorBits', 12);

        cicDec = dsphdl.CICDecimator( ...
            'DecimationFactor', 4, ...
            'DifferentialDelay', 1, ...
            'NumSections', 4, ...
            'OutputDataType', 'Same word length as input', ...
            'GainCorrection', true);

        % Coefficients pre-computed from dsp.CICCompensationDecimator in design script
        compCoeffs = [ ... ]; % <-- paste numeric vector from design script
        firDec = dsphdl.FIRDecimator( ...
            'DecimationFactor', 2, ...
            'Numerator', compCoeffs, ...
            'NumCycles', 4, ...
            'OutputDataType', 'Same word length as input', ...
            'FilterStructure', 'Direct form systolic');

        farrowCoeffs = [-1/6,  1/2, -1/3, 0; ...
                         1/2,  -1,   -1/2, 1; ...
                        -1/2,   1/2,  1,   0; ...
                         1/6,   0,   -1/6, 0];
        farrow = dsphdl.FarrowRateConverter( ...
            'RateChangeSource', 'Property', ...
            'RateChange', 41/40, ...
            'Coefficients', farrowCoeffs, ...
            'OutputDataType', 'Same as first input', ...
            'FilterStructure', 'Direct form systolic');
    end

    [ncoSample, ncoValid] = nco(validIn);
    mixed = fi(dataIn * ncoSample, 1, 16, 14);
    [cicSample, cicValid] = cicDec(mixed, ncoValid);
    [firSample, firValid] = firDec(cicSample, cicValid);

    % Farrow always outputs 3: [data, valid, ready]
    [dataOut, validOut, ~] = farrow(firSample, firValid);
end
```

**Key Farrow conventions:**
- `RateChange` = fsIn / fsOut. **In a DDC, Farrow must always decimate (RateChange > 1).** Never use RateChange < 1 in a DDC — that would be interpolation.
- Farrow always outputs 3 values: `[data, valid, ready]`. Capture `ready` with `~` if not using backpressure.
- Farrow must be called every clock cycle — it manages its own internal timing.
- Default 3rd-order Lagrange coefficients work well for most DDC applications.

For additional architecture variants (three-stage, Farrow vs FIR Rate Converter comparison, real I/Q mixing), see `references/architecture-variants.md`.

## Common Mistakes

These supplement the Critical Conventions above — only items not already covered there.

| Mistake | Fix |
|---|---|
| Using `mfilt` objects for filter design | **NEVER** use `mfilt` (e.g., `mfilt.cicdecim`, `mfilt.firinterp`) — it is deprecated. Use `dsp.CICCompensationDecimator`, `designMultirateFIR`, or `dsp.FIRDecimator`/`dsp.FIRInterpolator` for filter design |
| Using `fir1()` for CIC compensation filter | **ALWAYS** use `dsp.CICCompensationDecimator` — it inverts CIC droop; `fir1()` is a generic lowpass that ignores CIC response |
| Calling `dsp.CICCompensationDecimator` inside HDL function | `dsp.CICCompensationDecimator` is **NOT** supported for HDL code generation. Pre-compute coefficients in the design script, then hardcode the numeric vector in the HDL function |
| CIC decimation factor not integer | Each stage must be integer. For non-integer totals, use Farrow for the fractional part |
| Farrow misuse (wrong rate, missing output, not called every cycle) | `RateChange` = fsIn/fsOut (> 1 for DDC decimation). Always capture 3 outputs `[data, valid, ~]`. Call every cycle. Choose integer stages so CIC_R * FIR_R <= total_decimation — never > total (that requires interpolation) |
For component property tables and step method signatures, see `references/component-properties.md`.

----

Copyright 2026 The MathWorks, Inc.
