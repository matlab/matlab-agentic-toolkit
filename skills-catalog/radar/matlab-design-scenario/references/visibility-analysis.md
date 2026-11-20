# Analyze Visibility

## Line-of-Sight Analysis

Checks for a clear line between a source and one or more destinations, including terrain
and building occlusion.

```matlab
losA = losAnalysis(actr, c);                     % single destination
losMulti = losAnalysis(actr, [c, a]);            % multiple destinations
losRoof = losAnalysis(actr, c, DestinationReferencePoint="roof", DestinationSelfObstruction="on");
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `SourceReferencePoint` | `"centroid"` (default) \| reference point name | Point on the source |
| `DestinationReferencePoint` | `"centroid"` (default) \| reference point name \| one name per destination | Point on each destination |
| `SourceSelfObstruction` | `"off"` (default) \| `"on"` | Source 3D model can block the line |
| `DestinationSelfObstruction` | `"off"` (default) \| `"on"` | Destination 3D models can block the line |
| `DefaultVisibility` | `"on"` (default) \| `"off"` | Show the analysis in viewers initially; set at creation only |

### Terrain and LOS

- Default terrain (`"gmted2010"`): LOS accounts for terrain and buildings.
- `Terrain="none"`: the ground is the smooth ellipsoid (it still reflects rays); buildings
  still occlude. Use it for fast or offline runs, not where terrain relief matters.

## Reference Points

| Actor | Reference points |
|---|---|
| `car` (sedan) | `"centroid"`, `"asset-origin"`, `"roof"`, `"frontbumper"`, `"frontbumper-left"`, `"frontbumper-right"`, `"rearbumper"`, `"rearbumper-left"`, `"rearbumper-right"`, `"frontaxle-ground"`, `"rearaxle-ground"`, `"rearviewmirror"`, `"sideviewmirror-left"`, `"sideviewmirror-right"` |
| `aircraft` (narrowbody) | `"centroid"`, `"asset-origin"`, `"nosecone"`, `"fuselage-top"`, `"fuselage-bottom"`, `"rudder-top"`, `"rearaxle-ground"` |
| `actor` (no model) | `"centroid"` only. Other values error |

List them for any actor with a 3D model:

```matlab
rp = c.Asset.ReferencePoints;
keys(rp)            % available names
rp("roof")          % [x y z] in the asset frame, meters
isKey(rp, "roof")
```

Generic point actors have an empty `Asset`.

## Ray Trace Analysis

Finds reflected and direct geometric paths between actors.

```matlab
rt = rayTraceAnalysis(actr, c, DestinationReferencePoint="roof");
rtFine = rayTraceAnalysis(actr, c, DestinationReferencePoint="roof", ...
    MaxNumReflections=3, NumRaysLaunched=163842);
rtFine.MaxNumReflections = 2;      % options are also settable properties
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `MaxNumReflections` | `1` (default) \| nonnegative integer | Maximum reflections per path |
| `NumRaysLaunched` | `1e5` (default) \| positive integer | Number of rays launched |
| `SourceReferencePoint`, `DestinationReferencePoint` | `"centroid"` (default) \| as for LOS | Must be outside the 3D model (see below) |
| `DefaultVisibility` | `"on"` (default) \| `"off"` | Show in viewers initially; set at creation only |

`"centroid"` is inside the 3D model of cars and aircraft, so the analysis errors. For cars
and aircraft, always pass a surface point such as `"roof"` (car) or `"nosecone"` or
`"fuselage-top"` (aircraft).

## Query Results

```matlab
visible = hasLOS(losA);        % logical, one per destination
rtVisible = hasLOS(rt);        % ray trace analyses also report LOS
sets = findpaths(rt);          % RayPathSet, one per destination (see ray-path-analysis.md)
```

`hasLOS` returns `false` when the source and destination are at the same location.
Results update as actors move:

```matlab
losA = losAnalysis(actr, [c, a]);
while advance(scnro)
    visible = hasLOS(losA);
    fprintf("T=%.1fs: car=%d, aircraft=%d\n", seconds(scnro.SimulationTime), visible(1), visible(2));
end
```

## Customize the LOS Visual

`losA.Visual` is an empty `Visual` array until a viewer is attached; setting a property
before then errors because the array is empty.

```matlab
v = viewer(scnro);
vis = losA.Visual;                % LOSVisual
vis.VisibleColor = [0 1 0];
vis.ObstructedColor = [1 0 0];
vis.LineWidth = 3;
vis.ShowEndpoints = "off";
vis.ShowObstructionPoint = "on";
vis.ObstructedLineStyle = "--";
vis.Alpha = 0.5;
vis.Visible = "off";              % hide entirely
```

`LOSVisual` properties: `VisibleColor`, `ObstructedColor`, `LineWidth`, `ShowLine`,
`ShowEndpoints`, `ShowObstructionPoint`, `EndpointSize`, `ObstructedLineStyle` (`"--"`, `"-"`),
`Alpha`, `Visible`. For ray trace visuals see `ray-path-analysis.md`.

## Materials

Materials affect ray trace reflections.

```matlab
sceneMtls = materials(scnro.Scene);   % table: Material, MatchedCatalogMaterial
actorMtls = materials(c);             % materials of the actor's 3D model
```

`MatchedCatalogMaterial` is the built-in catalog entry each material maps to (empty if none).

## Manage Analyses

```matlab
an = analyses(scnro);      % all analyses in the scenario
restart(scnro);            % required before removing an analysis
remove(losA);
```

----

Copyright 2026 The MathWorks, Inc.

----
