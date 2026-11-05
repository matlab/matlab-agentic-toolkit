# Worked Example: Query, Route by Content, Thread the Model

Load this at Step 5 or Step 7 for concrete code showing the C1 (query the fit types), C2 (route
by channel content), and C3 (report scope completely) judgments in one place. These are worked
examples over a few representative MF62 types, **not** the complete routing map: iterate whatever
`fitTypes` returns for the queried model type, and select each type's data per its row in
`references/fit-type-data-requirements.md`.

## Query, route by content, thread the model (C1 + C2)

```matlab
% C1: query the fittable types and iterate in the returned order.
types = vdyntire.tiremodels.fitTypes(ModelType=modelType);
disp(types)   % MF62 returns Nominal first, then the force/moment types

% C2: classify channel content once (Step 2), then select per the reference table.
routeVars = ["Filename" "alpha" "kappa" "Fz" "gamma" "V"];   % VariableNames defaults to ALL properties
spans = summaryTable(td, VariableNames=routeVars, DataStat="range");  % span: large = swept, small = held
means = summaryTable(td, VariableNames=routeVars, DataStat="mean");   % mean of each, held or swept
subsetFxPure = td(spans.kappa > 0.05 & abs(means.alpha) < 0.01);   % kappa swept, alpha held at 0
subsetFyPure = td(spans.alpha > 0.05 & spans.kappa < 0.01);        % alpha swept, kappa ~ 0

% C1 runtime: reassign so each fit builds on the previous (dependency order).
mdl = tireModel.new(modelType);
mdl = fit(mdl, td, "Nominal");            % Nominal/Limits/Dimensions consume all data
mdl = fit(mdl, subsetFxPure, "Fx Pure");
mdl = fit(mdl, subsetFyPure, "Fy Pure");
% overwrite=true only for this script's own output; ask before replacing a user's file.
export(mdl, "fitted.tir", overwrite=true);
```

The threaded loop over the whole returned schedule, which is the shape to scale the three explicit
calls above into. `types` is a **column** string array, so index it; `for ft = types` would run a
single iteration with every type bound to `ft`. Do not carry an assumption over from
`modelTypes`, which returns a row:

```matlab
mdl = tireModel.new(modelType);
ranTypes = string.empty(0,1);       % keep it a column, to match setdiff below
for k = 1:numel(types)
    ft = types(k);
    subset = selectSubsetFor(ft);   % your Step-5 routing, per the reference table
    if isempty(subset)
        continue                    % no data for this type; it lands in the C3 not-run report
    end
    mdl = fit(mdl, subset, ft);     % reassign: the fit builds on every prior type
    ranTypes(end+1,1) = ft;
end
```

## Report scope completely, up front (C3)

Build the not-run set from the supported types minus the types you actually ran, and name the
baseline the untouched parameters carry.

```matlab
% ranTypes: the fit types you actually ran (Step 7).
% baselineLabel: "tireModel.new defaults" or "the imported parent model's coefficients" (Step 6).
supported = vdyntire.tiremodels.fitTypes(ModelType=mdl.ModelType);   % column
notRun    = setdiff(supported, ranTypes(:), "stable");               % (:) so orientation matches
fprintf("Not fit, parameters remain at %s:\n", baselineLabel);
fprintf("  %s\n", notRun);
```

`setdiff` keeps the orientation of its first input, so `notRun` is a column here. If you verify it
against a list you wrote out by hand, normalize both sides with `(:)` first: `isequal` is false for
a column and a row holding the same strings, which reads as a scope-tracking bug that is not one.

----

Copyright 2026 The MathWorks, Inc.

----
