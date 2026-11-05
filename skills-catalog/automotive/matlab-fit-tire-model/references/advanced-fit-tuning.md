# Advanced: Fine-Tune the Fit on User Request

Load this when the user explicitly asks to steer or fine-tune a force-and-moment fit (Step 7).
The normal path passes `fit` no options and you never change that on your own initiative; apply
the options below only when the user asks.

The normal path passes `fit` no options: the API's fitter picks the parameter set, bounds, and
solver, and every data point counts equally. Never change that on your own initiative to chase
a lower in-sample residual. A user may ask to steer the fit, and each option below is a normal,
supported way to do so, applied only when the user asks. All of them are meaningful only for the
optimizer-driven force and moment fits; `Nominal`, `Limits`, and `Dimensions` short-circuit the
optimizer and ignore them, emitting `vdyntire:warnings:ignoredInputsDependent`.

**`Weight`** emphasizes some data points over others. A cell array, one numeric vector per
routed `tireData` object in `Data`, each vector's length equal to that object's `dataLength`.
*Guardrail:* the weights are relative (`fit` normalizes with `sqrt(Weight/sum(Weight))`), so only
the ratios matter and the absolute scale washes out; a weighted fit trades accuracy elsewhere for
accuracy in the emphasized region, so disclose it in the Step 9 report.

```matlab
% Emphasize the low-slip-angle region of each routed object.
w = arrayfun(@(o) 1 + 4*(abs(o.alpha) < deg2rad(3)), subsetFyPure, ...
    UniformOutput=false);
mdl = fit(mdl, subsetFyPure, "Fy Pure", Weight=w);
```

**`Parameters`** fits only a chosen subset of coefficients. Supersedes the fit type's default
set. *Guardrail:* the names must be members of that fit type's set; query them with
`mdl.fitParameterSet(FitType)` (no fit run needed).

```matlab
% Fit only the peak-lateral-friction coefficients.
mdl = fit(mdl, subsetFyPure, "Fy Pure", Parameters=["PDY1","PDY2"]);
```

**`FixedParameters`** holds named coefficients at their seed value and fits the rest. *Guardrail:*
query the fit type's coefficients with `mdl.fitParameterSet(FitType)` and pick the ones the
request names. The camber terms for pure `Fy` are the inclination-keyed coefficients (`PKY6`,
`PKY7`, `PVY3`, `PVY4`, `PEY5`).

```matlab
% "Fit Fy Pure, but leave the camber-sensitive parameters at their seed value."
[~, valid] = mdl.fitParameterSet("Fy Pure");   % the coefficients this fit type tunes
mdl = fit(mdl, subsetFyPure, "Fy Pure", ...
    FixedParameters=["PKY6","PKY7","PVY3","PVY4","PEY5"]);
```

**`LowerBounds` / `UpperBounds`** constrain the fitted parameters to a range. *Guardrail:* the
bounds align in order with the parameter set being fit, so pass them alongside an explicit
`Parameters` list to keep the mapping unambiguous; a scalar broadcasts to all, otherwise the
length must match the parameter count (else `vdyntire:errors:tireModelFitBoundLength`).

```matlab
% Constrain the two peak-friction coefficients to physical ranges.
mdl = fit(mdl, subsetFyPure, "Fy Pure", ...
    Parameters=["PDY1","PDY2"], LowerBounds=[0.5 -0.5], UpperBounds=[2.0 0.0]);
```

**`Solver`** chooses the optimizer. *Guardrail:* one of `fmincon`, `fminunc`, `fsolve`, or
`lsqnonlin` (default `lsqnonlin`); do not invent solver names.

```matlab
mdl = fit(mdl, subsetFyPure, "Fy Pure", Solver="fmincon");
```

**`optimoptions`** overrides the solver's own settings (iterations, tolerances). *Guardrail:*
you must pass `Solver` too (errors otherwise), and the options object's class must match
`optimoptions(Solver)`. Heavier caveat: a freshly built `optimoptions` object also carries that
solver's default algorithm, which replaces the tuned, bounded configuration `fit` applies on the
normal path. Swapping in an unbounded algorithm can make the fit diverge and blow the residual up
by orders of magnitude rather than improve it, so only pass this on an informed user request, and
set the algorithm and any bounds deliberately rather than relying on the defaults.

```matlab
opts = optimoptions("lsqnonlin", MaxIterations=2000, FunctionTolerance=1e-10);
mdl = fit(mdl, subsetFyPure, "Fy Pure", Solver="lsqnonlin", optimoptions=opts);
```

The eighth option, `PlotFit`, is a plotting concern covered in Step 7 and
`references/inspect-by-plotting.md`.

----

Copyright 2026 The MathWorks, Inc.

----
