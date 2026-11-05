# Fit-Type Data Requirements and Content Routing

Load this when routing data to fit types (Step 5) or classifying channels (Step 2). The
fit-type SET and order are queried per model type with
`vdyntire.tiremodels.fitTypes(ModelType=...)`. This table is the model-type-independent
physics of what each fit type needs, so it does not change across releases.

## Per-fit-type data requirements

| fit type | response present | swept channel | extra condition |
|----------|------------------|---------------|-----------------|
| Fx Pure | Fx | kappa | mean alpha ≈ 0 |
| My | My | kappa | mean alpha ≈ 0 |
| Fy Pure | Fy | alpha | kappa ≈ 0 |
| Mz Pure | Mz | alpha | kappa ≈ 0 |
| Mx | Mx | alpha | kappa ≈ 0 |
| Fx / Fy / Mz Combined | Fx / Fy / Mz | kappa OR alpha (either, or neither) | BOTH slips nonzero at once (complementary slip held nonzero) |
| RL / Re | RL / Re | Fz | alpha and kappa ≈ 0 (load sweep) |
| Fx / Fy Relaxation Length | sig_x / sig_y | Fz | steady slip |
| Contact Patch Length / Width | patch_a / patch_b | Fz | steady slip |
| Nominal / Limits / Dimensions | (none) | (none) | consume ALL data |

Angles are radians after a recognized-format import (Step 1), so the thresholds are
radian-valued: 0.05 rad is about 2.9 degrees, 0.01 rad is about 0.57 degrees.

## Check required channels before fitting

Each fit type needs its response channel (the "response present" column) and its swept channel
actually present in the data routed to it. If a required channel is entirely absent, `fit` stops
with a "requires data for property ..." error; if only some measurements lack it, those
measurements are dropped and `fit` warns. Rather than call `fit` to discover the gap, check
presence up front from the Step-2 `summaryTable`, naming the response channels in `VariableNames`
alongside the routing channels, and treat a channel `ch` as absent when `all(ismissing(spans.(ch)))`
is true. Skip any type whose
required channel is absent and record it in the C3 not-run report instead of fitting it. In
practice this binds on the data-optional responses `My`, `sig_x`, `sig_y`, `patch_a`, and
`patch_b`; the force and moment responses and the swept channels are present whenever data is
routed sensibly. An absent response leaves that type at its seed value, which is a C3 not-run
entry rather than a fit to attempt.

## Combined-slip routing signal (C2)

Combined data is defined by BOTH slip quantities being nonzero at the same time, not by which
channel is swept. It arises three ways: kappa swept at a fixed nonzero alpha (most common,
easiest on MTS controls), alpha swept at a fixed nonzero kappa, or a steady-state point with
both nonzero and no dynamic sweep. The discriminator is therefore whether the complementary
slip quantity is near zero or held at a fixed nonzero level, tested on its MEAN, not which
channel moves.

Do not require a kappa sweep to recognize combined data. Automatic data assignment (for example
in the Tire Manager app) recognizes only the common case, kappa swept with the slip angle held at
a fixed nonzero value, so command-line routing must be broader than that. Pure fits are the
mirror: the complementary slip quantity is near zero (Fx Pure has alpha ≈ 0; Fy Pure, Mz Pure,
and Mx have kappa ≈ 0).

## Channel-content routing, worked example

Classify each object with `summaryTable(td, DataStat="range")` for the swept-versus-held
decision and `summaryTable(td, DataStat="mean")` for the mean of each channel (a meaningful
held level only for a channel the range shows is held). Route by selecting the objects whose
classification matches a fit type's row above, keyed on which channel is swept plus the held
levels of the others. Never route by filename, subfolder, or TESTMETH. For example, with values
in radians:

| file | alpha range | kappa range | mean alpha | Fz groups | reading |
|------|-------------|-------------|------------|-----------|---------|
| `sa` | 0.324 | 0 | 0.112 | 1 | alpha swept → `Fy` / `Mz Pure` |
| `sr` | 0 | 0.473 | 0.000 | 1 | kappa swept, mean alpha ≈ 0 → `Fx Pure` |
| `combined` | 0 | 0.335 | -0.087 | 1 | kappa swept, mean alpha fixed at -5 degrees → combined |

The pure-versus-combined split is on mean alpha, not alpha range. A naive alpha-range threshold
misclassifies: the Calspan SINE files sit just above a 0.05-rad range threshold, so mean alpha
near zero versus a fixed nonzero value is the clean discriminator.

## `Dimensions` geometry properties

`Dimensions` fits from five `tireData` geometry properties, not from `TireSize`.
Recognized-format import populates them from the file header when the keys are present:

| tireData property | model parameter | canonical unit |
|-------------------|-----------------|----------------|
| `OverallDiameter` | UNLOADED_RADIUS (halved) | meters |
| `SectionWidth` | WIDTH | mm |
| `AspectRatio` | ASPECT_RATIO | % |
| `RimDiameter` | RIM_RADIUS | inches |
| `RimWidth` | RIM_WIDTH | inches |

The units are deliberately mixed, so supply each in its stated unit or the fit produces
nonsense (an overall diameter given in mm yields a metre-scale radius). If a property is empty
across the array, the fit leaves that model parameter at its seed value and warns; report it
per C3. `TireSize` is bookkeeping only and never gates `Dimensions`.

Fallback when the data lacks geometry: ask the user for the tire size, assign the five
properties on the `tireData` object, then fit `Dimensions`. A standard size such as `235/45R18`
supplies four of the five directly (SectionWidth = 235 mm, AspectRatio = 45, RimDiameter =
18 in) plus a computed `OverallDiameter = (RimDiameter*25.4 + 2*SectionWidth*AspectRatio/100)/1000`
in meters. `RimWidth` is not encoded in the size code, so ask for it separately or leave that
one parameter at the seed value and report it per C3.

----

Copyright 2026 The MathWorks, Inc.

----
