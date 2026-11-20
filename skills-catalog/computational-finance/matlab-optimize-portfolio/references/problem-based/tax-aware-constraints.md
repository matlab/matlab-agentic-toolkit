# Formulate Tax-Aware Constraints

## Wash-sale — historical (asset-level)

Block buys on assets tied to a recent loss trade. Vectorized indexing on
the buy indicator does exactly this:

```matlab
lossAssets = [3, 7, 12, 22];                              % from user data
buyAsset   = optimvar("buyAsset", nAssets, Type="integer", LowerBound=0, UpperBound=1);
prob.Constraints.washSaleHistorical = buyAsset(lossAssets) == 0;
```

Vectorized indexing on an `optimvar` expands into one equality per index.

## Wash-sale — within-optimization (lot-level)

When the model itself decides which loss lots to sell in this run, couple
the sell-of-loss-lot decision with the buy indicator for that asset.
Preprocessing (outside the model) identifies which lots are loss lots and
their asset index.

Two formulations are semantically equivalent for the standard rule
("selling any share from any loss lot of asset `a` blocks buying asset
`a`"). Both are correct — pick based on the size and structure of the
problem.

**Form A — per-loss-lot binaries (canonical).** One binary per loss lot.
Directly expresses "did this specific loss lot participate in a sale":

```matlab
% Preprocessing: nLossLots x 1 vectors.
lossLotShares      = [300; 100; 600];                  % example: shares held per loss lot
lossLots2AssetsIdx = [1; 1; 4];                        % example: asset index per loss lot
nLossLots = numel(lossLotShares);

lossLotShareSold = optimvar("lossLotShareSold", nLossLots, LowerBound=0);
lossLotSold      = optimvar("lossLotSold",      nLossLots, Type="integer", ...
                            LowerBound=0, UpperBound=1);

% Sell no more than the lot holds; couple amount to indicator
prob.Constraints.lossLotSaleUB = lossLotShareSold <= lossLotShares .* lossLotSold;

% If any loss lot on asset a is sold, cannot buy asset a
prob.Constraints.washSaleWithinOpt = ...
    buyAsset(lossLots2AssetsIdx) <= 1 - lossLotSold;
```

The vectorized indexing `buyAsset(lossLots2AssetsIdx)` expands per
loss-lot row.

**Form B — per-loss-asset binary with an auxiliary "loss activity"
variable.** One binary per *asset* with at least one loss lot, plus a
continuous aux capturing how much loss-lot activity is happening on that
asset. Fewer binaries when `nLossLots >> nLossAssets`. Equivalent for the
standard rule because the wash-sale trigger is asset-level — it does not
matter *which* loss lot on asset `a` was touched, only *whether* any was.

```matlab
% Preprocessing: nLossAssets x 1 vectors.
lossAssets = [1; 4];                                   % example: asset index per loss asset
lossActUB  = [400; 600];                               % example: upper bound on aux, per loss asset
nLossAssets = numel(lossAssets);

washBlk  = optimvar("washBlk", nLossAssets, Type="integer", ...
                    LowerBound=0, UpperBound=1);
lossAct  = optimvar("lossAct", nLossAssets, LowerBound=0);

% Any positive loss-lot activity forces washBlk = 1
prob.Constraints.washTrig = lossAct <= lossActUB .* washBlk;

% Block the corresponding buy when washBlk fires
prob.Constraints.washBlk  = buyAsset(lossAssets) <= 1 - washBlk;

% lossAct must be tied to actual loss-lot sales by an explicit accounting
% constraint (per-lot sell variables summed by asset, or lossAct >=
% totalSold - nonLossHoldings). Without that link, the wash block does
% not fire.
```

Trade-off: **Form A** is the safer default (direct mapping, no aux
accounting to get wrong). **Form B** cuts binaries when a few assets
carry many loss lots (20 loss lots across 3 assets → 3 binaries instead
of 20), at the cost of one aux variable per loss asset and an accounting
constraint that must be right.

## Realized cap-gains — per-lot G&L

The realized-gains constraint is a **$ cap** on realized gains across all
sold lots. When each lot's dollar gain-or-loss at current market is known
(a per-lot G&L, signed — positive for gain lots, negative for loss lots),
a partial sale of lot `k` realizes `f_k * G_k`.

```matlab
% Preprocessing: per-lot G&L vector, nLots x 1, signed $.
lotGL = zeros(nLots, 1);

% Per-lot fraction sold in [0,1]. Bind together with the Form A loss-lot indicators above
% so the same "fraction of lot k sold" appears in both constraints.
f = optimvar("f", nLots, LowerBound=0, UpperBound=1);

prob.Constraints.capGains = sum(f .* lotGL) <= capGainsCap;
% units: (fraction) * ($) = $  ✓
```

**Why per-lot G&L and not asset-level `price`/`basis`.** Two lots of the
same asset generally have different cost bases. Collapsing "the basis of
asset `a`" to a single number and using `(price(a) - basis(a)) *
sharesSold` mis-prices the cap-gains total whenever any asset has
multiple lots with distinct G&Ls. Per-lot G&L is the tax-correct
formulation and uses less data.

**Share-denominated form.** If the decision is lot-level shares sold, use
per-share G&L:
```matlab
gainPerShare = lotGL ./ lotShares;
prob.Constraints.capGains = sum(lotSharesSold .* gainPerShare) <= capGainsCap;
% units: shares * ($/share) = $  ✓
```

----

Copyright 2026 The MathWorks, Inc.

----
