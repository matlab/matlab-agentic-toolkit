# Function: `partition` (Sense 2 — parallel)

> Used in: wf-parallel-process.md
> Toolbox: MATLAB datastore API (works on `signalDatastore`)

Slice a datastore into N **shards** for parallel processing across workers.
**This is the parallel sense of partition** — distinct from `subset(ds, idx)`
which carves out train/val/test on a single worker.

## Two senses of "partition" — disambiguate

| Sense | Function | Use when |
|---|---|---|
| **1. Split** (single-worker train/val/test) | `subset(ds, idx)` | You have indices from `splitlabels` and need three datastores. See fn-subset.md. |
| **2. Parallel** (multi-worker sharding) | `partition(ds, N, k)` | You're inside a `parfor` and want each worker to process a disjoint share of files. **This file.** |

If you searched `partition` and meant the split sense, see fn-subset.md
instead.

## Signature

`partition` has two forms on `signalDatastore`:

```matlab
shardDs   = partition(ds, N, k)         % N-shard form (parallel)
fileDs    = partition(ds, "Files", k)   % single-file form
```

| Form | Args | Returns |
|---|---|---|
| N-shard | `ds`, integer `N`, integer `k` (1..N) | A `signalDatastore` shard with roughly `numel(ds.Files)/N` files. |
| Single-file | `ds`, the literal `"Files"`, integer `k` | A `signalDatastore` containing only `ds.Files{k}` (one file). |

For the N-shard form, shards are **disjoint** and **exhaustive** (their
union is exactly `ds.Files`); within each shard the relative order of
`ds.Files` is preserved.

## Canonical pattern

```matlab
sds = signalDatastore("dataset", FileExtensions=".mat", ...
    SignalVariableNames="x");

pool = gcp("nocreate");
if isempty(pool)
    pool = parpool;
end
N = pool.NumWorkers;

results = cell(1, N);
parfor k = 1:N
    workerDs = partition(sds, N, k);
    workerOut = [];
    while hasdata(workerDs)
        s = read(workerDs);
        workerOut(end+1) = rms(s); %#ok<SAGROW>
    end
    results{k} = workerOut;
end
results = [results{:}];
```

## Anti-pattern

Don't `parfor i = 1:numel(ds.Files)` constructing a fresh datastore per file.
That spawns `N=files` datastores instead of `N=workers` and defeats the
partition abstraction (no shared metadata, no batched reads).

```matlab
% (Assume sds and N have been built as in the Canonical pattern above.)

% Bad — one datastore per file, on the worker:
parfor i = 1:numel(sds.Files)
    workerSds = signalDatastore(sds.Files{i});  % fresh per file
    s = read(workerSds);
    results(i) = rms(s); %#ok<SAGROW>
end

% Good — one datastore per worker, sharded:
parfor k = 1:N
    workerDs = partition(sds, N, k);
    while hasdata(workerDs)
        s = read(workerDs);
        % accumulate ...
    end
end
```

## Bootstrapping

You need `N` (`pool.NumWorkers`) **before** the `parfor` to call
`partition(ds, N, k)`. `parfor` will spin up a pool implicitly, but you
can't read `NumWorkers` until the pool exists. Bootstrap explicitly:

```matlab
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool;
end
N = pool.NumWorkers;
```

## Gotchas

- **Shards are contiguous alphabetical blocks, not round-robin.** Shard 1
  gets the alphabetically-first `numel(ds.Files)/N` files, shard N gets
  the last. If your files are class-grouped by name, all of one class
  can land on a single worker — don't assume `partition` randomizes.
- **Shards are by file count, not by data size.** If files have very
  uneven length, workers will see uneven runtime. For balanced parallelism
  with skewed file sizes, group files into bins of equal total size first
  and partition over the bins, or use `numpartitions(ds, pool)` for the
  documented size-aware partition count.
- **`partition(ds, N, k)` returns a datastore, not data.** You still need
  `read` / `readall` / `hasdata` on the shard.
- **Don't mix Sense 1 and Sense 2 in the same script.** `subset(ds, idx)`
  in a `parfor` body works but is a code-smell — if you need
  `splitIndices{1}` per worker, partition the train datastore once before
  the `parfor` and subset on a single worker.
- **`transform`/`combine` outputs are not always partitionable.** Plain
  `signalDatastore` is partitionable; the result of `transform(sds, fn)`
  or `combine(a, b)` may not be. Check before partitioning:
  `if isPartitionable(ds), workerDs = partition(ds, N, k); end`. If the
  derived datastore is not partitionable, partition the underlying
  `signalDatastore` first and apply `transform`/`combine` per worker.

## See also

- `fn-subset.md` — Sense 1 of partition (single-worker, index-based).
- `wf-parallel-process.md` — full workflow including pool bootstrap and
  result reduction.

----

Copyright 2026 The MathWorks, Inc.

----
