# Inspect by Plotting (Supplementary)

Load this when the user asks to plot or visually inspect measurement data or a fitted model's
response.

Plotting is never required by the fit, but a human review often wants it, so offer it when
asked and reach for the shipped methods rather than pulling channels off the object and
calling generic `plot`. Hand-rolling reinvents the axis labels, unit scaling, and legend the
API derives from the channel metadata, and it invites fabricated labels or coordinate-frame
claims. When plotting is wanted, it can support several points in the workflow: inspect imported
channels after Step 1, check data before and after the Step 2 processing, and overlay the model on
its data to judge fit accuracy in Step 7. In each case offer it rather than producing a figure
unrequested.

**Measurement data, `tireData.plot`.** Renders the channels held in the `tireData` array.
Give it `DataVariableNames` (one, two, or three channel names for index-vs-value, x-vs-y, or
a 3-D plot), or omit it for the multi-panel autoplot. `ColorBy` groups lines by any property
(for example a load level) and `ColorByScheme` is `"Legend"` or `"Colorbar"`. Axes are
labeled and unit-scaled from the channel metadata; `FilterBy`/`FilterByValues` subselect
objects before plotting.

```matlab
% Plot measured lateral force against slip angle, colored by load.
td.plot(DataVariableNames=["alpha","Fy"], ColorBy="Fz");
% Or let autoplot lay out the common channels.
td.plot();
```

**Model response, `tireModel.plot`.** A model holds only parameters, so plotting runs a
compute cycle. Drive it from measured conditions with `Data=<tireData>`, optionally with
`FitType` to focus one fit type, or specify conditions directly with `Direction` ("alpha",
"gamma", "kappa", or "Fz") and `Magnitude` plus held values (`Fz`, `alpha`, `gamma`, `kappa`,
`IP`, `Vx`, `psidot`) to inspect behavior where you have no measurement data. `DataVariableNames`
selects which channels go on which axes. With no arguments it draws a canned 2x2. It delegates
the actual drawing to `tireData.plot`.

```matlab
% Overlay the fitted model on the data it was fit to, to judge accuracy.
mdl.plot(Data=subset, DataVariableNames=["alpha","Fy"], ColorBy="Fz");
% Inspect model behavior at loads you never measured.
mdl.plot(Direction="alpha", Magnitude=deg2rad([-12 12]), ...
    Fz=[2000 4000 6000], DataVariableNames=["alpha","Fy"]);
```

When you only want to see a fit as it completes, `fit(mdl, data, FitType, PlotFit=true)`
triggers this same plot inline and returns the handle in `H`; the standalone calls above are
for inspecting outside a fit call.

----

Copyright 2026 The MathWorks, Inc.

----
