# Formulate Either/Or Constraints with Big-M

**Use when** the constraint is either/or:
- **Min-trade**: `|w(i) - w0(i)| >= δ` **OR** `w(i) = w0(i)`.
- **Semi-integer position**: integer `n(i) = 0` **OR** `n(i) in {L, ..., U}`
  (lots or shares). With continuous `w` this is semi-continuous — use
  `Portfolio` conditional bounds instead.

Both shapes need direction binaries and both sides of the big-M inequality.

## Min-trade — pitfalls to avoid

**Do not** interpret min-trade as a semi-continuous bound on `w(i)`
(`w(i) = 0` OR `w(i) >= δ`). The constraint is on the *change*
`w(i) - w0(i)`, not the level `w(i)`. Semi-continuous on `w(i)` blocks
legitimate trades (trimming `0.15` to `0.03`, trade size `0.12 >= δ`,
becomes forbidden) and forbids "no trade" when `w0(i) ∈ (0, δ)`.

**Do not** code min-trade as `w(i) - w0(i) >= δ*buyH(i)` (and mirror for
sell) *without* the upper bounds. The only feasible choice is then
`buyH = sellH = 0`: with `buyH = 1, sellH = 0` the rows require
`w - w0 >= δ > 0` and `w0 - w >= 0` at the same time, which cannot hold
(mirror argument for `sellH = 1`). So `w = w0` is forced and no asset can
be traded.

## Correct min-trade formulation — PREFER the tight 3-family form

**Use this form.** Two direction binaries plus **three constraint
families** — one lower-magnitude family, one upper-magnitude family,
one mutex. Couple *both* binaries into *both* magnitude bounds, so a
single lower-bound family and a single upper-bound family cover both
trade directions. The coupling coefficients are the *natural per-asset
trade bounds* from `w`'s box `[wLB, wUB]`: max downside `(w0 - wLB)`,
max upside `(wUB - w0)`.

```matlab
w    = optimvar("w",     nAssets, LowerBound=wLB, UpperBound=wUB);
buyH  = optimvar("buyH",  nAssets, Type="integer", LowerBound=0, UpperBound=1);
sellH = optimvar("sellH", nAssets, Type="integer", LowerBound=0, UpperBound=1);

minTrade = 0.005;

prob.Constraints.minBuy  = w - w0 >= minTrade*buyH  - (w0 - wLB).*sellH;
prob.Constraints.minSell = w - w0 <= (wUB - w0).*buyH - minTrade*sellH;
prob.Constraints.oneSide = buyH + sellH <= 1;
```

Case analysis per asset: `(buyH=1, sellH=0)` → `w - w0 ∈ [minTrade,
wUB-w0]`; `(buyH=0, sellH=1)` → `w - w0 ∈ [-(w0-wLB), -minTrade]`;
`(buyH=0, sellH=0)` → `w = w0`.

Why this is tight: `(w0 - wLB)` and `(wUB - w0)` are the exact max trade
magnitudes allowed by the box bounds. Both binaries appear in both
magnitude constraints, so two magnitude families cover both directions
(instead of four). When `wLB = 0` and `wUB = 1`, the coefficients
collapse to `w0` and `(1 - w0)`. Do not hard-code these — with a
short-sale limit or a per-asset cap the general form differs and
hard-coding under-bounds trades.

**Constraint-count comparison.** For `n` assets, the 3-family form has
`3n` linear constraints for the disjunction (`n` per family × 3 families:
minBuy, minSell, oneSide). The 5-family textbook form below has `5n`
(minBuy, minSell, maxBuy, maxSell, oneSide). For `n = 10`: 30 vs 50
constraints, ~40% fewer rows.

**AVOID the 5-family textbook form** — separate `minBuy`/`minSell`
families using `M*(1-buyH)`/`M*(1-sellH)` **plus** separate
`maxBuy`/`maxSell` families with a global `M`. This is correct but
strictly dominated by the 3-family form above: doubles the disjunction
constraint count. Signals you are drifting into this trap: writing four
per-direction magnitude constraints (`minBuy`, `minSell`, `maxBuy`,
`maxSell`) instead of two; introducing a global scalar `M`; both
binaries appearing in only *one* of the two magnitude families instead
of both.

## Alternative — reusing trade-magnitude aux vars

If `dpos` and `dneg` already exist for `w - w0 = dpos - dneg` (say, to
charge commission on trade magnitude — see `references/problem-based/trade-aux-variables.md`), reuse them:

```matlab
dpos = optimvar("dpos", nAssets, LowerBound=0, UpperBound=wUB - w0);
dneg = optimvar("dneg", nAssets, LowerBound=0, UpperBound=w0 - wLB);
ybuy  = optimvar("ybuy",  nAssets, Type="integer", LowerBound=0, UpperBound=1);
ysell = optimvar("ysell", nAssets, Type="integer", LowerBound=0, UpperBound=1);

prob.Constraints.tradeSplit = w - w0 == dpos - dneg;
prob.Constraints.oneDir     = ybuy + ysell <= 1;
prob.Constraints.buyUB      = dpos <= (wUB - w0) .* ybuy;    % natural per-asset big-M
prob.Constraints.sellUB     = dneg <= (w0 - wLB) .* ysell;
prob.Constraints.buyLB      = dpos >= minTrade * ybuy;
prob.Constraints.sellLB     = dneg >= minTrade * ysell;
```

Same tight per-asset big-M as the primary form. Cannot collapse to three
families because `dpos` and `dneg` are separate non-negative variables —
each needs its own coupling constraint to be forced to zero when
inactive.

## Per-asset big-M from problem data

When the decision variable is share count on an unbounded upper side,
derive big-M per asset from portfolio value and price:

```matlab
M_i = floor(PV ./ price);           % max shares of asset i affordable with full PV
buyShares = optimvar("buyShares", nAssets, Type="integer", LowerBound=0);
z         = optimvar("z",         nAssets, Type="integer", LowerBound=0, UpperBound=1);

prob.Constraints.buyLink = buyShares <= M_i .* z;      % z(i)=0 => buyShares(i)=0
```

Tight is better than loose. `M = 1e6` "just to be safe" is slow.
`floor(PV/price(i))` is not necessarily the tightest bound (other
constraints may shrink it further) but is a cheap data-derived value.

## Semi-integer positions

Same shape — `lots(i) = 0` OR `L <= lots(i) <= U`, on an integer lot count:

```matlab
L = 10;    % minimum lots per held asset
U = 200;   % maximum lots per asset
lots = optimvar("lots", nAssets, Type="integer", LowerBound=0, UpperBound=U);
z = optimvar("z", nAssets, Type="integer", LowerBound=0, UpperBound=1);

prob.Constraints.lotsLB = lots >= L * z;
prob.Constraints.lotsUB = lots <= U * z;
```

When `z(i)=0`, both force `lots(i)=0`. When `z(i)=1`, `lots(i)` is an
integer in `{L, ..., U}`.



----

Copyright 2026 The MathWorks, Inc.

----
