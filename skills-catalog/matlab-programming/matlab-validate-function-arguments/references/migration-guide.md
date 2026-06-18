# Migration Guide: inputParser and validateattributes to Arguments Blocks

## inputParser Migration

### Structural Mapping

| inputParser pattern | Arguments block equivalent |
|--------------------|--------------------------|
| `addRequired(p, 'x', @validator)` | `x` (positional, no default) |
| `addOptional(p, 'x', default, @validator)` | `x = default` (positional with default) |
| `addParameter(p, 'Name', default, @validator)` | `options.Name = default` (name-value) |
| `p.Results.Name` | `options.Name` or direct variable name |

### Complete Example

```matlab
% BEFORE: inputParser
function result = plotData(filename, varargin)
    p = inputParser;
    addRequired(p, 'filename', @ischar);
    addOptional(p, 'finish', 100, @(x) isnumeric(x) && x > 0);
    addOptional(p, 'color', 'blue', @(x) ismember(x, {'blue','red','green'}));
    addParameter(p, 'Width', 800, @isnumeric);
    addParameter(p, 'Height', 600, @isnumeric);
    parse(p, filename, varargin{:});
    % Use p.Results.filename, p.Results.finish, etc.
end

% AFTER: arguments block (strict fidelity)
function result = plotData(filename, finish, color, options)
    arguments
        filename {mustBeA(filename, 'char')}
        finish {mustBeNumeric, mustBePositive} = 100
        color {mustBeA(color, 'char'), mustBeMember(color, {'blue','red','green'})} = 'blue'
        options.Width {mustBeNumeric} = 800
        options.Height {mustBeNumeric} = 600
    end
    % Use filename, finish, color, options.Width, options.Height directly
end

% AFTER: arguments block (modernized — acceptable if contract change is intentional)
function result = plotData(filename, finish, color, options)
    arguments
        filename (1,1) string {mustBeNonzeroLengthText}
        finish (1,1) double {mustBePositive} = 100
        color (1,1) string {mustBeMember(color, ["blue","red","green"])} = "blue"
        options.Width (1,1) double {mustBePositive} = 800
        options.Height (1,1) double {mustBePositive} = 600
    end
end
```

### Key Decisions During Migration

**Q: The original uses `@ischar`. Should I use `string` or `char`?**

- `{mustBeA(x, 'char')}` — strict fidelity, rejects string inputs
- `(1,1) string` — modernized, accepts both char and string (auto-converts char→string)
- `{mustBeTextScalar}` — accepts both, no conversion (stays as whatever was passed)

Choose based on context: if the function passes the value to other functions expecting char, preserve char. If modernizing the whole API, use string.

**Q: The original uses `@isnumeric`. Should I add a class spec?**

No. Use `{mustBeNumeric}` without a class spec. Adding `double` would silently convert single/int32 inputs to double, changing the function's contract.

**Q: The original uses `@(x) x > 0`. How do I migrate that?**

Use `{mustBePositive}` for `> 0`, or `{mustBeGreaterThan(x, threshold)}` for custom bounds.

**Q: The original uses an anonymous-function validator like `@(x) ~isempty(x)`. Don't drop it.**

Anonymous-function validators almost always have a built-in equivalent —
see the "Anonymous-Function Validators" mapping table in `SKILL.md` for the
common cases (`@(x) ~isempty(x)` → `mustBeNonempty`, `@(x) isfinite(x)` →
`mustBeFinite`, `@(x) isa(x,'MyClass')` → `mustBeA(x, "MyClass")`, etc.).
Translate, don't omit.

If the anonymous function has no direct equivalent (e.g., it cross-references another argument), keep it as a local validator function and reference it from the arguments block: `x {myCustomValidator}`.

## validateattributes Migration

### Attribute Mapping

| validateattributes attribute | Arguments block equivalent |
|-----------------------------|--------------------------|
| `{'double'}` | `{mustBeA(x, "double")}` (strict) or `double` (converts) |
| `{'single','double'}` | `{mustBeFloat}` |
| `{'numeric'}` | `{mustBeNumeric}` |
| `{'nonempty'}` | `{mustBeNonempty}` |
| `{'real'}` | `{mustBeReal}` |
| `{'finite'}` | `{mustBeFinite}` |
| `{'positive'}` | `{mustBePositive}` |
| `{'nonnegative'}` | `{mustBeNonnegative}` |
| `{'integer'}` | `{mustBeInteger}` |
| `{'scalar'}` | `(1,1)` size spec |
| `{'vector'}` | `{mustBeVector}` |
| `{'2d'}` | `(:,:)` size spec |
| `{'size',[1,NaN]}` | `(1,:)` size spec reshapes columns to rows. To reject like `validateattributes` does, use `{mustBeRow}` (R2024b+) |
| `{'ncols',3}` | `(:,3)` size spec (note: scalar-expands, e.g. `5` becomes `[5 5 5]`; original rejects scalars) |
| `{'>=',0}` | `{mustBeNonnegative}` or `{mustBeGreaterThanOrEqual(x, 0)}` |
| `{'>=',0,'<=',1}` | `{mustBeBetween(x, 0, 1, "closed")}` |

### Complete Example

```matlab
% BEFORE: validateattributes
function result = processSignal(audioIn, fs, options)
    validateattributes(audioIn, {'single','double'}, ...
        {'nonempty','2d','real','finite'}, 'processSignal', 'audioIn');
    validateattributes(fs, {'single','double'}, ...
        {'positive','real','scalar'}, 'processSignal', 'fs');
    if isfield(options, 'WindowLength')
        validateattributes(options.WindowLength, {'double'}, ...
            {'integer','positive','scalar'}, 'processSignal', 'WindowLength');
    end
end

% AFTER: arguments block
function result = processSignal(audioIn, fs, options)
    arguments
        audioIn (:,:) {mustBeFloat, mustBeNonempty, mustBeReal, mustBeFinite}
        fs (1,1) {mustBeFloat, mustBePositive, mustBeReal}
        options.WindowLength (1,1) {mustBeA(options.WindowLength, "double"), ...
            mustBeInteger, mustBePositive}
    end
end
```

Note: `mustBeFloat` replaces `{'single','double'}` — it rejects int/char without converting.

## When NOT to Migrate

Keep `inputParser` or manual validation when:

- **Conditional parameters:** Valid options depend on the value of another parameter
- **Dynamic validation:** Validation rules computed at runtime
- **Partial parsing:** Using `p.KeepUnmatched` to pass through unknown arguments
- **Nested functions:** Arguments blocks are not supported in nested functions

In these cases, consider splitting into multiple functions or using arguments blocks for what you can, with manual validation for the rest.

----

Copyright 2026 The MathWorks, Inc.

----
