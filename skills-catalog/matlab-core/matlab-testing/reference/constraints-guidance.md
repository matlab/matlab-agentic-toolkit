# Constraints and Assertions

Advanced verification techniques, tolerances, and custom constraints. For basic assertion usage (`verify*`/`assert*`, `verifyError`, `AbsTol`/`RelTol` syntax), see SKILL.md.

## Floating-Point Comparisons

`AbsTol` and `RelTol` are only supported on `*Equal` methods.

### Choosing Tolerances

| Scenario | Recommended |
|----------|-------------|
| Small values near zero | `AbsTol` only |
| Large values | `RelTol` only |
| Mixed magnitudes | Both |
| Single precision | `AbsTol=1e-6`, `RelTol=1e-5` |
| Double precision | `AbsTol=1e-14`, `RelTol=1e-12` |

## Diagnostic Messages

Add diagnostics when the failure cause wouldn't be obvious:

```matlab
testCase.verifyEqual(result, expected, ...
    sprintf('Failed for input=%d', input));
```

## Constraint Objects

Prefer informal APIs (`verifyEqual`, `verifyGreaterThan`, `verifySubstring`, etc.) over `verifyThat` with constraint objects. Only use `verifyThat` when no informal API exists.

### Informal API Mapping

Most constraints map directly to informal equivalents. Non-obvious mappings:

| Constraint class | Informal equivalent |
|---|---|
| `HasElementCount` | `verifyNumElements` |
| `ContainsSubstring` | `verifySubstring` |
| `MatchesRegexp` | `verifyMatches` |
| `Throws` | `verifyError` |
| `IssuesWarnings` | `verifyWarning` |
| `IssuesNoWarnings` | `verifyWarningFree` |

### When to Use `verifyThat`

No informal equivalent exists for these:

- `StartsWithSubstring`, `EndsWithSubstring`
- `IsFinite`, `IsReal`, `IsSameSetAs`
- `EveryElementOf(...)`, `AnyElementOf(...)`
- Boolean combinations (`&`, `|`, `~`)

```matlab
import matlab.unittest.constraints.*

testCase.verifyThat(value, IsEmpty | IsEqualTo(0));
testCase.verifyThat(x, IsGreaterThan(0) & IsLessThan(10));
testCase.verifyThat(array, EveryElementOf(IsGreaterThan(0)));
```

## Custom Constraints

Extend `matlab.unittest.constraints.Constraint` for domain-specific checks. Implement `satisfiedBy(~, actual)` (returns logical) and `getDiagnosticFor(constraint, actual)` (returns `StringDiagnostic`). Use via `testCase.verifyThat(value, MyConstraint)`.

----

Copyright 2026 The MathWorks, Inc.

----

