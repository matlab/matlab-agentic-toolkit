# functionSignatures.json Rules

## Placement Rules

1. Regular functions in a folder → `<folder>/resources/functionSignatures.json`
2. Namespace (`+pkg`) functions → `resources/functionSignatures.json` in the **parent** of the outermost `+namespace`
3. Class (`@class`) in a namespace → same as namespace rule
4. Class outside namespace → `<folder>/resources/functionSignatures.json`

## What to Include

- All public functions (on MATLAB path)
- All namespace-qualified functions (`+pkg.func`)
- Class constructors and public static methods

## What to Skip

- Test files (in `tests/` or ending in `Test.m`)
- Scripts (no `function` keyword)
- GUI callbacks (`*_Callback.m` or `function name(hObject, eventdata, handles)`)
- Handle class definitions (methods get completion from the class definition)
- Private functions (users can't call them directly)
- Internal functions (discouraged from use — full qualified name signals "not for end users")

## Schema

Always include `_schemaVersion: "1.0.0"` at the top level.

## Extraction from `arguments` Blocks

```matlab
function result = myFunc(x, options)
    arguments
        x (1,:) double {mustBePositive}
        options.Method (1,1) string {mustBeMember(options.Method, ["fast","accurate"])} = "fast"
        options.Verbose (1,1) logical = false
    end
end
```

Maps to:

```json
{
  "_schemaVersion": "1.0.0",
  "myFunc": {
    "inputs": [
      {"name": "x", "kind": "required", "type": ["double", "row", "positive"], "purpose": "H1-derived description"},
      {"name": "Method", "kind": "namevalue", "type": ["string", "scalar", "choices={'fast','accurate'}"]},
      {"name": "Verbose", "kind": "namevalue", "type": ["logical", "scalar"]}
    ],
    "outputs": [
      {"name": "result", "type": ["double"]}
    ]
  }
}
```

## Type Mapping

| arguments block | JSON type |
|-----------------|-----------|
| `(1,1)` | `"scalar"` |
| `(:,1)` | `"column"` |
| `(1,:)` | `"row"` |
| `(:,:)` | `"2d"` |
| `double`, `single`, `string`, etc. | class name directly |
| `mustBePositive` | `"positive"` |
| `mustBeNonzero` | `"nonzero"` |
| `mustBeInteger` | `"integer"` |
| `mustBeMember(x, [...])` | `"choices={...}"` |

## Output Type Rules

- Outputs must use concrete class names (`"double"`, `"string"`, etc.) — NOT `"numeric"`
- If output type is unknown, use only size descriptors or omit `"type"` entirely
- Use `"inferredFrom:inputName"` when output type matches an input

## Validation

After generating, validate with MATLAB MCP:

```matlab
validateFunctionSignaturesJSON("path/to/resources/functionSignatures.json")
```

Ignore non-blocking warnings:
- "Function unrecognized by which" — folder not on path during validation
- "Unknown attribute or class" for toolbox-specific types — toolbox not installed

Fix and re-validate structural errors or invalid type specifications.

----

Copyright 2026 The MathWorks, Inc.

----
