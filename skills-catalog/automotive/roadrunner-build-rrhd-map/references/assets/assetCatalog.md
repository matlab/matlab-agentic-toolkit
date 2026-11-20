# Asset Catalog — Rules, Curve Markings, Signals, Stencils, Materials, Defaults

Consolidated lookup tables for mapping source map format elements to RoadRunner project asset paths. All paths are relative to the project `Assets/` folder.



## Key Rules

- **All asset paths start with `Assets/`** — always prefix when constructing `RelativeAssetPath` objects.
- **Extension matters.** `.rrlms` = lane marking style, `.rrcws` = crosswalk style, `.rrpms` = polygon marking style, `.svg_rrx` / `.svg` = sign. Using wrong extension causes "Asset file is missing" on import.
- **Signs are mostly `.svg_rrx`, but several US signs are plain `.svg`** (`Stop_US.svg`, `Yield_US.svg`, `White_Blank_US.svg`). Resolve with `resolveSignAsset` and pass `ProjectFolder` to verify.
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

See [references/laneMarkings.md](laneMarkings.md) for full mapping table.

**Key patterns:**
- All marking assets are in `Assets/Markings/` with `.rrlms` extension
- Markings are keyed by **type** (solid/dashed/double) + **color** (white/yellow)
- Default road center marking: `SolidDoubleYellow.rrlms`
- Default outer boundary: `SolidSingleWhite.rrlms`

## Signs

Resolve every sign with `resolveSignAsset` — full table, recognized codes, region detection, placement, and orientation (`GeoOrientation = [roll pitch heading]` in radians, `Dimension` = half-lengths): [signs.md](signs.md).

## Signals (Traffic Lights)

| Configuration | Asset Path |
|---|---|
| 3-light vertical (post) | `Props/Signals/Signal_3Light_Post01.fbx` |
| 3-light vertical (bare) | `Props/Signals/Signal_3Light_Bare01.fbx_rrx` |

**Authoring vs Import limitation:** You CAN author `SignalType` objects (add to `rrMap.SignalTypes`) and `Signal` instances (add to `rrMap.Signals`) in MATLAB and write the map to `.rrhd` — signal data IS written to the file and survives read/write cycles. However, RoadRunner **silently ignores** signals when importing `.rrhd` maps — signals will not appear in the RoadRunner scene after import. Show the asset paths and authoring code, but warn the user about this import limitation.

## Barriers & Extrusions

See [references/barriers.md](barriers.md) for full mapping table.

**Key patterns:**
- All extrusions in `Assets/Extrusions/` as `<Name>.rrext` (the `.rrmeta` file is the metadata sidecar)
- Barriers use `roadrunner.hdmap.BarrierType` with `ExtrusionPath`

## Props & Static Objects

See [references/staticObjects.md](staticObjects.md) for full mapping table.

**Key patterns:**
- Props in `Assets/Props/` subdirectories (Trees, Signals, TrafficControl, etc.)
- Static objects use `roadrunner.hdmap.StaticObjectType` with `AssetPath`
- Objects use `GeoOrientedBoundingBox` for placement

## Lane Types

See [references/laneTypes.md](laneTypes.md) for full mapping table.

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
| Crosswalk | `Markings/Japan/ContinentalCrosswalk_JP.rrcws_rrx` |
| Solid single white | `Markings/Japan/SolidSingleWhite_JP.rrlms_rrx` |
| Dashed single white | `Markings/Japan/DashedSingleWhite_JP.rrlms_rrx` |
| Solid double white | `Markings/Japan/SolidDoubleWhite_JP.rrlms_rrx` |
| Solid double yellow | `Markings/Japan/SolidDoubleYellow_JP.rrlms_rrx` |

**Germany-specific markings:**

| Type | Asset Path |
|---|---|
| Stop line | `Markings/Germany/StopLine.rrlms_rrx` |
| Crosswalk | `Markings/Germany/GermanCrosswalk.rrcws_rrx` |

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
| Blank Sign | `Assets/Signs/US/White_Blank_US.svg` |
| Blank Warning Sign | `Assets/Signs/US/Yellow_Blank_US.svg` |
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

## Conventions

- All marking assets: `Assets/Markings/<Name>.<ext>` — extension determines type (`.rrlms`, `.rrcws`, `.rrpms`)
- Regional marking variants: `Assets/Markings/<Region>/<Name>_<CC>.<ext>_rrx` (e.g., `_JP.rrlms_rrx`)
- Sign assets: `Assets/Signs/<Region>/<Category>/<Description>_<CC>.svg_rrx` — some US signs are `.svg`; verify on disk
- All extrusion assets: `Assets/Extrusions/<Name>.rrext`
- All prop assets: `Assets/Props/<Category>/<Name>.fbx` (or `.fbx_rrx`)
- Use `RelativeAssetPath(AssetPath="...")` for RRHD construction (Name=Value syntax)
- Default road center: `SolidDoubleYellow.rrlms`; default outer boundary: `SolidSingleWhite.rrlms`
- **Always verify asset exists at runtime** before assigning — paths vary by version and installed libraries

----

Copyright 2026 The MathWorks, Inc.

----
