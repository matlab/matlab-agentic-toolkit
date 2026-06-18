---
name: matlab-write-help
description: "Generate or improve MATLAB help text (documentation comments) for a function, class, or script file following MathWorks standards (H1 line, syntax paragraphs, See Also, 75-char lines). Read BEFORE writing MATLAB help — default patterns (Inputs:/Outputs: lists, block comments, uppercase See Also) produce non-conforming output. Use when writing, rewriting, fixing, or reviewing MATLAB help comments or function documentation."
license: MathWorks BSD-3-Clause
argument-hint: [name-or-path]
arguments: [file]
allowed-tools: Read(*) Edit(*) Bash(matlab *) mcp__matlab__evaluate_matlab_code(*)
metadata:
  author: MathWorks
  version: "1.0"
---

## When to Use

- Writing help text for a new MATLAB function, class, or script
- Rewriting or improving existing help text that is incomplete or non-conforming
- Reviewing help text for standards compliance
- Adding help to methods in a classdef file
- Generating property comments for a class

## When NOT to Use

- Writing general documentation or README files (not help comments)
- Generating code — this skill only produces help text
- Working with non-MATLAB languages
- Writing MATLAB Live Script markup (use plain-text-live-code guidelines instead)

## Task

Resolve `$file` to an M-file path and generate complete, standards-compliant MATLAB help text for it. If the file already has help text, improve it to meet the standards below. Present the proposed help text to the user for review before modifying the file.

## Standards for MATLAB Help Text

All rules below are mandatory. Violating any of them produces non-conforming help.

### General Rules

- Help begins on line 2 (after `function` or `classdef` line) for functions/classes
- Help begins on line 1 for scripts or built-in sidecar files
- Help comments must match the indentation of the body code.
  Look at the first non-comment content after the help block to
  determine the indentation level:
  - For `classdef` files: the body is `properties`/`methods` blocks,
    which are always indented 4 spaces → class help at 4 spaces
  - For `function` files: look at the first executable statement.
    If at column 1, help at column 1; if at 4 spaces, help at 4 spaces.
    Example at 4-space indent:
    ```
    function result = myFunc(x)
        %myFunc - Brief description
        %   RESULT = myFunc(X) does something with X.
        result = x + 1;
    end
    ```
  - For inline methods in classdef: if body is at 12 spaces, help at
    12 spaces
  Both styles are valid for top-level functions — match whichever one
  the file already uses. Do NOT change the file's indentation style
- No comment line may exceed 75 characters measured from the `%` onward
  (i.e., 75 characters of comment content including the `%` itself).
  If the `%` is indented, the total line width is indent + 75.
  Syntax lines are exempt (see below).

  Max column = indent + 75 (e.g., indent 12 → max col 87).
  Count from the `%`, not from column 1.
- No tabs — spaces only
- No trailing whitespace
- No block comments (`%{ %}`) — only `%` line comments
- No hardcoded links to documentation or webpages
- No `'href="matlab:'` evaluation links

### Section Order

1. H1 Line
2. Release Compatibility (if applicable)
3. Syntax Paragraphs
4. Example (optional)
5. See Also line
6. Note (optional)

A blank line (no `%`) separates help from the copyright line.

---

### Help Casing

When function or class names appear in help text (H1 lines, syntax
paragraphs, prose references, and See Also lines), they use **help
casing** to distinguish them from ordinary words. The `help` command
renders help-cased names as bold or hyperlinks.

Rules:
- Names that are entirely lowercase letters [a-z] are uppercased
  (e.g., `sort` → `SORT`, `magic` → `MAGIC`)
- Names that start with an uppercase letter but the remaining letters
  are all lowercase are also uppercased
  (e.g., `Table` → `TABLE`, `Handle` → `HANDLE`)
- Any other name (mixed case, digits, or underscores) keeps its exact
  original casing — do NOT uppercase it
  (e.g., `readTable` → `readTable`, `XMLReader` → `XMLReader`,
  `image_resize` → `image_resize`, `pdist2` → `pdist2`)

---

### H1 Line

```
%FUNCNAME - Brief description without a period
```

- Begins with `%` immediately followed by the function name in help
  casing (no space after `%`)
- Do NOT include namespace or class name
- ` - ` (space-dash-space) separates the name from the description
- Do NOT end with a period
- Description should be a brief summary of the function's purpose

---

### Syntax Paragraphs

```
%FUNC - Brief description without a period
%   B = FUNC(A,OPTION) does the thing with A using OPTION.
%
%   B = FUNC(A,Name=VALUE) also specifies a name-value argument.
```

Note: no blank `%` line between the H1 and the first syntax paragraph.

- One paragraph per syntax
- Each paragraph begins with the syntax it describes followed by a
  lowercase verb — the syntax reads as the subject of the sentence
  (e.g., `%   B = FUNC(A) does...` not `%   B = FUNC(A) Returns...`)
- Function name uses help casing
- All lines indented with three spaces after `%` (i.e., `%   `)
- No blank `%` line before the first syntax paragraph
- A blank `%` line separates each syntax paragraph
- Input ordering in syntax: Required → Optional → Name-Value
- The first syntax paragraph describes all required inputs only
- Each optional input gets its own syntax paragraph
- The first syntax paragraph shows only the primary output. Additional
  outputs are introduced one at a time in later syntax paragraphs —
  never jump from one output to all outputs at once. Each new output
  gets its own paragraph. This mirrors the input layering — start
  simple, add complexity one piece at a time. Examples:

  Two outputs — one additional paragraph:
  ```
  %   IDX = FINDNEAREST(POINTS,TARGET) finds the nearest point.
  %
  %   [IDX,DIST] = FINDNEAREST(...) also returns the distances.
  ```

  Three outputs — two additional paragraphs (not one):
  ```
  %   SEGMENTS = segmentSignal(DATA,THRESHOLD) segments the signal.
  %
  %   [SEGMENTS,BOUNDARIES] = segmentSignal(...) also returns the
  %   boundary indices where segments split.
  %
  %   [SEGMENTS,BOUNDARIES,LABELS] = segmentSignal(...) also returns
  %   string labels for each segment.
  ```
- Use `...` to abbreviate previously-described arguments when an optional
  applies to all prior syntaxes
- If a syntax exceeds 75 characters, the syntax itself is exempt from
  wrapping — keep it on one line. The description text that follows
  wraps normally starting on the next line. To shorten long syntaxes:
  - Abbreviate the LHS with `[...]` when outputs were described in an
    earlier syntax (e.g., `[...] = func(...,Name=VAL)`)
  - Abbreviate the RHS with `...` for previously-described inputs
  - Both abbreviations can be combined

#### Variable Naming in Syntaxes

- Inputs and outputs: use help casing
  — all-lowercase names become UPPERCASE; names with ANY uppercase
  letter, digit, or underscore keep exact original casing
  Examples: `data` → `DATA`, `method` → `METHOD`, `result` → `RESULT`,
  `depth` → `DEPTH`, `obj` → `OBJ`, `tf` → `TF`
  but `filePath` → `filePath`, `queryPoints` → `queryPoints`,
  `startSample` → `startSample`, `maxMemory` → `maxMemory`,
  `otherBuffer` → `otherBuffer`
  (these contain uppercase letters, so they keep exact casing)
- References to other functions in prose: use help casing — never
  fully-qualified for same-folder functions
- Generic logical outputs: use `TF`
- Generic data: single uppercase letters (`A`, `B`, `X`)
- Command-form arguments: all UPPERCASE

#### Flag (Option String) Inputs

```
%   B = SORT(A,DIRECTION) also specifies the sort direction. DIRECTION
%   must be:
%       "ascend"  - (default) Sorts in ascending order.
%       "descend" - Sorts in descending order.
```

- Flag name in UPPERCASE in the syntax
- Allowed values listed as double-quoted strings
- Values indented seven spaces after `%` (i.e., `%       `)
- Value separated from description by ` - ` (space-dash-space)
- Pad shorter values so dashes align vertically
- Indicate default with `(default)` at start of description
- Default value listed first

#### Name-Value Arguments

```
%   B = FUNC(A,...,Name=VALUE) also specifies the thing.
```

- Written as `Name=VALUE` with the value in UPPERCASE
- If the name-value has allowed values, list them using the same flag rules above

---

### Example Section

```
%   Example: Brief label describing the example
%       x = func(input1,input2);
%       disp(x)
```

- Only include an example if it helps illustrate non-obvious syntax usage
- Preceded by a blank `%` line
- Heading: `%   Example:` (or `%   Example: label`)
- Code indented seven spaces after `%` (i.e., `%       `)
- No control flow (`for`, `if`, `while`)
- Must run when copied to Command Window
- No more than 10 lines of code per example
- Separate multiple examples with a blank `%` line
- Do NOT number examples — use text labels on the heading line
- Use inline `% comments` to annotate code, not prose between lines

---

### See Also Line

```
%
%   See also readtable, griddedInterpolant, pdist2
```

- Preceded by a blank `%` line
- Begins with `%   See also ` (three-space indent)
- Names use their **original case-correct spelling** as they appear on
  the MATLAB path (e.g., `readtable`, `griddedInterpolant`, `pdist2`)
  — do NOT apply help casing to See Also names
- Use the shortest name that resolves. Functions on the MATLAB path
  without packages can use bare names. Functions in OTHER packages
  MUST be fully qualified (e.g., `pkg.subpkg.funcName`). Functions
  in the SAME folder (same package level) use bare names — they
  resolve relative to each other
- Do NOT reference private methods or private functions — they cannot
  be reached via `help` without full qualification, and even then only
  from within the class. In `@class` folders, any file that is not the
  class constructor is a method; check its Access before referencing it
- Methods in `@class` folders SHOULD have a See Also line referencing
  the class itself and relevant public methods or properties of the
  class, using unqualified names (e.g., `ClassName`, `methodName`,
  `propertyName`). Do NOT reference other private methods
- Separated by comma and space
- NOT terminated with a period
- Between 2 and 7 items
- Do NOT include descriptions — just names
- If the line exceeds 75 characters, wrap at a comma boundary:
  ```
  %   See also readtable, readtimetable,
  %   griddedInterpolant, scatteredInterpolant
  ```

---

### Note Section

```
%
%   Note: FUNC is in the Signal Processing Toolbox
```

- Preceded by a blank `%` line
- Begins with `%   Note: `
- Functions use their H1 casing
- Products use full names
- NOT terminated with a period

---

### Copyright Line

A copyright line is specifically a comment that matches:
```
%   Copyright YYYY
```
where the line starts with `%` followed by spaces, then the whole word
`Copyright`, then a four-digit year or year range (e.g.,`2024` or 
`2020-2025`). Other comments that merely contain the word "copyright" as
part of a function name or description are NOT copyright lines.

- The copyright is NOT part of the help text
- If a copyright comment exists in the file, ensure it appears after the
  help block, separated by a blank line (no `%` — just a newline)
- This blank line terminates the help block; MATLAB's `help` command
  stops reading at the first non-comment line
- The copyright line must be indented to match the help comments above it
- Do not add, remove, or modify the copyright — only move it if needed

---

### Class Help

For `classdef` files:

- Main class help describes construction (do NOT write separate constructor help)
- Construction syntax paragraphs follow the same required/optional rules:
  the first syntax shows required args only; each optional gets its own
  paragraph. Example for `MyClass(data, opts)` where data is required:
  ```
  %   OBJ = MyClass(DATA) creates an object from DATA.
  %
  %   OBJ = MyClass(DATA, sampleRate) also specifies the sample rate.
  ```
- After syntax paragraphs, include class detail listings:

```
%   CLASSNAME functions:
%       method1 - Brief description
%       method2 - Brief description
%
%   CLASSNAME properties:
%       Prop1   - Brief description
%       Prop2   - Brief description
```

- The heading MUST be `CLASSNAME functions:` — use the word
  **functions**, NOT **methods** (matches MATLAB's own `help` output).
  Never write `CLASSNAME methods:`
- List every public method and property
- Pad names so dashes align
- In the classdef file's own See Also, do NOT list the class's own
  methods or properties (they are already in the listings above)
- In method files (`@class` folder), DO reference the class itself
  and other public methods or properties — use unqualified names
  (e.g., `ClassName`, `methodName`, `propertyName`)

#### Property Help

**When generating help for a classdef file, always check that every
public property has a comment.** This is not optional and should not
require the user to ask — it is part of the standard classdef help
workflow. If any public property lacks a comment, add one.

Every public property should have at least a postfix comment:

Postfix (short, H1 only):
```
    PropName  % Brief description
```

Prefix (for longer descriptions):
```
    %PROPNAME - Brief description
    %   Additional detail about the property.
    PropName
```

If properties already have postfix comments, leave them as-is. Only add
missing ones. Do not duplicate the class-level properties listing — the
listing is a summary, while property-level comments are inline docs.

#### Method Help

Methods defined locally in a classdef file (not in separate `@class`
folder files) follow these rules based on access level:

**Public methods** get full function help:
- H1 line
- Syntax paragraph describing all inputs and outputs
- No blank `%` line between the H1 and the syntax paragraph
- Fill description text to the full 75-character width measured from
  `%` — do not wrap short
- The syntax itself (e.g., `%   OUT = func(A,B,C)`) is exempt from
  the 75-char limit — never wrap a syntax across lines. If the syntax
  exceeds 75 chars, put the description on the next line

```
        function result = myMethod(obj, x)
            %myMethod - Brief description
            %   RESULT = myMethod(OBJ,X) does something with X.
            result = x + 1;
        end
```

**Protected and private methods** get H1 only:
```
        function result = helperMethod(obj)
            %helperMethod - Brief description
            result = obj.data;
        end
```

**Exceptions** that get H1 only regardless of access:
- Property getters/setters (`get.Prop`, `set.Prop`)
- Constructors (class-level help covers construction)
- Trivial no-op methods (empty body)

**Overriding methods and help inheritance:**

When a subclass overrides a superclass method, MATLAB inherits the
superclass help if the override has none. Use this to avoid duplication:

- **Omit help** when the override does the same thing (different impl)
- **Write help** only when the contract changes (different inputs/outputs)

Write superclass help generically — describe *what*, not *how*.

Help for locally-defined methods is indented to match the method body
(typically 12 spaces when the `function` keyword is at 8 spaces).

Methods in separate files (`@class` folders) follow standard function
help rules independently — help indentation matches the body code
indentation of that file (column 1 if the body is at column 1, or
4 spaces if the body is indented 4 spaces).

---

## Using the arguments block for syntax paragraphs

When a function has an `arguments` block, read it to determine the correct
syntax paragraphs. The block tells you everything:

- **Required positional**: no `=` default value, no dot prefix
  ```
  inputData (1,:) double;
  ```
- **Optional positional**: has `= default`, no dot prefix
  ```
  method (1,1) string = "linear";
  ```
- **Name-value**: prefixed with a group name and dot
  ```
  opts.Tolerance (1,1) double = 1e-6;
  ```

Use this to generate syntax paragraphs:

1. **First syntax**: required positional args only → describe the base call
2. **Optional positional**: each gets its own paragraph with all prior args
   shown (or abbreviated with `...`)
3. **Name-value args**: show as `Name=VALUE` in additional syntaxes

Never write a raw internal variable name like `ARGS` in a syntax — expand
it into the actual name-value pairs the caller would use.

---

## Process

1. Resolve `$file` to a full file path:
   - If `$file` is already a valid absolute or relative path to an
     existing `.m` file, use it directly
   - Otherwise, resolve it via MATLAB using the MCP tool:
     ```matlab
     foundName = which("$file");
     if ~isempty(foundName), disp(foundName), end
     ```
   - If resolution fails (MCP unavailable, MATLAB not running, or
     name not found), report the failure and ask the user for
     a valid path
2. Read the resolved M-file
3. Identify: function, classdef, or script
4. If the function has an `arguments` block, read it to determine
   required, optional, and name-value arguments
5. Analyze the signature(s), inputs, outputs, and behavior
6. Draft help text following all rules above
7. For classdef files: check every public property for a comment. Add
   postfix comments to any that are missing — do this proactively as
   part of the draft, without waiting for the user to ask
8. Verify: no line > 75 chars from `%`, correct section order, correct
   indentation
9. Present the draft to the user
10. After approval, insert/replace the help text in the file using Edit

---

Copyright 2026 The MathWorks, Inc.
