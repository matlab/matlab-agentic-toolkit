---
name: matlab-instrument-opentelemetry-tracing
description: >
  Add OpenTelemetry tracing to MATLAB code. Use when the user asks to "add tracing",
  "instrument with spans", "add OpenTelemetry", "trace my code", "add observability"
  (when about tracing), or mentions "spans", "distributed tracing", or "OTel tracing"
  in the context of MATLAB functions. Covers span creation, parent-child context
  propagation, error handling, attributes, events, and semantic conventions.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Instrument MATLAB Code with OpenTelemetry Tracing

Add OpenTelemetry tracing spans to MATLAB functions with correct implicit context
propagation, RAII lifecycle, and semantic conventions.

## Prerequisites

The [OpenTelemetry-MATLAB](https://www.mathworks.com/matlabcentral/fileexchange/130979-opentelemetry-matlab) package (Version 1.11.0 or newer) must be installed. It provides the `opentelemetry.trace.*` namespace used throughout this skill. Requires MATLAB R2022b or newer.

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `opentelemetry.trace.getTracer` | Obtain a tracer instance by name | OpenTelemetry-MATLAB | R2022b |
| `startSpan` | Create a new span from a tracer | OpenTelemetry-MATLAB | R2022b |
| `makeCurrent` | Set span as current context (enables implicit parent-child) | OpenTelemetry-MATLAB | R2022b |
| `setAttributes` | Attach key-value metadata to a span | OpenTelemetry-MATLAB | R2022b |
| `setStatus` | Mark span as "Ok" or "Error" | OpenTelemetry-MATLAB | R2022b |
| `recordException` | Record an MException on a span | OpenTelemetry-MATLAB | R2022b |
| `addEvent` | Record a timestamped event within a span | OpenTelemetry-MATLAB | R2022b |
| `endSpan` | End a span mid-function (loops only) | OpenTelemetry-MATLAB | R2022b |

## MATLAB API Differences

The MATLAB OpenTelemetry API differs slightly from C++, Java, and Python implementations. Do not rely on general OTel knowledge from other languages — when unsure about a function, use `help opentelemetry.trace.Span` or similar to check what exists. Common traps:

- `setAttribute` (singular) does not exist — use `setAttributes` (plural)
- `opentelemetry.trace.StatusCode.Ok` / `StatusCode.Error` enums do not exist — pass the strings `"Ok"` or `"Error"` directly to `setStatus`

## When to Use

- User asks to add tracing or spans to MATLAB code
- User asks to instrument code with OpenTelemetry
- User asks to add observability and tracing is part of the request
- User wants parent-child span relationships across functions

## When NOT to Use

- User wants metrics only (counters, histograms, gauges) — no tracing skill needed
- User wants logging only (structured log records) — no tracing skill needed
- User wants to configure the TracerProvider/SDK (exporters, samplers, resource) — that belongs in a separate setup script
- User wants to propagate context across network boundaries (inject/extract into HTTP headers)
- User wants to instrument inside `parfor` loops — OTel context is not thread-safe in MATLAB

## Absolute Rules

These rules override all other considerations. Violating any of them produces incorrect instrumentation.

### 1. Never modify function signatures

Instrumentation must be invisible to callers. Never add parameters (tracer, context, span) to a function. Never change return values. Each function obtains its own tracer internally:

```matlab
tr = opentelemetry.trace.getTracer("tracer_name");
```

This is a cheap lookup from the global provider, not a resource allocation.

### 2. Spans are RAII — never call `endSpan` at function exit

The MATLAB Span object holds a C++ shared pointer. When the span variable goes out of scope (function returns, error thrown), the C++ destructor automatically ends the span. Only call `endSpan` when you need to end a span **mid-function** before the variable naturally goes out of scope.

### 3. Scope is RAII — never call `clear(scope)` at function exit

The Scope object returned by `makeCurrent` restores the previous context when it goes out of scope. Assign it to a variable to control its lifetime. The `%#ok<NASGU>` pragma suppresses the "unused variable" warning because the variable's lifetime is its purpose, not its value. Exception: inside loops, `clear` is required to restore the parent context before the next iteration (see loop pattern).

### 4. Always call `makeCurrent` on every span

Every span must be made current so child spans created in called functions automatically become children. Without `makeCurrent`, child spans become orphaned root spans.

### 5. Never pass explicit "Context" to `startSpan`

When `makeCurrent` is used consistently, `startSpan` automatically picks up the current span as parent. Passing `"Context"` explicitly is redundant and error-prone. The only exception is when creating a span that must be a child of a *different* span than the current one (rare).

### 6. Always set span status

Every span must have its status set before it ends:
- `setStatus(span, "Ok")` on the success path
- `setStatus(span, "Error", message)` on the failure path

A span without explicit status is ambiguous in trace viewers.

### 7. Use `getTracer` directly

```matlab
tr = opentelemetry.trace.getTracer("tracer_name");
```

Never use `opentelemetry.sdk.trace.TracerProvider()` or `opentelemetry.trace.Provider.getTracerProvider()` followed by `getTracer`. The one-liner above is the correct entry point.

### 8. Use snake_case attribute names with meaningful domain nouns

All attribute names must be lowercase, dot-separated, and use snake_case within each component. The namespace (left of the dot) must be a meaningful domain noun — not a generic word like "total", "numeric", or "count". See the Semantic Conventions section below for the full pattern and examples.

## Workflow

### Step 1: Analyze the code

Identify:
- Entry-point function (top-level function the user calls)
- Sub-functions and local functions that represent distinct units of work
- I/O operations (file read/write, network calls, database)
- Error-prone sections (file I/O, external systems, parsing)
- Computationally significant operations worth tracking

### Step 2: Choose a tracer name

Derive from the file name or containing package:
- `processSensorData.m` → `"processSensorData"`
- `+mypackage/analyze.m` → `"mypackage"`

All functions in the same workflow should share the same tracer name.

### Step 3: Instrument each function

Apply the core pattern to every function that represents a meaningful unit of work. Do not instrument trivial helpers (< 5 lines, no I/O) or functions called thousands of times in tight loops.

### Step 4: Add error handling where needed

Add try-catch with `recordException` only for functions that perform I/O or call external systems. Do not add try-catch around pure computation.

### Step 5: Add attributes and events

Add attributes that would help with debugging: input sizes, key parameters, output characteristics. Record events for significant milestones. Follow semantic conventions (see `references/semantic-conventions.md`).

### Step 6: Verify

Run the instrumented code via `mcp__matlab__evaluate_matlab_code` or `mcp__matlab__run_matlab_file` to confirm it executes without error.

## Core Pattern

This is the one correct pattern for every instrumented function:

```matlab
function result = processData(inputData, method)
    tr = opentelemetry.trace.getTracer("myService");
    span = startSpan(tr, "processData");
    scope = makeCurrent(span); %#ok<NASGU>

    % --- original function body (unchanged) ---
    result = transform(inputData, method);

    setStatus(span, "Ok");
end
```

Key points:
- `getTracer` inside the function — never passed as argument
- `startSpan` with no `"Context"` — inherits from current context automatically
- `scope = makeCurrent(span)` — makes this span the parent for any child spans
- `%#ok<NASGU>` — suppresses false warning; scope lifetime is the point
- `setStatus` before the function returns
- No `endSpan` — span ends via RAII when function returns

### Multi-function example

```matlab
function results = runPipeline(inputFile)
    tr = opentelemetry.trace.getTracer("pipeline");
    span = startSpan(tr, "runPipeline");
    scope = makeCurrent(span); %#ok<NASGU>

    data = loadData(inputFile);
    cleaned = cleanData(data);
    results = analyze(cleaned);

    setStatus(span, "Ok");
end

function data = loadData(filepath)
    tr = opentelemetry.trace.getTracer("pipeline");
    span = startSpan(tr, "loadData");
    scope = makeCurrent(span); %#ok<NASGU>

    data = readtable(filepath);

    setStatus(span, "Ok");
end

function cleaned = cleanData(data)
    tr = opentelemetry.trace.getTracer("pipeline");
    span = startSpan(tr, "cleanData");
    scope = makeCurrent(span); %#ok<NASGU>

    cleaned = rmmissing(data);

    setStatus(span, "Ok");
end

function results = analyze(data)
    tr = opentelemetry.trace.getTracer("pipeline");
    span = startSpan(tr, "analyze");
    scope = makeCurrent(span); %#ok<NASGU>

    results = summary(data);

    setStatus(span, "Ok");
end
```

Each function independently obtains a tracer and creates its own span. Parent-child relationships are established automatically through `makeCurrent`.

## Error Handling Pattern

Use for functions with I/O or external system calls:

```matlab
function data = fetchData(url)
    tr = opentelemetry.trace.getTracer("myService");
    span = startSpan(tr, "fetchData", SpanKind="client");
    scope = makeCurrent(span); %#ok<NASGU>
    setAttributes(span, "url.full", url);

    try
        data = webread(url);
        setAttributes(span, "http.response.status_code", 200);
    catch ME
        recordException(span, ME);
        setStatus(span, "Error", ME.message);
        rethrow(ME);
    end

    setStatus(span, "Ok");
end
```

Key points:
- `recordException` captures the full MException (identifier, message, stack trace, cause)
- `setStatus(span, "Error", ...)` marks the span as errored in trace viewers
- `rethrow(ME)` preserves the original error — span still ends via RAII after rethrow
- Both `recordException` and `setStatus` are needed: one records detail, the other sets the visual indicator
- `setStatus(span, "Ok")` goes **after** the try-catch block, not inside `try` — `rethrow` exits the function so "Ok" is only reached on success

## Attributes

Set attributes with `setAttributes` (plural, never singular `setAttribute` which does not exist):

```matlab
setAttributes(span, "input.rows", height(data), "input.columns", width(data));
```

Or using a dictionary at span creation:

```matlab
span = startSpan(tr, "processData", Attributes=dictionary( ...
    ["input.file", "input.format"], ...
    {filepath, "csv"}));
```

Numeric values do not need type casting — the API handles all MATLAB numeric types natively.

## Events

Record events for significant milestones within a span:

```matlab
addEvent(span, "validationComplete", "rows.valid", validCount, "rows.rejected", rejectCount);
```

## SpanKind

Set `SpanKind` only when the operation involves remote communication. Do not set it for internal operations (the default is `"internal"`).

| SpanKind | When | MATLAB examples |
|----------|------|-----------------|
| `"client"` | Outgoing request awaiting response | `webread`, `webwrite`, `ftp`, database queries |
| `"server"` | Handling an incoming request | MATLAB Production Server handler |
| `"producer"` | Initiating work without waiting | Publishing to a queue, enqueuing a batch job |
| `"consumer"` | Processing work from a producer | Queue listener, batch worker |

```matlab
span = startSpan(tr, "fetchData", SpanKind="client");
```

## When to Use `endSpan`

Only use `endSpan` when ending a span **mid-function** — before the variable would naturally go out of scope:

```matlab
function results = batchProcess(items)
    tr = opentelemetry.trace.getTracer("myService");
    span = startSpan(tr, "batchProcess");
    scope = makeCurrent(span); %#ok<NASGU>

    results = cell(numel(items), 1);
    for i = 1:numel(items)
        itemSpan = startSpan(tr, "processItem");
        itemScope = makeCurrent(itemSpan); %#ok<NASGU>
        setAttributes(itemSpan, "item.index", i);
        results{i} = processOne(items{i});
        setStatus(itemSpan, "Ok");
        endSpan(itemSpan);  % Needed: itemSpan must end each iteration
        clear("itemScope");  % Needed: restore parent context before next iteration
    end

    setStatus(span, "Ok");
end
```

Both lines at the end of the loop body are **mandatory**:
- `endSpan(itemSpan)` — ends the span's timing. Without it, the span duration extends until the variable is overwritten on the next iteration (wrong timing).
- `clear("itemScope")` — restores the parent span as the current context. Without it, `makeCurrent` on the next iteration would make the new span a child of the *previous* iteration's span (nested chain) instead of a sibling under the parent (correct flat list).

## Semantic Conventions

Attribute names must follow the `{object}.{property}` pattern:

- **Lowercase** and **dot-separated** — never camelCase
- **snake_case** within each component — `total_paths` not `totalPaths`
- **Namespace is a meaningful domain noun** — the word left of the dot must be a concrete object in the domain (e.g., `batch`, `file`, `result`, `data`), not a generic adjective or quantifier (`total`, `numeric`, `count`)

| Wrong | Right | Why |
|-------|-------|-----|
| `batch.totalPaths` | `batch.total_paths` | snake_case, not camelCase |
| `option.S0` | `option.initial_price` | descriptive, lowercase |
| `numeric.columns` | `data.numeric_columns` | "data" is meaningful domain noun; "numeric" is not |
| `total.paths` | `result.total_paths` | "total" is not a domain noun |

See `references/semantic-conventions.md` for full guidance on code attributes, file I/O attributes, HTTP client attributes, and domain-specific patterns.

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Pass tracer as function argument | Modifies the function API; breaks existing callers | Call `getTracer` inside each function |
| Pass context as function argument | Modifies the function API; makes instrumentation visible | Use `makeCurrent` — child spans inherit automatically |
| Call `endSpan` at function exit | Redundant — span ends via RAII; adds noise | Remove it; only use `endSpan` mid-function |
| Call `clear(scope)` at function exit | Redundant — scope restores context via RAII when function returns | Remove it; let the variable go out of scope. Inside loops, `clear` IS required — see loop pattern above |
| Pass `"Context"` to `startSpan` | Redundant when `makeCurrent` is used; explicit coupling | Omit it; `startSpan` uses current context |
| Omit `makeCurrent` in child function | Grandchild spans won't inherit context; breaks deep traces | Always call `makeCurrent` on every span |
| Use `setAttribute` (singular) | Does not exist in MATLAB OTel API | Use `setAttributes` (plural) |
| Omit `setStatus` | Span status is ambiguous in trace viewer | Always set "Ok" or "Error" |
| Wrap OTel code in `if isConfigured` | Unnecessary — OTel methods are no-ops when not configured | Remove the guard; instrument unconditionally |
| Use `TracerProvider()` then `getTracer` | Indirect; extra line of code for no benefit | Use `opentelemetry.trace.getTracer(name)` directly |
| Cast attributes to `int64` | Unnecessary — API handles all MATLAB numeric types | Use native types as-is |

## What NOT to Instrument

- Trivial helper functions (< 5 lines, no I/O)
- Functions called thousands of times in tight loops (overhead)
- Anonymous functions or callbacks (unless significant work)
- Code inside `parfor` blocks (context is not thread-safe)

----

Copyright 2026 The MathWorks, Inc.

----
