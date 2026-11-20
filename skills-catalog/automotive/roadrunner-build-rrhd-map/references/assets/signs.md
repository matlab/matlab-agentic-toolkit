# Sign Asset Mapping, Placement, and Orientation

Resolve every sign code with [scripts/resolveSignAsset.m](../../scripts/resolveSignAsset.m) — do not hand-build lookup tables.

```matlab
[assetPath, objectType, code, isFallback] = resolveSignAsset("jp_330-A", region);
[assetPath, ~, ~, isFallback] = resolveSignAsset("DE-2017/274-70", region, ProjectFolder=projectFolder);  % verify on disk
```

## Extensions and names (RoadRunner_Asset_Library, R2026a)

- Most signs are `.svg_rrx`, but several US signs are plain `.svg` (`Stop_US.svg`, `Yield_US.svg`, `NoUTurns_US.svg`, `White_Blank_US.svg`). Never assume one extension — pass `ProjectFolder` so the resolver checks both.
- Names are descriptive English with a region suffix. Numeric names such as `Sign_330-A.svg` do not exist.
- Asset paths start with `Assets/`. On disk each asset may appear only as `<asset>.rrmeta`; reference the asset path without `.rrmeta`.

| Sign | Japan | Germany | US |
|---|---|---|---|
| Stop | `Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx` | `Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx` | `Signs/US/Regulatory Signs/Stop_US.svg` |
| Yield | `Signs/Japan/Auxiliary Signs/Yield_JP.svg_rrx` | `Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx` | `Signs/US/Regulatory Signs/Yield_US.svg` |
| Speed limit N | `Signs/Japan/Regulatory Signs/MaxSpeedLimit_<N>_JP.svg_rrx` (10–100) | `Signs/Germany/Regulatory Signs/MaxSpeed_<N>_DE.svg_rrx` | `Signs/US/Regulatory Signs/SpeedLimit_<N>_US.svg_rrx` |
| No U-turn | `Signs/Japan/Regulatory Signs/NoUTurns_JP.svg_rrx` | — | `Signs/US/Regulatory Signs/NoUTurns_US.svg` |
| No entry / parking / stopping | `NoEntryForVehicles_JP`, `NoParking_JP`, `NoStopping_JP` (`.svg_rrx`, Regulatory Signs) | — | — |
| One way / no overtaking / slow down | `OneWay_JP_01`, `NoOvertaking_JP`, `SlowDown_JP_01` (`.svg_rrx`, Regulatory Signs) | — | — |
| Unrecognized code (all regions) | `Signs/US/White_Blank_US.svg` | same | same |

Traffic lights resolve to `Props/Signals/Signal_3Light_Post01.fbx` with `objectType = "signal"` — RoadRunner ignores signals on RRHD import, so count and report them instead of building them.

## Codes the resolver recognizes

| Source | Examples | Resolves to |
|---|---|---|
| Keyword (any region) | `stop`, `stop_sign`, `yield`, `give_way`, `speed_limit_30`, `no_u_turn` | Region stop / yield / speed / no U-turn |
| Japan (Autoware `traffic_sign_id`, `sign_type`) | `jp_330-A` (一時停止 stop), `jp_323-40` (最高速度 speed), `jp_329` (徐行 slow down), `no_entry`, `no_parking`, `no_stopping`, `one_way`, `no_overtaking` | Japan assets |
| Germany (StVO) | `de206` stop, `de205` yield, `de274-30` speed; prefixed `DE-2017/274-70` | Germany assets |
| Germany (StVO, exact assets) | 267 no entry, 272 no U-turn, 276/277 no passing (all / trucks), 278 end speed limit, 280/281 end no passing, 282 end of restrictions, 283/286 no stopping / no parking, 264/265/266 max width / height / length, 215 roundabout, 220 one way, 237 bicycle path, 239 footpath, 301/306/307/308 priority signs | `Signs/Germany/Regulatory Signs/…`, `Signs/Germany/Directional Signs/…` |
| US (MUTCD) | `us_r1_1` stop, `us_r1_2` yield, `us_r2_1-30` speed | US assets |
| Anything else (`unknown`, `DE-2017/dynamic`, `DE-2017/267`) | — | Blank sign, `isFallback = true` — count and report |

Prefixes `traffic_sign/`, `de`, `de-2017/`, `us_`, `jp_` are stripped before matching.

## Region detection

```matlab
lat = geoRef(1); lon = geoRef(2);
if lat >= 24 && lat <= 46 && lon >= 122 && lon <= 154
    region = "Japan";
elseif lat >= 35 && lat <= 72 && lon >= -10 && lon <= 25
    region = "Germany";
else
    region = "US";   % UK, China, and other regions are not mapped — US assets
end
```

## Sign geometry and orientation

`Sign.Geometry` is a `GeoOrientedBoundingBox`:

| Property | Meaning |
|---|---|
| `Center` | `[x y z]` in map coordinates |
| `Dimension` | **Half-lengths** along the box's local axes (center to face). A 0.6 m × 0.6 m sign → `[0.02 0.3 0.3]` |
| `GeoOrientation` | **`[roll pitch heading]` in radians** — heading is the third element |

Face approaching traffic: take the nearest lane center-line segment, and rotate its travel direction by 180°.

```matlab
% laneCenters: cell array of Nx3 lane center lines in travel direction
best = inf; heading = 0;
for k = 1:numel(laneCenters)
    c = laneCenters{k};
    [d, i] = min(vecnorm(c(:,1:2) - signCenter(1:2), 2, 2));
    if d < best
        i = min(max(i, 1), size(c,1) - 1);
        seg = c(i+1,1:2) - c(i,1:2);
        heading = atan2(-seg(2), -seg(1));     % radians, facing oncoming traffic
        best = d;
    end
end
bb = roadrunner.hdmap.GeoOrientedBoundingBox;
bb.Center = signCenter;
bb.Dimension = [0.02 0.3 0.3];
bb.GeoOrientation = [0 0 heading];
```

Build one `SignType` per resolved asset path and one `Sign` per **physical** sign — for Lanelet2 maps, the Convert workflow's sign step (extractNonLaneElements.md, Step 9c) removes duplicate sign ways and regulatory elements.

----

Copyright 2026 The MathWorks, Inc.

----
