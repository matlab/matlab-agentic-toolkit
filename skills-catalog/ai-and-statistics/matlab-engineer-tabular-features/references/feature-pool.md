# Feature Pool — build the candidate feature set

This phase produces the **candidate feature pool** — the set of features that
selection will then evaluate. How many features that is depends entirely on the
producer: `gencfeatures` in generate-only mode emits a broad pool by design,
while a domain extractor may emit only a handful of well-motivated features.
Either is a complete pool.

This phase does not choose the final set — selection does. But **selection is not
guaranteed to reduce the pool.** Consensus ranking evaluates the whole pool and
keeps the set the evidence warrants; when the producer already emitted a compact,
well-motivated pool, that can be all of it. A broad `gencfeatures` pool almost
always gets cut down substantially; a small domain-extracted pool may pass
through largely or entirely intact. So do not assume, describe, or report
selection as a reduction step — it is an evaluation step whose *outcome* may or
may not be smaller than its input.

There are two ways to produce the pool, and they are interchangeable downstream:

- **Default (tabular):** `generateFeatures` wraps SMLT `gencfeatures` /
  `genrfeatures` in generate-only mode.
- **Domain (signals / time series / cycling data, etc.):** hand pool-building to
  an installed domain-specific feature-extraction skill (see
  [`domain-routing.md`](domain-routing.md)). Its feature table **is** the pool —
  do not run `gencfeatures` on top of it.

Whichever path runs, this phase returns the same three-part **pool contract**,
and every later phase reads only that contract — never the producer that built
it.

---

## The pool contract

| Member | Type | What it is |
|---|---|---|
| `FeatureTable` | table | the candidate pool: engineered predictors + the response column |
| `Recipe` | opaque | the per-generator artifact needed to reproduce the pool on new raw data |
| `describeFeatures(Recipe)` / `describeFeatures(Recipe, Index)` | fn → table | `Feature \| Type \| Definition` — one row per engineered feature; the optional `Index` returns just those features, in requested order |
| `transformFeatures(Recipe, RawTbl)` / `transformFeatures(Recipe, RawTbl, Index)` | fn → table | apply the recipe to new raw data, reproducing the engineered columns; the optional `Index` returns just the named/positional subset, in requested order |

`Recipe` is opaque on purpose: downstream code moves it around and calls the two
operations, but never inspects it. The two operations are the **only** way the
rest of the pipeline touches generator internals:

- **`describeFeatures`** feeds the report's *Selected Feature Definitions*
  chapter.
- **`transformFeatures`** is the inference operation — `writeInferenceScript`
  packages it so new raw data becomes the engineered+selected set with one call.
- Both take an **optional `Index`** (a string array of feature names, or numeric
  positions) as a trailing argument. Omitted, they act on the whole pool; supplied,
  they return exactly those features in the requested order. This is how the
  selected subset is reproduced/documented downstream. `selectFeatures(Recipe,
  RawTbl, SelectedNames)` is the named inference entry point and simply delegates
  to `transformFeatures(Recipe, RawTbl, SelectedNames)`.

> Naming: `transformFeatures` (our generic contract wrapper) is distinct from the
> SMLT method `transform` it calls under the hood. Keep them straight — the
> resemblance is intentional, not a typo.

### Contract bindings per producer

| Contract member | SMLT (`generateFeatures`) | Domain skill |
|---|---|---|
| `FeatureTable` | `gencfeatures`/`genrfeatures` output table | the feature table the skill produced |
| `Recipe` | the `FeatureTransformer` object | a captured extraction spec (packaged at run time) |
| `describeFeatures` | wraps `describe(Transformer)`, passing `Index` natively when given | the definition table the skill emits, subset by name |
| `transformFeatures` | wraps `transform(Transformer, RawTbl)`, passing `Index` natively when given | re-run the captured extraction, then subset by name |

The SMLT bindings ship as working code. The domain bindings are **assembled at
run time** by the orchestrator when it routes to a domain skill — see
[`domain-routing.md`](domain-routing.md) for the routing decision and
[`provider-protocol.md`](provider-protocol.md) for the Recipe struct shape it
must produce.

---

## Default path: `generateFeatures` (SMLT generate-only)

Assemble the optional name-value arguments in an `Opts` struct and forward them
with `namedargs2cell`, so the *same* call site works whether or not the
wide-input conversation added a `NumFeatures`. Never build the name-value list by
hand — let the struct carry only the options that apply:

```matlab
% Required positional args + the always-set options.
Opts.TargetModel = TargetModel;        % agnostic | tree_ensemble | linear | kernel_distance
Opts.Standardization = "auto";

% Wide-input guard (see below): only when the user chose a bounded pool or "skip".
% Leave Opts.NumFeatures UNSET to take the default full rich pool.
if UserChoseBoundedPool
    Opts.NumFeatures = ChosenQ;        % a custom q, or width(RawTbl)-1 for "skip"
end

OptArgs = namedargs2cell(Opts);
[~, Transformer, GenInfo] = generateFeatures(TrainTbl, Response, ProblemType, ...
    OptArgs{:});
```

Fit on the **training rows only** (`TrainTbl = ScreenedTbl(TrainIdx,:)`, the split
from `splitStrategy`) — this keeps the fitted transformer leakage-clean. The
all-rows engineered pool used for holdout scoring is materialized afterward by
replaying that transformer over every row (see *What downstream sees*). Key behavior
(full rationale in the function header):

- **Generate-only.** By default `NumFeatures` is unset, so the function requests
  an effectively-infinite feature count (`q = intmax('uint64')`) and the
  generator's own internal selection never trims the pool. Our external consensus
  selector does the cutting. The generator caps `q` at its true maximum and warns;
  that warning is expected and suppressed by exact id.
- **Wide-input guard.** The generators build features combinatorially, so a wide
  predictor table produces a huge, mostly-useless pool that is slow to build and
  rank. When `D` (predictor count) exceeds `MaxNumPredictors` (default 50) **and**
  no explicit `NumFeatures` was given, `generateFeatures` errors
  (`generateFeatures:tooManyPredictors`) rather than silently grinding. That error
  is the orchestrator's cue to **hold the wide-input conversation** (next section)
  and re-call with `Opts.NumFeatures` set. Below the threshold the unbounded
  default runs unimpeded.
- **`Response`** may be a bare variable name (`"Target"`) or a Wilkinson formula
  (`"Y ~ x1 + x2"`) — a formula is passed to the generator verbatim so it honors
  the predictor subset.
- **`TargetModel`** (`agnostic` | `tree_ensemble` | `linear` | `kernel_distance`)
  biases which candidates the generator prioritizes. The pool is taken whole, so
  this only shapes ordering, not membership.
- **Multi-class + binary-only learners.** `gencfeatures` binary-only learners
  hard-error on 3+ classes. The only response-dependent transform is
  Weight-of-Evidence (WoE), so generation runs under a deterministic dummy binary
  response and the WoE columns are flagged in `GenInfo.BinaryReliant`. Selection
  excludes them (pass `ExcludeFeatures=GenInfo.BinaryReliant`), so no
  dummy-response leakage reaches the delivered set.

`GenInfo` carries `.PoolSize`, `.TargetLearner`, `.Standardization`,
`.UsedDummyResponse`, `.BinaryReliant`, and `.Reasoning`. **Announce the pool
size** before selection.

### Wide-input conversation (D > MaxNumPredictors)

When the guard fires, don't proceed silently — tell the user the pool would be
large and slow, then offer two ways forward and re-call with the choice in
`Opts.NumFeatures`:

- **Bounded pool** — a custom `q` (e.g. `Opts.NumFeatures = 200`): the generator
  builds engineered features up to that total.
- **"Skip" generation** — `Opts.NumFeatures = width(RawTbl) - 1` (the predictor
  count): with `IncludeInputVariables="include"`, `q = D` yields the originals
  passed through and **no** engineered features, while still returning a real
  `FeatureTransformer` so the downstream contract is unchanged.

(Raising `Opts.MaxNumPredictors` above `D` is a third path — proceed unbounded on
wide data — but it is rarely what you want.)

The returned `Transformer` **is** the SMLT `Recipe` — nothing to bind. The
contract verbs are standalone functions that dispatch on the recipe type
internally (SMLT `FeatureTransformer` vs. a domain recipe struct), so the
orchestrator just calls them with the transformer directly:

```matlab
Recipe = Transformer;                                    % SMLT recipe is the transformer
FullPoolDesc = describeFeatures(Recipe);                 % whole pool
SelectedTbl  = transformFeatures(Recipe, RawTbl, SelectedNames);  % subset, in order
```

An omitted `Index` acts on the whole pool; a supplied one subsets natively, in
requested order. Only the **domain** path assembles bindings at run time (see
[`domain-routing.md`](domain-routing.md)), because a domain skill returns a plain
table rather than a `FeatureTransformer`.

---

## Domain path (summary)

When the data is not plain tabular predictors (1D signals, vibration / biosignal
/ radar traces, battery cycling data, rotating-machinery sensor streams, …) and
an installed skill covers that modality, route pool-building there instead. The
domain skill runs its own extraction procedure and yields a **feature table**;
that table is the pool. The orchestrator then packages `describeFeatures` /
`transformFeatures` bindings so the rest of the pipeline is unchanged.

The full matching / confirm / invoke / package / fallback protocol lives in
[`domain-routing.md`](domain-routing.md).

---

## What downstream sees

After this phase, regardless of path, the orchestrator holds:

- `Recipe` — the reproducibility artifact (the transformer, fit on train rows)
- `FullEng` — the engineered pool over **all** rows, response re-attached:
  `FullEng = transformFeatures(Recipe, ScreenedTbl); FullEng.(Response) = ...`.
  Because `Recipe` was fit on the training rows only, the held-out rows are pure
  inference — no leakage. Selection and the fixed-pool stability read take its
  **train slice** `FullEng(TrainIdx,:)`; the model-specific baseline scores the
  outer holdout over the whole table. (`transformFeatures` returns predictors
  only, hence the explicit response re-attach.) On the **domain path** the
  captured table already spans all rows — it *is* `FullEng`.
- `describeFeatures`, `transformFeatures` — the two contract operations
- generator metadata for the report (pool size, generator identity, any excluded
  columns)

Selection ([`select.md`](select.md)) takes it from here on the train slice.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
