# Test Execution, Coverage, and CI/CD

Running tests, analyzing results, collecting code coverage, and configuring CI/CD pipelines.

## Running Tests

```matlab
results = runtests('tests');                              % all tests in directory
results = runtests('computeAreaTest');                     % specific file
results = runtests('computeAreaTest/testSquare');          % specific method
```

### Filtering Options

```matlab
results = runtests('tests', Name='*Calculator*');         % by name pattern
results = runtests('tests', Tag='Unit');                  % by tag
results = runtests('tests', ExcludeTag='Slow');           % exclude tag
results = runtests('tests', ProcedureName='testX');       % by procedure
results = runtests('tests', UseParallel=true);            % parallel execution
results = runtests('tests', Strict=true);                 % warnings = failures
results = runtests('tests', Debug=true);                  % debugger on failure
results = runtests('tests', OutputDetail='Detailed');     % verbose output
```

**Parallel requirements**: Tests must be independent — no shared state, no order dependence, no shared file system artifacts.

### Analyzing Results

```matlab
results = runtests('tests');
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

## Code Coverage

### Collect and Display

Run tests with coverage. Include `CoverageResult` (programmatic) and `CoverageReport` (HTML). Add `CoberturaFormat` for CI.

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
for i = 1:numel(covResults)
    disp(covResults(i));
end
```

### Identify Coverage Gaps

Script: [scripts/printCoverageGaps.m](../scripts/printCoverageGaps.m)

Deploy to the user's project when requested. The script expects `covResults` from the Collect step and prints uncovered items. It has 4 tiers — include tiers up to the `MetricLevel` used:
- default (no MetricLevel) → statement & function only
- `"decision"` → through decision
- `"condition"` → through condition
- `"mcdc"` → all tiers

## CI/CD Integration with buildtool

Always use `buildtool` with a `buildfile.m` for CI.

### Example buildfile.m

```matlab
function plan = buildfile
    plan = buildplan(localfunctions);

    plan("clean") = matlab.buildtool.tasks.CleanTask;

    plan("check") = matlab.buildtool.tasks.CodeIssuesTask("src");

    plan("test") = matlab.buildtool.tasks.TestTask("tests", ...
        SourceFiles="src", ...
        ReportFormat=["html", "cobertura"], ...
        OutputDirectory="reports");

    plan("ci") = matlab.buildtool.Task( ...
        Description="Full CI pipeline", ...
        Dependencies=["check", "test"]);

    plan.DefaultTasks = "test";
end
```

### Running buildtool

```matlab
buildtool              % run default task
buildtool test         % run specific task
```

### CI Pipeline Configurations

#### GitHub Actions

```yaml
# .github/workflows/matlab.yml
name: MATLAB Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: matlab-actions/setup-matlab@v2
      - uses: matlab-actions/run-build@v2
```

#### Azure DevOps

```yaml
# azure-pipelines.yml
trigger: [main]
pool:
  vmImage: 'ubuntu-latest'
steps:
  - task: InstallMATLAB@1
  - task: RunMATLABBuild@1
```

#### GitLab CI

```yaml
# .gitlab-ci.yml
test:
  image: mathworks/matlab:r2024a
  script:
    - matlab -batch "buildtool"
```
