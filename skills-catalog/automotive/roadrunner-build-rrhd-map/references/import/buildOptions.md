# Choose Build Options

## Build Options Reference (`roadrunnerHDMapBuildOptions`)

| Property | Type | Default | Description |
|---|---|---|---|
| `FitCrossSections` | logical | `"auto"` | Enable cross-section fitting |
| `DetectAsphaltSurfaces` | logical | `"auto"` | Generate road surfaces |
| `ClearSceneOfExistingData` | logical | `"auto"` | Remove prior scene content |
| `CurvatureBlend` | double | `"auto"` | Position of fit arcs in transitions |
| `UseLaneGroups` | logical | `"auto"` | Combine only same-group lanes into roads (R2024a+) |
| `CombineTransitionLanes` | logical | `"auto"` | Merge transition lanes into single road (R2025a+) |
| `AutoDetectBridgesOptions` | `autoDetectBridgesOptions` | `"auto"` | Bridge detection settings |
| `EnableOverlapGroupsOptions` | `enableOverlapGroupsOptions` | `"auto"` | Junction creation from overlaps |

## `enableOverlapGroupsOptions` Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `IsEnabled` | logical | `false` | When `false`, RoadRunner creates automatic junctions at geometric overlaps. When `true`, overlapping lanes are grouped (no auto junctions). |
| `GroupName` | string | `"SceneBuild"` | Overlap group identifier |
| `PreserveJunctionLanes` | logical | `"auto"` | Retain junction lane definitions from RRHD (R2026a+) |
| `PreserveJunctionShape` | logical | `"auto"` | Maintain junction polygon geometry from RRHD (R2026a+) |

## Import Workflow

For the full import workflow (file location requirements, `ImportStep="Load"` for inspection, connection strategy), see [importScene.md](importScene.md). Key points:
- **File must be inside the RoadRunner project folder** — copy it there before `importScene`
- **`ImportStep="Load"`** for HD Map inspection without building
- **Omitting ImportStep triggers a build** — use `"Load"` explicitly when you only want to inspect

## Without explicit junctions — let RoadRunner auto-detect from overlaps:

```matlab
importOpts = roadrunnerHDMapImportOptions;
buildOpts = roadrunnerHDMapBuildOptions;
buildOpts.ClearSceneOfExistingData = true;
buildOpts.DetectAsphaltSurfaces = true;

% EnableOverlapGroups.IsEnabled = false (default) means RoadRunner
% creates junctions automatically where lanes geometrically overlap.
% No explicit action needed — default behavior produces junctions from overlaps.

importOpts.BuildOptions = buildOpts;
importScene(rrApp, destFile, "RoadRunner HD Map", importOpts);
```

## With explicit junctions in RRHD (preserve authored junction polygons):

```matlab
importOpts = roadrunnerHDMapImportOptions;
buildOpts = roadrunnerHDMapBuildOptions;
buildOpts.ClearSceneOfExistingData = true;
buildOpts.DetectAsphaltSurfaces = true;

% Enable overlap groups + preserve junction definitions from RRHD
eoOpts = enableOverlapGroupsOptions;
eoOpts.IsEnabled = true;
eoOpts.PreserveJunctionLanes = true;
eoOpts.PreserveJunctionShape = true;
buildOpts.EnableOverlapGroupsOptions = eoOpts;

importOpts.BuildOptions = buildOpts;
importScene(rrApp, destFile, "RoadRunner HD Map", importOpts);
```

## Suppress junctions entirely (overlap grouping, no junctions):

```matlab
eoOpts = enableOverlapGroupsOptions;
eoOpts.IsEnabled = true;  % group overlapping lanes instead of creating junctions
buildOpts.EnableOverlapGroupsOptions = eoOpts;
```

## Troubleshooting After Import

| Issue | Cause |
|---|---|
| Grass on road surface | Wrong boundary alignment — check dot product logic |
| Markings in junction | Junction boundary markings not stripped |
| Disconnected lanes | Topology threshold too tight or opposing boundaries not detected |
| Giant junction polygon | Used union-find instead of proximity BFS clustering |
| No junctions at intersections | `EnableOverlapGroupsOptions.IsEnabled` is `true` — set to `false` |
| "connectedLane.Object != this" error on import | Self-referencing topology (lane is its own pred/succ) |
| "A name is expected" error | Used positional args for RelativeAssetPath or AlignedReference |
| Empty array assignment error | Used `[]` instead of `ClassName.empty` for typed properties |

----

Copyright 2026 The MathWorks, Inc.

----
