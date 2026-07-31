---
name: roadrunner-asset-mapping
description: >
  RoadRunner asset path lookup tables for map format conversions in MATLAB. Maps lane markings,
  signs, signals, barriers, objects, and lane types to RoadRunner asset paths. Use when converting
  map formats to RRHD, resolving asset paths, or assigning visual assets to HD Map objects.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
user-invocable: false
metadata:
  author: MathWorks
  version: "1.1"
---

# RoadRunner Asset Mapping

Consolidated lookup tables for mapping source map format elements to RoadRunner project asset paths. All paths are relative to the project `Assets/` folder.

## When to Use

- Resolving lane marking subtypes to RoadRunner `.rrlms` asset paths
- Mapping sign codes (US MUTCD, German StVO, Japanese) to sign asset SVGs
- Looking up barrier/extrusion asset paths for fence, guard rail, jersey barrier, wall
- Finding prop/static object asset paths for placement in RRHD
- Determining region-specific sign paths based on geoReference coordinates
- Assigning lane type enums from source format lane classifications

## When NOT to Use

- Building RRHD objects from scratch — use `roadrunner-rrhd-authoring`
- Performing the full Lanelet2 conversion pipeline — use `roadrunner-convert-lanelet2-to-rrhd`
- Importing maps into RoadRunner — use `roadrunner-import-scene`

## Key Rules

- **All asset paths start with `Assets/`** — always prefix when constructing `RelativeAssetPath` objects.
- **Extension matters.** `.rrlms` = lane marking style, `.rrcws` = crosswalk style, `.rrpms` = polygon marking style, `.svg_rrx` = sign. Using wrong extension causes "Asset file is missing" on import.
- **Signs use `.svg_rrx` extension** (NOT `.svg`). The `.svg` paths in XML configs are internal references only.
- **Sign naming: descriptive English names** with region suffix (e.g., `Stop_JP_01.svg_rrx`, `MaxSpeedLimit_30_DE.svg_rrx`). The old `Sign_<code>.svg` naming is obsolete.
- **Region detection from geoReference.** Use lat/lon to determine Japan/Germany/US for sign and marking paths.
- **Runtime asset discovery is MANDATORY for signs.** Asset names vary by version — always verify file exists before assigning.

## Source Data

Asset mappings are derived from the official RoadRunner project configuration XMLs:
- `DefaultAssets.xml` — default materials and markings
- `ApolloAssetData.xml` — Apollo/Baidu HD Map format
- `OpenDriveAssetData.xml` — OpenDRIVE format
- `HEREAssetData_NA.xml` / `HEREAssetData_WE.xml` — HERE HD Map (NA/EU)
- `TomTomAssetData.xml` — TomTom HD Map format

These XML files are located in the RoadRunner project's configuration directory (typically `<RoadRunner Project>/Configuration/`).

## Lane Markings

See [references/laneMarkings.md](references/laneMarkings.md) for full mapping table.

**Key patterns:**
- All marking assets are in `Assets/Markings/` with `.rrlms` extension
- Markings are keyed by **type** (solid/dashed/double) + **color** (white/yellow)
- Default road center marking: `SolidDoubleYellow.rrlms`
- Default outer boundary: `SolidSingleWhite.rrlms`

## Signs

See [references/signs.md](references/signs.md) for full mapping table.

**CRITICAL: Asset File Extension**
- RoadRunner sign assets use **`.svg_rrx`** extension on disk (NOT `.svg`)
- The `.svg` paths in project XML configs are internal references only
- **Always use `.svg_rrx` in `RelativeAssetPath` objects** — using `.svg` causes "Could not find asset" errors

**MANDATORY: Runtime Asset Discovery**
- Sign asset names vary by RoadRunner version and installed asset libraries
- **Always verify at runtime** that the target asset exists before assigning it
- Use `dir(fullfile(projFolder, 'Assets', 'Signs', region, category, '*.svg_rrx'))` to discover available signs

**Key patterns:**
- US signs: `Assets/Signs/US/Regulatory Signs/` or `Assets/Signs/US/Warning Signs/`
- German signs: `Assets/Signs/Germany/Regulatory Signs/`
- Japan signs: `Assets/Signs/Japan/Regulatory Signs/` or `Assets/Signs/Japan/Warning Signs/`
- Sign geometry uses `GeoOrientedBoundingBox` (Center + Dimension + GeoOrientation)

**Naming convention:** Signs use **descriptive English names** with region suffix:
- Pattern: `<Description>_<Region>.svg_rrx` (e.g., `Stop_JP_01.svg_rrx`, `MaxSpeedLimit_30_JP.svg_rrx`)
- The old `Sign_<code>.svg` naming is **obsolete** — files do NOT exist on disk

**Region detection from geoReference:**
```matlab
lat = geoRef(1); lon = geoRef(2);
if lat >= 24 && lat <= 46 && lon >= 122 && lon <= 154
    region = "Japan";
elseif lat >= 35 && lat <= 72 && lon >= -10 && lon <= 25
    region = "Germany";
else
    region = "US";
end
```

**Region-specific sign paths (verified R2026a with RoadRunner_Asset_Library):**

| Sign | Japan | US | Germany |
|---|---|---|---|
| Stop | `Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx` | `Signs/US/Stop_US.svg_rrx` | `Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx` |
| Yield | — | `Signs/US/Yield_US.svg_rrx` | `Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx` |
| Speed N | `Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx` | `Signs/US/Regulatory Signs/MaxSpeedLimit_<N>_US.svg_rrx` | `Signs/Germany/Regulatory Signs/MaxSpeedLimit_<N>_DE.svg_rrx` |
| Fallback | `Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx` | `Signs/US/White_Blank_US.svg_rrx` | `Signs/Germany/Warning Signs/Danger_DE.svg_rrx` |

## Signals (Traffic Lights)

| Configuration | Asset Path |
|---|---|
| 3-light vertical (post) | `Props/Signals/Signal_3Light_Post01.fbx` |
| 3-light vertical (bare) | `Props/Signals/Signal_3Light_Bare01.fbx_rrx` |

**Authoring vs Import limitation:** You CAN author `SignalType` objects (add to `rrMap.SignalTypes`) and `Signal` instances (add to `rrMap.Signals`) in MATLAB and write the map to `.rrhd` — signal data IS written to the file and survives read/write cycles. However, RoadRunner **silently ignores** signals when importing `.rrhd` maps — signals will not appear in the RoadRunner scene after import. Show the asset paths and authoring code, but warn the user about this import limitation.

## Barriers & Extrusions

See [references/barriers.md](references/barriers.md) for full mapping table.

**Key patterns:**
- All extrusions in `Assets/Extrusions/` with `.rrext` or `.rrext.rrmeta` extension
- Barriers use `roadrunner.hdmap.BarrierType` with `ExtrusionPath`

## Props & Static Objects

See [references/staticObjects.md](references/staticObjects.md) for full mapping table.

**Key patterns:**
- Props in `Assets/Props/` subdirectories (Trees, Signals, TrafficControl, etc.)
- Static objects use `roadrunner.hdmap.StaticObjectType` with `AssetPath`
- Objects use `GeoOrientedBoundingBox` for placement

## Lane Types

See [references/laneTypes.md](references/laneTypes.md) for full mapping table.

## Crosswalks & Curve Markings

**Extension rules** (commonly confused):
- `.rrcws` = crosswalk style (only for actual crosswalks)
- `.rrlms` = lane marking style (stop lines, bike markings, zig-zag)
- `.rrpms` = polygon marking style (striped regions, chevrons)
- `.rrcws_rrx` / `.rrlms_rrx` = region-specific variants (Japan, Germany, etc.)

**Base assets (universal):**

| Type | Asset Path | Extension |
|---|---|---|
| Simple crosswalk | `Markings/SimpleCrosswalk.rrcws` | `.rrcws` |
| Continental crosswalk | `Markings/ContinentalCrosswalk.rrcws` | `.rrcws` |
| Ladder crosswalk | `Markings/LadderCrosswalk.rrcws` | `.rrcws` |
| Stop line | `Markings/StopLine.rrlms` | `.rrlms` |
| Striped region | `Markings/StripedRegion.rrpms` | `.rrpms` |

**Japan-specific markings (`.rrlms_rrx` / `.rrcws_rrx`):**

| Type | Asset Path |
|---|---|
| Stop line | `Markings/Japan/StopLine_JP.rrlms_rrx` |
| Crosswalk | `Markings/Japan/SimpleCrosswalk_JP.rrcws_rrx` |
| Solid single white | `Markings/Japan/SolidSingleWhite_JP.rrlms_rrx` |
| Dashed single white | `Markings/Japan/DashedSingleWhite_JP.rrlms_rrx` |
| Solid double white | `Markings/Japan/SolidDoubleWhite_JP.rrlms_rrx` |
| Solid double yellow | `Markings/Japan/SolidDoubleYellow_JP.rrlms_rrx` |

**Germany-specific markings:**

| Type | Asset Path |
|---|---|
| Stop line | `Markings/Germany/StopLine_DE.rrlms_rrx` |
| Crosswalk | `Markings/Germany/SimpleCrosswalk_DE.rrcws_rrx` |

**Region selection:** Use base (non-regional) assets as default. Use regional variants when the map's geoReference indicates a specific region AND the regional asset exists in the project.

## Stencils (Road Surface Markings)

| Type | Asset Path |
|---|---|
| Arrow left | `Assets/Stencils/Stencil_ArrowType4L.svg` |
| Arrow right | `Assets/Stencils/Stencil_ArrowType4R.svg` |
| STOP text | `Assets/Stencils/Stencil_STOP.svg` |

## Materials

| Purpose | Asset Path |
|---|---|
| Road surface | `Assets/Materials/Asphalt1.rrmtl` |
| Sidewalk / concrete | `Assets/Materials/Concrete1.rrmtl` |
| Ground / grass | `Assets/Materials/Grass1.rrmtl` |

## Default Assets

These are the project-wide defaults (from `DefaultAssets.xml`):

| Name | Path |
|---|---|
| Island Curb Material | `Assets/Materials/Concrete1.rrmtl` |
| Blank Sign | `Assets/Signs/US/White_Blank_US.svg_rrx` |
| Blank Warning Sign | `Assets/Signs/US/Yellow_Blank_US.svg_rrx` |
| Surface Material | `Assets/Materials/Grass1.rrmtl` |
| Crosswalk | `Assets/Markings/SimpleCrosswalk.rrcws` |
| Stop Line | `Assets/Markings/StopLine.rrlms` |
| Parking Space Marking | `Assets/Markings/SolidSingleWhite.rrlms` |
| Road Surface Material | `Assets/Materials/Asphalt1.rrmtl` |
| Road Center Marking | `Assets/Markings/SolidDoubleYellow.rrlms` |
| Dashed Road Marking | `Assets/Markings/DashedSingleWhite.rrlms` |
| Road Outer Boundary | `Assets/Markings/SolidSingleWhite.rrlms` |
| Road Inner Boundary | `Assets/Markings/SolidSingleYellow.rrlms` |
| One Way Passing | `Assets/Markings/DashedSolidYellow.rrlms` |
| Vehicle | `Assets/Vehicles/Sedan.fbx` |

## Usage Pattern (MATLAB)

```matlab
% Example: resolve marking asset path
function assetPath = resolveMarkingAsset(type, color)
    % type: "solid", "dashed", "solid_solid", etc.
    % color: "white", "yellow" (default: white)
    if nargin < 2, color = "white"; end
    % Use lookup from references/laneMarkings.md
end
```

All asset paths are prefixed with `Assets/` when used in RRHD `RelativeAssetPath` objects.

## Conventions

- All marking assets: `Assets/Markings/<Name>.<ext>` — extension determines type (`.rrlms`, `.rrcws`, `.rrpms`)
- Regional marking variants: `Assets/Markings/<Region>/<Name>_<CC>.<ext>_rrx` (e.g., `_JP.rrlms_rrx`)
- All sign assets: `Assets/Signs/<Region>/<Category>/<Description>_<CC>.svg_rrx` (NOT `.svg`)
- All extrusion assets: `Assets/Extrusions/<Name>.rrext` (or `.rrext.rrmeta`)
- All prop assets: `Assets/Props/<Category>/<Name>.fbx` (or `.fbx_rrx`)
- Use `RelativeAssetPath(AssetPath="...")` for RRHD construction (Name=Value syntax)
- Default road center: `SolidDoubleYellow.rrlms`; default outer boundary: `SolidSingleWhite.rrlms`
- **Always verify asset exists at runtime** before assigning — paths vary by version and installed libraries

----

Copyright 2026 The MathWorks, Inc.
