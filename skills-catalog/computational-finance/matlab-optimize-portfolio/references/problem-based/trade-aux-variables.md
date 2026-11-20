# Linearize Trades with Auxiliary Variables

Use the magnitude aux (§1) when only `|w - w0|` matters; use the buy/sell
split (§2) when direction matters.

## 1. Trade magnitude via aux vars (`|w - w0|`)

**Use when** only the magnitude of `w - w0` matters — symmetric transaction
cost proportional to trade size, turnover cap, single-direction cap on
`|w - w0|`. No direction distinction; no fixed cost per trade.

**Decomposition.** Introduce a non-negative continuous aux vector `t` and
bound both sides:

```matlab
w = optimvar("w", nAssets, LowerBound=0, UpperBound=1);
t = optimvar("t", nAssets, LowerBound=0);              % t(i) >= |w(i) - w0(i)|

prob.Constraints.tPos = t >=  (w - w0);
prob.Constraints.tNeg = t >= -(w - w0);
```

The fold `t(i) = |w(i) - w0(i)|` holds at optimum only when `t` appears in
the objective with a strictly positive coefficient (a real cost, or a
downstream cap that binds). Otherwise `t` drifts to its upper bound — in
that case, use the buy/sell aux split from §2, which gives exact
magnitudes unconditionally. No binaries; problem stays LP / QP.

**Symmetric proportional cost:**
```matlab
tc = 0.001;                                              % per unit weight
prob.Objective = mu' * w - tc * sum(t);
```

**Turnover cap:**
```matlab
prob.Constraints.turnover = sum(t) <= 0.2;
```

For a **per-asset cap on `|w(i) - w0(i)|`** (e.g., "each asset can move by
at most 0.05"), do not introduce `t` — the cap folds into bounds on `w`:

```matlab
w = optimvar("w", nAssets, LowerBound=max(wLB, w0 - 0.05), UpperBound=min(wUB, w0 + 0.05));
```

Aux vars are only needed when the magnitude appears in the objective or in
a constraint that combines across assets (turnover, class-varying trade
cost caps).

**Do not** put `abs(w - w0)` directly in the objective. `abs()` on a signed
decision variable is nonlinear; `optimproblem` accepts it via
`fcn2optimexpr` but the dispatch drops to `ga`. Self-inflicted MINLP.

## 2. Buy/sell aux split

**Use when** the direction of each trade matters — anything that treats
buys and sells differently. Common triggers:

- Asymmetric proportional commissions (buy rate ≠ sell rate).
- Fixed per-buy and per-sell commissions.
- Tax-aware constraints — wash-sale blocks on **buys**, realized cap-gains
  on **sells**, tax-loss harvesting on **sell** decisions.
- Any other constraint that mentions "buys" or "sells" separately.

**Example — asymmetric per-lot commissions on round lots.** With `$5/lot`
buy and `$8/lot` sell, split direction into non-negative integer aux vars:

```matlab
lotSize = 100;

buyLots  = optimvar("buyLots",  nAssets, Type="integer", LowerBound=0);
sellLots = optimvar("sellLots", nAssets, Type="integer", LowerBound=0);

shares     = h0 + lotSize * (buyLots - sellLots);            % net share position
commission = 5 * sum(buyLots) + 8 * sum(sellLots);           % linear ($5/lot buy, $8/lot sell)
```

Objective (net expected profit):
```matlab
prob.Objective = mu' * (price .* shares) - commission;
```

Self-financing (dollar accounting, includes commissions):
```matlab
prob.Constraints.selfFinancing = ...
    price' * (lotSize * (buyLots - sellLots)) + commission <= 0;
```

`buyLots` and `sellLots` are non-negative and independent — the solver
drives one to zero at optimum per asset. Commission is linear. No `abs()`.
A heuristic solve (`ga`, for MIQP/MINLP) can return both a buy and a sell
on the same asset, paying commission twice. Net them after the solve:

```matlab
netLots  = round(sol.buyLots - sol.sellLots);
buyLots  = max(netLots, 0);
sellLots = max(-netLots, 0);
```

Netting keeps the position and lowers the commission, so self-financing
still holds. Recompute the objective and every reported figure from the
netted trades. If another constraint needs a *minimum* gross buy or sell,
add binaries and a `noBoth` constraint (fixed-fee example below) instead.

**Example — asymmetric fixed per-trade commissions on continuous weights.**
With a `$25` fixed fee on any buy and a `$30` fixed fee on any sell, the
direction determines the fee. Introduce two amount aux vectors and two
direction binaries per asset:

```matlab
buyAmt  = optimvar("buyAmt",  nAssets, LowerBound=0, UpperBound=1);
sellAmt = optimvar("sellAmt", nAssets, LowerBound=0, UpperBound=1);
isBuy   = optimvar("isBuy",   nAssets, Type="integer", LowerBound=0, UpperBound=1);
isSell  = optimvar("isSell",  nAssets, Type="integer", LowerBound=0, UpperBound=1);

prob.Constraints.balance = w == w0 + buyAmt - sellAmt;
prob.Constraints.buyUB   = buyAmt  <= isBuy;
prob.Constraints.sellUB  = sellAmt <= w0 .* isSell;
prob.Constraints.noBoth  = isBuy + isSell <= 1;

fixedFeeBuy  = 25;
fixedFeeSell = 30;
commission = fixedFeeBuy * sum(isBuy) + fixedFeeSell * sum(isSell);   % in dollars
```

If the fee is the *same* for buys and sells and no other constraint
discriminates direction, a single trade binary plus the magnitude aux
from §1 suffices and halves the binary count:

```matlab
t     = optimvar("t",     nAssets, LowerBound=0);
trade = optimvar("trade", nAssets, Type="integer", LowerBound=0, UpperBound=1);

M = 1;                                       % tight upper bound on |w - w0| when w in [0,1]
prob.Constraints.tPos    = t >=  (w - w0);
prob.Constraints.tNeg    = t >= -(w - w0);
prob.Constraints.tradeUB = t <= M * trade;   % if trade(i)=0, then t(i)=0 => w(i)=w0(i)

commission = 25 * sum(trade);                % in dollars
```

`M` is the per-asset upper bound on `|w(i) - w0(i)|`. When `w in [0, 1]`,
`M = 1` is tight. If leverage or short-selling permits `w` outside `[0,1]`,
raise `M` to the tight data-derived max — a loose `M` slows `intlinprog`;
an `M` below the actual max blocks legitimate trades.


----

Copyright 2026 The MathWorks, Inc.

----
