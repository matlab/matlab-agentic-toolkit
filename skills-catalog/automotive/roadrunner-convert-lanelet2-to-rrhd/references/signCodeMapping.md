# Sign Code Mapping (Lanelet2 → RoadRunner)

Maps standard Lanelet2 `sign_type` codes to RoadRunner asset paths.

**CRITICAL:** All sign assets use `.svg_rrx` extension (NOT `.svg`). The old `Sign_<code>.svg` naming is obsolete. Use descriptive naming: `<Description>_<Region>.svg_rrx`.

**Region detection:** Determine the region from `rrMap.GeoReference` using the bounding-box algorithm in `roadrunner-asset-mapping` skill's `references/signs.md`. Apply region-appropriate assets.

## Function Pattern

```matlab
function [assetPath, defaultDim, objectType] = mapSignCode(signCode)
% Returns empty assetPath if unmapped (caller should skip)
```

## Lookup Table

### Traffic Lights / Signals
| Code pattern | Asset Path | Dimensions | Type |
|---|---|---|---|
| Contains `traffic_light` or `signal` | `Assets/Props/Signals/Signal_3Light_Post01.fbx` | [0.26 0.32 0.58] | `signal` |

### US Signs
| Code(s) | Asset Path | Type |
|---|---|---|
| `us_r1_1`, `stop`, `us_stop` | `Assets/Signs/US/Stop_US.svg_rrx` | `sign` |
| `us_r1_2`, `yield`, `us_yield` | `Assets/Signs/US/Yield_US.svg_rrx` | `sign` |
| `us_r2_1`, or `us_` + contains `speed` | `Assets/Signs/US/Regulatory Signs/MaxSpeedLimit_<N>_US.svg_rrx` | `sign` |
| `us_r3_4`, `us_no_u_turn` | `Assets/Signs/US/NoUTurns_US.svg_rrx` | `sign` |
| Unresolved US code | `Assets/Signs/US/White_Blank_US.svg_rrx` | `sign` |

### German StVO Signs
| Code pattern | Asset Path | Type |
|---|---|---|
| `de206` or `de_stop` | `Assets/Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx` | `sign` |
| `de205` or `de_yield` | `Assets/Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx` | `sign` |
| starts with `de274` + value N | `Assets/Signs/Germany/Regulatory Signs/MaxSpeedLimit_<N>_DE.svg_rrx` | `sign` |
| Unresolved German code | `Assets/Signs/Germany/Warning Signs/Danger_DE.svg_rrx` | `sign` |

### Japanese Signs
| Code pattern | Asset Path | Type |
|---|---|---|
| `jp_stop`, `stop` (Japan region) | `Assets/Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx` | `sign` |
| `jp_speed` or contains `speed` (Japan) | `Assets/Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx` | `sign` |
| Unresolved Japanese code | `Assets/Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx` | `sign` |

### Generic / Autoware Conventions (fallback — uses region detection)
| Code contains | Asset Path (region-resolved) | Type |
|---|---|---|
| `stop` or `stop_sign` | Region-appropriate stop sign (see above) | `sign` |
| `yield` or `give_way` | Region-appropriate yield sign (see above) | `sign` |
| `speed` + value N | Region-appropriate `MaxSpeedLimit_<N>_<CC>.svg_rrx` | `sign` |

### Defaults
- Default sign dimensions: `[0 0.50 0.50]` (flat, 0.5m × 0.5m)
- Match order: traffic lights → US MUTCD → German StVO → generic keywords
- If no match: return empty `assetPath` (caller skips this sign)

## Orientation Estimation

Signs/signals face approaching traffic. Estimate orientation by finding the nearest lanelet center line segment and rotating 180°:

```matlab
% For each lanelet center geometry, find closest segment to sign position
% Project sign pos onto segment, get segment direction
% Sign faces opposite: yawRad = atan2(-segDir(2), -segDir(1))
% orientation = [0, 0, rad2deg(yawRad)]
```

## Standard Regulatory Element Processing

### `subtype=traffic_sign`
1. Get `sign_type` tag from the relation → look up asset via table above
2. **Fallback:** If `sign_type` is empty, get `subtype` tag from the referred way (e.g., `stop_sign`, `yield_sign`)
3. Skip if code is empty or `"unknown"`
4. Find physical location from `refers` member (way centroid or node coords)
5. Estimate orientation from nearest lanelet
6. Create SignType + Sign instance (use `GeoOrientedBoundingBox` for Geometry)

### `subtype=traffic_light`
1. Use `traffic_light` asset path from table
2. Find location from `refers` member
3. Estimate orientation from nearest lanelet
4. Create SignalType + Signal instance

### `subtype=speed_limit`
1. Extract speed value from `sign_type` (regex `(\d+)$`) or `speed_limit` tag
2. Apply to all `refers` relation members (lanelet speed_limit field)
3. Optionally create a speed limit sign (if `sign_type` is present)

## Speed Value Extraction

```matlab
% From sign_type tag like "de274-30" → extract trailing digits
tokens = regexp(signType, '(\d+)$', 'tokens');
if ~isempty(tokens), speedVal = str2double(tokens{1}{1}); end
% Also check explicit 'speed_limit' tag on the relation
```

----

Copyright 2026 The MathWorks, Inc.
