---
name: matlab-run-tests
description: >
  Run MATLAB test suites and analyze results, including test filtering, parallel execution,
  result diagnostics, code coverage collection, gap analysis, and CI/CD with buildtool. Use
  when running tests, filtering test suites, analyzing test failures, checking, collecting,
  or analyzing coverage, justifying uncovered code, or configuring CI pipelines. Do NOT use
  for writing, generating, or structuring tests. Do NOT use for Simulink coverage or
  Simulink testing workflows.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Run Tests

Run MATLAB test suites, analyze results, collect code coverage metrics, and configure CI/CD pipelines using `matlab.unittest` infrastructure.

## When to Use

- User wants to run an existing test suite
- User needs to filter tests by name, tag, or folder
- User wants to analyze test failures or incomplete results
- User needs code coverage collection or analysis
- User wants CI/CD pipeline configuration with buildtool
- User asks about parallel test execution

## When NOT to Use

- Writing tests, creating test classes, parameterization, fixtures, mocking — use `matlab-write-tests`
- Baseline/regression tests against stored reference data — use `matlab-write-tests`
- Testing Simulink models — use Simulink test skills
- Performance benchmarking — use profiling workflows
- Buildtool setup without test context — use `matlab-software-development:matlab-create-buildfile`

## Workflow

### Run and report
1. **Run tests** — Execute via `run_matlab_test_file` MCP tool or `runtests` with filtering
2. **Analyze results** — Report pass/fail counts, iterate failed tests for diagnostics
3. **Verify** — Confirm all tests pass before proceeding to coverage or CI

### Coverage analysis (when requested)
1. **Collect** — Set up `TestRunner` with `CodeCoveragePlugin` and `CoverageResult`
2. **Report summary** — Call `coverageSummary` and present percentages to user
3. **Act on results** — Generate reports, analyze gaps, or justify — as user directs

### CI/CD setup
1. **Create buildfile.m** — Define `TestTask` with source and report options
2. **Add CI config** — GitHub Actions, Azure DevOps, or GitLab CI template

## Running Tests

### Via MCP

Use the `run_matlab_test_file` MCP tool to run test files directly. When you need filtering, parallel execution, or other options, use `evaluate_matlab_code` with `runtests`:

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

for r = results([results.Incomplete])
    fprintf('\nINCOMPLETE: %s\n', r.Name);
    disp(r.Details.DiagnosticRecord.Report);
end
```

## Coverage Analysis

```matlab
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

runner = TestRunner.withTextOutput;
covFormat = CoverageResult;
runner.addPlugin(CodeCoveragePlugin.forFolder('src', ...
    IncludingSubfolders=true, Producing=covFormat, MetricLevel='mcdc'));
results = runner.run(testsuite('tests'));

covResults = covFormat.Result;
summary = coverageSummary(covResults, "mcdc");
fprintf('Coverage: %d/%d (%.1f%%)\n', sum(summary(:,1)), sum(summary(:,2)), ...
    100*sum(summary(:,1))/sum(summary(:,2)));
```

For detailed coverage workflows — gap analysis, justifications, generated C code coverage, and data type/size coverage — see [references/code-coverage-guidance.md](references/code-coverage-guidance.md).

## Key Functions

| Category | Functions | Purpose |
|----------|-----------|---------|
| Execution | `runtests`, `TestSuite`, `TestRunner` | Run and organize tests |
| Coverage | `CodeCoveragePlugin`, `CoverageResult`, `coverageSummary` | Measure test coverage |
| Reports | `CoverageReport`, `generateStandaloneReport`, `generateCoberturaReport` | Coverage output formats |
| CI/CD | `buildtool`, `TestTask`, `addCodeCoverage` | Pipeline automation |
| Scripts | [`printCoverageGaps`](scripts/printCoverageGaps.m) | Print all uncovered items across metric levels — see [references/code-coverage-guidance.md](references/code-coverage-guidance.md) for interface |

## CI/CD Integration

Use `buildtool` with a `buildfile.m` for CI pipelines. See [references/test-execution-guidance.md](references/test-execution-guidance.md) for `buildfile.m` templates and CI configs (GitHub Actions, Azure DevOps, GitLab CI).

## References

Load these on demand — most test runs only need what's in this file.

| Load when... | Reference |
|---|---|
| Running tests in CI, buildtool config, filtering options, parallel execution details | [references/test-execution-guidance.md](references/test-execution-guidance.md) |
| Collecting code coverage (MC/DC, statement, decision, condition), analyzing gaps, justifying uncovered code, generated C code coverage, type-size coverage | [references/code-coverage-guidance.md](references/code-coverage-guidance.md) |
| Creating or modifying filter rule XML for coverage justifications | [references/justification-filter-rules.md](references/justification-filter-rules.md) |
| Extracting data type and size coverage results from hidden property | [references/datatype-size-extraction.md](references/datatype-size-extraction.md) |

## Conventions

- Always: run tests via the `run_matlab_test_file` MCP tool when possible
- Always: report pass/fail summary before taking further action
- Always: check for Failed/Incomplete tests before analyzing coverage
- Prefer: `forFolder` with `IncludingSubfolders=true` as the default source specification for coverage
- Prefer: MC/DC as the default metric level because each level includes all lower levels
- Never: generate coverage reports (HTML, Cobertura) unless the user explicitly requests them
- Never: use `CoverageResult` as the only format — always use it as the primary programmatic format

----

Copyright 2026 The MathWorks, Inc.

----
