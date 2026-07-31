# fitcnet / fitrnet Compression: Fixed-Point Designer

For classical ML models (`fitcnet`, `fitrnet`), compression uses Fixed-Point Designer
to convert the predict function to fixed-point arithmetic. The approach uses
`generateLearnerDataTypeFcn` to produce a data-type function, then `codegen` with
`-float2fixed` to generate fixed-point C code.

## Entry-Point Function

The entry-point must load the model internally using `loadLearnerForCoder` — do NOT
pass the model as a function input.

```matlab
function y = predictClassifier(x)
%#codegen
    persistent mdl;
    if isempty(mdl)
        mdl = loadLearnerForCoder('trainedClassifier.mat');
    end
    [~, y] = predict(mdl, x);
end
```

Before saving the model for codegen, use `saveLearnerForCoder`:

```matlab
saveLearnerForCoder(trainedMdl, 'trainedClassifier.mat');
```

## Fixed-Point Conversion Workflow

```matlab
% Step 1: Generate the data-type function using representative data
% XRepresentative should cover the expected input range for calibration.
generateLearnerDataTypeFcn('predictClassifier', XRepresentative);
% This creates: predictClassifier_datatype_fcn.m

% Step 2: Configure code generation with fixed-point conversion
cfg = coder.config('lib');
cfg.TargetLang = 'C';
cfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-M';

% Step 3: Define input type
inputType = coder.typeof(single(0), [1 numFeatures]);

% Step 4: Generate fixed-point C code
codegen -float2fixed predictClassifier_datatype_fcn predictClassifier -args {inputType} -config cfg
```

## Fixed-Point Considerations for Lean Hardware

| Target Hardware         | Typical Word Length | Notes                           |
|-------------------------|--------------------|---------------------------------|
| Cortex-M0/M0+           | 8 or 16 bit        | Very constrained, aggressive quantization |
| Cortex-M4/M4F           | 16 or 32 bit       | Has FPU, but fixed-point still faster |
| Cortex-M7               | 16 or 32 bit       | Double-precision FPU available   |
| DSP (e.g., C2000)       | 16 or 32 bit       | Native fixed-point support      |
| Custom ASIC / NPU       | 8 bit              | Often int8-only inference       |


Copyright 2026 The MathWorks, Inc.
