# Analyze Ray Paths

`findpaths(rt)` returns one `RayPathSet` per destination. Each set holds the `RayPath`
objects found between the source and that destination. Paths contain geometry only
(angles, distance, interactions). They don't include received power.

```matlab
rt = rayTraceAnalysis(actr, [c, a], DestinationReferencePoint=["roof","fuselage-top"], ...
    MaxNumReflections=3);
sets = findpaths(rt);          % 1-by-2 RayPathSet
raypath = sets(1).Paths;       % RayPath array for the first destination (may be empty)
```

## RayPathSet

| Property | Description |
|---|---|
| `SourcePose` | Source `pose` at the time of the analysis |
| `DestinationPose` | Destination `pose` at the time of the analysis |
| `Paths` | `RayPath` array |

## RayPath Functions

| Function | Returns |
|---|---|
| `[az, el] = aoa(raypath)` | Angle of arrival at the destination, degrees (`Units="radians"` optional) |
| `[az, el] = aod(raypath)` | Angle of departure from the source, degrees |
| `d = propdist(raypath)` | Propagation distance, meters |
| `raypathOut = reverse(raypath)` | Paths with source and destination swapped |
| `pathvis = plot(raypath)` | One `RayPathVisual` per path |

Azimuth is measured counterclockwise from the actor's forward axis; elevation is positive
up. `aoa` points back toward where the ray arrives from. To get a direction in the scene frame,
combine the azimuth with the actor's yaw from `euler(pose(actor))`.

## Interactions

`raypath(i).Interactions` lists the interaction points; each has `Type`
(`"specular-reflection"`) and `Material`. A material with no catalog match (empty
`MatchedCatalogMaterial`, see `visibility-analysis.md`) reports `"concrete"`. A path with no
interactions is the direct line-of-sight path.

```matlab
isDirect = arrayfun(@(p) isempty(p.Interactions), raypath);
losPaths = raypath(isDirect);
reflectedPaths = raypath(~isDirect);
fprintf("LOS paths: %d, reflected paths: %d\n", numel(losPaths), numel(reflectedPaths));
```

## Plot Paths

`plot` draws in the given viewer, or in the current viewer (`gcv`) if none is passed. Plot
one `RayPathSet` at a time, as in the loop below.

```matlab
setvis = plot(v, sets(1));                        % RayTraceVisual
for k = 1:numel(sets)
    plot(v, sets(k), ColorMetric="distance", Colormap="turbo", ...
        LineWidth=3, ShowEndpoints="on", ShowInteractionPoints="on");
end
pathvis = plot(v, raypath, Color=[1 0 0]);        % RayPathVisual per path, fixed color
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `ColorMetric` | `"num-interactions"` (default) \| `"distance"` | Metric for ray path colors |
| `Colormap` | `parula` (default) \| colormap name \| m-by-3 RGB | Colormap for ray paths |
| `ColorLimits` | automatic (default) \| `[cmin cmax]` | Color limits |
| `ShowLegend` | `"on"` (default) \| `"off"` | Option to show color legend |
| `LineWidth` | `5` (default) \| positive scalar | Pixels |
| `ShowLine` | `"on"` (default) \| `"off"` | Path lines |
| `ShowEndpoints` | `"off"` (default) \| `"on"` | Source and destination markers |
| `EndpointSize` | `7` (default) \| positive scalar | Endpoint marker radius, pixels |
| `ShowInteractionPoints` | `"off"` (default) \| `"on"` | Reflection markers |
| `Alpha` | `1` (default) \| scalar in [0, 1] | Opacity |
| `Color` | RGB triplet \| color name | Fixed color. `RayPath` input only; not with `ColorMetric`, `Colormap`, or `ColorLimits` |

## Customize the Ray Trace Visual

`rt.Visual` (or `getvisual(v, rt)`) is a `RayTraceVisual`; it is empty until a viewer is attached.

```matlab
vis = rt.Visual;
vis.ColorMetric = "distance";
vis.Colormap = "turbo";
vis.ColorLimits = [50 500];
vis.ColorLimitsMode = "manual";     % "auto" recomputes limits on each update
vis.ShowEndpoints = "on";
vis.ShowInteractionPoints = "on";
vis.LineWidth = 3;
vis.Alpha = 0.8;
```

`RayTraceVisual` properties: `ColorMetric`, `Colormap`, `ColorLimits`, `ColorLimitsMode`,
`ShowLegend`, `ShowLines`, `ShowEndpoints`, `ShowInteractionPoints`, `LineWidth`,
`EndpointSize`, `Alpha`, `Visible`. Note the property is `ShowLines`, while the `plot`
argument is `ShowLine`.

`RayPathVisual` properties: `Color`, `Alpha`, `LineWidth`, `ShowLine`, `ShowEndpoints`,
`EndpointSize`, `ShowInteractionPoints`, `Visible`.

## Path Statistics

```matlab
sets = findpaths(rt);
raypath = sets(1).Paths;
if ~isempty(raypath)
    d = propdist(raypath);
    [arrAz, arrEl] = aoa(raypath);
    [depAz, depEl] = aod(raypath);
    fprintf("Found %d paths, shortest %.1f m, longest %.1f m\n", ...
        numel(raypath), min(d), max(d));
end
```

## Paths During Simulation

```matlab
while advance(scnro)
    sets = findpaths(rt);
    for k = 1:numel(sets)
        d = propdist(sets(k).Paths);
        fprintf("T=%.1fs, dest %d: %d paths, min dist %.1f m\n", ...
            seconds(scnro.SimulationTime), k, numel(d), min([d(:); NaN]));
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
