---
name: matlab-set-up-worker-state
description: >
  Set up worker environment and per-worker state for parallel pools. Use when
  code needs paths, environment variables, database connections, loaded libraries,
  or expensive objects available on workers before parfor/parfeval runs. Teaches
  parallel.pool.Constant, parfevalOnAll, and parpool name-value pairs. Also use
  when refactoring existing code that uses spmd for side-effect setup (an
  anti-pattern). Triggers: worker setup, pool constant, per-worker state,
  non-serializable, loadlibrary on workers, database connection parfor,
  addpath workers, spmd before parfor, worker environment, reduce parfor
  overhead, parfor setup, resource creation in parallel loop,
  cannot serialize error, undefined function or variable on workers error,
  load data per worker, reduce data transfer, parallelize setup, improve parallel code.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Set Up Worker State for Parallel Pools

By default, process workers in a parallel pool inherit MATLAB path state from
their controlling client, but they do not inherit loaded libraries, open
connections, or expensive pre-computed objects. Code that relies on any of
these needs explicit setup. This skill teaches the correct APIs for each
scenario. Most patterns target process-based pools; thread pool applicability
is noted where relevant.

## When to Use

- Code needs a **non-serializable resource** on workers (database connections,
  COM objects, loaded shared libraries, file handles)
- Code needs **expensive one-time setup** per worker (large object construction,
  data loading) that should not repeat every parfor iteration
- Code needs **paths or environment variables** set on workers
- User has existing code using **spmd for side-effect setup** before parfor
  (anti-pattern — help them modernise)
- User sees errors about objects not being serializable when passed to parfor

## When NOT to Use

- Data already in client memory used in a single parfor loop (MATLAB broadcasts it automatically — Constant adds complexity for no benefit in this case)
- Choosing between process and thread pools (out of scope — this skill assumes a pool type is already chosen)

## Decision Framework

| Scenario | Correct API | Why |
|----------|-------------|-----|
| Non-serializable resource needing cleanup (connections, libraries) | `parallel.pool.Constant(@buildFcn, @cleanupFcn)` | Constructs on each worker; automatic cleanup on delete |
| Data from a file needed on workers | `parallel.pool.Constant(@() load(file).var)` | **Default for file-based data.** Each worker loads from disk; client never holds the dataset. Always prefer this when the source is a file. |
| Data already in client memory, used in multiple parfor loops | `parallel.pool.Constant(data)` | Transfers once for pool lifetime; without Constant, broadcast re-sends for every parfor loop. Not needed for a single parfor — let MATLAB broadcast. |
| One-shot side effect, no return value needed | `parfevalOnAll(pool, @fcn, 0)` | Runs once on all workers; use `fetchOutputs` to surface errors |
| Paths needed on workers — parpool call is in your code | `parpool(..., AdditionalPaths=paths)` | Cleanest option when you can modify the parpool call; client path entries are inherited automatically |
| Paths needed on workers — pool opened elsewhere (can't modify call) | `parfevalOnAll(pool, @addpath, 0, p)` | Never delete and recreate a pool just to add paths — use parfevalOnAll on the existing pool |
| Environment variables on workers — parpool call is in your code | `parpool(..., EnvironmentVariables=vars)` | Forwards named env vars from client to workers at startup; set values with setenv on the client before this call |
| Environment variables on workers — pool opened elsewhere (can't modify call) | `parfevalOnAll(pool, @setenv, 0, k, v)` | Never delete and recreate a pool just to set env vars — use parfevalOnAll on the existing pool |

**Thread pool notes:** `parallel.pool.Constant` and `parfevalOnAll` also work on
thread pools. However, thread workers share the client's process, so path and
environment variable changes on the client are visible to threads automatically —
`AdditionalPaths` and `EnvironmentVariables` do not apply. To modify a thread
worker's environment, alter the client environment before the parfor.

## The spmd Anti-Pattern

This applies equally to process pools and thread pools — prefer
`parallel.pool.Constant` over `spmd` for worker state setup regardless of pool
type.

### What it looks like

```matlab
% ANTI-PATTERN: Do not do this
spmd
    loadlibrary("mylib", "mylib.h");
end
parfor i = 1:100
    result(i) = calllib("mylib", "compute", data(i));
end
spmd
    unloadlibrary("mylib");
end
```

### Why it's fragile

1. **No cleanup guarantee** — if the parfor errors, the second spmd never runs
2. **Makes the pool fragile to worker disconnection** — once a pool has run an
   `spmd` block, a single worker losing connection tears down the entire pool.
   Pools that never use `spmd` continue operating with fewer workers if one
   disconnects (no replacement occurs — the pool simply shrinks).
3. **Composite variables cannot be used inside `parfor`** — values created in
   `spmd` are Composite objects that require indexing on the client; they
   cannot be referenced directly from within a `parfor` body

### How to modernise

Replace with `parallel.pool.Constant`:

```matlab
C = parallel.pool.Constant( ...
    @() loadAndReturn(), ...
    @(~) unloadlibrary("mylib")); %#ok<NASGU> — kept alive for cleanup

result = zeros(1, 100);
parfor i = 1:100
    result(i) = calllib("mylib", "compute", data(i));
end

% Cleanup happens automatically when C goes out of scope
```

Or with `parfevalOnAll` for simple side effects:

```matlab
f = parfevalOnAll(pool, @setupWorker, 0);
fetchOutputs(f);

result = zeros(1, 100);
parfor i = 1:100
    result(i) = doWork(data(i));
end
% No automatic cleanup
```

Prefer `parallel.pool.Constant` when cleanup is needed. Use `parfevalOnAll`
only for operations where cleanup is not required.

## Patterns

### Pattern 1: Loading data from a file for use in parfor

**Always use the build-function form when the source is a file.** This avoids
loading the data into client memory entirely — each worker loads directly from
disk. This is critical for large files but is also the correct default for any
file-based data because it scales without code changes as file size grows.

```matlab
c = parallel.pool.Constant(@() load("costSurface.mat").costSurface);

results = zeros(1, 10000);
parfor i = 1:10000
    results(i) = processWithLookup(input(i), c.Value);
end
```

Each worker calls `load()` once. The client never holds the full dataset.

**Do NOT do this** — loading on the client then wrapping defeats the purpose:

```matlab
% WRONG: loads entire file into client memory, then copies to each worker
data = load("costSurface.mat").costSurface;
c = parallel.pool.Constant(data);  % client already paid the memory cost
```

The only time `parallel.pool.Constant(data)` (without a build function) is
appropriate is when the data is already in client memory and used across
multiple parfor loops (avoids re-broadcasting each loop). For a single parfor
loop, just let MATLAB broadcast — Constant adds no benefit.

### Pattern 2: Shared library (non-serializable, needs cleanup)

```matlab
c = parallel.pool.Constant( ...
    @() loadLibraryAndReturn("mylib", "mylib.h"), ...
    @unloadlibrary);

results = zeros(1, 100);
parfor i = 1:100
    results(i) = calllib(c.Value, "compute", data(i));
end
% Cleanup runs automatically when c goes out of scope

function libName = loadLibraryAndReturn(libName, headerFile)
    loadlibrary(libName, headerFile);
end
```

The build function returns the library name so that `c.Value` is naturally
referenced in the parfor body — this triggers lazy initialisation. The cleanup
function receives the same value and calls `unloadlibrary` on it.

### Pattern 3: One-shot setup with parfevalOnAll (no cleanup needed)

```matlab
pool = gcp;
f = parfevalOnAll(pool, @setupWorker, 0);
fetchOutputs(f);
```

### Pattern 4: Database connection (use `createConnectionForPool`)

Database connections are a common specific case that requires Database
Toolbox. Prefer the purpose-built helper
[`createConnectionForPool`](https://www.mathworks.com/help/database/ug/createconnectionforpool.html)
over a hand-rolled `parallel.pool.Constant`. It returns a
`parallel.pool.Constant` whose value is a per-worker connection to the
configured data source, and it handles worker-side initialisation that a naive
`database()` call inside a Constant build function does not.

```matlab
pool = gcp;
c = createConnectionForPool(pool, "MyDataSource", "", "");

results = cell(1, 1000);
parfor i = 1:1000
    conn = c.Value;
    results{i} = fetch(conn, sprintf("SELECT val FROM t WHERE id=%d", i));
end
```


The returned Constant is the standard `parallel.pool.Constant` type, so it
participates in the normal lifetime model: connections are torn down when the
Constant goes out of scope or the pool shuts down.

## Recognising When pool.Constant Is Needed

Look for these signals in user code:

| Signal | Indicates |
|--------|-----------|
| Object created and destroyed every parfor iteration | Per-worker resource needed |
| "Cannot serialize" or "not valid on workers" errors | Non-serializable resource |
| `loadlibrary`/`unloadlibrary` inside parfor | Library should persist across iterations |
| `database()`/`close()` inside parfor | Connection should persist |
| `fopen`/`fclose` inside parfor (same file) | File handle should persist |
| Large variable used read-only in multiple parfor loops (>100 MB) | Send-once with Constant |
| `spmd` block doing setup before parfor | Modernise to Constant or parfevalOnAll |

## Common Mistakes

| What the agent does wrong | Why it's wrong | Correct approach |
|---------------------------|---------------|------------------|
| Uses `spmd` before parfor for setup | Fragile, no cleanup, pool tears down if any worker disconnects | `parallel.pool.Constant` with build + cleanup functions |
| Creates resource every iteration | Massive overhead (N connections for N iterations) | `parallel.pool.Constant` — one per worker |
| Uses persistent variables on workers | No cleanup, hard to reason about lifecycle | `parallel.pool.Constant` — explicit lifecycle |
| Tries to send non-serializable object from client | Will error — can't serialize connections, libraries | Use build function form: `parallel.pool.Constant(@buildFcn)` |
| Build function calls a function not on the worker path | Workers can't find it — "Unable to create parallel.pool.Constant on the workers" | Ensure build function helpers are on the path (or use `AdditionalPaths`). Local functions in the same file work — MATLAB captures them with the handle. |
| Uses `addpath` inside parfor on process pool | Runs every iteration unnecessarily | `parpool(..., AdditionalPaths=...)` or `parfevalOnAll` |
| Deletes and recreates pool to change paths or env vars | Extremely expensive — pool startup can take 30+ seconds and may queue on a scheduler | Use `parfevalOnAll` on the existing pool instead |

## Key Functions

| Function | Product | Available From | Purpose |
|----------|---------|----------------|---------|
| `parallel.pool.Constant` | Parallel Computing Toolbox | R2015b | Per-worker state with lifecycle management |
| `parfevalOnAll` | Parallel Computing Toolbox | R2013b | Run a function once on all workers |
| `parpool(..., AdditionalPaths=)` | Parallel Computing Toolbox | R2025a | Set worker paths at pool creation |
| `parpool(..., EnvironmentVariables=)` | Parallel Computing Toolbox | R2017b | Forward env vars to workers at pool creation |
| `createConnectionForPool` | Database Toolbox | R2019a | Per-worker database connections (optional) |

## Conventions

- Prefer `parallel.pool.Constant` over `spmd` for any worker state that persists across parfor iterations
- The build-function form (`parallel.pool.Constant(@buildFcn)`) is lazily initialised — the build function does not run until `c.Value` is first accessed on a worker. Always reference `c.Value` inside the parfor body to ensure initialisation occurs.
- Always provide a cleanup function when the resource needs explicit teardown
- Use `parfevalOnAll` only when no handle is needed back and no cleanup is required
- Use `parpool` name-value pairs when the setup is needed for the entire pool lifetime (paths, env vars)
- When modernising `spmd`-based setup code, preserve the original's intent (what resource, what cleanup) while switching to Constant

----

Copyright 2026 The MathWorks, Inc.

----
