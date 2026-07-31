# Verification and Testing Best Practices

## Test Count Proposal

Before running verification, **propose to the user** how many tests to run and why:

- **Minimum:** 50 tests for simple models (single-output regression, binary classification)
- **Recommended:** 100 tests for standard models (multi-class, moderate complexity)
- **Thorough:** 200+ tests for complex models (transformers, multi-output, wide output range)

**Factors to consider when proposing:**
- Number of output classes (cover all classes for classification)
- Output range width (cover full range for regression)
- Model complexity (more parameters → more potential for numerical issues)
- Input dimensionality (higher dims → more edge cases)

Present: "I propose running N verification tests because [rationale]. Does this
work for you, or would you prefer a different number?"

Wait for user agreement or correction before proceeding.

## Three Verification Stages

Every generated C binary must be validated through three stages:

```
PyTorch Reference --> MATLAB (via loadPyTorchExportedProgram) --> Generated C
       (1)                        (2)                            (3)
```

## Stage 1: PyTorch vs MATLAB

Verify `loadPyTorchExportedProgram` produces the same outputs as PyTorch.

```matlab
load('test_vectors.mat', 'test_inputs', 'test_outputs_ref');

net = loadPyTorchExportedProgram('model.pt2');

errors = zeros(size(test_inputs, 1), 1);
for i = 1:size(test_inputs, 1)
    x = single(squeeze(test_inputs(i,:,:)));
    y = invoke(net, x);
    ydata = single(y);
    errors(i) = max(abs(ydata(:) - test_outputs_ref(i,:)'));
end

fprintf('Max error: %.2e, Mean error: %.2e\n', max(errors), mean(errors));
assert(max(errors) < 1e-5, 'PyTorch vs MATLAB mismatch');
```

## Stage 2: MATLAB vs MEX

Generate a MEX function and verify it matches MATLAB execution.

```matlab
% Generate MEX
mexCfg = coder.config('mex');
mexCfg.DeepLearningConfig = coder.DeepLearningConfig('none');
mexCfg.SIMDAcceleration = 'full';
codegen -config mexCfg predict_fn -args {inputType}

% Compare on all test vectors
for i = 1:size(test_inputs, 1)
    x = single(squeeze(test_inputs(i,:,:)));
    y_matlab = predict_fn(x);
    y_mex = predict_fn_mex(x);
    err = max(abs(y_matlab(:) - y_mex(:)));
    assert(err < 1e-6, sprintf('MEX mismatch on input %d: %.2e', i, err));
end
fprintf('All %d MEX tests passed.\n', size(test_inputs, 1));
```

## Stage 3: C Executable Verification

Build a standalone C test harness and compare against PyTorch reference.

```c
#include "predict_fn.h"
#include <stdio.h>
#include <math.h>

#include "test_vectors.h"  // Generated from Python (see pytorch-export.md)

int main() {
    predict_fn_initialize();

    float max_err = 0.0f;
    int pass = 0, fail = 0;

    for (int i = 0; i < NUM_TESTS; i++) {
        float output[OUTPUT_SIZE];
        predict_fn(test_inputs[i], output);

        float err = 0.0f;
        for (int j = 0; j < OUTPUT_SIZE; j++) {
            float diff = fabsf(output[j] - test_outputs_ref[i][j]);
            if (diff > err) err = diff;
        }

        if (err > max_err) max_err = err;

        if (err < 1e-4f) {
            pass++;
        } else {
            fail++;
            printf("FAIL test %d: max error %.6e\n", i, err);
        }
    }

    predict_fn_terminate();
    printf("Results: %d/%d passed, max error: %.6e\n", pass, NUM_TESTS, max_err);
    return (fail == 0) ? 0 : 1;
}
```

Compile with (choose for your platform):
```bash
# Linux / macOS / Windows (gcc, clang, or MinGW)
gcc -O3 -std=c99 -ffast-math \
    -I/path/to/codegen \
    -I"$MATLAB_ROOT/extern/include" \
    test_harness.c predict_fn.c predict_fn_initialize.c predict_fn_terminate.c \
    -lm -o test_harness

# Windows (MSVC — from Developer Command Prompt)
cl /O2 /std:c11 /fp:fast ^
    /I"C:\path\to\codegen" ^
    /I"%MATLAB_ROOT%\extern\include" ^
    test_harness.c predict_fn.c predict_fn_initialize.c predict_fn_terminate.c ^
    /Fe:test_harness.exe

# Cross-compile for ARM Cortex-M (any OS with arm-none-eabi-gcc)
arm-none-eabi-gcc -O2 -std=c99 -mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 \
    -I/path/to/codegen \
    test_harness.c predict_fn.c predict_fn_initialize.c predict_fn_terminate.c \
    -lm -o test_harness.elf
```

**Important -- column-major input layout:** The generated C function expects column-major
input arrays. If your test vectors are in row-major order (standard for Python/C), you must
transpose them in the harness. See [`architecture-patterns.md`](architecture-patterns.md)
for the transpose pattern.

## Test Input Diversity

**Do not rely only on random inputs.** Random inputs tend to produce the same dominant-class
prediction, which hides numerical bugs that only surface in boundary cases.

### For Classification Models

Generate inputs that cover ALL output classes:
```python
boundary_inputs = []
for target_class in range(num_classes):
    found = 0
    for _ in range(10000):
        x = torch.randn(1, *input_shape)
        with torch.no_grad():
            pred = model(x).argmax(-1).item()
        if pred == target_class:
            boundary_inputs.append(x.numpy())
            found += 1
            if found >= 20:
                break
```

### For Regression Models

Generate inputs that span the full output range:
```python
outputs = []
for _ in range(1000):
    x = torch.randn(1, *input_shape) * scale
    with torch.no_grad():
        y = model(x)
    outputs.append((x.numpy(), y.item()))

# Sort by output value and sample uniformly
outputs.sort(key=lambda t: t[1])
selected = outputs[::10]  # Every 10th to cover the range
```

## Accuracy Budget

Define before starting:

| Application | Acceptable Max Error | Metric |
|-------------|---------------------|--------|
| Classification (argmax) | 0 mismatches | Exact class match |
| Regression (tight) | < 1e-3 | MAE in physical units |
| Regression (loose) | < 1e-2 | MAE in physical units |

## SIL/PIL Testing (Primary On-Target Verification)

Software-in-the-Loop (SIL) and Processor-in-the-Loop (PIL) testing provide
automated verification of generated code without writing a custom C harness.

- **SIL mode:** Compiles and runs generated code on the host machine, comparing
  outputs against MATLAB execution automatically.
- **PIL mode:** Cross-compiles and runs on the actual target hardware (requires
  a connected board and Embedded Coder Support Package for the target).

```matlab
% SIL verification: compile generated code and run on host
silCfg = coder.config('lib', 'ecoder', true);
silCfg.VerificationMode = 'SIL';
silCfg.DeepLearningConfig = coder.DeepLearningConfig('none');
codegen -config silCfg predict_fn -args {inputType}

% Run test vectors through SIL — automatically compares against MATLAB
for i = 1:numTests
    x = single(squeeze(test_inputs(i,:,:)));
    y_sil = predict_fn_sil(x);
end
fprintf('All %d SIL tests passed.\n', numTests);
```

For PIL (on-target):
```matlab
% PIL verification: compile, download, and run on target hardware
pilCfg = coder.config('lib', 'ecoder', true);
pilCfg.VerificationMode = 'PIL';
pilCfg.Hardware = coder.hardware('STM32F7xx Based');  % Use concrete board name
pilCfg.Hardware.PILInterface = "Serial";              % Transport to target
pilCfg.Hardware.PILCOMPort = "COM4";                  % Adjust to actual port
pilCfg.DeepLearningConfig = coder.DeepLearningConfig('none');
codegen -config pilCfg predict_fn -args {inputType}

% Run test vectors through PIL — executes on the connected board
for i = 1:numTests
    x = single(squeeze(test_inputs(i,:,:)));
    y_pil = predict_fn_pil(x);
end
```

**PIL hardware name:** Must be a concrete board name recognized by the installed support
package (e.g., `'STM32F7xx Based'`, `'Raspberry Pi'`, `'NVIDIA Jetson'`). Generic family
strings like `'ARM Cortex-M'` are NOT valid `coder.hardware` names — they will error.
Ask the user which board they are targeting.

**SIL/PIL vs custom C harness:** SIL/PIL is the recommended primary approach because
it automates compilation, execution, and numerical comparison. Use the custom C
harness (below) as a secondary option when SIL/PIL is not available (e.g., no
Embedded Coder, or the target board is not supported by a PIL connectivity config).

## Benchmarking Protocol (Custom C Harness)

For reliable performance measurements, or when SIL/PIL is unavailable:

```c
// Cross-platform C benchmark pattern
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
static double get_time_us(void) {
    LARGE_INTEGER freq, count;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&count);
    return (double)count.QuadPart / (double)freq.QuadPart * 1e6;
}
#else
#include <time.h>
static double get_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}
#endif

#define WARMUP 50
#define ITERATIONS 1000

int main() {
    float output[OUTPUT_SIZE];
    predict_fn_initialize();

    // Warmup
    for (int i = 0; i < WARMUP; i++)
        predict_fn(test_input, output);

    // Measure
    double start = get_time_us();
    for (int i = 0; i < ITERATIONS; i++)
        predict_fn(test_input, output);
    double elapsed_us = get_time_us() - start;

    printf("Mean: %.1f us/inference\n", elapsed_us / ITERATIONS);

    predict_fn_terminate();
}
```

Key practices:
- **Warmup:** 50+ iterations to warm CPU caches
- **Measurement iterations:** 1000+ for statistical significance
- **Independent trials:** 7+ runs to measure cross-process variance
- **Report mean and standard deviation**

**Rule of thumb:** Larger models have slightly higher error due to accumulated floating-point
rounding, but should always stay below 1e-3.

## Code Generation Report

After all verification stages pass, **ask the user** if they want to open the code generation report:

```matlab
% Open the code generation report (after user confirms)
reportPath = fullfile('codegen', 'lib', 'predict_fn', 'html', 'report.mldatx');
if isfile(reportPath)
    open(reportPath);
else
    reportFiles = dir(fullfile('codegen', '**', 'report.mldatx'));
    if ~isempty(reportFiles)
        open(fullfile(reportFiles(1).folder, reportFiles(1).name));
    end
end
```

Ask: "Code generation is complete. Would you like me to open the code generation report
so you can review the generated code, warnings, and resource metrics?"

## Verification Summary Report

After completing all three stages, present a comprehensive summary:

```
Full Pipeline Numerical Equivalency Report
============================================
Tests run:                       N (as agreed)
Stage 1 (PyTorch vs MATLAB):    MAE=X.Xe-Y, Max=X.Xe-Y  [PASS/FAIL]
Stage 2 (MATLAB vs MEX):        MAE=X.Xe-Y, Max=X.Xe-Y  [PASS/FAIL]
Stage 3 (MEX vs C executable):  MAE=X.Xe-Y, Max=X.Xe-Y  [PASS/FAIL]
Overall pipeline status:         PASS / INVESTIGATE
```


Copyright 2026 The MathWorks, Inc.
