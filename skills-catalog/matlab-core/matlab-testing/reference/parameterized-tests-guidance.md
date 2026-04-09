# Parameterized Tests

Data-driven testing using `TestParameter` properties.

## Named Parameters with Structs

Use structs for clearer test names and grouped input/expected data:

```matlab
properties (TestParameter)
    rectangleCase = struct(...
        'small', struct('input', [2 3], 'expected', 6), ...
        'large', struct('input', [10 20], 'expected', 200));
end

methods (Test)
    function testRectangleArea(testCase, rectangleCase)
        area = calculateArea(rectangleCase.input(1), rectangleCase.input(2));
        testCase.verifyEqual(area, rectangleCase.expected);
    end
end
```

## Parameter Combinations

| Mode | What it does | When to use |
|------|-------------|-------------|
| `exhaustive` (default) | Every combination of all parameters | 1-2 parameters, or when every combination genuinely matters |
| `sequential` | Zips parameters positionally | Input-output pairs that must stay aligned (same length required) |
| `pairwise` | All 2-way interactions, fewer tests | 3+ parameters where exhaustive is too many |

Watch for combinatorial explosion: 4 params × 5 values = 625 tests with `exhaustive`.

```matlab
% exhaustive (default)
methods (Test)
    function testConversion(testCase, dataType, arrayShape)
    end
end

% sequential — paired (same length required)
methods (Test, ParameterCombination = 'sequential')
    function testPairedInputs(testCase, input, expected)
        testCase.verifyEqual(myFunction(input), expected);
    end
end

% pairwise — all 2-way interactions
methods (Test, ParameterCombination = 'pairwise')
    function testMultipleFactors(testCase, dataType, solver, tolerance)
    end
end
```

## Edge Case Parameters

Include edge cases relevant to the function's input domain:

```matlab
properties (TestParameter)
    numericEdge = struct('zero', 0, 'negative', -1, 'large', 1e15, 'nan', NaN);
    arrayEdge = struct('empty', [], 'scalar', 5, 'row', [1 2 3], 'column', [1; 2; 3]);
end
```

## Dynamic Parameters with TestParameterDefinition

Use when parameters should refresh each run (e.g., files in a folder) or depend on a higher-level parameter.

```matlab
properties (TestParameter)
    dataFile  % No default — populated by method below
end

methods (Static, TestParameterDefinition)
    function dataFile = getDataFiles()
        listing = dir('testdata/*.mat');
        dataFile = struct();
        for i = 1:numel(listing)
            [~, name] = fileparts(listing(i).name);
            dataFile.(matlab.lang.makeValidName(name)) = ...
                fullfile(listing(i).folder, listing(i).name);
        end
    end
end
```

### Parameters Dependent on ClassSetupParameter

```matlab
properties (ClassSetupParameter)
    precision = {'single', 'double'};
end

properties (TestParameter)
    tolerance  % depends on precision
end

methods (Static, TestParameterDefinition)
    function tolerance = getTolerance(precision)
        if strcmp(precision, 'single')
            tolerance = struct('loose', 1e-4, 'tight', 1e-6);
        else
            tolerance = struct('loose', 1e-10, 'tight', 1e-14);
        end
    end
end
```

## Best Practices

1. **Parameterize only when assertion logic is identical** — if the test body needs `if`/`switch`, use separate methods
2. **Use meaningful names** — they appear in test results
3. **Group related values in structs** — keeps input/expected together
4. **Keep parameter tables small** — growing tables may mean the tests are testing different logic
5. **Use the right level** — `TestParameter` for test data, `ClassSetupParameter` for expensive shared fixtures
