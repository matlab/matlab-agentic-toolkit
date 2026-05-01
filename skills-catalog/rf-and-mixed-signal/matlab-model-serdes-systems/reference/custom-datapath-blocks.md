# Custom Datapath Blocks for SerDes Toolbox

Create custom equalization or signal-processing blocks that integrate into the
SerDes Toolbox datapath alongside built-in blocks like `serdes.FFE`, `serdes.CTLE`,
and `serdes.DFECDR`.

## When to Use

- The built-in blocks don't cover your equalization algorithm
- You need a custom Tx or Rx processing stage (e.g., nonlinear equalizer, custom AGC)
- You want your custom block to export AMI parameters and compile into a DLL/SO

## Architecture

Custom datapath blocks inherit from `serdes.SerdesAbstractSystemObject`, which
itself inherits from `matlab.System`. This base class provides the SerDes-specific
interface that the toolbox framework expects.

### Class Hierarchy

```
matlab.System
  └── serdes.SerdesAbstractSystemObject    ← inherit from this
        ├── serdes.FFE                      (built-in examples)
        ├── serdes.CTLE
        ├── serdes.DFECDR
        └── YourCustomBlock                 (your block)
```

## Required Interface

### Properties

**Inherited from base class** (do not redefine):

| Property | Type | Purpose |
|----------|------|---------|
| `SymbolTime` | double | Symbol duration (s) — set by framework |
| `SampleInterval` | double | Sample interval (s) — set by framework |
| `Modulation` | integer | Modulation levels (2=NRZ through 16) — set by framework |

**Must define on your subclass:**

| Property | Type | Attributes | Purpose |
|----------|------|------------|---------|
| `Mode` | integer | public | 0 = Fixed (not exported), 1 = Fixed (exported), 2 = Adaptive |
| `WaveType` | char | public | `'Impulse'` or `'Sample'` — set by framework, drives `stepImpl` |
| `IsLinear` | logical | `Hidden, SetAccess = immutable` | `true` if block is linear. Enables statistical (Init) analysis |
| `IsTimeInvariant` | logical | `Hidden, SetAccess = immutable` | `true` if block parameters do not adapt over time |

### Methods

| Method | Access | Required | Purpose |
|--------|--------|----------|---------|
| `stepImpl(obj, x)` | protected | Yes | Core algorithm. Must handle both `WaveType` values |
| `resetImpl(obj)` | protected | Yes | Reset internal states |
| `getAMIParameters(obj)` | **public** | Yes (abstract) | Return AMI parameter definitions for `.ami` file |
| `getAMIInputNames(obj)` | **public** | Yes (abstract) | Return input port names for AMI |
| `getAMIOutputNames(obj)` | **public** | Yes (abstract) | Return output port names for AMI |

## Class Template

```matlab
classdef (StrictDefaults) CustomEQ < serdes.SerdesAbstractSystemObject
%CustomEQ Custom equalizer for SerDes datapath.

    properties(Nontunable)
        NumTaps (1,1) {mustBeInteger, mustBePositive} = 3
    end

    properties
        TapWeights (1,:) double = [0 1 0]
        Mode (1,1) {mustBeMember(Mode, [0 1 2])} = 1
    end

    properties(DiscreteState)
        Buffer
    end

    properties(Access = private)
        pSamplesPerSymbol
    end

    % WaveType: set by Simulink framework; set manually in standalone MATLAB
    properties
        WaveType (1,:) char {mustBeMember(WaveType, {'Impulse','Sample'})} = 'Sample'
    end

    % IsLinear/IsTimeInvariant: immutable — set once in constructor, cannot change
    % IMPORTANT: no size spec or validators on inherited abstract properties
    properties(Hidden, SetAccess = immutable)
        IsLinear
        IsTimeInvariant
    end

    methods
        function obj = CustomEQ(varargin)
            % Set immutable properties before setProperties
            obj.IsLinear = true;
            obj.IsTimeInvariant = true;
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj, x)
            obj.pSamplesPerSymbol = round(obj.SymbolTime / obj.SampleInterval);
        end

        function y = stepImpl(obj, x)
            switch obj.WaveType
                case "Impulse"
                    % Init path: convolve with impulse response
                    % Input x is the channel impulse response (column vector)
                    h = upsample(obj.TapWeights(:), obj.pSamplesPerSymbol);
                    y = conv(x, h);
                    y = y(1:numel(x));  % truncate to input length

                case "Sample"
                    % GetWave path: process time-domain samples
                    % Input x is a block of waveform samples
                    nTaps = obj.NumTaps;
                    nSamples = numel(x);
                    y = zeros(size(x));
                    for k = 1:nSamples
                        % Shift buffer
                        obj.Buffer = [x(k); obj.Buffer(1:end-1)];
                        % Apply FIR
                        y(k) = obj.TapWeights * obj.Buffer(1:nTaps);
                    end
            end
        end

        function resetImpl(obj)
            obj.Buffer = zeros(obj.NumTaps, 1);
        end
    end

    % getAMI* methods are public (abstract on base class)
    methods
        function params = getAMIParameters(obj)
            params = struct();
            params.TapWeights = struct(...
                'Usage', 'InOut', ...
                'Type', 'Float', ...
                'Default', obj.TapWeights, ...
                'Description', 'FIR tap weights');
        end

        function names = getAMIInputNames(~)
            names = {"in"};
        end

        function names = getAMIOutputNames(~)
            names = {"out"};
        end
    end

    methods (Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Code generation";
        end
    end
end
```

## WaveType: The Critical Dispatch

The `WaveType` property is the key to dual-mode (Init + GetWave) operation:

| WaveType | When Set | Input `x` Contains | Algorithm Should |
|----------|----------|---------------------|-----------------|
| `"Impulse"` | Init path (statistical analysis) | Channel impulse response | Apply LTI transfer function via convolution |
| `"Sample"` | GetWave path (time-domain) | Block of waveform samples | Process samples, update adaptive state |

**Critical:** Simulink sets `WaveType` automatically before each call. In standalone
MATLAB usage, you must set it explicitly:

```matlab
eq = CustomEQ('TapWeights', [0.2 0.6 0.2]);
eq.SymbolTime = 100e-12;
eq.SampleInterval = 6.25e-12;

% For impulse processing
eq.WaveType = "Impulse";
yImpulse = eq(channelImpulse);

% For sample processing (reset first)
release(eq);
eq.WaveType = "Sample";
ySamples = eq(waveformBlock);
```

## Integration Workflow

### Option A: Replace PassThrough in SerdesSystem

1. Design the system with `serdes.PassThrough` as a placeholder
2. Export to Simulink via `exportToSimulink`
3. In the Simulink model, replace the PassThrough MATLAB System block with your custom block

```matlab
% Step 1: Design with placeholder
sys = SerdesSystem(...
    'RxModel', Receiver('Blocks', ...
        {serdes.CTLE, serdes.PassThrough, serdes.DFECDR}), ...
    'SymbolTime', 100e-12, ...
    'SamplesPerSymbol', 16);

% Step 2: Export
exportToSimulink(sys);

% Step 3: Replace PassThrough block in Simulink
% Open the model, find the PassThrough MATLAB System block,
% and change its System object name to 'CustomEQ'
% Or programmatically:
mdl = 'untitled';
blk = [mdl '/Rx/PassThrough'];
set_param(blk, 'System', 'CustomEQ');
```

### Option B: Direct Use in MATLAB (Without Simulink)

```matlab
% Create and configure
eq = CustomEQ('NumTaps', 5, 'TapWeights', [-0.1 -0.05 0.8 -0.05 -0.1]);
eq.SymbolTime = 100e-12;
eq.SampleInterval = 6.25e-12;

% Process impulse (Init path)
eq.WaveType = "Impulse";
impulse = zeros(1024, 1);
impulse(1) = 1;
yInit = eq(impulse);

% Convert to pulse and analyze
pulse = impulse2pulse(yInit, 16, 6.25e-12);
metrics = optPulseMetric(pulse, 16, 6.25e-12, 1e-6);
```

## Example: Saturating Amplifier

The built-in `serdes.SaturatingAmplifier` provides a basic limiter. Here is how
to use it as a custom Rx stage for signal conditioning before DFE:

```matlab
% Built-in saturating amplifier — no custom class needed
amp = serdes.SaturatingAmplifier;
amp.Limit = 0.4;              % clip at ±400 mV
amp.LinearGain = 2;           % 2x gain in linear region
amp.Specification = "Limit";  % "Limit" or "LinearGain"
amp.Mode = 1;                 % export as AMI parameter

% Place between CTLE and DFECDR in the Rx chain
sys = SerdesSystem(...
    'RxModel', Receiver('Blocks', {ctle, amp, dfecdr}), ...
    'TxModel', Transmitter('Blocks', {ffe}), ...
    'SymbolTime', symbolTime, 'SamplesPerSymbol', 16);
```

### When to Write a Custom Block Instead

Use `serdes.SaturatingAmplifier` for simple clipping/limiting. Write a custom
`serdes.SerdesAbstractSystemObject` subclass when you need:
- Nonstandard transfer functions (e.g., polynomial, piecewise)
- State-dependent behavior (e.g., AGC with custom adaptation law)
- Multiple interacting parameters not covered by built-in blocks

## Common Mistakes

### 1. Inheriting from `matlab.System` Instead of `serdes.SerdesAbstractSystemObject`

```matlab
% WRONG — won't integrate with SerDes framework
classdef CustomEQ < matlab.System

% CORRECT — inherits SerDes interface
classdef CustomEQ < serdes.SerdesAbstractSystemObject
```

### 2. Not Handling Both WaveType Values

```matlab
% WRONG — only handles samples, Init path gives wrong results
function y = stepImpl(obj, x)
    y = filter(obj.TapWeights, 1, x, obj.Buffer);
end

% CORRECT — dispatch on WaveType
function y = stepImpl(obj, x)
    switch obj.WaveType
        case "Impulse"
            y = conv(x, upsample(obj.TapWeights(:), obj.pSamplesPerSymbol));
            y = y(1:numel(x));
        case "Sample"
            y = filter(obj.TapWeights, 1, x, obj.Buffer);
    end
end
```

### 3. Confusing IsLinear with IsTimeInvariant for Adaptive Blocks

```matlab
% WRONG — adaptive linear equalizer marked as time-invariant
obj.IsLinear = true;
obj.IsTimeInvariant = true;   % NO — adaptation means time-varying

% CORRECT — adaptive LINEAR blocks (DFE, adaptive FIR):
obj.IsLinear = true;           % YES — it's a linear filter (Init uses optimal taps)
obj.IsTimeInvariant = false;   % NO — taps change during GetWave

% For truly NONLINEAR blocks (limiter, decision feedback with slicing):
obj.IsLinear = false;           % Disables statistical (Init) analysis
obj.IsTimeInvariant = false;
```

Note: `serdes.DFECDR` uses `IsLinear=true, IsTimeInvariant=false`. The Init
path computes optimal DFE taps and applies them as a linear operation.
Adaptation (time-varying behavior) only matters during GetWave.

### 4. Forgetting to Set WaveType in Standalone MATLAB

```matlab
% WRONG — WaveType defaults to "Sample", impulse processing is incorrect
eq = CustomEQ;
eq.SymbolTime = 100e-12;
eq.SampleInterval = 6.25e-12;
y = eq(impulseResponse);  % Processes as samples, not impulse

% CORRECT — set WaveType before calling
eq.WaveType = "Impulse";
y = eq(impulseResponse);  % Correct impulse-domain processing
```

### 5. Impulse Convolution Boundary Effects

Custom blocks using `conv(x, h)` truncated to `y(1:numel(x))` may produce
small boundary differences compared to built-in blocks like `serdes.FFE`.
The built-in blocks use optimized internal convolution that handles edge
samples differently. For most practical purposes the difference is negligible
(< 1e-15 in the main lobe), but it can appear in the trailing edge of the
impulse response. This is expected — not a bug in your block.

### 6. strjoin Fails on getAMIInputNames / getAMIOutputNames

`getAMIInputNames` and `getAMIOutputNames` return cell arrays of **strings**
(not char vectors). `strjoin` rejects this — wrap with `string()` first:

```matlab
% WRONG — strjoin errors on cell of strings
inNames = eq.getAMIInputNames();
fprintf("%s\n", strjoin(inNames, ", "));  % ERROR: InvalidCellType

% CORRECT — convert to string array
fprintf("%s\n", strjoin(string(inNames), ", "));
```

### 7. GetWave Produces NaN/Inf from Uninitialized Persistent Variables

Custom blocks using `persistent` variables in `stepImpl` for GetWave (Sample
mode) must initialize them in `setupImpl` or `resetImpl`. Uninitialized
persistent variables default to `[]`, and arithmetic on `[]` propagates NaN/Inf
through the entire waveform. The DLL compiles and loads successfully — the
failure only appears at runtime as corrupted output.

```matlab
% WRONG — persistent not initialized, first GetWave call produces NaN
function y = stepImpl(obj, x)
    persistent prevSample
    y = x - prevSample;      % prevSample is [] on first call → NaN
    prevSample = x;
end

% CORRECT — initialize in resetImpl
function resetImpl(obj)
    obj.PrevSample = 0;      % use DiscreteState property instead
end
```

## File Placement

Place your custom System object `.m` file on the MATLAB path. For Simulink
integration, the file must be accessible when the model is opened and built.
Recommended location: alongside the Simulink model, or in a project `src/` folder
added to the path via `startup.m`.
----

Copyright 2026 The MathWorks, Inc.
----
