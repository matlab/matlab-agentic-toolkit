# Baseline Tests

Write MATLAB unit tests that validate function output against stored reference data using MATLAB Test (R2024b+).

## Key Functions

| Function | Purpose |
|----------|---------|
| `matlabtest.parameters.matfileBaseline` | Create MAT-file baseline parameter |
| `verifyEqualsBaseline` | Verify actual output matches a baseline |

## Workflow

1. **Identify output type** — Determine whether the function output suits MAT-file baselines (numeric arrays, structures, objects, tables, or any MATLAB data type that you can save to a MAT file).

2. **Define parameterization properties** — One property per baseline value, using `matlabtest.parameters.matfileBaseline`. Define properties in a block with the `TestParameter`, `MethodSetupParameter`, or `ClassSetupParameter` attribute. Consolidate related baselines into a single MAT file using `VariableName` to identify which baseline each parameter points to.

3. **Write test methods** — Each method accepts the baseline parameter and calls `verifyEqualsBaseline`.

4. **Create baseline data** — Run the function under test, save results to the baseline MAT file. The test will compare against this file on later runs.

5. **Run tests** — Execute the test file to confirm the actual values match the baselines.

## Patterns

### MAT-File Baseline (Single File, Multiple Variables)

Use `VariableName` to store multiple baselines in one MAT file. This is the default pattern — avoid creating separate files for logically related baselines.

```matlab
classdef CreateOutputMatrixTest < matlab.unittest.TestCase

    properties (TestParameter)
        squareResult = matlabtest.parameters.matfileBaseline( ...
            "baselines/outputMatrices.mat", VariableName="squareResult")
        rectResult = matlabtest.parameters.matfileBaseline( ...
            "baselines/outputMatrices.mat", VariableName="rectResult")
        singleRowResult = matlabtest.parameters.matfileBaseline( ...
            "baselines/outputMatrices.mat", VariableName="singleRowResult")
    end

    methods (Test)
        function testSquareInput(testCase, squareResult)
            actual = createOutputMatrix([1 2 3; 4 5 6; 7 8 9]);
            testCase.verifyEqualsBaseline(actual, squareResult);
        end

        function testRectangularInput(testCase, rectResult)
            actual = createOutputMatrix([10 20 30 40; 50 60 70 80]);
            testCase.verifyEqualsBaseline(actual, rectResult);
        end

        function testSingleRow(testCase, singleRowResult)
            actual = createOutputMatrix([1 2 3 4 5]);
            testCase.verifyEqualsBaseline(actual, singleRowResult);
        end
    end

end
```

### MAT-File Baseline (Multiple Files for Unrelated Data)

When baselines are not logically related, separate files are appropriate:

```matlab
classdef ProcessDataTest < matlab.unittest.TestCase

    properties (TestParameter)
        numericOutput = matlabtest.parameters.matfileBaseline( ...
            "baselines/numericOutput.mat", VariableName="numericOutput")
        metadataOutput = matlabtest.parameters.matfileBaseline( ...
            "baselines/metadataOutput.mat", VariableName="metadataOutput")
    end

    methods (Test)
        function testNumericOutput(testCase, numericOutput)
            actual = processData(sampleInput(), "numeric");
            testCase.verifyEqualsBaseline(actual, numericOutput);
        end

        function testMetadataOutput(testCase, metadataOutput)
            actual = processData(sampleInput(), "metadata");
            testCase.verifyEqualsBaseline(actual, metadataOutput);
        end
    end

end
```

### Tolerance

Pass `AbsTol` or `RelTol` as name-value arguments to `verifyEqualsBaseline` when floating-point differences are expected:

```matlab
testCase.verifyEqualsBaseline(actual, baselineParam, AbsTol=1e-6);
testCase.verifyEqualsBaseline(actual, baselineParam, RelTol=0.01);
```

## Generating Initial Baseline Data

After writing the test class, generate the baseline files by running the function under test and saving the output:

```matlab
squareResult = createOutputMatrix([1 2 3; 4 5 6; 7 8 9]);
rectResult = createOutputMatrix([10 20 30 40; 50 60 70 80]);
singleRowResult = createOutputMatrix([1 2 3 4 5]);
save("baselines/outputMatrices.mat", "squareResult", "rectResult", "singleRowResult");
```

## Common Mistakes

| Mistake | Why It Is Wrong | Correct Approach |
|---------|----------------|-----------------|
| Separate MAT file for every baseline even when logically related | Unnecessary file proliferation; harder to manage | Consolidate related baselines into one file with `VariableName` |
| Using generic variable names such as `data` | Collisions when consolidating multiple baselines in one file | Descriptive lowerCamelCase: `squareResult`, `filteredOutput` |
| Using `verifyEqual` with manual `load` | Bypasses baseline framework; no automatic baseline regeneration | Use `matfileBaseline` + `verifyEqualsBaseline` |
| Using `verifyEqual` with hardcoded or computed expected values | Bypasses baseline framework entirely; defeats the purpose of gold-file testing | Use `matfileBaseline` + `verifyEqualsBaseline` — even for simple cases |
| Using `verifyEqual(..., AbsTol=...)` for floating-point baselines | Tolerance works with `verifyEqualsBaseline` directly; no need to bypass the framework | Use `verifyEqualsBaseline(actual, param, AbsTol=1e-12)` |
| Hardcoding large expected values in test methods | Unreadable, unmaintainable, clutters the test file | Store in baseline MAT file |

## Conventions

- Consolidate related baselines into a single MAT file using `VariableName`
- Store baseline files in a `baselines/` subfolder relative to the test file
- Name baseline files after the data they contain, not the test class
- Use lowerCamelCase for MAT-file variable names that describe the stored data
- Use `verifyEqualsBaseline` by default; `AbsTol`/`RelTol` when floating-point tolerance needed
- Use lowerCamelCase for `TestParameter` property names matching the scenario

----

Copyright 2026 The MathWorks, Inc.

----
