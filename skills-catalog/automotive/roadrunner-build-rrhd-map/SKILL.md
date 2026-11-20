---
name: roadrunner-build-rrhd-map
description: >
  Build, convert, and import RoadRunner HD Maps (.rrhd) in MATLAB. Author lanes, lane boundaries,
  markings, junctions, signs, barriers, and speed limits with roadrunnerHDMap; convert Lanelet2
  (.osm, Autoware) maps to RRHD; resolve RoadRunner road asset paths for markings, crosswalks,
  signs, signals, and barriers; and import or build .rrhd or OpenDRIVE (.xodr) files into a
  RoadRunner scene. Use when creating road networks for driving simulation, converting Lanelet2 or
  other HD map sources to RRHD, looking up road asset paths, or loading and verifying a map in
  RoadRunner or RoadRunner Scene Builder. Not for building scenes from recorded sensor data,
  running simulations, or recreating OpenSCENARIO (.xosc) scenarios.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Build RoadRunner HD Maps

Build RoadRunner HD Map (`.rrhd`) content with the `roadrunnerHDMap` API, convert Lanelet2 maps to RRHD, resolve asset paths, and import the result into a RoadRunner scene. Pick the workflow from the router below and load only the references it lists.

## When to Use

- Building RRHD maps from scratch — synthetic scenes, test roads, multi-lane segments, junctions
- Converting a Lanelet2 `.osm` file (with `type=lanelet` relations) to `.rrhd`
- Looking up RoadRunner asset paths for lane markings, crosswalks, stop lines, signs, signals, barriers, props
- Importing or building a `.rrhd` or OpenDRIVE `.xodr` file into a RoadRunner scene
- Debugging RRHD construction errors — wrong `roadrunner.hdmap.*` property names or constructor syntax, alignment (green grass), missing assets, `validateRRHD` or enforcement-gate failures; check [Critical API Gotchas](#critical-api-gotchas) first

## When NOT to Use

- Connecting to RoadRunner or managing projects/scenes without a map — use `roadrunner-manage-project`
- Authoring scenarios, actors, routes, or phase logic — use `roadrunner-author-scenario`
- Running or co-simulating scenarios — use `roadrunner-simulate-scenario`
- Building scenes from recorded sensor data (GPS, lidar, camera) — use `matlab-use-scenario-builder`
- Recreating a scenario from an OpenSCENARIO (`.xosc`) file — use `roadrunner-author-scenario` (this skill only imports the `.xodr` scene it references)
- Vehicle or character asset paths, or pedestrian-crossing actors — use `roadrunner-author-scenario` (this skill covers crosswalk markings)
- SUMO networks (`.net.xml`, `.sumocfg`) or OpenDRIVE for Eclipse SUMO co-simulation — use `matlab-cosimulate-sumo-simulink`
- Standard OpenStreetMap files (`highway=*` ways, no `type=lanelet` relations) — not supported; to build roads from OpenStreetMap with recorded GPS data, use `matlab-use-scenario-builder`
- Lanelet2 routing-graph exports (`*.rg.osm`, only `routing_cost` ways, no relations) — no geometry to convert
- UAV simulation environments with terrain, OSM buildings, or drone platforms and sensors — use `matlab-create-uav-scenario`
- General MATLAB runtime errors not tied to the `roadrunner.hdmap` API (indexing, dimension mismatch in your own code) — use `matlab-debug-code`

## Workflow Router

| User intent | Workflow | Load |
|---|---|---|
| Build RRHD from scratch | [Author](#author-rrhd-from-scratch) | `authoring/*` + `assets/*` |
| Convert Lanelet2 `.osm` → `.rrhd` | [Convert](#convert-lanelet2-to-rrhd) | `lanelet2/*` → `authoring/*` → `assets/*` |
| Resolve an asset path only | [Assets](#resolve-asset-paths) | `assets/*` |
| Import / build `.rrhd` or `.xodr` in RoadRunner | [Import](#import-into-roadrunner) | `import/*` |
| End-to-end Lanelet2 → RoadRunner scene | Convert, then Import | `lanelet2/*` → `authoring/*` → `assets/*` → `import/*` |

## Key Rules

- **Always write multi-line MATLAB code to `.m` files** and run with `run_matlab_file`; edit on error. Exception: the user asks to "show the pattern" or "do not execute".
- **Read only the references the workflow needs** — do not load everything upfront.
- **Only build what the user asked for** — no extra lanes, junctions, or objects.
- **`rrMap = roadrunnerHDMap;` first** — loads the `roadrunner.hdmap.*` namespace.
- **Never pass positional constructor arguments** to `roadrunner.hdmap.*` classes — use Name=Value (`RelativeAssetPath(AssetPath=...)`, `AlignedReference(Reference=..., Alignment=...)`) or create-then-assign.
- **Empty typed arrays** — `ClassName.empty`, never `[]`.
- **All geometry is Nx3** — include Z (default 0).
- **Boundary geometry is immutable** in conversions — never flip, resample, or project source boundaries; use `Alignment="Backward"`. Keep source elevation (never flatten Z).
- **One boundary object per source way**; detect alignment for every lane — never hardcode `"Forward"`.
- **Run the enforcement gate before `write()`** and before `importScene`.
- **Asset paths start with `Assets/`**; extension selects the style (`.rrlms`, `.rrcws`, `.rrpms`, `.rrext`, signs `.svg_rrx` or `.svg`). Resolve signs with `resolveSignAsset` and pass `ProjectFolder` to verify assets exist.
- **Import requires `rrApp`** from `roadrunner-manage-project`; copy the file into the project folder, use `ImportStep="Load"` by default, never hardcode asphalt detection, and preserve junctions when the map has them (OSM-derived maps from `matlab-use-scenario-builder` follow that skill's overlap-group default instead).

## Critical API Gotchas

| Wrong | Correct |
|---|---|
| `LeftBoundary` / `RightBoundary` | `LeftLaneBoundary` / `RightLaneBoundary` (`AlignedReference`) |
| `RelativeAssetPath("path")` | `RelativeAssetPath(AssetPath="path")` |
| `AlignedReference(ref, "Forward")` | `AlignedReference(Reference=ref, Alignment="Forward")` |
| `lane.Predecessors = []` | `lane.Predecessors = roadrunner.hdmap.AlignedReference.empty` |
| `Junction.Geometry = polygon` | wrap in `MultiPolygon`; ring property is `ExteriorRing` |
| `MarkingReference.MarkingID = 5` | `MarkingID` takes a `Reference` object |
| `pa.StartFraction` / `EndFraction` | `pa.Span = [0 1]` |
| `cm.CurveMarkingTypeID`, `b.BarrierTypeID` | `MarkingTypeReference`, `BarrierTypeReference` |
| `Sign.BoundingBox`, `bb.Position` | `Sign.Geometry` = `GeoOrientedBoundingBox` with `Center`, `Dimension`, `GeoOrientation` |
| `GeoOrientation = [headingDeg 0 0]`, full-size `Dimension` | `GeoOrientation = [roll pitch heading]` in **radians**; `Dimension` = **half-lengths** |
| `SpeedLimit.Speed`, `Unit="KPH"` | `Value` (int32), `VelocityUnit="Kph"` |
| `b = a; b.ID = "x"` to copy an object | `roadrunner.hdmap.*` classes are **handles** — assignment shares the object; construct a new one to copy |

Full class/property table: [references/authoring/apiReference.md](references/authoring/apiReference.md). For classes or options not covered there, check `help <class>`, then `matlab-read-documentation` — do not guess property names.

## Author RRHD from Scratch

1. Follow [authoringWorkflow.md](references/authoring/authoringWorkflow.md) — shared boundaries (N lanes → N+1 boundaries), multi-lane recipe, complete 2-lane example, enforcement gate.
2. Compute alignment with [alignmentRules.md](references/authoring/alignmentRules.md); derive center lines with [synthesizeCenterLine.md](references/authoring/synthesizeCenterLine.md).
3. Junctions: `detectJunctions` for overlapping lanes, or [junctionPolygon.md](references/authoring/junctionPolygon.md) for hand-authored polygons. Closed loops / tracks: [splitClosedGeometry.md](references/authoring/splitClosedGeometry.md), [orthogonalSplit.md](references/authoring/orthogonalSplit.md).
4. Markings, signs, barriers: resolve paths via [Resolve Asset Paths](#resolve-asset-paths).
5. Validate with [validateMap.md](references/authoring/validateMap.md) (or `validateRRHD`), then `write(rrMap, file)`.

## Convert Lanelet2 to RRHD

Run every step — the map is incomplete without junctions, curve markings, barriers, signs, and speed limits. Full step-by-step instructions, code constraints, and invariants: [conversionPipeline.md](references/lanelet2/conversionPipeline.md).

| Step | Reference |
|---|---|
| 1. Parse OSM (`parseOSM`) | [readOSM.md](references/lanelet2/readOSM.md) |
| 2. Validate format (`type=lanelet` present; reject standard OSM and routing graphs) | [conversionPipeline.md](references/lanelet2/conversionPipeline.md) |
| 3. Extract lanelets; discover ALL way and relation types | [extractLanelets.md](references/lanelet2/extractLanelets.md), [discoverRelations.md](references/lanelet2/discoverRelations.md) |
| 4. Origin, projection, way geometry (`geomMap`); alignment and center lines | [coordinates.md](references/lanelet2/coordinates.md), [extractGeometry.md](references/lanelet2/extractGeometry.md) |
| 5. Split closed roads | [splitClosedRoads.md](references/lanelet2/splitClosedRoads.md) |
| 6. Topology (node matching, opposing filter, left-gap filter) | [extractTopology.md](references/lanelet2/extractTopology.md), [leftGapFilter.md](references/authoring/leftGapFilter.md) |
| 7. Junctions — geometric, from overlapping lane footprints (`detectJunctions`, run in Step 9) | [extractJunctions.md](references/lanelet2/extractJunctions.md) |
| 8. Semantics (markings, lane types, speed limits; crosswalks → CurveMarkings) | [extractSemantics.md](references/lanelet2/extractSemantics.md) |
| 9. Build RRHD objects + non-lane elements | [buildRRHD.md](references/lanelet2/buildRRHD.md), [extractNonLaneElements.md](references/lanelet2/extractNonLaneElements.md), [placedObjects.md](references/lanelet2/placedObjects.md); signs via `resolveSignAsset` ([signs.md](references/assets/signs.md)) |
| 10. Post-process: snap, heights, dedup | [snapEndpoints.md](references/authoring/snapEndpoints.md), [resolveHeights.md](references/authoring/resolveHeights.md), [deduplicateBoundaries.md](references/authoring/deduplicateBoundaries.md) |
| 11. Enforcement gate, then `write()` | [enforcementGate.md](references/lanelet2/enforcementGate.md) |

After writing, print unmapped element counts, then continue with [Import into RoadRunner](#import-into-roadrunner) if the user wants to view the map.

## Resolve Asset Paths

Start with [assetCatalog.md](references/assets/assetCatalog.md) — extension rules, curve markings and crosswalks, signals, stencils, materials, default assets, region detection. Detailed tables:

| Element | Reference |
|---|---|
| Lane markings (incl. Japan/Germany variants) | [laneMarkings.md](references/assets/laneMarkings.md) |
| Signs (US MUTCD, German StVO, Japanese) | [signs.md](references/assets/signs.md) |
| Barriers and extrusions | [barriers.md](references/assets/barriers.md) |
| Props and static objects | [staticObjects.md](references/assets/staticObjects.md) |
| Lane types | [laneTypes.md](references/assets/laneTypes.md) |

## Import into RoadRunner

Requires a connected `rrApp` (from `roadrunner-manage-project`). Follow [importScene.md](references/import/importScene.md): new scene → copy file into the project folder → enforcement gate → `importScene` with `ImportStep="Load"` → build only when asked. Choose build options (asphalt detection, junction preservation, bridges) from map content with [buildOptions.md](references/import/buildOptions.md).

## Scripts

For one-off calls, use `evaluate_matlab_code` with `project_path` set to this skill's `scripts/` folder. Generated `.m` files run with `run_matlab_file` execute in their own folder, so add the folder explicitly at the top and remove it at the end:

```matlab
skillScripts = "<absolute path to this skill>/scripts";
addpath(skillScripts);
% ... generated pipeline ...
rmpath(skillScripts);
```

| Script | Inputs | Output | Example |
|---|---|---|---|
| `parseOSM` | `osmFile` (string, Lanelet2 `.osm`) | `ll2` struct: `.nodes`, `.ways`, `.relations` (`containers.Map`), `.sourceFile` | `ll2 = parseOSM("map.osm");` |
| `discoverWayTypes` | `ways` (`containers.Map` from `parseOSM`) | `discovery` struct of way buckets (stop lines, markings, barriers, signs, lights, unmapped); each way carries `.wayID` | `d = discoverWayTypes(ll2.ways);` |
| `detectAlignment` | `centerGeom`, `leftBndGeom`, `rightBndGeom` (Nx3) | `[leftAlignment, rightAlignment]` (`"Forward"`/`"Backward"`) | `[la, ra] = detectAlignment(c, L, R);` |
| `snapConnectedEndpoints` | `lanes`, `laneBoundaries`, optional `threshold` (m, default 1.0) | `[lanes, laneBoundaries, snapCount]` | `[ln, lb, n] = snapConnectedEndpoints(ln, lb);` |
| `resolveHeightConflicts` | `lanes`, `laneBoundaries`, optional `zStep` (m, default 0.15), `MinSeparation=` (m, default 2.0), `JunctionLaneIDs=` (skip crossings inside junctions) | `[lanes, laneBoundaries, info]` — `info.nComponents`, `.nConflicts`, `.nZLevels`, `.maxZ`, `.lanesAdjusted`; offsets are added to source Z | `[ln, lb, info] = resolveHeightConflicts(ln, lb);` |
| `resolveSignAsset` | `rawCode` (string), `region` (`"Japan"`/`"Germany"`/`"US"`), optional `ProjectFolder=` | `[assetPath, objectType, code, isFallback]` — `objectType` `"sign"`/`"signal"`; unrecognized codes → blank sign | `[p, t] = resolveSignAsset("jp_330-A", "Japan");` |
| `detectClosedLoop` | `rrMap` (`roadrunnerHDMap`), optional `MinLoopLength=` (m, default 100), `MinRingLength=` (m, default 30) | `[hasClosedLoop, info]` — `info.reason`, `.loopLanes`, `.loopLength`, `.nRings` (roundabouts) | `[tf, info] = detectClosedLoop(m);` |
| `detectJunctions` | `lanes`, `laneBoundaries`, optional `MinOverlapArea=` (0.01), `MinOverlapFraction=` (0), `MinJunctionArea=` (15), `DropDivergeMerge=` (false), `MergeGap=` (1 m), `SideBySideLength=` (4 m) | `[junctions, info]` — `Junction` array (union of member lane footprints); `info.laneCounts`, `.areas`, `.centers`, `.junctionLaneIDs` | `[J, info] = detectJunctions(lanes, laneBoundaries);` |
| `validateRRHD` | `rrMap` (`roadrunnerHDMap`) | `report` struct: `.errors`, `.warnings`, `.isValid` | `r = validateRRHD(rrMap);` |

## Key Functions

| Function | Purpose |
|---|---|
| `roadrunnerHDMap`, `read`, `write` | Create, read, and write HD Map objects |
| `roadrunner.hdmap.Lane`, `LaneBoundary`, `LaneMarking`, `Junction` | Core road entities |
| `roadrunner.hdmap.AlignedReference`, `RelativeAssetPath`, `ParametricAttribution` | References, asset paths, marking/speed spans |
| `xmlread` | Parse Lanelet2 OSM XML |
| `importScene`, `roadrunnerHDMapImportOptions`, `roadrunnerHDMapBuildOptions` | Import and build a map in RoadRunner |
| `enableOverlapGroupsOptions`, `autoDetectBridgesOptions` | Junction preservation and bridge detection |

## Known Limitations

- RoadRunner silently ignores `SignalTypes`/`Signals` on `.rrhd` import — signals survive MATLAB write/read but do not appear in the scene.
- RoadRunner cannot render self-closing lanes — split closed loops (see [orthogonalSplit.md](references/authoring/orthogonalSplit.md)).
- Track maps (closed-loop ovals): omit topology, marking attributes, and Z bumps; use natural elevation.
- The RoadRunner Asset Library has no curb extrusion — Lanelet2 `curbstone` ways are reported, not built.
- Unrecognized sign codes become a blank sign (`isFallback`); report their count so the user can map them.

## Conventions

- `roadrunner.hdmap.*` constructors: Name=Value or create-then-assign — never positional
- `ClassName.empty` for empty typed arrays; Nx3 geometry everywhere
- Shared boundaries: one object per source way, referenced by multiple lanes with independent alignment
- `containers.Map` for indexed lookups in conversions; print a discovery summary — never silently drop elements
- Copy files into the RoadRunner project folder before `importScene`; `ImportStep="Load"` unless a build is requested
- `tiledlayout`/`nexttile` for multi-panel figures

----

Copyright 2026 The MathWorks, Inc.

----
