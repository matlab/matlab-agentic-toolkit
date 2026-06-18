---
name: matlab-validate-function-arguments
description: >
  Use when writing MATLAB functions with arguments blocks — repeating arguments
  (arguments (Repeating)), .?ClassName property import in constructors,
  name-value forwarding with namedargs2cell, or migrating from inputParser or
  validateattributes. Also when reviewing signatures for implicit-conversion
  pitfalls (size reshaping, class coercion, computed defaults), or when
  restricting, constraining, or validating function inputs — scalar vs vector
  enforcement, type rejection, size checking. Also when asked to harden inputs,
  make a function more robust, tighten input checking, or rewrite for safer
  input acceptance — even without "validation" or "arguments block" wording.
  Triggers on: arguments block, mustBe validators, name-value arguments,
  varargin, inputParser, nargin/narginchk, restrict input, type checking,
  scalar constraint, harden inputs, defensive programming. Not for: App
  Designer callbacks, Simulink mask parameters, class inheritance, or runtime
  validation outside function or property declarations.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Function Argument Validation

Write robust MATLAB functions using `arguments` blocks with correct semantics for size, class, repeating arguments, and property import.

## When to Use

- Writing a function with an `arguments` block
- Using repeating arguments (`arguments (Repeating)`)
- Writing a class constructor that accepts name-value arguments
- Migrating from `inputParser` or `validateattributes`
- Reviewing a function signature for implicit conversion pitfalls
- Choosing between class specs, `mustBeA`, and validators

## When NOT to Use

- Basic MATLAB programming without argument validation
- App building or UI components (use `matlab-building-apps`)
- Unit testing (use `matlab-testing`)
- General OOP class design unrelated to argument validation
- Simple `if`/`error` guard clauses for runtime invariants inside a function body
  (those aren't input validation — leave them as-is unless the user asks for an
  `arguments` block specifically)
- **`.mlx` (Live Script) or `.mlapp` (App Designer) files** — these are binary
  ZIP containers. Don't unzip them or attempt structural edits. If the user
  asks to add an `arguments` block to a function inside one, ask them to
  export to plain `.m` first, or open the file in MATLAB and edit it there.

## Critical Misconceptions

These are things the agent commonly gets wrong. Read these FIRST.

### Size specs RESHAPE, not reject

**WRONG belief:** `(1,:)` rejects column vectors with an error.

**ACTUAL behavior:** MATLAB silently reshapes the input to fit the declared size.

```matlab
function out = myFunc(x)
    arguments
        x (1,:) double
    end
    out = x;
end

myFunc([1; 2; 3])  % Does NOT error! Returns [1 2 3] (reshaped to row)
```

A column vector `[1;2;3]` passed to `(1,:)` becomes a row vector `[1 2 3]`. To actually reject column vectors, use a validator:

```matlab
function out = myFunc(x)
    arguments
        x {mustBeNumeric, mustBeRow}
    end
    out = x;
end
```

### Class specs CONVERT, not reject

**WRONG belief:** `double` in the arguments block rejects non-double inputs.

**ACTUAL behavior:** MATLAB attempts implicit conversion to the declared class.

```matlab
function out = myFunc(x)
    arguments
        x double
    end
    out = x;
end

myFunc('hello')  % Does NOT error! Returns [104 101 108 108 111] (ASCII codes)
myFunc(single(3.14))  % Does NOT error! Returns double(3.14)
```

To reject without converting, use `mustBeA` or `mustBeFloat`:

```matlab
x {mustBeA(x, "double")}           % Rejects single, char, int32, etc.
x {mustBeFloat}                     % Accepts single OR double, rejects char/int
x {mustBeNumeric}                   % Accepts any numeric, rejects char/string
```

### Numeric validators don't reject complex values

**WRONG belief:** `mustBeNumeric`, `mustBeFinite`, and `mustBeInteger` reject
complex inputs like `1+2i`.

**ACTUAL behavior:** Complex values are numeric, finite, and (when their real
and imaginary parts are integer-valued) integer — so `1+2i` passes all three
silently. Sizes, indices, counts, and most physical scalars should reject
complex values explicitly:

```matlab
function H = hilb2(n)
    arguments
        n (1,1) {mustBeInteger, mustBePositive, mustBeReal}
    end
    H = 1./((1:n)' + (0:n-1));
end
```

Add `mustBeReal` whenever a complex input would be nonsensical for the
function's contract.

### Computed defaults see PASSED values, not declared defaults

**WRONG belief:** Default expressions use the declared default values of earlier arguments.

**ACTUAL behavior:** Default expressions evaluate using the actual passed values.

```matlab
function out = myFunc(fs, windowSize)
    arguments
        fs (1,1) double {mustBePositive}
        windowSize (1,1) double {mustBePositive} = round(fs / 10)
    end
    out = windowSize;
end

myFunc(8000)      % windowSize = round(8000/10) = 800 (uses passed fs)
myFunc(8000, 256) % windowSize = 256 (explicitly passed)
```

This eliminates the need for sentinel values (`[]`) and post-validation fixup.

### `~` is a valid placeholder — don't rename it

**WRONG belief:** A name in the `arguments` block is mandatory, so a `~`
placeholder in the function signature must be renamed to `obj`/`this`/etc.

**ACTUAL behavior:** `~` is valid as an argument-block name (R2019b+). Keep it.

```matlab
function normalize(~, results)
    arguments
        ~
        results (1,:) struct
    end
    ...
end
```

When a method signature uses `~` to mark an unused input (e.g. an unused
class instance), **preserve the `~`** in the arguments block:

- **No class or size spec on `~`** — type specs like `(1,1) MetricCalculator`
  require a name, so adding one forces a rename. Skip the spec entirely.
- **No `%#ok<INUSL>` / `%#ok<INUSA>` / `%#ok<MANU>` pragma** — `~` already
  tells the lint pass the input is intentionally unused.
- **Don't rename `~` to `obj`** to "tighten validation." Renaming reintroduces
  the lint warning the original `~` was suppressing, with no contract benefit.

## Patterns

### Repeating Arguments

Use `arguments (Repeating)` for functions accepting variable groups of arguments (like `plot(x1,y1,x2,y2,...)`). Each declared variable becomes a **cell array** in the function body.

```matlab
function plotMultiSeries(x, y)
    arguments (Repeating)
        x (1,:) double {mustBeFinite}
        y (1,:) double {mustBeFinite}
    end

    figure;
    hold on;
    for i = 1:numel(x)
        plot(x{i}, y{i});
    end
    hold off;
end
```

Key rules:
- Variables become cell arrays — access with `x{i}`, not `x(i)`
- All variables in the group repeat together (complete sets)
- Repeating arguments cannot have default values
- Zero repetitions is valid (produces empty cell arrays)

### Output Argument Validation — `arguments (Output)` and `(Output, Repeating)`

> **R2022b+.** Output argument validation is unavailable in earlier releases —
> input validation (the bulk of this skill) works from R2019b onward.

Use `arguments (Output, Repeating)` to declare a function whose output count
scales with `nargout`. The block must declare **exactly one** name — MATLAB
rejects multi-name repeating output blocks with
`MATLAB:functionValidation:MultipleRepeatingOutputs`. To return groups of
related values (e.g. triples), pack them into the single output and have the
caller request `N * groupSize` outputs.

```matlab
function out = productTriples()
    arguments (Output, Repeating)
        out (1,1) double
    end
    out = cell(1, nargout);
    for k = 1:3:nargout
        b = rand;
        c = rand;
        out{k}   = b * c;
        out{k+1} = b;
        out{k+2} = c;
    end
end
```

Caller: `[p1, a1, b1, p2, a2, b2] = productTriples();`

Key rules:
- **One name only** — `arguments (Output, Repeating) a; b; c; end` errors at parse
- The output is assigned a `1×nargout` cell array; comma-list expansion at the
  call site distributes its contents across the requested LHS variables
- Validators on the single declared name apply to **each cell element**
- `nargout` tells the body how many outputs were requested; zero is valid

### Composition Rules — What Can Coexist

A function may have **multiple `arguments` blocks**. The rules below apply to
the function as a whole — argument categories must appear in this order across
all blocks combined:

```
required → optional (with defaults) → repeating → name-value
```

Violating the order at any point — even across separate blocks — fails to
parse. Don't trust intuition: **all of these compose legally in one function**:

- required + optional + repeating + name-value (`.?ClassName` allowed too)
- required + repeating + name-value
- repeating + name-value
- `(Output, Repeating)` plus any combination of input blocks
- `~` placeholders inside a `(Repeating)` block

**Multiplicity:**

| Block kind | How many allowed |
|------------|------------------|
| Plain `arguments` (positional and/or name-value) | Multiple, in order |
| `arguments (Repeating)` (input) | **Exactly one** per function |
| `arguments (Output, Repeating)` | **Exactly one** per function |
| Name-value structs across plain blocks | Multiple — different struct names |

**Parse-time error identifiers** — when in doubt, write the function and let
MATLAB tell you. These are the only errors composition can produce; the names
spell out the rule:

| Identifier | Means |
|------------|-------|
| `MATLAB:functionValidation:RequiredAfterOptional` | A required arg appears after one with a default |
| `MATLAB:functionValidation:OptionalAfterRepeating` | An optional/positional arg appears after the repeating block |
| `MATLAB:functionValidation:PositionalAfterNamed` | A positional or repeating arg appears after a name-value arg |
| `MATLAB:functionValidation:MultipleRepeatingBlocks` | More than one `(Repeating)` block (input or output) |
| `MATLAB:functionValidation:RepeatingHasDefault` | A `(Repeating)` arg has a default value |

If you're unsure whether a combination is legal, **don't fabricate a
restriction** — write a minimal version and run it. The error identifier (or
its absence) is the answer.

#### Maximal example

A single function with required + optional + ignored + repeating + ignored
repeating + name-value + class-imported name-value (here `SensorConfig` —
the class defined in the `.?ClassName` section above):

```matlab
function maximal(req, opt, ~, x, ~, options, classArg)
    arguments
        req (1,1) double
        opt (1,1) double = 7
        ~
    end
    arguments (Repeating)
        x (1,1) double
        ~
    end
    arguments
        options.Title (1,1) string = "default"
        options.Verbose (1,1) logical = false
        classArg.?SensorConfig
    end
    % function body
end
```

Call: `maximal(1, 2, 3, 4, 'a', 5, 'b', Title="t", SampleRate=44100)` —
parses and runs. `SampleRate` is one of the name-value args imported from
`SensorConfig` by the `.?` line.

**Don't pick a class with no public-settable properties** for `.?ClassName` —
`onCleanup`, for example, has only `task` (private set), so `.?onCleanup`
imports zero name-value args. The line is syntactically valid but a no-op,
and any "name-value" the caller writes against it is treated as an unknown
name — see "unknown `Name=Value` is silently swallowed" in Common Mistakes.

For combining repeating args with name-value options, see the Maximal
example above and [references/examples/repeating-args.md](references/examples/repeating-args.md).

### .?ClassName — Import Properties as Name-Value Args

Use `.?ClassName` in constructors to derive name-value arguments directly from property definitions. This avoids redeclaring properties in the arguments block.

For additional patterns — overriding specific properties, static factory with forwarding, and wrapping graphics-class properties — see [references/examples/dot-question-syntax.md](references/examples/dot-question-syntax.md).

```matlab
classdef SensorConfig
    properties
        SampleRate (1,1) double {mustBePositive} = 1000
        Resolution (1,1) double {mustBePositive, mustBeInteger} = 16
        FilterOrder (1,1) double {mustBePositive, mustBeInteger} = 4
        Label (1,1) string = "unnamed"
    end

    methods
        function obj = SensorConfig(nvArgs)
            arguments
                nvArgs.?SensorConfig
            end
            props = fieldnames(nvArgs);
            for i = 1:numel(props)
                obj.(props{i}) = nvArgs.(props{i});
            end
        end
    end
end
```

Benefits:
- No duplication of size, class, validators, or defaults
- Constructor stays in sync when properties are added or removed
- Tab completion shows all settable properties automatically

### namedargs2cell — Forward Name-Value Args

Use `namedargs2cell` to convert a validated struct back to a name-value cell array for forwarding to other functions:

```matlab
function obj = fromPreset(presetName, nvArgs)
    arguments
        presetName (1,1) string
        nvArgs.?SensorConfig
    end

    switch presetName
        case "audio"
            defaults = struct(SampleRate=44100, Resolution=24, Label="audio");
        case "vibration"
            defaults = struct(SampleRate=10000, Resolution=16, Label="vibration");
    end

    % Apply overrides
    overrides = fieldnames(nvArgs);
    for i = 1:numel(overrides)
        defaults.(overrides{i}) = nvArgs.(overrides{i});
    end

    args = namedargs2cell(defaults);
    obj = SensorConfig(args{:});
end
```

## Migration Decision Framework

When migrating from `inputParser` or `validateattributes`, use this decision tree for class handling:

| Original check | What it does | Arguments block equivalent | Why |
|---------------|-------------|---------------------------|-----|
| `@isnumeric` | Accepts any numeric, no conversion | `{mustBeNumeric}` | No class spec — avoids conversion |
| `@ischar` | Accepts char only | `{mustBeA(label, 'char')}` or `(1,:) char` | `mustBeText`/`mustBeTextScalar` widens to accept string |
| `@islogical` | Accepts logical only | `(1,1) logical` | Safe — nothing converts TO logical implicitly |
| `{'numeric'}` | Accepts any numeric, no conversion | `{mustBeNumeric}` | `validateattributes` meta-class — same set as `@isnumeric` |
| `{'float'}` | Accepts single or double | `{mustBeFloat}` | Equivalent to `{'single','double'}` |
| `{'integer'}` (class spec, rare) | Accepts only integer types (int8…uint64) | Usually `{mustBeNumeric, mustBeInteger}`. Strict-only-if-intentional: `{mustBeA(x, ["int8","int16","int32","int64","uint8","uint16","uint32","uint64"])}` | The class-only form rejects integer-valued doubles like `5.0` — usually accidental. Widen to the lenient pairing unless the original code clearly meant to reject doubles. |
| `{'numeric'}, {'integer'}` (class+attr) | Numeric, integer-valued | `{mustBeNumeric, mustBeInteger}` | Common pairing — accepts both int types and integer-valued floats |
| `{'single','double'}` | Restricts to float types | `{mustBeFloat}` | Class spec `double` would convert single→double |
| `{'double'}` exact | Rejects single, int, char | `{mustBeA(x, "double")}` | Class spec `double` would convert, not reject |
| `@(x) isa(x,'MyClass')` | Class membership | `{mustBeA(x, "MyClass")}` | Validates without conversion |

**Key principle:** If the original code REJECTS mismatched types, use validators (`mustBeA`, `mustBeFloat`, `mustBeNumeric`). If you WANT automatic conversion for caller convenience, use a class spec.

### Anonymous-Function Validators

Don't drop these on migration — each has a built-in equivalent:

| `inputParser` validator | Arguments block equivalent |
|-------------------------|----------------------------|
| `@(x) ~isempty(x)` | `{mustBeNonempty}` |
| `@(x) x > 0` | `{mustBePositive}` |
| `@(x) x >= 0` | `{mustBeNonnegative}` |
| `@(x) x < 0` | `{mustBeNegative}` |
| `@(x) x <= 0` | `{mustBeNonpositive}` |
| `@(x) isfinite(x)` | `{mustBeFinite}` |
| `@(x) isreal(x)` | `{mustBeReal}` |
| `@(x) isnumeric(x) && isreal(x)` | `{mustBeNumeric, mustBeReal}` |
| `@(x) ismember(x, set)` | `{mustBeMember(x, set)}` |
| `validatestring(x, set)` | **Don't replace with `mustBeMember`.** `validatestring` does case-insensitive prefix matching and returns the canonical form; `mustBeMember` is exact-match only. Keep the call inside the body and use the arguments block only for `{mustBeTextScalar}`. |

For detailed migration examples, see [references/migration-guide.md](references/migration-guide.md).

## Conventions

- **Prefer `string` over `char`** for new code (not migrations)
- **Never use `varargin` with manual parsing** when `arguments (Repeating)` or name-value blocks can express the same interface
- **Use `.?ClassName`** in constructors rather than redeclaring properties
- **Prefer computed defaults** (`= expression`) over sentinel values with `isempty` checks, when the default depends only on earlier arguments
- **Don't combine `mustBeNumeric` with a `double` class spec to reject non-numeric input** — the class spec converts char (`'A'` → `65`) before the validator runs, defeating the check. Drop the class spec: `x {mustBeNumeric}` not `x (1,1) double {mustBeNumeric}`
- **Don't combine text validators with a `string` class spec** — the class spec converts non-text (e.g., `42` → `"42"`) before the validator runs, defeating the check. Use text validators alone: `p {mustBeTextScalar}` not `p (1,1) string {mustBeTextScalar}`
- **Never reach for `varargin` + manual `class()` checks to reject types.** When a class spec like `double` would convert (rather than reject) char/single/int input, the right answer is a validator (`mustBeNumeric`, `mustBeFloat`, `mustBeA`), not a fallback to `varargin`. Falling back to `varargin` defeats the entire point of the arguments block.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `varargin` for repeated arg groups | Requires 30+ lines of manual parsing | `arguments (Repeating)` — 3 lines |
| Redeclaring properties in constructor | Duplication drifts out of sync | `nvArgs.?ClassName` |
| Believing `(1,:)` rejects columns | It silently reshapes them | Use `mustBeRow` to reject |
| Believing `double` rejects char | It silently converts to ASCII before validators run | Drop the `double` class spec and use `{mustBeNumeric}` alone, or `{mustBeA(x,"double")}` for strict class check |
| Using `[]` sentinel for computed defaults | Over-engineered, needs custom validator | `= expression` referencing earlier args |
| Replacing `@ischar` with `mustBeTextScalar` | Widens contract to accept strings | Use `mustBeA(x,'char')` for strict fidelity |
| Using `(1,1) string {mustBeTextScalar}` | Class spec converts `42` → `"42"` before validator | Use `{mustBeTextScalar}` alone (no class spec) |
| Replacing `validatestring` with `mustBeMember` | `validatestring` does case-insensitive prefix matching (`'AU'` → `'auto'`) and returns the canonical form; `mustBeMember` is exact-match only | Keep `validatestring` inside the body. Use the arguments block only for the type/size guard: `mode {mustBeTextScalar}` then `mode = validatestring(mode, {...})` |
| Omitting `mustBeReal` for numeric args | Complex values pass `mustBeNumeric`, `mustBeFinite`, and `mustBeInteger` silently — `1+2i` is a finite numeric integer | Add `mustBeReal` whenever a complex input would be nonsensical (indices, sizes, counts, physical scalars) |
| Renaming `~` to `obj`/`this` in arguments block | `~` is a valid placeholder name in arguments blocks — renaming reintroduces the lint warning the original `~` suppressed | Keep `~`, no class/size spec, no `%#ok` pragma |
| Declaring multiple names in `arguments (Output, Repeating)` | MATLAB errors with `MultipleRepeatingOutputs` — only one name is allowed | Declare a single output name; pack groups of values into that one cell array and have the caller request `N * groupSize` outputs |
| Claiming optional positional args and `(Repeating)` are mutually exclusive | They aren't — required + optional + repeating + name-value all compose legally in order | See "Composition Rules". When unsure, write the function and let MATLAB's parse-time error identifier (e.g. `OptionalAfterRepeating`, `PositionalAfterNamed`) tell you what's actually wrong |
| Assuming an unknown `Name=Value` errors loudly when the function has `arguments (Repeating)` | It doesn't. With a `(Repeating)` block present, an unrecognized `Name=Value` is silently absorbed as two **positional** repeating args (name token, then value). One bad pair also reclassifies preceding **valid** name-value args back to positional, so set options revert to their defaults. (Without `(Repeating)`, the same call errors with `MATLAB:TooManyInputs`.) | A common way to land here: `.?ClassName` against a class with no public-settable properties (e.g. `.?onCleanup`) — the import exposes nothing, so every NV the caller writes against it is unknown. Pick a class with public-set properties. When debugging "why is my NV default showing up?", check the call for **any** unrecognized `Name=` — one bad name poisons the whole NV section |

## Validators Quick Reference

| Validator | Purpose | Note |
|-----------|---------|------|
| `mustBeFloat` | Accept single or double only | Rejects int, char |
| `mustBeA(x, classes)` | Strict class check, no conversion | `mustBeA(x, ["single","double"])` |
| `mustBeBetween(x, lo, hi, type)` | Range check | R2025a+. Pre-R2025a: use `mustBeGreaterThan`/`mustBeLessThan` |
| `mustBeNonNan` | Reject NaN values | Built-in, not custom |
| `mustBeMatrix` | Require 2D (M-by-N) | R2024b+ |
| `mustBeRow` | Require 1-by-N | R2024b+. Rejects columns unlike `(1,:)` |
| `mustBeVector` | Accept row or column | Flexible orientation |
| `mustBeSorted` | Elements in sorted order | R2026a+ |

For the complete validator reference, see [references/validators-reference.md](references/validators-reference.md).

----

Copyright 2026 The MathWorks, Inc.

----
