# Verify Generated Code Against MATLAB

Confirm that generated C/C++ code (MEX or standalone) produces numerically equivalent results to the original MATLAB function using reusable test scripts.

## Verification Approaches

Choose based on available toolboxes:

| Approach | When to Use | Requires |
|----------|-------------|----------|
| `coder.runTest` | Standard path — always available with MATLAB Coder | MATLAB Coder |
| `matlabtest.coder.TestCase` | Preferred when available — cleaner API, built-in tolerances | MATLAB Test |

**Decision rule:** Check if MATLAB Test is available. If yes, use `matlabtest.coder.TestCase`. If not, use `coder.runTest`.

```matlab
hasMLTest = ~isempty(ver('matlabtest'));
```

## Workflow: coder.runTest

Use this approach when MATLAB Test is not available.

### Step 1: Write a Test Script with Assertions

The test script must call the original MATLAB function and include `assert` statements that verify correctness. `coder.runTest` replaces calls to the MATLAB function with calls to the MEX — if the assertions pass with both, the generated code is correct.

```matlab
%% test_myFunction.m
% Test script for verifying myFunction MEX equivalence

% Test case 1: nominal input
input1 = randn(100, 1);
result = myFunction(input1);
assert(numel(result) == 100, 'Output size mismatch');
assert(all(isfinite(result)), 'Non-finite values in output');

% Test case 2: edge case
input2 = zeros(100, 1);
result2 = myFunction(input2);
assert(max(abs(result2)) < 1e-10, 'Zero input should produce near-zero output');

% Test case 3: compare specific known result
input3 = ones(10, 1);
result3 = myFunction(input3);
expected = 3.14159;  % known analytical result
assert(abs(result3(1) - expected) < 1e-6, 'Failed known-answer test');
```

**Critical:** The test script MUST contain `assert` statements. `coder.runTest` produces no output on success — without assertions, a passing run tells you nothing about correctness.

### Step 2: Run the Test Script Normally

Run the test script in MATLAB first to confirm it passes against the interpreted function:

```matlab
run('test_myFunction.m')
```

If this errors, fix the test script before proceeding.

### Step 3: Generate MEX and Run with coder.runTest

**Option A: Generate and test in one command:**

```matlab
codegen myFunction -args {coder.typeof(zeros(100,1))} -test test_myFunction
```

This generates the MEX and immediately runs the test script with MEX replacement. Convenient for iterative development.

**Option B: Separate generation and testing:**

```matlab
codegen myFunction -args {coder.typeof(zeros(100,1))}
coder.runTest('test_myFunction', 'myFunction')
```

This re-runs `test_myFunction.m` but replaces every call to `myFunction` with `myFunction_mex`. The MEX must already exist.

**Calling conventions:**

```matlab
% Replace one function with its default _mex:
coder.runTest('testScript', 'myFunction')

% Replace one function with an explicit MEX name:
coder.runTest('testScript', 'myFunction', 'myFunction_optimized_mex')

% Replace multiple functions:
coder.runTest('testScript', {'func1', 'func2'}, 'multiFuncMex')
```

### Step 4: Interpret Results

- **No error:** All assertions passed with the MEX — generated code is equivalent.
- **Assertion error:** The MEX produces different results. Inspect which assertion failed to identify the divergence.
- **Runtime error:** The MEX hit an error — read the error message to diagnose (common causes: input size/type mismatch with codegen spec, out-of-bounds access, unsupported operation).

### SIL Verification (requires Embedded Coder)

For standalone code (lib/dll), use SIL to verify without manually writing a SIL harness:

```matlab
cfg = coder.config('lib');
cfg.VerificationMode = 'SIL';
codegen -config cfg myFunction -args {inputTypes}

% Now run the same test script — SIL MEX replaces the function:
coder.runTest('test_myFunction', 'myFunction', 'myFunction_sil')
```

SIL compiles and runs the actual standalone library code through a MEX wrapper, giving higher confidence than MEX alone that the deployed code is correct.

## Workflow: matlabtest.coder.TestCase

Use this approach when MATLAB Test is available. It provides a cleaner API with built-in tolerance support and automatic MATLAB-vs-MEX comparison.

### Step 1: Write a Test Class

```matlab
classdef tMyFunction < matlabtest.coder.TestCase

    properties (TestParameter)
        inputCase = struct( ...
            'nominal', struct('x', randn(100,1)), ...
            'zeros',   struct('x', zeros(100,1)), ...
            'ones',    struct('x', ones(100,1)))
    end

    methods (TestClassSetup)
        function buildMex(testCase)
            inputType = {coder.typeof(zeros(100,1))};
            testCase.BuildResults = build(testCase, 'myFunction', ...
                Inputs=inputType);
        end
    end

    properties
        BuildResults
    end

    methods (Test)
        function testEquivalence(testCase, inputCase)
            executionResults = execute(testCase, ...
                testCase.BuildResults, Inputs={inputCase.x});
            verifyExecutionMatchesMATLAB(testCase, executionResults);
        end

        function testWithTolerance(testCase)
            x = randn(100, 1) * 1e6;
            executionResults = execute(testCase, ...
                testCase.BuildResults, Inputs={x});
            verifyExecutionMatchesMATLAB(testCase, executionResults, ...
                AbsTol=1e-8, RelTol=1e-12);
        end
    end

end
```

### Step 2: Run the Tests

```matlab
results = runtests('tMyFunction');
disp(results)
```

### Key Design Points

1. **Build in `TestClassSetup` when all tests share the same input types.** If different tests need different input type specifications (e.g., fixed-size vs. variable-size), build separately per test or per parameter group.
2. **Use `execute` with `Inputs` name-value** — pass runtime inputs as a cell array.
3. **`verifyExecutionMatchesMATLAB` does the comparison** — it runs the original MATLAB function internally and compares outputs. You do not call the MATLAB function yourself.
4. **Tolerances** — use `AbsTol` and `RelTol` name-value arguments when floating-point differences are expected (e.g., different math libraries in generated code vs. MATLAB).

### Qualification Variants

| Method | Behavior on Failure |
|--------|-------------------|
| `verifyExecutionMatchesMATLAB` | Records failure, continues running other tests |
| `assertExecutionMatchesMATLAB` | Fails current test, continues other tests |
| `assumeExecutionMatchesMATLAB` | Marks test as filtered (incomplete), continues |
| `fatalAssertExecutionMatchesMATLAB` | Stops entire test suite |

Use `verify` for most cases. Use `assert` when later test steps depend on this check passing.

### SIL Configuration (requires Embedded Coder)

To verify standalone code instead of MEX:

```matlab
methods (TestClassSetup)
    function buildSil(testCase)
        inputType = {coder.typeof(zeros(100,1))};
        testCase.BuildResults = build(testCase, 'myFunction', ...
            Inputs=inputType, Configuration='lib');
    end
end
```

Pass `Configuration='lib'` or `Configuration='dll'` to `build`. This generates SIL-wrapped standalone code. The `execute` and `verifyExecutionMatchesMATLAB` calls remain identical.

## Key Functions

| Function | Purpose | Toolbox | Since |
|----------|---------|---------|-------|
| `codegen ... -test testFile` | Generate MEX and run test in one command | MATLAB Coder | R2012a |
| `coder.runTest` | Run test script replacing MATLAB calls with MEX | MATLAB Coder | R2012a |
| `matlabtest.coder.TestCase` | Base class for codegen equivalence tests | MATLAB Test | R2023a |
| `build` | Generate MEX/SIL from within a test class | MATLAB Test | R2023a |
| `execute` | Run generated code with specific inputs | MATLAB Test | R2023a |
| `verifyExecutionMatchesMATLAB` | Compare generated code output to MATLAB | MATLAB Test | R2023a |

## Conventions

- Always write reusable test scripts or classes — avoid one-off inline comparisons
- Test with representative inputs including edge cases (zeros, large values, boundary sizes)
- For floating-point differences: use tolerances (`AbsTol`/`RelTol`) rather than exact equality. Small differences (< 1e-10 relative) between MEX and MATLAB are normal due to different math libraries
- Generate MEX before running `coder.runTest`, or use `codegen -test` to combine both steps
- For `matlabtest.coder.TestCase`: build in `TestClassSetup` when all tests share input types; build per test when input type specs differ
- Use SIL (with Embedded Coder) when you need higher confidence that standalone lib/dll code matches MATLAB — SIL tests the actual deployed code path, not just MEX

## Floating-Point Differences

Generated code may produce small numerical differences compared to MATLAB due to:
- Different FFT implementations (portable radix-2 vs. FFTW/MKL)
- Different SIMD instruction ordering
- Compiler optimization reordering of floating-point operations

These are **expected** for MEX and SIL. For adaptive algorithms (filters, optimizers), small per-step differences can accumulate over many iterations. Use appropriate tolerances based on the algorithm's sensitivity, not a blanket epsilon.

## Related references

- `references/generate-code.md` — generating the MEX or standalone code to be verified
- `references/accelerate-mex.md` — profiling MEX after correctness is established

----

Copyright 2026 The MathWorks, Inc.

----
