---
name: matlab-write-tests
description: >
  Generate and structure MATLAB unit tests using matlab.unittest and matlab.uitest
  features, including class-based tests, parameterized testing, fixtures, mocking, and app
  testing with gestures. Use when writing, generating, or adding tests, creating test classes, adding
  test methods, parameterizing tests, setting up fixtures, mocking dependencies, or testing
  App Designer apps. Do NOT use for running tests, collecting coverage, or CI/CD
  configuration.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Write Tests

Generate, structure, and organize MATLAB unit tests using the `matlab.unittest` and `matlab.uitest` frameworks.

## When to Use

- User asks to write tests for a MATLAB function or class
- User wants to add test methods or parameterize existing tests
- User needs fixtures, mocking, or dependency injection in tests
- Test-driven development — writing tests before implementation
- Testing App Designer apps with programmatic gestures
- Baseline/regression tests against stored reference data (golden file, snapshot, characterization tests)

## When NOT to Use

- Running tests, analyzing failures, or filtering test suites — use `matlab-run-tests`
- Collecting or analyzing code coverage — use `matlab-run-tests`
- CI/CD pipeline configuration — use `matlab-run-tests`
- Testing Simulink models — use Simulink test skills

## Must-Follow Rules

- **Present a test plan first** — For non-trivial test suites, propose test methods and edge cases for user approval before writing code
- **Always use class-based tests** — Inherit from the appropriate TestCase superclass. Never use script-based tests
- **No logic in test methods** — No `if`, `switch`, `for`, or `try/catch`. Follow **Arrange-Act-Assert**. If a test needs conditionals, split into separate methods
- **Test public interfaces, not implementation** — Never test private methods directly
- **Execute via MCP** — Use `run_matlab_test_file` or `evaluate_matlab_code` to run tests after writing. For advanced test execution (coverage, filtering, CI), see the `matlab-run-tests` skill

## Workflow

### Simple tests (clear behavior, limited scope)
1. Briefly state what you'll test (methods + key edge cases)
2. Write the test file after user confirms
3. Run via `run_matlab_test_file` MCP tool to confirm tests pass

### Standard tests (large codebase, multiple files)
1. **Gather requirements** — Code to test, expected behaviors, error conditions, scope, dependencies
2. **Present test plan** — List test methods, edge cases, parameterization strategy for approval
3. **Implement** — Write tests following the patterns below
4. **Verify** — Run via `run_matlab_test_file` MCP tool to confirm tests pass

## Key Functions

| Category | Functions | Purpose |
|----------|-----------|---------|
| Equality | `verifyEqual`, `verifyNotEqual` | Compare values (use `AbsTol` for floats) |
| Boolean | `verifyTrue`, `verifyFalse` | Check logical conditions |
| Size/type | `verifySize`, `verifyClass`, `verifyEmpty` | Structural checks |
| Errors | `verifyError` | Confirm error is thrown with correct ID |
| Warnings | `verifyWarning`, `verifyWarningFree` | Check warning behavior |

### Qualification Levels

| Level | On failure | When to use |
|-------|-----------|-------------|
| `verify` | Continues test | Default — most assertions |
| `assert` | Stops current test | Setup validation |
| `fatalAssert` | Stops entire suite | Environment preconditions |
| `assume` | Skips test | Conditional execution (e.g., toolbox check) |

## Patterns

### Basic Test Class

```matlab
classdef computeAreaTest < matlab.unittest.TestCase

    methods (Test)
        function testSquare(testCase)
            result = computeArea(5, 5);
            testCase.verifyEqual(result, 25);
        end

        function testFloatingPoint(testCase)
            result = computeArea(1/3, 3);
            testCase.verifyEqual(result, 1, AbsTol=1e-12);
        end

        function testNegativeInputErrors(testCase)
            testCase.verifyError( ...
                @() computeArea(-1, 5), 'computeArea:negativeInput');
        end
    end
end
```

### Parameterized Tests

Parameterize only when assertion logic is identical across all cases — only the data varies. Use struct for readable test names:

```matlab
classdef unitConverterTest < matlab.unittest.TestCase

    properties (TestParameter)
        conversionCase = struct( ...
            'freezing', struct('input', 0, 'expected', 32), ...
            'boiling',  struct('input', 100, 'expected', 212), ...
            'bodyTemp', struct('input', 37, 'expected', 98.6));
    end

    methods (Test)
        function testCelsiusToFahrenheit(testCase, conversionCase)
            result = celsiusToFahrenheit(conversionCase.input);
            testCase.verifyEqual(result, conversionCase.expected, AbsTol=1e-10);
        end
    end
end
```

Error testing — identical `verifyError` logic, only inputs and error IDs vary:

```matlab
properties (TestParameter)
    InvalidInput = struct( ...
        'zeroDivisor', struct('input', {{5, 0}}, 'errorId', 'fn:zeroDivisor'), ...
        'stringArg',   struct('input', {{'hello', 1}}, 'errorId', 'fn:nonNumeric'), ...
        'cellArg',     struct('input', {{{1}, 2}}, 'errorId', 'fn:nonNumeric'))
end

methods (Test)
    function testInvalidInputThrows(testCase, InvalidInput)
        testCase.verifyError(@() fn(InvalidInput.input{:}), InvalidInput.errorId);
    end
end
```

For advanced parameterization (combinations, dynamic parameters, `ClassSetupParameter`), see [references/parameterized-tests-guidance.md](references/parameterized-tests-guidance.md).

### Setup, Teardown, and Fixtures

Prefer `addTeardown` over `TestMethodTeardown` blocks. Use `PathFixture` to add source folders:

```matlab
classdef fileProcessorTest < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder, ...
                IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testProcessFile(testCase)
            tmpDir = string(tempname);
            mkdir(tmpDir);
            testCase.addTeardown(@() rmdir(tmpDir, 's'));

            testFile = fullfile(tmpDir, "data.csv");
            writematrix(rand(10, 3), testFile);

            result = processFile(testFile);
            testCase.verifySize(result, [10 3]);
        end
    end
end
```

For built-in fixtures, custom fixtures, and shared fixtures, see [references/fixtures-guidance.md](references/fixtures-guidance.md).

### Determinism

Seed the RNG and restore it in teardown for reproducible tests:

```matlab
methods (TestMethodSetup)
    function resetRandomSeed(testCase)
        originalRng = rng;
        testCase.addTeardown(@() rng(originalRng));
        rng(42, "twister");
    end
end
```

### Test Tags

Use `TestTags` for selective execution:

```matlab
methods (Test, TestTags = {'Unit'})
    function testFastCalculation(testCase)
        % ...
    end
end

methods (Test, TestTags = {'Integration', 'Slow'})
    function testFullPipeline(testCase)
        % ...
    end
end
```

## App Designer Testing

For testing apps with programmatic UI gestures (`press`, `choose`, `type`, `drag`), see [references/app-testing-guidance.md](references/app-testing-guidance.md).

Key points:
- Inherit from `matlab.uitest.TestCase` (not `matlab.unittest.TestCase`)
- Call `drawnow` after app creation, before first gesture
- Compare `uilabel.Text` with char (`'text'`), not string (`"text"`)
- Compare `.Enable` with `matlab.lang.OnOffSwitchState.on`/`.off`

## Baseline Tests

For baseline, regression, gold-file, snapshot, or characterization tests, use `matlabtest.parameters.matfileBaseline` + `verifyEqualsBaseline` (requires MATLAB Test, R2024b+) instead of hardcoding expected values or manually loading reference data.

### Workflow

1. **Define parameterization** — One `TestParameter` property per baseline value, using `matlabtest.parameters.matfileBaseline` with `VariableName`. Consolidate related baselines into a single MAT file.
2. **Write test methods** — Each method accepts the baseline parameter and calls `verifyEqualsBaseline`. Pass `AbsTol` or `RelTol` for floating-point tolerance.
3. **Generate baseline data** — Run the function under test, save results to the baseline MAT file.
4. **Run tests** — Execute the test file to confirm actual values match baselines.

```matlab
properties (TestParameter)
    result = matlabtest.parameters.matfileBaseline( ...
        "baselines/output.mat", VariableName="result")
end

methods (Test)
    function testOutput(testCase, result)
        actual = myFunction(inputData);
        testCase.verifyEqualsBaseline(actual, result);
    end
end
```

**Never use `verifyEqual` with hardcoded or manually-computed expected values for baseline/regression/gold-file tests.** Always use `matfileBaseline` + `verifyEqualsBaseline` — even when tolerance is needed (pass `AbsTol`/`RelTol` to `verifyEqualsBaseline`).

Store baselines in `baselines/` relative to the test file. For detailed patterns, multiple-variable consolidation, and baseline generation, see [references/baseline-tests-guidance.md](references/baseline-tests-guidance.md).

## References

Load these on demand — most tests only need what's in this file.

| Load when... | Reference |
|---|---|
| Tests need setup/teardown, temp dirs, path management, shared state | [references/fixtures-guidance.md](references/fixtures-guidance.md) |
| Floating-point tolerance selection, constraint objects, custom constraints | [references/constraints-guidance.md](references/constraints-guidance.md) |
| Multiple parameters, dynamic parameters, combination strategies | [references/parameterized-tests-guidance.md](references/parameterized-tests-guidance.md) |
| Code depends on external services, needs mock objects or dependency injection | [references/mocking-guidance.md](references/mocking-guidance.md) |
| Testing App Designer apps with gestures, dialogs, async callbacks | [references/app-testing-guidance.md](references/app-testing-guidance.md) |
| Baseline/regression tests against stored reference data, golden file tests | [references/baseline-tests-guidance.md](references/baseline-tests-guidance.md) |

## Conventions

- Always use class-based tests inheriting from `matlab.unittest.TestCase`
- Name test files `<functionName>Test.m` and place in `tests/` directory
- Use `verify` qualifications by default — they let all tests run even if one fails
- Use `AbsTol` for every floating-point comparison — never rely on exact equality
- No logic in test methods — follow Arrange-Act-Assert
- Use `addTeardown` for cleanup — it runs even if the test fails
- Use struct-based `TestParameter` for readable parameterized test names
- Prefer: parameterized error testing over repeated methods when multiple inputs trigger the same verifyError pattern
- Keep test methods focused — test one behavior per method
- Tests must be independent and compatible with parallel execution
- Run tests via the `run_matlab_test_file` MCP tool for automatic result capture

----

Copyright 2026 The MathWorks, Inc.

----
