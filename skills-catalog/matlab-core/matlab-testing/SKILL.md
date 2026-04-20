---
name: matlab-testing
description: Generate and run MATLAB unit tests using matlab.unittest and matlab.uitest. Parameterized tests, fixtures, mocking, coverage analysis, CI/CD with buildtool, app testing with gestures. Use when creating tests, writing test classes, running test suites, checking coverage, testing apps, or validating MATLAB code.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Testing

Generate, structure, and run MATLAB unit tests using the `matlab.unittest` framework. Covers class-based tests, parameterized testing, fixtures, mocking, coverage analysis, CI/CD integration, and app testing via MCP.

## When to Use

- User asks to write tests for a MATLAB function or class
- User wants to run an existing test suite
- User needs coverage analysis or CI/CD configuration
- Test-driven development — writing tests before implementation
- Testing App Designer apps with programmatic gestures (see [reference/app-testing-guidance.md](reference/app-testing-guidance.md))

## When NOT to Use

- Testing Simulink models — use Simulink test skills
- Performance benchmarking — use profiling workflows

## Must-Follow Rules

- **Present a test plan first** — For non-trivial test suites, propose test methods and edge cases for user approval before writing code
- **Always use class-based tests** — Every test file must inherit from `matlab.unittest.TestCase`. Never use script-based tests
- **No logic in test methods** — No `if`, `switch`, `for`, or `try/catch`. Follow **Arrange-Act-Assert**. If a test needs conditionals, split into separate methods
- **Test public interfaces, not implementation** — Never test private methods directly
- **Execute via MCP** — Use `run_matlab_test_file` or `evaluate_matlab_code` to run tests

## Workflow

### Simple tests (clear behavior, limited scope)
1. Briefly state what you'll test (methods + key edge cases)
2. Write the test file after user confirms

### Standard tests (large codebase, multiple files)
1. **Gather requirements** — Code to test, expected behaviors, error conditions, scope, dependencies
2. **Present test plan** — List test methods, edge cases, parameterization strategy for approval
3. **Implement** — Write tests following the patterns below
4. **Run** — Execute via `run_matlab_test_file` MCP tool
5. **Check coverage** — Identify untested paths, add tests

## Key Functions

| Category | Functions | Purpose |
|----------|-----------|---------|
| Equality | `verifyEqual`, `verifyNotEqual` | Compare values (use `AbsTol` for floats) |
| Boolean | `verifyTrue`, `verifyFalse` | Check logical conditions |
| Size/type | `verifySize`, `verifyClass`, `verifyEmpty` | Structural checks |
| Errors | `verifyError` | Confirm error is thrown with correct ID |
| Warnings | `verifyWarning`, `verifyWarningFree` | Check warning behavior |
| Infra | `runtests`, `TestSuite`, `TestRunner` | Run and organize tests |
| Coverage | `CodeCoveragePlugin`, `CoverageResult` | Measure test coverage |

### Qualification Levels

| Level | On failure | When to use |
|-------|-----------|-------------|
| `verify` | Continues test | Default — most assertions |
| `assert` | Stops current test | Setup validation |
| `fatal` | Stops entire suite | Environment preconditions |
| `assume` | Skips test | Conditional execution (e.g., toolbox check) |

## Patterns

### Basic Test Class

```matlab
classdef computeAreaTest < matlab.unittest.TestCase
    %computeAreaTest Tests for the computeArea function.

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

For advanced parameterization (combinations, dynamic parameters, `ClassSetupParameter`), see [reference/parameterized-tests-guidance.md](reference/parameterized-tests-guidance.md).

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

For built-in fixtures, custom fixtures, and shared fixtures, see [reference/fixtures-guidance.md](reference/fixtures-guidance.md).

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

Run by tag: `runtests('tests', Tag='Unit')` or `runtests('tests', ExcludeTag='Slow')`.

## Running Tests

### Via MCP

Use the `run_matlab_test_file` MCP tool for test files. For inline runs with filtering:

```matlab
results = runtests('tests');                            % all tests in folder
results = runtests('tests', Tag='Unit');                % by tag
results = runtests('tests', Name='*Calculator*');       % by name pattern
results = runtests('tests', UseParallel=true);          % parallel execution
results = runtests('tests', Strict=true);               % warnings = failures
```

### Analyzing Results

```matlab
disp(results);

for r = results([results.Failed])
    fprintf('\nFAILED: %s\n', r.Name);
    disp(r.Details.DiagnosticRecord.Report);
end
```

## Coverage Analysis

```matlab
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult
import matlab.unittest.plugins.codecoverage.CoverageReport

runner = TestRunner.withTextOutput;
covFormat = CoverageResult;
runner.addPlugin(CodeCoveragePlugin.forFolder('src', ...
    Producing=[covFormat, CoverageReport('coverage-report')]));
results = runner.run(testsuite('tests'));

covResults = covFormat.Result;
disp(covResults);
```

For coverage gap analysis, use the `printCoverageGaps` script in [reference/test-execution-guidance.md](reference/test-execution-guidance.md).

## CI/CD Integration

Use `buildtool` with a `buildfile.m` for CI pipelines. See [reference/test-execution-guidance.md](reference/test-execution-guidance.md) for `buildfile.m` templates and CI configs (GitHub Actions, Azure DevOps, GitLab CI).

## App Designer Testing

For testing apps with programmatic UI gestures (`press`, `choose`, `type`, `drag`), see [reference/app-testing-guidance.md](reference/app-testing-guidance.md).

Key points:
- Inherit from `matlab.uitest.TestCase` (not `matlab.unittest.TestCase`)
- Call `drawnow` after app creation, before first gesture
- Compare `uilabel.Text` with char (`'text'`), not string (`"text"`)
- Compare `.Enable` with `matlab.lang.OnOffSwitchState.on`/`.off`

## References

Load these on demand — most tests only need what's in this file.

| Load when... | Reference |
|---|---|
| Tests need setup/teardown, temp dirs, path management, shared state | [reference/fixtures-guidance.md](reference/fixtures-guidance.md) |
| Floating-point tolerance selection, constraint objects, custom constraints | [reference/constraints-guidance.md](reference/constraints-guidance.md) |
| Multiple parameters, dynamic parameters, combination strategies | [reference/parameterized-tests-guidance.md](reference/parameterized-tests-guidance.md) |
| Code depends on external services, needs mock objects or dependency injection | [reference/mocking-guidance.md](reference/mocking-guidance.md) |
| Running tests in CI, buildtool config, coverage gap analysis | [reference/test-execution-guidance.md](reference/test-execution-guidance.md) |
| Testing App Designer apps with gestures, dialogs, async callbacks | [reference/app-testing-guidance.md](reference/app-testing-guidance.md) |

## Conventions

- Always use class-based tests inheriting from `matlab.unittest.TestCase`
- Name test files `<functionName>Test.m` and place in `tests/` directory
- Use `verify` qualifications by default — they let all tests run even if one fails
- Use `AbsTol` for every floating-point comparison — never rely on exact equality
- No logic in test methods — follow Arrange-Act-Assert
- Use `addTeardown` for cleanup — it runs even if the test fails
- Use struct-based `TestParameter` for readable parameterized test names
- Keep test methods focused — test one behavior per method
- Tests must be independent and compatible with parallel execution
- Run tests via the `run_matlab_test_file` MCP tool for automatic result capture

----

Copyright 2026 The MathWorks, Inc.

----

