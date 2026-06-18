# MATLAB Coder Configuration for PyTorch Support Package

## Minimal Working Configuration

The absolute minimum to generate C from a PyTorch model via the support package:

```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C';
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');

inputType = coder.typeof(single(zeros(inputShape)), inputShape, false(size(inputShape)));
codegen -config cfg predict_fn -args {inputType} -report
```

## Full Production Configuration

Expert-reviewed settings validated across 8+ models with measured 3x+ speedup.

```matlab
%% 1. Embedded Coder config (not plain coder.config('lib'))
cfg = coder.config('lib', 'ecoder', true);
cfg.TargetLang = 'C';
cfg.GenerateReport = true;
cfg.GenCodeOnly = true;   % true unless cross-compiler is installed

%% 2. Deep learning config -- 'none' for portable C without runtime deps
%%    CRITICAL: Without this, codegen may try to use CUDNN/TensorRT/oneDNN
dlcfg = coder.DeepLearningConfig('none');
cfg.DeepLearningConfig = dlcfg;

%% 3. Hardware target (choose one based on your deployment)
%    See "Target-Specific Configurations" section below

%% 4. SIMD -- generates vectorized code for ARM
%%    CRITICAL: Property of cfg, NOT dlcfg! Common source of confusion.
cfg.InstructionSetExtensions = 'Neon v7';   % For ARM Cortex-A

%% 5. OpenMP -- multi-core acceleration
cfg.EnableOpenMP = true;    % For multi-core (Cortex-A) -- measured 3x speedup
% cfg.EnableOpenMP = false; % For single-core (Cortex-M)

%% 6. Weight storage -- separate binary files
cfg.LargeConstantThreshold = 0;  % Weights in .bin files, not inline in .c
% Result: 8K lines of logic vs 63K lines with embedded constants

%% 7. Memory and optimization settings
cfg.SupportNonFinite = false;           % Save code size (no NaN/Inf checks)
cfg.PreserveVariableNames = 'None';     % Smaller generated code
cfg.InlineBetweenUserFunctions = 'Always';
cfg.InlineBetweenMathWorksFunctions = 'Always';
cfg.EnableMemcpy = true;
cfg.MemcpyThreshold = 64;
cfg.BuildConfiguration = 'Faster Runs';
cfg.PurelyIntegerCode = false;          % Need float for DNN

%% 8. Stack constraints for MCU
cfg.StackUsageMax = 4096;  % 4 KB stack typical for Cortex-M
```

## DeepLearningConfig Target Libraries

| Value | Use Case | Dependencies |
|-------|----------|-------------|
| `'none'` | **Portable C, bare-metal MCU, any CPU** | None -- fully self-contained |
| `'mkldnn'` | Intel CPUs with AVX2 | Intel oneDNN library |
| `'arm-compute'` | ARM Cortex-A with NEON | ARM Compute Library |
| `'cudnn'` | NVIDIA GPU (GPU Coder) | cuDNN |
| `'tensorrt'` | NVIDIA GPU optimized (GPU Coder) | TensorRT |

**For embedded deployment:** Always use `'none'` combined with `InstructionSetExtensions` for SIMD.

## Target-Specific Configurations

### Bare-Metal MCU (STM32, Cortex-M)

```matlab
cfg = coder.config('lib', 'ecoder', true);
cfg.TargetLang = 'C';
cfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-M';
cfg.HardwareImplementation.ProdBitPerFloat = 32;
cfg.HardwareImplementation.ProdBitPerDouble = 64;
cfg.EnableOpenMP = false;       % Single-core -- OpenMP adds overhead
cfg.StackUsageMax = 4096;       % 4 KB stack typical for MCU
cfg.SupportNonFinite = false;
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
```

### Linux SBC (Raspberry Pi, Cortex-A)

```matlab
cfg = coder.config('lib', 'ecoder', true);
cfg.TargetLang = 'C';
try
    cfg.Hardware = coder.hardware('Raspberry Pi');
catch
    fprintf('Raspberry Pi support package not installed -- using generic ARM.\n');
    cfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-A';
end
cfg.InstructionSetExtensions = 'Neon v7';  % 128-bit SIMD, 4x float32
cfg.EnableOpenMP = true;                    % Quad-core -- measured 3x speedup
cfg.LargeConstantThreshold = 0;            % Weights in .bin files
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
```

### Desktop Validation (x86-64)

```matlab
cfg = coder.config('lib');
cfg.TargetLang = 'C';
cfg.EnableOpenMP = true;
cfg.DeepLearningConfig = coder.DeepLearningConfig('mkldnn');  % Intel optimized
```

## InstructionSetExtensions by Target

| Target | Value | Notes |
|--------|-------|-------|
| ARM Cortex-A (RPi) | `'Neon v7'` | 128-bit SIMD, 4x float32 |
| Intel x86-64 | `'SSE'`, `'SSE4.1'`, `'AVX'`, `'AVX2'`, `'FMA'`, `'AVX512F'` | Match target CPU |
| ARM Cortex-M | Use `CodeReplacementLibrary = 'ARM Cortex-M'` instead | Different mechanism |

## MEX Configuration (Host Validation Before Deploying)

Generate a MEX function first to validate on the host machine before cross-compiling:

```matlab
mexCfg = coder.config('mex');
mexCfg.TargetLang = 'C';
mexCfg.GenerateReport = true;
mexCfg.SIMDAcceleration = 'full';   % Best MEX performance
mexCfg.DeepLearningConfig = coder.DeepLearningConfig('none');

codegen -config mexCfg predict_fn -args {inputType}
% Then call: predict_fn_mex(testInput) to validate
```

## Common Configuration Mistakes

### Mistake 1: InstructionSetExtensions on wrong object
```matlab
% WRONG -- dlcfg does not have this property
dlcfg.InstructionSetExtensions = 'Neon v7';   % ERROR: Unrecognized property

% CORRECT -- property of cfg (EmbeddedCodeConfig)
cfg.InstructionSetExtensions = 'Neon v7';
```

### Mistake 2: Invalid hardware names
```matlab
% WRONG -- not valid Embedded Coder hardware names
cfg.Hardware = coder.hardware('ARM Cortex-A embedded platform');
cfg.Hardware = coder.hardware('ARM Cortex-A');
cfg.Hardware = coder.hardware('STM32F746G-Discovery');  % only if support pkg installed

% CORRECT -- valid names (require support packages)
cfg.Hardware = coder.hardware('Raspberry Pi');
cfg.Hardware = coder.hardware('BeagleBone Black');
cfg.Hardware = coder.hardware('NVIDIA Jetson');
```

### Mistake 3: Forgetting DeepLearningConfig
```matlab
% WRONG -- default may try to use unavailable libraries
cfg = coder.config('lib');
codegen ...  % Fails with missing library errors

% CORRECT
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
```

### Mistake 4: Not separating weights from code
```matlab
% DEFAULT -- weights embedded inline in .c
% Result: 63,000 lines of float constants, slow compile

% CORRECT
cfg.LargeConstantThreshold = 0;
% Result: 8,000 lines of logic + separate .bin files
```

### Mistake 5: OpenMP on single-core MCU
```matlab
% WRONG for Cortex-M (single-core) -- adds unnecessary overhead
cfg.EnableOpenMP = true;

% CORRECT for Cortex-M
cfg.EnableOpenMP = false;
```

## Codegen Command Variants

```matlab
% Generate static library (most common for embedded)
codegen -config cfg predict_fn -args {inputType} -report

% Generate MEX for host testing
codegen -config mexCfg predict_fn -args {inputType}

% Generate code only (no compile -- for cross-compilation)
cfg.GenCodeOnly = true;
codegen -config cfg predict_fn -args {inputType} -report

% Specify output directory
codegen -config cfg predict_fn -args {inputType} -d codegen_output -report
```


Copyright 2026 The MathWorks, Inc.
