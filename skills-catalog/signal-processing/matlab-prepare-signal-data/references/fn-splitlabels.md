# Function: `splitlabels`

> Used in: wf-load-and-split.md, wf-frame-and-label.md
> Toolbox: Signal Processing Toolbox

Stratified train/val/test splitter for a label source. Produces **index
sets** that you feed into `subset(ds, idx)` — does not slice the datastore
itself.

## Signature

```matlab
splitIndices = splitlabels(lblsrc, p)                    % stratified (default)
splitIndices = splitlabels(lblsrc, p, 'randomized')      % per-class shuffle
splitIndices = splitlabels(___, Name=Value)              % filters / table column
```

`lblsrc` accepts:
- **categorical / string / logical / numeric vector**
- **cell array** of character vectors / numeric / logical scalars
- **table** — set `TableVariable` to pick the column
- **datastore** whose `readall` returns one of the above
- **`CombinedDatastore`** — set `UnderlyingDatastoreIndex` to pick the constituent

`p` — proportions or counts. Vector of fractions summing to ≤ 1
(e.g. `[0.7 0.15 0.15]`), vector of integers (e.g. `[500 300]`), or
scalar in (0,1) for a single-cut.

> **There is no `'stratified'` literal flag.** `splitlabels` only accepts
> `'randomized'`. The default form (no flag) IS stratified — class
> proportions are preserved exactly in each bin. The `'randomized'` flag
> is also stratified but does an additional per-class shuffle so
> within-class order is randomized.

## Return shape — the most-replicated confusion point

`splitIndices` is **always an `(N+1)`-element cell array of index vectors**,
where N is the number of split ratios. The last cell holds whatever
fraction is left over (`1 - sum(ratios)`) and is **empty when
`sum(ratios) == 1`** — but it's still there.

For `ratios = [0.7 0.15 0.15]` → `splitIndices` is a `4×1` cell:
- `splitIndices{1}` — indices for the 70% bin (train)
- `splitIndices{2}` — indices for the 15% bin (val)
- `splitIndices{3}` — indices for the 15% bin (test)
- `splitIndices{4}` — empty (leftover; sum was 1.0)

```matlab
splitIndices = splitlabels(labels, [0.7 0.15 0.15]);
disp(class(splitIndices))           % cell
disp(size(splitIndices))            % [4 1]
disp(class(splitIndices{1}))        % double  — index vector into labels
disp(isempty(splitIndices{4}))      % true    — leftover bin is empty
```

Index the bins you asked for (`{1}`, `{2}`, `{3}`); ignore `{end}`.

## Canonical pattern

```matlab
splitIndices = splitlabels(labels, [0.7 0.15 0.15]);
sdsTrain = subset(sds, splitIndices{1});
sdsVal   = subset(sds, splitIndices{2});
sdsTest  = subset(sds, splitIndices{3});
```

## Anti-pattern

Don't use `cvpartition` for datastore-backed splits. `cvpartition` is the
Stats/ML default but requires materializing labels first and doesn't
compose with `subset(ds, idx)`.

```matlab
% Bad — Stats/ML reflex, doesn't compose with datastores:
c = cvpartition(labels, "HoldOut", 0.3);
trainLabels = labels(training(c));   % labels are split, but datastore isn't
% ... now you need to manually map back to sds indices.

% Good — splitlabels returns indices ready for subset:
splitIndices = splitlabels(labels, [0.7 0.15 0.15]);
sdsTrain = subset(sds, splitIndices{1});
```

## Stratification

`splitlabels` stratifies by default — class proportions in each split
match class proportions in the input. If a class has too few samples for
the requested ratios, `splitlabels` errors with a clear message.

```matlab
% Check distribution before splitting:
countlabels(labels)
splitIndices = splitlabels(labels, [0.7 0.15 0.15]);   % errors if infeasible
```

## Name-value arguments (all 4)

| NV-pair | Default | Purpose |
|---|---|---|
| `Include` | all categories | Vector or cell array of categories to include in the split. Categories must match those in `lblsrc`. |
| `Exclude` | none | Vector or cell array of categories to drop before splitting. |
| `TableVariable` | first table variable | Column to use when `lblsrc` is a table. Character vector or string scalar. |
| `UnderlyingDatastoreIndex` | required for `CombinedDatastore` | Integer scalar selecting which underlying datastore in a `CombinedDatastore` carries the labels. |

```matlab
% Filter a noisy label set and split only A/B/C:
splitIndices = splitlabels(labels, [0.7 0.15 0.15], ...
    Include=["A","B","C"]);

% Table input — pick the label column:
splitIndices = splitlabels(T, [0.7 0.15 0.15], TableVariable="ClassName");
```

## Gotchas

- **Output is cell, not vector.** The single most-replicated confusion.
  `subset(sds, splitIndices)` (without `{}`) errors.
- **Index space is 1..numel(labels).** Make sure `labels` and `sds.Files`
  are aligned — derive `labels` from the same `sds` that you'll subset.
- **Class proportions must support the split.** If a class has 2 samples
  and you ask for `[0.7 0.15 0.15]`, no integer split satisfies the ratios
  for that class. The function errors clearly.
- **Order within each split is randomized.** If you need reproducibility,
  set `rng(seed)` before the call.
- **`'stratified'` is not a valid third positional argument** — only
  `'randomized'` is accepted. Stratification is the default behavior, not
  an opt-in flag.

## See also

- `fn-subset.md` — consumes the returned cell entries.
- `fn-countlabels.md` — pre-flight distribution check.
- For the chain `splitlabels` → `subset`, see wf-load-and-split.md (step 4).

----

Copyright 2026 The MathWorks, Inc.

----
