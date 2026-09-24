# Data Type and Size Coverage Extraction

**Requires R2026b or later.** Before using the APIs below, check the MATLAB version with `version('-release')`. If the release is earlier than R2026b, use an instrumentation-based fallback (wrap source functions to log argument types and sizes during test execution) instead of attempting the `Metrics` parameter or `DatatypeSizeCovData` property.

After collecting coverage with `Metrics=["statement", "type-size"]`, extract type-size data from the coverage result's `DatatypeSizeCovData` property.

## Accessing the Data

Data type and size coverage data can be accessed via the `DatatypeSizeCovData` property of the `matlab.coverage.Result` object:

```matlab
for i = 1:numel(coverageResult)
    data = coverageResult(i).DatatypeSizeCovData;
    if isempty(data), continue; end
    % Process data for this source file...
end
```

## Data Structure

```
coverageResult(i).DatatypeSizeCovData
  └── .FunctionSizeTypeCoverageData (array, one per function)
        ├── .FunctionName          (string)
        ├── .InputArgNames         (cell array of strings)
        └── .SizeTypeCoverageData  (array, one per unique input signature)
              ├── .NumRepetitions  (how many times this signature was called)
              └── .SizeTypeDataOnInputArguments (array, one per argument)
                    ├── .ArgumentName  (string)
                    ├── .DataType      (string, e.g. "double", "single")
                    └── .Size          (numeric vector, e.g. [1 10], [3 3])
```

## Complete Extraction Example

```matlab
import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

suite = TestSuite.fromFolder("tests");
runner = TestRunner.withTextOutput;
format = CoverageResult;

plugin = CodeCoveragePlugin.forFolder("src", ...
    IncludingSubfolders=true, Producing=format, ...
    Metrics=["statement", "type-size"]);

runner.addPlugin(plugin);
results = runner.run(suite);
covResults = format.Result;

% Extract type-size data
for i = 1:numel(covResults)
    [~, fname] = fileparts(covResults(i).Filename);
    data = covResults(i).DatatypeSizeCovData;
    if isempty(data), continue; end

    fcnData = data.FunctionSizeTypeCoverageData;
    for f = 1:numel(fcnData)
        fprintf('Function: %s\n', fcnData(f).FunctionName);
        fprintf('  Input args: %s\n', strjoin(fcnData(f).InputArgNames, ', '));

        invocations = fcnData(f).SizeTypeCoverageData;
        fprintf('  Unique type-size signatures: %d\n', numel(invocations));

        for inv = 1:numel(invocations)
            fprintf('  Signature #%d (called %d times):\n', ...
                inv, invocations(inv).NumRepetitions);
            argData = invocations(inv).SizeTypeDataOnInputArguments;
            for a = 1:numel(argData)
                fprintf('    %-12s: %-8s  size=%s\n', ...
                    argData(a).ArgumentName, ...
                    argData(a).DataType, ...
                    mat2str(argData(a).Size));
            end
        end
        fprintf('\n');
    end
end
```

## Identifying Size Mismatches

To find arguments tested with multiple different sizes (good test diversity indicator):

```matlab
for i = 1:numel(covResults)
    data = covResults(i).DatatypeSizeCovData;
    if isempty(data), continue; end

    fcnData = data.FunctionSizeTypeCoverageData;
    for f = 1:numel(fcnData)
        invocations = fcnData(f).SizeTypeCoverageData;
        if numel(invocations) <= 1, continue; end

        argNames = fcnData(f).InputArgNames;
        for a = 1:numel(argNames)
            sizes = {};
            for inv = 1:numel(invocations)
                argObjs = invocations(inv).SizeTypeDataOnInputArguments;
                for k = 1:numel(argObjs)
                    if argObjs(k).ArgumentName == argNames{a}
                        sizes{end+1} = mat2str(argObjs(k).Size);
                        break;
                    end
                end
            end
            uniqueSizes = unique(sizes);
            if numel(uniqueSizes) > 1
                fprintf('  %s.%s tested with %d sizes: %s\n', ...
                    fcnData(f).FunctionName, argNames{a}, ...
                    numel(uniqueSizes), strjoin(uniqueSizes, ', '));
            end
        end
    end
end
```

## Key Points

- `Metrics` and `MetricLevel` are **mutually exclusive** — cannot use both
- `"type-size"` must be combined with a structural metric: `Metrics=["statement", "type-size"]`
- `DatatypeSizeCovData` is a property on `matlab.coverage.Result` — access it directly from the result object
- Available from R2026b
- `coverageSummary` does not include type-size data — access it directly from the result object

----

Copyright 2026 The MathWorks, Inc.

----
