# Internal helpers — interface reference

These are the leaf helpers under `scripts/` that the **documented entry points**
(intake, feature-pool, select, assess, deliver, report) call internally. The agent
does not invoke them by hand during a run — it drives the pipeline through the
entry points, which wire these together. This file exists so every shipped script
has its name, inputs, outputs, and an example call documented in Markdown: at
runtime the agent never needs to open a helper's source to use it.

Seven of these are **p-coded at packaging** (marked ⓟ below). P-coding hides the
implementation, not the interface — the signatures here remain the contract. Call
them exactly as documented; do not rely on any internal behavior beyond what is
stated.

Every helper follows the MathWorks Coding Guidelines (`arguments` blocks,
lowerCamelCase, `end` terminators).

---

## Consensus voters

The selection layer runs several ranking methods, then fuses their rankings into
one consensus order. `createConsensusVoter` is the factory; the three concrete
voters differ only in how they score a feature from its positions across methods.

### `createConsensusVoter`

```matlab
Voter = createConsensusVoter(Method)
Voter = createConsensusVoter(Method, Name=Value)
```

Factory that returns a voter instance with `rank()` and `select()` methods.

- **Method** — `(1,1) string`, one of `"borda"`, `"majority"`, `"rrf"`.
- **Name-Value** — forwarded to the chosen voter: `Weights` (borda), `TopK`
  (majority), `K` (rrf).
- **Returns** — a `ConsensusVoter` subclass instance.

```matlab
Voter = createConsensusVoter("rrf", K=10);
[RankedIdx, Scores] = Voter.rank({r1, r2, r3}, nFeatures);
[Selected, Tbl]     = Voter.select({r1, r2, r3}, FeatureNames, 10);
```

### `ConsensusVoter` (abstract base)

Base class for the voters. Not instantiated directly — use the factory. Defines
the `select(Rankings, FeatureNames, NumSelect)` method (rank, then take the top
`NumSelect`) shared by every subclass.

### `BordaVoter`

Consensus by Borda count: a feature at rank *k* of *N* earns *N−k+1* points,
summed across methods. Favors features that rank consistently high everywhere.

```matlab
Voter = BordaVoter();                 % uniform method weights
Voter = BordaVoter(Weights=[1 2 1]);  % trust method 2 more
[RankedIdx, Scores] = Voter.rank({[3 1 2], [1 3 2]}, 3);
```

- **Property `Weights`** — `(1,:) double`, one per ranking; empty = uniform.
- **`rank(Rankings, NumFeatures)`** — `Rankings` is a `(1,:) cell` of index
  vectors; `NumFeatures` is the feature-universe size. Returns best-first
  `RankedIdx` and per-feature `Scores`.

### `MajorityVoter`

Consensus by majority vote: each method's top-*K* features get one vote; score is
the vote count. Binary — ignores rank within the top-*K*.

```matlab
Voter = MajorityVoter(TopK=5);
[RankedIdx, Scores] = Voter.rank({[3 1 2 5 4], [1 3 5 2 4]}, 6);
```

- **Property `TopK`** — `(1,1) double`; `0` (default) auto-sets to
  `ceil(nFeatures/3)`.
- **`rank(...)`** — same signature as `BordaVoter.rank`.

### `RRFVoter`

Consensus by Reciprocal Rank Fusion: score = `sum(1 ./ (K + rank))` across
methods. The reciprocal damps outlier ranks, so one method ranking a feature very
low barely moves the fused score.

```matlab
Voter = RRFVoter(K=60);   % K=60 is the standard constant; smaller K = top ranks dominate
[RankedIdx, Scores] = Voter.rank({[3 1 2], [1 3 2]}, 3);
```

- **Property `K`** — `(1,1) double`, positive, default `60`.
- **`rank(...)`** — same signature as `BordaVoter.rank`.

---

## Feature-ranking forks

Each fork runs one supervised ranking method over the whole predictor set and
returns a **complete** best-first permutation (never truncated), so a voter can
fuse full rankings. All share the signature
`RankedIdx = <fork>(Texp, y, ProblemType)`:

- **Texp** — `table` of predictors (numeric and/or categorical).
- **y** — response vector aligned to `Texp` rows.
- **ProblemType** — `(1,1) string`, `"classification"` or `"regression"`.
- **RankedIdx** — `(1,width(Texp))` best-first column indices into `Texp`.

```matlab
RankedIdx = mrmrFeatureRanking(Texp, y, "classification");
```

| Fork | Ranks by |
|---|---|
| `mrmrFeatureRanking` ⓟ | minimum-redundancy maximum-relevance |
| `oobFeatureRanking` ⓟ | bagged out-of-bag permuted predictor importance |
| `ncaFeatureRanking` ⓟ | neighborhood component analysis feature relevance |
| `lassoFeatureRanking` ⓟ | order of entry along a lasso penalty path |

The four forks are tuned to match the feature-generation stage's own selection
configuration, so their rankings are faithful to it.

### `expandBlockMap` ⓟ

```matlab
[BlockMap, Xexp, yPrep] = expandBlockMap(X, y)
```

Dummy-expands categorical predictors the way the fit-family learners do, and maps
each expanded column back to its origin predictor — so a length-*E* coefficient
vector can be collapsed to per-feature scores.

- **X** — `table` of predictors, no response column.
- **y** — response vector (numeric-coded for a lasso path, e.g. `grp2idx(y)-1`).
- **BlockMap** — `(1,E) double`; `BlockMap(j)` is the origin predictor index of
  expanded column *j*.
- **Xexp** — `(N,E) double`, expanded numeric predictor matrix.
- **yPrep** — response aligned to `Xexp` rows (NaN-response rows removed).

```matlab
[BlockMap, Xexp] = expandBlockMap(X, grp2idx(y)-1);
Score = accumarray(BlockMap(:), abs(Coef(:)), [width(X) 1], @max, 0);
```

### `lambdaSequence` ⓟ

```matlab
lambda = lambdaSequence(Xexp, y, ProblemType)
```

Builds the log-spaced lasso penalty sequence used by `lassoFeatureRanking`. The
largest value is the smallest penalty that zeros every coefficient.

- **Xexp** — `(N,E) double`, expanded predictor matrix (from `expandBlockMap`).
- **y** — `(N,1) double`, numeric-coded response aligned to `Xexp` rows.
- **ProblemType** — `(1,1) string`, `"classification"` or `"regression"`.
- **lambda** — `(1,100) double`, ascending penalty sequence.

---

## Mutual information and scoring

### `mutualInformationPanel` ⓟ

```matlab
[Ix, Iy] = mutualInformationPanel(X, y, ProblemType)
[Ix, Iy] = mutualInformationPanel(X, y, ProblemType, Name, Value)
```

The single MI kernel behind the model-free relevance and redundancy reads. Bins
predictors and response consistently with the MRMR ranking method, then estimates
MI on the bin codes.

- **X** — `(N,P)` numeric matrix or table; numeric columns are adaptively binned,
  categorical/ordinal detected and re-indexed, missing handled as code 0.
- **y** — `(N,1)` response; grouped into class codes for classification, adaptively
  binned for regression.
- **ProblemType** — `"classification"` or `"regression"`.
- **Name-Value** — `Verbose` (nonnegative integer, default 0), `UseMissing`
  (logical, default false).
- **Ix** — `(P,P)` MI (nats) among features, symmetric; off-diagonal is the
  redundancy read.
- **Iy** — `(P,1)` MI (nats) between each feature and the response — the relevance
  read.

### `macroF1Score`

```matlab
F1 = macroF1Score(TrueY, Scores, ClassNames)
```

Macro-averaged F1: per-class max F1 across thresholds (via `rocmetrics`),
averaged over classes.

- **TrueY** — `(:,1)` categorical or numeric true labels.
- **Scores** — `(N,K)` posterior scores from `predict`.
- **ClassNames** — `(1,K)` / `(K,1)` class names (from `model.ClassNames`).
- **F1** — `(1,1)` scalar.

### `nogueiraStability`

```matlab
[Stability, Info] = nogueiraStability(Z)
```

Chance-corrected selection-stability index (Nogueira, Sechidis & Brown, JMLR 2018,
eq. 2). Scores how consistently a selector picks the same features across runs.
Handles variable per-run subset sizes and is feature-type agnostic.

- **Z** — `(K,p)` binary matrix over a fixed feature universe; `Z(i,j)=1` if
  feature *j* was selected in run *i*. `K≥2` runs, `p≥1` features.
- **Stability** — `(1,1)` index (typically `[0,1]`; may be slightly negative;
  `1` = identical every run, `~0` = no better than chance).
- **Info** — struct: `.SelectionFrequency (1,p)`, `.MeanSubsetSize`, `.NumRuns`,
  `.NumFeatures`.

---

## Ranking utilities

### `rankFeatures`

```matlab
[RankedIdx, Scores] = rankFeatures(TrainX, TrainY, Method)
[RankedIdx, Scores] = rankFeatures(TrainX, TrainY, Method, Name=Value)
```

Unified supervised ranking dispatcher. Accepts a table for methods that support
mixed numeric/categorical input; extracts numeric columns automatically for the
numeric-only methods.

- **TrainX** — predictor table or matrix; **TrainY** — `(:,1)` response.
- **Method** — `(1,1) string`, one of `"fscmrmr"`, `"fsrmrmr"`, `"relieff"`,
  `"fscnca"`, `"fsrnca"`, `"lasso"`, `"chi2"`, `"ftest"`, `"sequentialfs"`,
  `"permutation"`, `"predictorImportance"`, `"stepwiselm"`, `"stepwiseglm"`.
- **Name-Value** — `ProblemType` (`"classification"`|`"regression"`, default
  classification), `MethodOptions` (`struct`).
- **RankedIdx / Scores** — best-first indices and their scores.

### `rankAgreement`

```matlab
[MeanRho, PairwiseRho] = rankAgreement(Rankings)
```

Mean pairwise Spearman correlation among ranking vectors — used to pick the
consensus voter (high agreement, `MeanRho ≥ 0.7`, favors Borda; low favors RRF).

- **Rankings** — `(1,M) cell`, each a `(1,P)` best-first index vector.
- **MeanRho** — `(1,1)` scalar; **PairwiseRho** — `(M,M)` symmetric matrix.

---

## Data-prep utilities

### `chooseNumBins`

```matlab
[NumBins, Info] = chooseNumBins(X, ContinuousMask, NEff)
[NumBins, Info] = chooseNumBins(X, ContinuousMask, NEff, Options)
```

Data-driven bin count for the chi-square / F-test filters (`fscchi2` / `fsrftest`),
replacing the fixed default of 10. Uses the median per-column Freedman-Diaconis
count, capped so the sparsest contingency cell stays populated (Cochran's rule) and
floored to keep resolution.

- **X** — table or numeric matrix of predictors.
- **ContinuousMask** — `(1,p) logical`, true for continuous predictors to bin.
- **NEff** — `(1,1)` effective sample size, already reduced to the binding
  constraint (minority-class count for classification, row count for regression).
- **Options** — `MinPerCell` (default 5), `MinBins` (default 5).
- **NumBins** — `(1,1)` positive integer.
- **Info** — struct: `.FDBins`, `.MedianFDBins`, `.ValidityCap`, `.Reasoning`.

### `chooseStandardization`

```matlab
[Mode, Reasoning] = chooseStandardization(RawTbl, Response, TargetModel)
```

Resolves the generator's `TransformedDataStandardization` mode from the numeric
predictors and the declared model family. Returns a concrete mode (never `"auto"`).

- **RawTbl** — table of raw predictors + response.
- **Response** — `(1,1) string`, response variable name.
- **TargetModel** — `(1,1) string`, `"agnostic"` | `"tree_ensemble"` | `"linear"`
  | `"kernel_distance"`.
- **Mode** — `(1,1) string`: `"none"` (tree ensembles), `"mad"` (heavy-skew
  predictors dominate), or `"zscore"` (scale-sensitive families, low skew).
  `"range"` is reached only via explicit override, never auto-selected.
- **Reasoning** — `(1,1) string`, justification citing the measured skew fraction.

### `sampleSkewness`

```matlab
S = sampleSkewness(Col)
```

Sample skewness (standardized third central moment) of a numeric vector.

- **Col** — `(:,1)` numeric vector (NaNs pre-removed).
- **S** — `(1,1)` scalar (`0` = symmetric).

### `stratifiedDownsampleRows`

```matlab
KeepIdx = stratifiedDownsampleRows(Response, MaxRows)
```

Row indices trimming a table to at most `MaxRows` while preserving class
proportions — bounds the cost of a stability read on large data. Applied once, up
front, before any resampling.

- **Response** — `(n,1)` response vector; its type decides stratification
  (categorical/logical/string → per-class `Holdout` trim; continuous → random
  draw).
- **MaxRows** — `(1,1)` positive integer, default 3000.
- **KeepIdx** — `(:,1)` sorted row indices to keep (all rows when `n ≤ MaxRows`).

### `isStringEmpty`

```matlab
Tf = isStringEmpty(Index)
```

True when an optional `Index` argument was effectively omitted — the empty
string/char default the contract verbs (`transformFeatures`, `describeFeatures`)
use to mean "no subset requested, return the whole pool". Numeric, logical, or
non-empty string returns false.

- **Index** — the value under test; **Tf** — `(1,1) logical`.

----

Copyright 2026 The MathWorks, Inc.

----
