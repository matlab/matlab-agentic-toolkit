# Code Coverage Collection and Analysis

Collect coverage metrics for MATLAB source code and generated C code, identify gaps, justify unreachable code, and write targeted tests to close gaps.

## Workflow

### 1. Check environment

Before collecting coverage, verify what's available:

```matlab
hasMLTest = ~isempty(ver('matlabtest'));
v = version('-release');
fprintf('MATLAB %s | MATLAB Test installed: %d\n', v, hasMLTest);
```

Advanced metrics (decision, condition, MC/DC, justifications) require MATLAB Test. Default to `MetricLevel="mcdc"` when MATLAB Test is installed; fall back to `"statement"` otherwise.

### 2. Collect coverage

Coverage collection requires programmatic `TestRunner` setup with plugins. Run all coverage code via `mcp__matlab__evaluate_matlab_code` — the `mcp__matlab__run_matlab_test_file` tool does not support coverage plugins.

Use `CodeCoveragePlugin.forFolder` with `CoverageResult` as the single output format:

```matlab
import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

suite = TestSuite.fromFolder("tests");
runner = TestRunner.withTextOutput;

format = CoverageResult;
runner.addPlugin(CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, MetricLevel="mcdc"));

results = runner.run(suite);
coverageResult = format.Result;  % Object array — one element per source file
```

Verify `results` has no `Failed` or `Incomplete` outcomes before analyzing coverage — failed tests produce incomplete coverage data. If tests fail, fix them first and re-run.

### 3. Report summary

`coverageResult` is an **object array** with one element per instrumented source file. `coverageSummary` accepts the full array and returns an Nx2 matrix (one row per file: `[achieved, total]`).

Report **all metric levels** up to the collected level — call `coverageSummary` once per level. Present the results in a single combined table with one row per file and one column per metric level.

| Collected MetricLevel | Report these levels |
|-----------------------|---------------------|
| `"statement"` | statement |
| `"decision"` | statement, decision |
| `"condition"` | statement, decision, condition |
| `"mcdc"` | statement, decision, condition, mcdc |

```matlab
% 1-output form: Nx2 matrix [achieved, total] per file
summary = coverageSummary(coverageResult, "mcdc");
fprintf('Coverage: %d/%d (%.1f%%)\n', sum(summary(:,1)), sum(summary(:,2)), ...
    100*sum(summary(:,1))/sum(summary(:,2)));
```

After reporting the summary, tell the user the coverage percentage and ask what they'd like to do next: analyze gaps, generate a report, or write tests.

### 4. Act on results (user-directed)

Based on user request:
- **Generate interactive report** — `generateHTMLReport(coverageResult, "coverage-report")` (folder-based, browseable per-file view)
- **Generate portable report** — `generateStandaloneReport(coverageResult, "report.html")` (single file, shareable)
- **Generate CI artifact** — `generateCoberturaReport(coverageResult, "coverage.xml")`
- **Analyze gaps** — see Gap Analysis pattern below
- **Justify unreachable code** — see Justification pattern (only when user asks)
- **Write tests for gaps** — see Test Generation pattern

Alternatively, produce the interactive report during collection using `CoverageReport`:

```matlab
import matlab.unittest.plugins.codecoverage.CoverageReport

runner.addPlugin(CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, ...
    Producing=[format, CoverageReport("coverage-report")], ...
    MetricLevel="mcdc"));
```

## Key Functions

| Function | Purpose | Requires |
|----------|---------|----------|
| `CodeCoveragePlugin.forFolder` | Instrument source folder for coverage | (core) |
| `CodeCoveragePlugin.forFile` | Instrument specific files | (core) |
| `CodeCoveragePlugin.forNamespace` | Instrument source code in a specified namespace | (core) |
| `coverageSummary(result, level)` | Get coverage counts + gap details | (core) |
| `generateHTMLReport` | Interactive HTML report (folder-based, browseable) | (core) |
| `generateStandaloneReport` | Single-file HTML report (portable, shareable) | (core) |
| `generateCoberturaReport` | Cobertura XML for CI | (core) |
| `CodeCoveragePlugin(..., Filter=file)` | Apply filter rules during collection | MATLAB Test |
| `result.applyFilter(file)` | Apply filter rules to existing results | MATLAB Test |
| `result.resetFilter` | Remove applied filters, return unfiltered results | MATLAB Test |
| `GeneratedCodeCoveragePlugin` | Coverage for generated C code | MATLAB Test + MATLAB Coder |

## Patterns

### Basic Coverage Collection

Always use `forFolder` with `IncludingSubfolders=true` for projects with nested source directories. Use `forFile` only when measuring specific individual files. Use `forNamespace` when source code is organized in namespaces (`+packageName` folders).

```matlab
% CORRECT: covers all .m files in src/ and its subfolders
plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, MetricLevel="mcdc");

% For namespace-organized code: covers all files in +myPackage and inner namespaces
plugin = CodeCoveragePlugin.forNamespace("myPackage", ...
    IncludingInnerNamespaces=true, Producing=format, MetricLevel="mcdc");

% WRONG: verbose manual enumeration — don't do this
% srcFiles = dir(fullfile("src", '**', '*.m'));
% plugin = CodeCoveragePlugin.forFile(filePaths, ...);
```

**MetricLevel values:** `"statement"`, `"decision"`, `"condition"`, `"mcdc"`. Default to `"mcdc"` when MATLAB Test is installed, `"statement"` otherwise.

Each level includes all levels below it — `"mcdc"` gives you statement + decision + condition + MC/DC.

**Release compatibility:** On R2026b+, `MetricLevel` is deprecated in `CodeCoveragePlugin` — use `Metrics` instead. `Metrics` also supports `"type-size"` (see Data Type and Size Coverage below). When unsure of the release, use `MetricLevel` — it works on all supported versions.

```matlab
% R2026b+ only: Metrics replaces MetricLevel for CodeCoveragePlugin
plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, Metrics="mcdc");
```

### Generated C Code Coverage

For generated code from MATLAB Coder, use `GeneratedCodeCoveragePlugin` (not `CodeCoveragePlugin`). Always pass `Producing=format` to get programmatic access to results — without it, coverage is collected but not accessible.

```matlab
import matlabtest.coder.plugins.GeneratedCodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

suite = TestSuite.fromClass(?myCoderEquivalenceTest);
runner = TestRunner.withTextOutput;

format = CoverageResult;
runner.addPlugin(GeneratedCodeCoveragePlugin( ...
    MetricLevel="condition", Producing=format));

results = runner.run(suite);
coverageResult = format.Result;  % Object array, same as CodeCoveragePlugin
```

**`PreserveInFolder` is only required for Cobertura XML output.** When producing `CoberturaFormat`, the test must use `PreserveInFolder` in its `build()` call so build artifacts (C source files) remain on disk for report generation:

```matlab
import matlab.unittest.plugins.codecoverage.CoberturaFormat

% Only needed when producing Cobertura XML:
runner.addPlugin(GeneratedCodeCoveragePlugin( ...
    MetricLevel="condition", Producing=CoberturaFormat("coverage.xml")));

% The test class must call:
%   testCase.build(fcn, Inputs=args, Configuration=cfg, PreserveInFolder=folder)
```

### Data Type and Size Coverage

Tracks which `(type, size)` combinations of input arguments are exercised. Uses the `Metrics` parameter with `"type-size"` as an additional metric alongside a structural metric.

Available from R2026b. Check availability before using:

```matlab
plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, ...
    Metrics=["statement", "type-size"]);
```

Note: `"type-size"` cannot be used alone — it must be combined with a structural metric (`"statement"`, `"decision"`, `"condition"`, or `"mcdc"`).

For extracting and interpreting the results, see [datatype-size-extraction.md](datatype-size-extraction.md) — consult when the user asks about type-size coverage data or input diversity.

### Gap Analysis

Use the 2-output form of `coverageSummary` to get detailed gap information:

```matlab
[summary, description] = coverageSummary(coverageResult, "mcdc");

% description.mcdc contains per-decision detail:
mcdcDetails = description.mcdc;
for i = 1:numel(mcdcDetails)
    conditions = mcdcDetails(i).Condition;
    for j = 1:numel(conditions)
        if ~conditions(j).Achieved
            fprintf('Decision %d, Cond %d: "%s" — needs: %s\n', ...
                i, j, conditions(j).Text, conditions(j).FalseResult);
        end
    end
end
```

For decision-level gaps:

```matlab
[summary, description] = coverageSummary(coverageResult, "decision");
decisions = description.decision;
for i = 1:numel(decisions)
    for j = 1:numel(decisions(i).Outcome)
        if decisions(i).Outcome(j).ExecutionCount == 0
            fprintf('Decision %d: %s outcome uncovered\n', ...
                i, decisions(i).Outcome(j).Text);
        end
    end
end
```

### printCoverageGaps

Prints all uncovered items across all metric levels (statement, function, decision, condition, MC/DC) present in the coverage result.

**Script:** [../scripts/printCoverageGaps.m](../scripts/printCoverageGaps.m)

| | |
|---|---|
| **Input** | `covResults` — `matlab.coverage.Result` array from `CoverageResult` format |
| **Output** | Prints to stdout; no return value |

```matlab
printCoverageGaps(covResults);
```

### Programmatic Justification

Justify structurally unreachable code when the user requests it. Justifications can only be applied up to decision level — condition and MC/DC outcomes cannot be justified. This is a human-in-the-loop workflow: highlight the gaps, then justify when the user confirms.

The approach: create a **filter rule XML file** that can be reused across runs. This is preferable to constructing justification objects programmatically because the XML file is version-controllable, shareable, and can be supplied at collection time or applied after.

For the full XML schema, attribute reference, and usage patterns, see [justification-filter-rules.md](justification-filter-rules.md) — consult whenever applying justifications.

Quick example:

```matlab
% 1. Create the filter rule XML file
filterXml = fullfile(projectRoot, "resources", "CodeCoverageFilter.xml");
xmlContent = [ ...
    '<?xml version="1.0" encoding="utf-8"?>', newline, ...
    '<filter>', newline, ...
    '    <rule type="DECISION" fileName="shortest_path.m" ', ...
    'functionName="shortest_path" ', ...
    'expr="if ~isNodeValid(endIdx)" index="3" ', ...
    'mode="JUSTIFIED" ', ...
    'rationale="Structurally unreachable: early return prevents reaching this branch"/>', newline, ...
    '</filter>'];
writelines(string(xmlContent), filterXml);

% 2a. Supply at collection time (justifications applied during run)
plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, ...
    MetricLevel="decision", Filter=filterXml);

% 2b. Or apply after collection
filteredResult = coverageResult.applyFilter(filterXml);
generateStandaloneReport(filteredResult, "report.html");
```

### Coverage-Driven Test Generation

When the user wants to close coverage gaps, follow this pattern:

1. Collect coverage and extract gaps using `coverageSummary` 2-output form
2. For each uncovered condition/decision, analyze the source code to determine what input would trigger it
3. Write targeted test methods that exercise the specific uncovered path
4. Re-run coverage to verify improvement

Do not use internal `matlabtest.internal.testcreation.*` APIs to generate tests (they produce empty stubs only). Write test methods directly instead.

```matlab
% After identifying: condition "windowSize < 1" is uncovered (false branch)
% Write a test that makes windowSize < 1 to trigger that branch:

function testWindowSizeLessThanOne(testCase)
    data = randn(100, 1);
    testCase.verifyError(@() movingAverageFilter(data, 0), ...
        'movingAverageFilter:invalidWindow');
end
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `dir`+`arrayfun`+`forFile` for multi-folder | Verbose, fragile with package dirs | `forFolder(path, IncludingSubfolders=true)` |
| `CodeCoveragePlugin` for generated C code | Only instruments MATLAB code | `matlabtest.coder.plugins.GeneratedCodeCoveragePlugin` |
| Missing `PreserveInFolder` when using `CoberturaFormat` with generated code | Build artifacts cleaned up, empty Cobertura report | Add `PreserveInFolder=folder` to `testCase.build()` (only needed for Cobertura XML) |
| Using `Metrics=` without checking release | `Metrics` only works on R2026b+; errors on older releases | Use `MetricLevel` by default (works on all versions); use `Metrics` only when you confirm R2026b+ |
| `Metrics="type-size"` alone | Must combine with a structural metric | `Metrics=["statement","type-size"]` |
| Treating `coverageSummary` 2nd output as numeric | 2-output form returns `[summary, description]` — description is a struct, not a matrix | Use 1-output `summary = coverageSummary(result, level)` for totals; 2-output only for gap analysis |
| Using `coverageResult.Files` | Property does not exist | Use `coverageResult(i).Filename` in a loop, or `[coverageResult.Filename]` to get all paths |
| Generating multiple report formats unrequested | Wastes tokens and confuses user | Use `CoverageResult` only; generate reports when asked |
| Using `matlabtest.coverage.Justification` constructor | Error-prone 8-arg API, hard to reuse | Write a filter rule XML file and pass via `Filter=` or `applyFilter` |
| Lowercase `type` in filter rule XML | `type` attribute requires uppercase | Use `type="DECISION"`, `type="MCDC_OUTCOME"` |

## Conventions

- Always: use `CoverageResult` as the primary output — produce reports only when the user asks
- Always: report coverage numbers to the user before taking further action
- Always: when MATLAB Test is not installed, fall back to statement-level coverage only
- Prefer: `forFolder` with `IncludingSubfolders=true` as the default source specification
- Prefer: advanced metrics (decision, MC/DC) — MATLAB Test provides capabilities beyond what most coverage tools offer
- Prefer: MC/DC as the default metric level because each level includes all lower levels
- Never: justify coverage proactively — wait for user to request justification
- Never: use internal `matlabtest.internal.*` APIs

----

Copyright 2026 The MathWorks, Inc.

----
