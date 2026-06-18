---
name: matlab-diagnose-parfor
description: >
  Diagnose and fix parfor errors in MATLAB. Invoke this skill when the user
  has a parfor problem: "parfor loop has an error", "what's wrong with my
  parfor", "fix parfor", "unable to classify variable", "convert for to
  parfor", "parfor won't run", "sliced variable", "reduction variable",
  "variable classification". Also invoke when you read a .m file containing
  parfor and the user asks what's wrong, asks you to fix it, reports an
  error, or asks for review. Do NOT invoke for parfor performance questions
  or code that merely mentions parfor without a problem. ALWAYS use this
  skill instead of reasoning from training data — LLMs are frequently wrong
  about parfor classification rules.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Diagnose and Fix parfor Variable Classification

**Do NOT reason about parfor classification rules from memory.** LLM training
data contains incomplete and often incorrect explanations of these rules.
MATLAB's code analyser (`checkcode` / `codeIssues` / `mcp__matlab__check_matlab_code`)
is the only reliable authority — it implements the exact same classifier that
the runtime uses. Always run it first; never guess.

## When to Use

- ANY code involving `parfor` where the user reports a problem or asks for help
- User gets a parfor classification error (runtime or in editor)
- User wants to convert a `for` loop to `parfor`
- User asks why parfor complains, won't run, or is slow due to classification
- You are about to suggest changes to parfor code — run the analyser first

## When NOT to Use

- parfor runs but is **slow** — performance/pool-choice question, not a classification error
- Worker needs setup/state (paths, environment, toolboxes) — not a parfor variable problem
- Code simply mentions `parfor` but the user does not mention any problems with it

## Workflow

**Always follow this order. Never guess at classification rules.**

1. **Run the code analyser** on the file containing the parfor loop using
   the `mcp__matlab__check_matlab_code` MCP tool. Do NOT shell out to MATLAB
   via Bash — always use the MCP tool. Read the exact error message.

2. **Identify the error type** from the message (see table below).

3. **Apply the matching fix pattern** (see Patterns section).

4. **Verify** by re-running `mcp__matlab__check_matlab_code` on the fixed
   code — confirm zero parfor classification errors.

## Error Messages and Root Causes

For the full catalog of all 48 parfor analyser messages (with IDs), see
`references/parfor-analyser-messages.md`. The table below covers the most
common classification errors.

| checkcode message | Root cause | Fix pattern |
|-------------------|-----------|-------------|
| "Unable to classify variable 'X'" | Catch-all: many causes. Often invalid slicing (inconsistent subscripts, indexing not involving the loop variable) or invalid combinations of accesses (e.g. indexed reduction). Struct-field accesses are one specific way to trigger this. | Identify the specific access pattern, then restructure to fit one category or split conflicting roles |
| "multiple sliced accesses...do not all have the same list of subscripts" | Same variable sliced with different subscript patterns (e.g. `A{i,1}`, `A{i,2}`) | Use single assignment: `A(i,:) = {...}` |
| "Variable 'X' is indexed...but it is not a valid sliced output variable" | One subscript is non-deterministic (random, function call), or loop variable appears in multiple dimensions, or subscript pattern otherwise violates slicing rules | Pre-compute problematic subscripts, restructure to use loop variable in exactly one dimension with fixed remaining subscripts |
| "accessed with an invalid combination of sliced indexing expressions and non-indexed reads" | Variable is written with sliced indexing AND read whole in the same iteration — conflicting roles | Separate into two variables: one for sliced writes, a snapshot or broadcast copy for whole reads |
| "The temporary variable 'X' might be used after the PARFOR loop" / "Temporary variable 'X' must be set inside the parfor loop before it is used" | Variable is conditionally assigned (only in an if-branch), so MATLAB treats it as temporary — but it's used after the loop or read before being set on some paths | Restructure as sliced output (store per-iteration values) + post-loop reduction |
| "When indexing a sliced variable with a nested for loop variable, the range...must be a row vector of positive constant numbers or variables" | Inner `for j = 1:(expr)` where `expr` is not a literal constant or a broadcast variable | Make the inner loop range a constant or broadcast variable, or accumulate into a local temporary and assign the sliced variable once per outer iteration |
| "The entire array or structure 'X' is a broadcast variable" | Variable used whole (not indexed by loop variable); read-only | Not an error — performance warning. Use `parallel.pool.Constant(X)` if large |

## Variable Classification Rules (Reference)

parfor classifies each variable into exactly one category:

| Category | Rule | Example |
|----------|------|---------|
| **Loop** | The loop index variable | `parfor i = 1:N` |
| **Sliced** | Indexed by the loop variable in any one dimension (not just the first); the same subscript pattern is used in every access. The loop variable may be offset by a literal constant or a broadcast variable (e.g. `A(i+1,:)`, `A(:,i-k)` where `k` is broadcast). | `A(i,:) = ...`, `A(:,i) = ...`, `A(i+1) = ...` |
| **Broadcast** | Used whole (not indexed by loop variable); read-only | `total = sum(bigArray)` |
| **Reduction** | Form `X = X op expr` or `X = expr op X` where X is the entire variable, `op` is associative operator `+`, `.*`, `&`, `\|` etc. | `total = total + val` |
| **Temporary** | First use in iteration is an assignment; not used after loop | `temp = rand(10)` |

**Critical constraint:** A variable must fit exactly ONE category. Mixed usage
(e.g. struct fields used as reductions, or same variable sliced with different
subscripts) causes classification failure.

## Patterns

### Fix 1: Struct field as sliced output → plain array

**Error:** "Unable to classify variable 'out'"

The most common cause of "Unable to classify" with structs. Users write
`out.field(i) = someFcn()` expecting to slice into a struct field, but
first-level indexing on `out` is dot (`.field`), not parentheses. Sliced
variables require first-level `()` or `{}` indexing with the loop variable —
dot-indexing is never valid for slicing.

```matlab
% BROKEN: first-level subscript on out is dot, not paren
parfor i = 1:N
    out.x(i) = computeX(i);
    out.y(i) = computeY(i);
end
```

**Fix:** Use separate arrays for sliced output, pack into struct after the loop:

```matlab
xVals = zeros(1, N);
yVals = zeros(1, N);
parfor i = 1:N
    xVals(i) = computeX(i);
    yVals(i) = computeY(i);
end
out.x = xVals;
out.y = yVals;
```

A related variant: struct fields used as reductions (`results.sum = results.sum + val`).
The same rule applies — extract each field into its own scalar variable, reduce
independently, then pack the struct after the loop.

### Fix 2: Multiple sliced subscripts → single assignment

**Error:** "multiple sliced accesses...do not all have the same list of subscripts"

```matlab
% BROKEN: {i,1}, {i,2}, {i,3} are three different subscript patterns
output = cell(N, 3);
parfor i = 1:N
    [a, b, c] = computeStuff(i);
    output{i,1} = a;
    output{i,2} = b;
    output{i,3} = c;
end
```

**Fix:** Single parenthesis-indexed assignment with consistent subscripts:

```matlab
output = cell(N, 3);
parfor i = 1:N
    [a, b, c] = computeStuff(i);
    output(i,:) = {a, b, c};
end
```

Note: use `()` parenthesis indexing (assigns cells), not `{}` brace indexing when assigning
multiple cells.

### Fix 3: Invalid sliced subscript patterns

**Error:** "Variable 'X' is indexed...but it is not a valid sliced output variable"

A sliced variable must be indexed by the loop variable in exactly one
dimension, with the remaining subscripts fixed (literals, broadcast variables,
or colon). Three common violations:

```matlab
parfor i = 1:N
    out(i, randi(5)) = val;      % (a) non-deterministic subscript
    out2(i, 1:4, i) = row;      % (b) loop variable in two dimensions
    for j = 1:(N-1)
        out3(i, j) = fcn(i,j);  % (c) nested-for range is not constant
    end
end
```

**Fixes:**

(a) Pre-compute non-deterministic indices before the parfor, or accumulate
into a local temporary and assign a full row once:

```matlab
parfor i = 1:N
    localRow = zeros(1, 5);
    localRow(randi(5)) = val;
    out(i,:) = localRow;
end
```

(b) Remove the duplicate loop-variable dimension — restructure so `i` indexes
only one dimension:

```matlab
parfor i = 1:N
    out2(i,:) = computeRow(i);  % i in dim 1 only
end
```

(c) Make the nested-for range a constant or broadcast variable, OR collect
into a local variable and assign the sliced output once:

```matlab
innerN = N - 1;  % broadcast (constant before parfor)
parfor i = 1:N
    row = zeros(1, innerN);
    for j = 1:innerN
        row(j) = fcn(i, j);
    end
    out3(i, 1:innerN) = row;
end
```

### Fix 4: Sliced write combined with full read

**Error:** "Unable to classify variable 'data'"

A sliced *read* combined with a broadcast (whole) read is **legal** — the
variable simply "decays" to broadcast in that case. The unclassifiable
combination is a sliced **write** together with a full read of the same
variable in the same iteration. Often the whole read is simply attempting
to extract size or type information from the sliced output variable.

```matlab
% BROKEN: data is sliced-write (data(i,j) = ...) AND read whole (size(data,2))
data = buildMatrix(); % 
parfor i = 1:size(data,1)
    for j = 1:size(data,2) % This counts as a "full read" of data
        data(i,j) = myFunc(i,j);
    end
end
```

**Fix:** Extract the constant information needed ahead of the loop.

```matlab
data = buildMatrix();
[N,M] = size(data);
parfor i = 1:N
    for j = 1:M
        data(i,j) = myFunc(i,j);
    end
end
```

Note that if the "whole read" of a sliced output variable depends on the actual values within the
variable, then this fix is not appropriate, and may imply that iterations are not independent.

### Fix 5: Reduction not in standard form

**Error:** "Unable to classify variable 'X'"

A reduction must be exactly: `X = X op expr` or `X = expr op X` or `X = fcn(X, expr)` where `X` is
the entire variable (no indexing) and `op` is an associative operator `+`, `.*` etc.; `fcn` can be any
associative function such as `union`, `max` etc.

```matlab
% BROKEN: indexed reduction
counts = zeros(1, 5);
parfor i = 1:100
    bin = randi(5);
    counts(bin) = counts(bin) + 1;  % indexed reduction - not supported
end
```

**Fix:** Accumulate per-iteration, then reduce:

```matlab
counts = zeros(1, 5);
parfor i = 1:100
    bin = randi(5);
    localCounts = zeros(1, 5);
    localCounts(bin) = 1;
    counts = counts + localCounts;  % whole-variable reduction
end
```

### Fix 6: Temporary variable incorrectly flagged

If a variable is assigned before use in every iteration but checkcode still
warns, ensure the **first** reference in the iteration is a full assignment
(not indexed):

```matlab
% BROKEN: temp is not fully-assigned as first reference
parfor i = 1:10
    temp.a = rand();
    temp.b = 2*rand();
    result(i) = temp.a * temp.b;
end
```

**Fix:** Create `temp` in single assignment

```matlab
parfor i = 1:N
    temp = struct('a', rand(), 'b', 2*rand()); % Ok - single non-indexed assignment
    result(i) = sum(temp);
end
```

### Fix 7: Conditional update that needs to survive the loop

**Error:** "The temporary variable 'X' might be used after the PARFOR loop"

Any temporary variable is unavailable after the loop — this is a fundamental
parfor rule, not specific to conditional assignment. The "best so far" pattern
fails because `bestscore = score` inside a conditional doesn't match reduction
form (`X = X op expr`), so the classifier cannot treat it as a reduction. It
falls through to temporary, and temporaries are discarded when the loop ends:

```matlab
% BROKEN: bestscore doesn't match reduction form — classified as temporary
bestscore = -Inf;
parfor i = 1:N
    score = expensiveCompute(i);
    if score > bestscore
        bestscore = score;
        X = candidates(i);
    end
end
% bestscore and X are undefined here
```

**Fix:** Compute all candidates as sliced output, then reduce after the loop:

```matlab
scores = zeros(1, N);
allX = cell(1, N);
parfor i = 1:N
    scores(i) = expensiveCompute(i);
    allX{i} = candidates(i);
end
[bestscore, idx] = max(scores);
X = allX{idx};
```

## Conventions

- **ALWAYS run the code analyser before diagnosing.** Use
  `mcp__matlab__check_matlab_code` (MCP tool), `codeIssues` (R2022b+), or
  `checkcode`. The analyser implements the exact same classifier as the
  runtime — it is the ground truth. Never diagnose from memory alone.
- **ALWAYS verify the fix with the analyser** — re-run on the fixed file until there are 
  no further parfor errors before declaring success. Fixing one problem may reveal other problems.
- **Don't run the code** — the parallel pool may be slow or unavailable. The
  code analyser catches all classification errors statically.
- **Preserve semantics** — the fix must produce the same results as the
  original `for` loop.
- **Minimal changes** — fix only the classification issue. Don't restructure
  the entire algorithm unless the user asks.

----

Copyright 2026 The MathWorks, Inc.

----
