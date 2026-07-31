# rrhd_mapLanelet2SignCode

Maps Lanelet2 sign/signal type codes to RoadRunner asset paths, default bounding box dimensions, and object type classification.

**CRITICAL:** All sign assets use `.svg_rrx` extension (NOT `.svg`). Use descriptive naming (`Stop_US.svg_rrx`, `MaxSpeedLimit_30_DE.svg_rrx`). Determine region from `rrMap.GeoReference` using the bounding-box algorithm in `roadrunner-asset-mapping/references/signs.md`.

## Signature

```matlab
[assetPath, defaultDim, objectType] = rrhd_mapLanelet2SignCode(signCode, region)
```

## Inputs

| Parameter | Type | Description |
|-----------|------|-------------|
| `signCode` | `string` | Lanelet2 `sign_type` value (e.g. `"us_r1_1"`, `"de274-30"`, `"traffic_light"`) |
| `region` | `string` | Detected region: `"US"`, `"Germany"`, or `"Japan"` (from geoReference) |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `assetPath` | `string` | RoadRunner relative asset path (e.g. `"Assets/Signs/US/Stop_US.svg_rrx"`) |
| `defaultDim` | `1x3 double` | Default bounding box `[width, depth, height]` in meters |
| `objectType` | `string` | `"sign"` or `"signal"` — determines which RRHD object type to create |

## Supported Sign Code Families

### US Signs
| Code | Meaning | Asset |
|------|---------|-------|
| `us_r1_1`, `stop`, `us_stop` | Stop | `Signs/US/Stop_US.svg_rrx` |
| `us_r1_2`, `yield`, `us_yield` | Yield | `Signs/US/Yield_US.svg_rrx` |
| `us_r2_1`, or `us_` + `speed` | Speed Limit | `Signs/US/Regulatory Signs/MaxSpeedLimit_<N>_US.svg_rrx` |
| `us_no_u_turn` | No U-Turn | `Signs/US/NoUTurns_US.svg_rrx` |
| Unresolved US code | Fallback | `Signs/US/White_Blank_US.svg_rrx` |

### German StVO Signs
| Code | Meaning | Asset |
|------|---------|-------|
| `de206`, `de_stop` | Stop | `Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx` |
| `de205`, `de_yield` | Yield | `Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx` |
| `de274-*` + value N | Speed Limit | `Signs/Germany/Regulatory Signs/MaxSpeedLimit_<N>_DE.svg_rrx` |
| Unresolved German code | Fallback | `Signs/Germany/Warning Signs/Danger_DE.svg_rrx` |

### Japanese Signs
| Code | Meaning | Asset |
|------|---------|-------|
| `jp_stop`, `stop` (Japan region) | Stop | `Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx` |
| contains `speed` + value N (Japan) | Speed Limit | `Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx` |
| Unresolved Japanese code | Fallback | `Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx` |

### Generic Keywords (resolved using detected region)
| Pattern | Mapping |
|---------|---------|
| Contains `stop` | Region-appropriate stop sign |
| Contains `yield` or `give_way` | Region-appropriate yield sign |
| Contains `speed` + value N | Region-appropriate `MaxSpeedLimit_<N>_<CC>.svg_rrx` |
| Contains `traffic_light` or `signal` | Traffic signal (`objectType = "signal"`) |

### Default Dimensions
| Object Type | Width | Depth | Height |
|-------------|-------|-------|--------|
| Sign | 0.00 | 0.50 | 0.50 |
| Signal | 0.26 | 0.32 | 0.58 |

## Unmapped Codes

If a sign code doesn't match any known pattern, use the region-appropriate fallback sign (never return empty — always place a visible sign).

## Example

```matlab
[path, dim, type] = rrhd_mapLanelet2SignCode("us_r1_1", "US");
% path = "Assets/Signs/US/Stop_US.svg_rrx"
% dim  = [0.00, 0.50, 0.50]
% type = "sign"

[path, dim, type] = rrhd_mapLanelet2SignCode("de274-30", "Germany");
% path = "Assets/Signs/Germany/Regulatory Signs/MaxSpeedLimit_30_DE.svg_rrx"
% dim  = [0.00, 0.50, 0.50]
% type = "sign"

[path, dim, type] = rrhd_mapLanelet2SignCode("traffic_light", "US");
% path = "Assets/Props/Signals/Signal_3Light_Post01.fbx"
% dim  = [0.26, 0.32, 0.58]
% type = "signal"
```

----

Copyright 2026 The MathWorks, Inc.
