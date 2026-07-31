---
name: matlab-write-performance-tests
description: "Writes MATLAB performance tests using the matlab.perftest.TestCase framework. Use when asked to write, create, or add performance tests for MATLAB code, benchmark functions, measure execution time with statistical rigor, or use runperf."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Writing MATLAB Performance Tests

Write performance tests for MATLAB code using the `matlab.perftest.TestCase` framework. This framework provides statistically rigorous timing with automatic warmup, multiple samples, and outlier handling.

## When to Use

- User wants to write repeatable performance tests for their MATLAB code
- User needs to benchmark functions with statistical confidence
- User wants to detect performance regressions over time
- User is setting up continuous performance monitoring
- User asks how to use `runperf` or `matlab.perftest.TestCase`

## When NOT to Use

- User wants a quick one-off timing (use `timeit` instead — see `matlab-optimize-performance`)
- User wants to optimize existing code (use `matlab-optimize-performance`)
- User wants to measure memory usage (use `matlab-optimize-memory`)
- User wants to profile code to find bottlenecks (use `matlab-optimize-performance`, Step 2)

## Framework: `matlab.perftest.TestCase`

All performance tests subclass `matlab.perftest.TestCase` and use measurement boundaries to control what gets timed.

### Basic Template

```matlab
classdef MyFeaturePerformanceTest < matlab.perftest.TestCase

    properties (MethodSetupParameter)
        DataSize = struct('Small', 100, 'Medium', 1000, 'Large', 10000)
    end

    properties
        inputData
    end

    methods (TestMethodSetup)
        function setupData(testCase, DataSize)
            % ALL setup outside the measurement boundary
            testCase.inputData = randn(DataSize, 1);
        end
    end

    methods (Test)
        function testMyFunction(testCase)
            data = testCase.inputData;
            while testCase.keepMeasuring
                result = myFunction(data);
            end
            testCase.verifyNotEmpty(result);
        end
    end
end
```

### Running Performance Tests

```matlab
% Run with statistical rigor (automatic sample size)
results = runperf('MyFeaturePerformanceTest');

% View results
disp(results)

% Fixed sample count (faster, less statistical power)
import matlab.perftest.TimeExperiment;
suite = testsuite('MyFeaturePerformanceTest');
experiment = TimeExperiment.withFixedSampleSize(4);
results = run(experiment, suite);
```

## Measurement Boundaries

The framework offers three ways to control what gets measured:

### 1. `keepMeasuring` — Needed when code is fast (<10ms)

Automatically loops the code until enough samples are collected. Required for sub-10ms operations to achieve statistical rigor; works at any speed but adds overhead for slower code where `startMeasuring`/`stopMeasuring` is preferred:

```matlab
function testFastFunction(testCase)
    data = testCase.inputData;
    while testCase.keepMeasuring
        result = fastFunction(data);
    end
    testCase.verifyNotEmpty(result);
end
```

### 2. `startMeasuring`/`stopMeasuring` — For precise control

Use when you need setup between iterations or want to exclude specific code:

```matlab
function testWithBoundaries(testCase)
    data = testCase.inputData;
    % Pre-computation (NOT measured)
    preparedData = preprocess(data);

    testCase.startMeasuring();
    result = functionUnderTest(preparedData);
    testCase.stopMeasuring();

    % Verification (NOT measured)
    testCase.verifyEqual(size(result), [100 1]);
end
```

### 3. No boundary — Entire method is measured

The whole `Test` method body is timed. Use only when the entire method IS the workload:

```matlab
function testSlowFunction(testCase, DataSize) %#ok<INUSD>
    data = testCase.inputData;
    result = slowFunction(data);
    testCase.verifyNotEmpty(result);
end
```

## Parameterization

Parameterize tests to measure across different input sizes or configurations.

### `MethodSetupParameter` — When setup uses the parameter

```matlab
properties (MethodSetupParameter)
    DataSize = struct('Small', 100, 'Medium', 1000, 'Large', 10000)
end

methods (TestMethodSetup)
    function setupData(testCase, DataSize)
        testCase.inputData = randn(DataSize, 1);
    end
end
```

### `TestParameter` — When only test methods use the parameter

```matlab
properties (TestParameter)
    Algorithm = {'chol', 'lu', 'qr'}
end

methods (Test)
    function testSolve(testCase, Algorithm)
        ...
    end
end
```

**Critical gotcha:** Do NOT use `TestParameter` for properties consumed by `TestMethodSetup`. MATLAB will error with "Define 'X' as a MethodSetupParameter." If your setup method needs the parameter, it must be `MethodSetupParameter`.

### Combining Both — Size in setup, algorithm in test

```matlab
properties (MethodSetupParameter)
    DataSize = struct('Small', 100, 'Medium', 1000, 'Large', 10000)
end

properties (TestParameter)
    Algorithm = {'chol', 'lu', 'qr'}
end

methods (TestMethodSetup)
    function setupData(testCase, DataSize)
        testCase.inputData = randn(DataSize);
    end
end

methods (Test)
    function testSolve(testCase, Algorithm)
        A = testCase.inputData' * testCase.inputData; % SPD matrix
        data = A;
        while testCase.keepMeasuring
            result = decomposition(data, Algorithm);
        end
        testCase.verifyNotEmpty(result);
    end
end
```

This produces 9 test points (3 sizes × 3 algorithms).

## Lean Setup — Critical Rule

ALL setup must be outside the measurement boundary:

| Setup Task | Where to Put It |
|-----------|-----------------|
| Data generation | `TestMethodSetup` |
| Loading files | `TestClassSetup` |
| Creating objects | `TestMethodSetup` or `TestClassSetup` |
| Path manipulation | `TestClassSetup` |
| RNG seeding | `TestMethodSetup` |

**Never** include setup/teardown inside the measured region. This inflates timing and adds noise.

**Copy properties to local variables before measuring.** Don't access `testCase.PropertyName` inside the measurement boundary — it measures the `matlab.perftest.TestCase` indexing overhead. Assign to a local variable outside the boundary instead:

```matlab
% Correct: local variable assigned before measurement
data = testCase.inputData;
while testCase.keepMeasuring
    result = myFunction(data);
end
```

```matlab
methods (TestMethodSetup)
    function setupData(testCase, DataSize)
        rng(42, 'twister');  % Deterministic data
        testCase.inputData = randn(DataSize, 1);
    end
end
```

## Noise and Duration

### Target Duration
- Each test point should take **>10ms** to execute
- If too fast, increase data size or use `keepMeasuring`
- Sub-millisecond tests produce unreliable results

### Reducing Noise
- Use `keepMeasuring` for fast operations
- Pre-allocate all data in setup
- Suppress all output (`'Display', 'off'`)
- Avoid file I/O in the measured region
- Avoid `drawnow`, `pause`, or GUI operations
- Seed RNG in setup for deterministic data

### Interpreting Results

```matlab
results = runperf('MyPerformanceTest');

% Access timing statistics
for i = 1:numel(results)
    samples = results(i).Samples.MeasuredTime;
    fprintf('%s: median=%.4fs, std=%.4fs, CV=%.1f%%\n', ...
        results(i).Name, median(samples), std(samples), ...
        100*std(samples)/mean(samples));
end
```

A coefficient of variation (CV) above 10% indicates noisy results — revisit your test setup.

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|-------------|---------------|-----|
| Setup inside measurement | Inflates timing, adds noise | Move to `TestMethodSetup` |
| Sub-1ms test without `keepMeasuring` | Noise dominates | Use `keepMeasuring` or increase data size |
| `tic/toc` instead of framework | No statistical rigor, no warmup handling | Use `runperf`/`keepMeasuring` |
| `TestParameter` for setup params | Framework error at runtime | Use `MethodSetupParameter` |
| Single test covering multiple APIs | Can't isolate regressions | Split into focused tests |
| Random data without seeding RNG | Non-deterministic, harder to debug | `rng(42, 'twister')` in setup |
| Printing/plotting in measured code | Console/graphics I/O adds noise | Suppress all output |

## Comparing Results Over Time

Save and compare results to detect regressions:

```matlab
% Save baseline
baselineResults = runperf('MyPerformanceTest');
save('perfBaseline.mat', 'baselineResults');

% Later: compare against baseline
currentResults = runperf('MyPerformanceTest');
load('perfBaseline.mat');

for i = 1:numel(currentResults)
    baseMed = median(baselineResults(i).Samples.MeasuredTime);
    currMed = median(currentResults(i).Samples.MeasuredTime);
    ratio = currMed / baseMed;
    status = "OK";
    if ratio > 1.2
        status = "REGRESSION";
    elseif ratio < 0.8
        status = "IMPROVEMENT";
    end
    fprintf('%s: %.4fs -> %.4fs (%.2fx) %s\n', ...
        currentResults(i).Name, baseMed, currMed, ratio, status);
end
```

## Test Granularity

When asked to write performance tests, consider which level is appropriate:

| Level | Scope | Parameterized? | Duration Target |
|-------|-------|---------------|-----------------|
| **Unit** | Single operation (e.g., `svd`, `mldivide`) | Yes — sweep sizes | >10ms per testpoint |
| **System** | One function end-to-end | Yes — sweep sizes | >10ms per testpoint |
| **Workflow (ALB)** | Complete multi-step customer workflow | No — one representative size | 0.5–5s total |

**When to use each:**
- **Unit**: Function has multiple expensive operations and you need to isolate which one regressed
- **System**: Default choice — measures the function as users call it
- **Workflow**: Validates that unit optimizations translate to real-world speedups; catches cross-function bottlenecks

If unsure, generate system-level tests first, then ask whether unit-level decomposition or workflow-level benchmarks are needed.

### Workflow Benchmarks (Application-Level)

For end-to-end workflow benchmarks, the structure differs from unit/system tests:

- **No parameterization** — one representative problem size (that's what unit tests are for)
- **Realistic data** — production-scale inputs, not synthetic
- **Single test method** — the whole workflow is one testpoint
- **`startMeasuring`/`stopMeasuring`** — always (never `keepMeasuring`)
- **Setup in `TestClassSetup`** — load data once, not per method
- **Target 0.5–5s** — sub-0.5s is noise-dominated; >30s slows iteration

See `references/tExampleWorkflow.m` for the complete template.

## Quality Checklist

Verify after generating each test class:

- [ ] Setup is outside the measurement boundary (`TestMethodSetup`)
- [ ] Properties copied to local variables before measuring
- [ ] Each test point exceeds 10ms (or uses `keepMeasuring` if faster)
- [ ] RNG seeded for deterministic data
- [ ] No console output, plotting, or file I/O in measured region
- [ ] Parameterized by data size
- [ ] Single API/operation per test method (not bundling multiple)
- [ ] `MethodSetupParameter` used (not `TestParameter`) when setup consumes the parameter

## Reference Files

- `references/FeaturePerformanceTest.m` — Performance test class template with all measurement patterns
- `references/tExampleWorkflow.m` — Workflow-level benchmark template (application-level)
- `references/simulink-template.md` — Performance test template for Simulink model benchmarks

Copyright 2026 The MathWorks, Inc.
