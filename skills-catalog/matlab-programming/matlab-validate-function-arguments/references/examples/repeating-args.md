# Repeating Arguments — Worked Examples

For the basic paired-data pattern (`plotMultiSeries`), see the "Repeating
Arguments" section of `SKILL.md`. The examples below extend that pattern.

## Three-Element Groups

Accept (x, y, lineSpec) triplets:

```matlab
function styledPlot(x, y, lineSpec)
    arguments (Repeating)
        x (1,:) double {mustBeFinite}
        y (1,:) double {mustBeFinite}
        lineSpec (1,1) string
    end

    figure;
    hold on;
    for i = 1:numel(x)
        plot(x{i}, y{i}, lineSpec{i});
    end
    hold off;
end
```

Call: `styledPlot([1 2 3], [4 5 6], "-r", [1 2 3], [7 8 9], "--b")`

## Two-Block Pattern: Repeating + Name-Value

Combine repeating groups with name-value options using two `arguments` blocks:

```matlab
function stackedBarChart(categories, values, options)
    arguments (Repeating)
        categories (1,:) string
        values (1,:) double {mustBeFinite}
    end
    arguments
        options.Title (1,1) string = ""
        options.ColorMap (1,1) string = "parula"
        options.Normalize (1,1) logical = false
    end

    numGroups = numel(categories);

    % Collect all unique categories
    allCats = categories{1};
    for i = 2:numGroups
        allCats = union(allCats, categories{i}, 'stable');
    end

    % Build data matrix
    dataMatrix = zeros(numel(allCats), numGroups);
    for i = 1:numGroups
        for j = 1:numel(categories{i})
            idx = find(allCats == categories{i}(j), 1);
            dataMatrix(idx, i) = values{i}(j);
        end
    end

    if options.Normalize
        colSums = sum(dataMatrix, 1);
        colSums(colSums == 0) = 1;
        dataMatrix = dataMatrix ./ colSums * 100;
    end

    figure;
    bar(categorical(allCats, allCats), dataMatrix, 'stacked');
    colormap(options.ColorMap);
    if options.Title ~= ""
        title(options.Title);
    end
end
```

Call: `stackedBarChart(["A","B","C"], [10,20,30], ["A","B","C"], [5,15,25], Title="Sales")`

## Key Rules

1. **All args in the repeating block repeat together** — you cannot have some repeat and others not
2. **Variables become cell arrays** — access with `{i}` indexing
3. **No defaults allowed** in repeating blocks
4. **Zero repetitions is valid** — produces 1x0 empty cell arrays
5. **Name-value args go in a separate block** — they cannot be in the same block as repeating args
6. **Only one repeating input block** per function
7. **Do NOT use `varargin`** with argument validation — declare named variables instead

## Repeating Outputs — What Fails to Parse

For the working `productTriples` example and the one-name rule, see the
"Output Argument Validation" section of `SKILL.md`. The counter-example below
shows the parse-time failure mode:

```matlab
% BAD — multi-name (Output, Repeating) — does not parse
function [p, a, b] = productTriples()
    arguments (Output, Repeating)
        p (1,1) double
        a (1,1) double
        b (1,1) double
    end
    % Error: Declaring multiple repeating output arguments is not supported.
    % Identifier: MATLAB:functionValidation:MultipleRepeatingOutputs
end
```

To return groups of related values, declare a single output and pack groups
into it via convention (e.g. every third output is the product, the next two
are factors). Validators on the single declared name apply to each cell
element; comma-list expansion at the call site distributes elements across
the requested LHS variables.

## Anti-Pattern: varargin in Repeating Block

This is syntactically valid but useless — it provides no validation benefit:

```matlab
% BAD — do not do this
function bad(varargin)
    arguments (Repeating)
        varargin
    end
    % varargin is still just a cell array with no validation
end
```

Instead, declare named variables with types and validators.

----

Copyright 2026 The MathWorks, Inc.

----
