# Provider Protocol — make a domain pool speak the contract

Every downstream phase (selection, assessment, delivery, reporting) reads the
feature pool through **one contract** and never inspects the producer that built
it (see [feature-pool.md](feature-pool.md)). The default `generateFeatures`
(SMLT) path speaks that contract natively. A **domain skill** does not — it
returns a plain feature table and a procedure, not a self-describing artifact — so
its output must be wrapped into a compliant **Recipe** before the pipeline can
consume it.

This file is the provider-side specification: the exact shape a domain Recipe must
take, the one invariant it must uphold, and how that Recipe gets built. It freezes
what [domain-routing.md §5](domain-routing.md) ("Package the pool contract at run
time") and the contract-verb dispatchers already depend on.

---

## The two producer shapes

The contract verbs — `transformFeatures`, `describeFeatures`, and the
`selectFeatures` entry point — dispatch on the Recipe's *type*. There are exactly
two shapes, and a provider is always one of them:

| Recipe shape | Who produces it | How the verbs handle it |
|---|---|---|
| **SMLT `FeatureTransformer`** | `generateFeatures` / `gencfeatures` / `genrfeatures` | native: `transform` / `describe` methods, including native subsetting by `Index` |
| **Domain recipe struct** (`Kind == "domain"`) | assembled at run time when pool-building is routed to a domain skill | `.Apply` replays extraction; `.Describe` supplies definitions; the verbs subset by name (or use `.ApplySelected` for a cheaper subset) |

The SMLT shape needs no wrapping — the transformer *is* the Recipe. Everything
below is about the **domain recipe struct**: the only object a provider has to
construct.

---

## The domain Recipe struct

A domain Recipe is a **scalar struct** with these fields:

| Field | Type | What it is |
|---|---|---|
| `Kind` | `(1,1) string` | the literal `"domain"` — the type tag the dispatchers key on |
| `Apply` | `(1,1) function_handle` | maps the raw data (in whatever form the extraction consumes) to the **full** feature table (the replayed extraction) |
| `ApplySelected` | `(1,1) function_handle` | maps `(RawInput, SelectedNames)` to **only those** columns — requested separately at deliver time (see below) |
| `Describe` | `table` | a `Feature \| Type \| Definition` table, one row per feature |
| `Provider` | `(1,1) string` | free-text label for the source skill, used only in report prose |

Each verb reads only the field it consumes (`isDomainRecipe(Recipe, "Apply")` for
`transformFeatures`, `isDomainRecipe(Recipe, "Describe")` for `describeFeatures`),
so the dispatchers key on nothing more than `Kind` plus that one field. The recipe
is captured in **two requests**: at pool capture it carries `Kind`, `Apply`,
`Describe`, and `Provider` — the four fields generation, selection, and assessment
need — and `validateRecipe` confirms `Apply` and `Describe` faithfully match the
pool. `ApplySelected` is requested separately at deliver time, once selection has
fixed the feature set, and validated then (see [deliver.md](deliver.md)). A missing
or unfaithful artifact is a capture failure to send back to the domain skill, not
an optional extra.

### `Apply` — the replay

```matlab
Recipe.Apply = @(RawInput) < extraction that returns a feature table >;
```

- **Input: the raw data in its native form** — whatever the extraction actually
  consumes. For an ordinary tabular domain that is a `table`, but it may equally be
  a numeric matrix of signals, a cell array of images, or a `datastore`. The
  pipeline makes **no** assumption about the raw form; `Apply` is a black box mapping
  raw → feature table, so the raw type is the extractor's business alone.
- **Output: a `table` of engineered features — this is the one hard requirement.**
  `transformFeatures` errors with id `transformFeatures:domainNotTable` if `Apply`
  returns anything else. The output table's column names are the pool's feature
  names (the invariant below); the *input* type is unconstrained.
- It must be **self-contained and replayable** on *new* raw data — this is the
  inference artifact `writeInferenceScript` packages. If a domain procedure is too
  interactive to capture as a pure function of a raw table, say so plainly rather
  than emitting an `Apply` that cannot be re-run (see *Capture*, below).

### `ApplySelected` — the cheap inference path

`Apply` builds the whole pool; inference wants only the selected columns.
`ApplySelected` computes just those, so `transformFeatures` (and the emitted
script) use it for by-name subset requests instead of full-`Apply`-then-discard:

```matlab
Recipe.ApplySelected = @(RawInput, SelectedNames) < extraction of ONLY those columns >;
```

`RawInput` here is the same raw form `Apply` consumes — table, matrix, cell array,
whatever the extraction takes; only the return is constrained to a table.

- It must return the **same values** `Apply` would for those columns, named
  identically — an optimization, not a second definition. The missing-column guard
  runs on its output too, and deliver-time `validateRecipe` confirms it agrees with
  the pool.
- Not used for generation or k-fold (those need the full pool) or for a numeric
  index (name-based only) — there `transformFeatures` uses full `Apply`. It is
  requested only at deliver time, targeted at the selected set.

### `Describe` — the definitions

```matlab
Recipe.Describe = table(Feature, Type, Definition, ...
    VariableNames=["Feature", "Type", "Definition"]);
```

- Exactly three variables, named `Feature`, `Type`, `Definition`, each a string
  column. `describeFeatures` validates this shape and errors with
  `describeFeatures:domainMissingVars` if a variable is missing, or
  `describeFeatures:domainNotTable` if `Describe` is not a table.
- One row per feature the pool contains. `Feature` values must match the column
  names `Apply` produces (see the invariant below). `Type` is a short category
  label (e.g. `"spectral"`, `"statistical"`); `Definition` is a one-line
  human-readable account of how the feature was computed.

---

## The one invariant: identical column names

> **`Apply` must reproduce columns named *identically* to the pool the features
> were selected from, and `Describe.Feature` must list those same names.**

Selection produces a set of feature *names*. Inference reproduces the pool with
`Apply` and then subsets to those names; the report documents them by looking them
up in `Describe`. Both steps are **by name**, so a name mismatch breaks the
pipeline:

- If `Apply` renames or drops a selected column, `transformFeatures(Recipe,
  RawTbl, SelectedNames)` raises `transformFeatures:missingColumns`.
- If `Describe` omits a selected feature, `describeFeatures(Recipe,
  SelectedNames)` raises `describeFeatures:missingFeatures`.

The SMLT `transform`/`describe` methods guarantee this stability automatically;
a domain provider must guarantee it **by construction** — the extraction must be
deterministic in its naming, producing the same column name for the same feature
every time it runs. If `ApplySelected` is supplied it is bound by the same rule:
the columns it returns must be named identically to the ones `Apply` produces, or
`transformFeatures:missingColumns` fires just as it would on the full path.

---

## How a Recipe gets built

Whatever captured the pieces — `Apply`, `Describe`, `Provider` — the struct is
always assembled the same way, through the **`buildRecipe` constructor**:

```matlab
Recipe = buildRecipe(Apply, Describe, Provider, FeatureTable, RawInput, ...
    ResponseVar=ResponseVar, CheckIdx=TestIdx);
```

`buildRecipe` sets `Kind = "domain"`, packs the three pieces, checks their shape,
and runs the `validateRecipe` round-trip gate **inline** — so a recipe that is
missing a field or cannot reproduce its own pool fails at construction, not
silently downstream. A returned recipe is a proven one; there is no separate
"remember to validate" step. This is the single point both
[domain-routing.md](domain-routing.md) paths (subagent dispatch and inline
fallback) converge on, so downstream cannot tell which path built the pool.
`buildRecipe` is capture-time only — it builds the four fields generation /
selection / assessment need; `ApplySelected` is requested and validated separately
at deliver time.

The pieces `buildRecipe` consumes come from one of two sources; only the first is
exercised in the current build.

### 1. Orchestrator-capture (current mechanism)

The installed domain skills are **instruction-driven procedures**, not callable
APIs: they ship reference guidance, the orchestrator drives their MATLAB
extraction via MCP, and a feature table lands in the workspace. In that flow the
orchestrator **captures** the pieces from the commands it actually ran, then hands
them to `buildRecipe`:

- `Apply` = a function handle wrapping the exact extraction commands, parameterized
  on the raw data (in whatever form the extractor consumes — table, signal matrix,
  image cell array, datastore), so they replay on new data. Pass that raw form to
  `buildRecipe` as `RawInput` unchanged; do not coerce it to a table first (the only
  fixed contract is that `Apply` *returns* a table).
- `Describe` = assembled from the same commands — one row per produced feature,
  with a one-line definition of how each was computed. If the domain skill emits
  its own definition table, use it directly.
- `Provider` = the source skill's name.

This works for the currently-installed domain skills **unmodified** — they need
know nothing about this contract. Capture is best-effort: if a procedure cannot be
reduced to a replayable `Apply`, flag it rather than emit a broken Recipe.

### 2. Native compliance (authoring guide, for future providers)

A domain skill *can* be authored to return the pieces ready-made — its own `Apply`
handle and `Describe` table — so the orchestrator does no capture. That is the
cleaner long-term shape, but it is not required: it still hands those pieces to
`buildRecipe` like any other source, and because the dispatchers key only on
`Kind == "domain"` and the two field checks, a natively-supplied Recipe and a
captured one are indistinguishable to the rest of the pipeline.

---

## Minimal worked example

A trivial domain "extractor" over two raw columns, wrapped as a compliant Recipe:

```matlab
Apply = @(R) table(R.a + R.b, R.a - R.b, R.a .* R.b, ...
    VariableNames=["sum_ab", "diff_ab", "prod_ab"]);

Describe = table( ...
    ["sum_ab"; "diff_ab"; "prod_ab"], ...
    ["derived"; "derived"; "derived"], ...
    ["a plus b"; "a minus b"; "a times b"], ...
    VariableNames=["Feature", "Type", "Definition"]);

Recipe = buildRecipe(Apply, Describe, "demo", Pool, RawTbl, ResponseVar="y");
```

Downstream then treats it exactly like an SMLT recipe — the whole pool, a subset,
or its definitions — with no knowledge that it is domain-produced:

```matlab
FullPool  = transformFeatures(Recipe, RawTbl);                 % all three columns
Selected  = selectFeatures(Recipe, RawTbl, ["prod_ab","sum_ab"]);  % subset, in order
Defs      = describeFeatures(Recipe, ["prod_ab","sum_ab"]);    % their definitions
```

Note `sum_ab`/`prod_ab`/`diff_ab` are the same names in `Apply`'s output, in
`Describe.Feature`, and in the selected set — the invariant in miniature.

---

## Error-id reference

A malformed domain Recipe surfaces through these ids, so a provider can recognize
what its Recipe violated:

| Id | Raised when |
|---|---|
| `transformFeatures:unknownRecipe` | Recipe is neither a `FeatureTransformer` nor a `Kind=="domain"` struct with an `Apply` handle |
| `transformFeatures:domainNotTable` | `Apply` returned a non-table |
| `transformFeatures:missingColumns` | a selected column is absent from `Apply`'s output |
| `describeFeatures:unknownRecipe` | Recipe is neither a `FeatureTransformer` nor a `Kind=="domain"` struct with a `Describe` table |
| `describeFeatures:domainNotTable` | `Describe` is not a table |
| `describeFeatures:domainMissingVars` | `Describe` lacks a `Feature`, `Type`, or `Definition` variable |
| `describeFeatures:missingFeatures` | a requested feature is absent from `Describe.Feature` |

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See
[www.mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list
of additional trademarks.

----

Copyright 2026 The MathWorks, Inc.

----
