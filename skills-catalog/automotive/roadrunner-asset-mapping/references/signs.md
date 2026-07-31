# Sign Asset Mapping

Maps traffic sign types to RoadRunner asset paths across all source formats.

## CRITICAL: Asset File Extension

RoadRunner project sign assets use `.svg_rrx` extension on disk (NOT `.svg`). The `.svg` paths in project XML configs are internal references only. **Always use `.svg_rrx` in `RelativeAssetPath` objects.** Using `.svg` causes "Could not find asset" errors on import.

## MANDATORY: Runtime Asset Discovery

Sign asset names and paths vary by RoadRunner version and installed asset libraries. **Always verify at runtime** that the target asset exists in the project before assigning it:

```matlab
% Discover available sign assets for a region
projFolder = '<project path>';
signDir = fullfile(projFolder, 'Assets', 'Signs', region, 'Regulatory Signs');
availableSigns = dir(fullfile(signDir, '*.svg_rrx'));
signNames = {availableSigns.name};
% Match sign codes to available assets using contains() or regexp
```

## Naming Convention

Sign assets use **descriptive English names** with a region suffix, NOT numeric regulatory codes:
- Pattern: `<Description>_<Region>.svg_rrx` (e.g., `Stop_JP_01.svg_rrx`, `MaxSpeedLimit_30_JP.svg_rrx`)
- The old `Sign_<code>.svg` naming (e.g., `Sign_330-A.svg`) is **obsolete** and files do NOT exist on disk

## US Signs (North America)

| Sign Type | Asset Path |
|---|---|
| STOP | `Signs/US/Stop_US.svg_rrx` |
| YIELD | `Signs/US/Yield_US.svg_rrx` |
| NO_U_TURN | `Signs/US/NoUTurns_US.svg_rrx` |
| ROUNDABOUT | `Signs/US/Roundabout_US.svg_rrx` |
| Blank (white) | `Signs/US/White_Blank_US.svg_rrx` |
| Blank (yellow) | `Signs/US/Yellow_Blank_US.svg_rrx` |

**Speed limit pattern:** `Signs/US/Regulatory Signs/MaxSpeedLimit_<N>_US.svg_rrx`

## German StVO Signs

| Sign Type | Asset Path |
|---|---|
| Stop (206) | `Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx` |
| Yield (205) | `Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx` |
| Speed limit (274) | `Signs/Germany/Regulatory Signs/MaxSpeedLimit_<N>_DE.svg_rrx` |
| Warning (fallback) | `Signs/Germany/Warning Signs/Danger_DE.svg_rrx` |

**Speed limit pattern:** `Signs/Germany/Regulatory Signs/MaxSpeedLimit_<N>_DE.svg_rrx`

## Japanese Signs (Lanelet2 maps in Japan)

| Sign Type | Asset Path |
|---|---|
| STOP | `Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx` |
| STOP (variant) | `Signs/Japan/Regulatory Signs/Stop_JP_02.svg_rrx` |
| SPEED_LIMIT | `Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx` |
| NO_ENTRY | `Signs/Japan/Regulatory Signs/NoEntryForVehicles_JP.svg_rrx` |
| NO_PARKING | `Signs/Japan/Regulatory Signs/NoParking_JP.svg_rrx` |
| NO_STOPPING | `Signs/Japan/Regulatory Signs/NoStopping_JP.svg_rrx` |
| ONE_WAY | `Signs/Japan/Regulatory Signs/OneWay_JP_01.svg_rrx` |
| NO_OVERTAKING | `Signs/Japan/Regulatory Signs/NoOvertaking_JP.svg_rrx` |
| NO_U_TURN | `Signs/Japan/Regulatory Signs/NoUTurns_JP.svg_rrx` |
| SLOW_DOWN (fallback) | `Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx` |

**Speed limit values available:** 10, 20, 30, 40, 50, 60, 70, 80, 90, 100

**Pattern:** `Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx`

## Region Detection from GeoReference

Determine sign region from the map's geoReference latitude/longitude:

| Latitude Range | Longitude Range | Region | Sign Prefix |
|---|---|---|---|
| 24–46 | 122–154 | Japan | `Signs/Japan/` |
| 35–72 | -10–25 | Germany/EU | `Signs/Germany/` |
| 24–50 | -130– -60 | US/NA | `Signs/US/` |
| 50–60 | -8–2 | UK | `Signs/UK/` |
| 18–54 | 73–135 | China | `Signs/China/` |
| (fallback) | — | US | `Signs/US/` |

**Implementation:**
```matlab
function region = detectSignRegion(geoRef)
    lat = geoRef(1); lon = geoRef(2);
    if lat >= 24 && lat <= 46 && lon >= 122 && lon <= 154
        region = "Japan";
    elseif lat >= 35 && lat <= 72 && lon >= -10 && lon <= 25
        region = "Germany";
    elseif lat >= 50 && lat <= 60 && lon >= -8 && lon <= 2
        region = "UK";
    elseif lat >= 18 && lat <= 54 && lon >= 73 && lon <= 135
        region = "China";
    else
        region = "US";  % default fallback
    end
end
```

## Blank/Fallback Signs

| Type | Asset Path |
|---|---|
| White blank (US) | `Signs/US/White_Blank_US.svg_rrx` |
| Yellow blank (US) | `Signs/US/Yellow_Blank_US.svg_rrx` |
| Slow down (Japan) | `Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx` |
| Danger (Germany) | `Signs/Germany/Warning Signs/Danger_DE.svg_rrx` |

## Lanelet2 Sign Code Mapping

| Lanelet2 `sign_type` / way `subtype` | Resolved Asset |
|---|---|
| `stop`, `stop_sign`, `us_stop`, `de206` | Stop sign (region-appropriate `.svg_rrx`) |
| `yield`, `give_way`, `us_yield`, `de205` | Yield sign (region-appropriate `.svg_rrx`) |
| contains `speed` + value N | `MaxSpeedLimit_<N>_<region>.svg_rrx` |
| `de274` + value | German speed limit sign |
| `unknown`, unresolved | Region-specific fallback (never skip) |
| `traffic_light` | → Signal (not sign — not importable via RRHD) |

## OpenDRIVE Signal Resolution

OpenDRIVE uses `<signal type="274" country="DE" value="30"/>`:
1. Match by `Type` + `Country` + `Value` in the lookup table
2. If no match, fall back to country-appropriate blank sign
3. Variant field (0-3) all map to same asset

## Sign Geometry (RRHD)

```matlab
st = roadrunner.hdmap.SignType;
st.ID = "SpeedLimit_30";
rap = roadrunner.hdmap.RelativeAssetPath;
rap.AssetPath = "Assets/Signs/Japan/Regulatory Signs/MaxSpeedLimit_30_JP.svg_rrx";
st.AssetPath = rap;

sg = roadrunner.hdmap.Sign;
sg.ID = "Sign_1";
gobb = roadrunner.hdmap.GeoOrientedBoundingBox;
gobb.Center = [x, y, z];
gobb.Dimension = [0, 0.6, 0.6];  % flat sign, width x height
gobb.GeoOrientation = [yawDeg, 0, 0];  % [heading, pitch, roll] in degrees
sg.Geometry = gobb;
typeRef = roadrunner.hdmap.Reference;
typeRef.ID = "SpeedLimit_30";
sg.SignTypeReference = typeRef;
```

----

Copyright 2026 The MathWorks, Inc.
