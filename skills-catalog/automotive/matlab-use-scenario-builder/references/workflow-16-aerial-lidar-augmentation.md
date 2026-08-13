---
name: workflow-16-aerial-lidar-augmentation
description: Augment or improve an existing/OSM-derived road scene using aerial (top-down) lidar — extract trees and buildings as static objects, add real elevation/banking to flat OSM maps, and georeference projected point clouds to a local frame. Covers the US-only USGS 3DEP entry point (lat/lon → aerial lidar → OSM → combined .rrhd) and the non-US user-supplied LAS/LAZ + CRS path. Also covers the elevation-only variant where the user wants to improve OSM elevation/banking without extracting static objects.
---

# Workflow 16 — Road Scene Augmentation from Aerial Lidar

> **Parent skill:** [`SKILL.md`](../SKILL.md). Load this when the user wants to **enhance / augment / improve** a road scene (existing or OSM-derived) by adding real-world trees, buildings, or elevation/banking from aerial top-down lidar.
>
> **Related references:**
> - [`workflow-09-static-objects.md`](workflow-09-static-objects.md) — `roadrunnerStaticObjectInfo` + cuboid format. This workflow's static-object placement reuses that contract.
> - [`workflow-11-point-cloud-georef.md`](workflow-11-point-cloud-georef.md) — `addElevation` semantics, `GridStep` choice. This workflow's elevation-only variant reduces to that pattern.
> - [`workflow-04-roadrunner-export-detail.md`](workflow-04-roadrunner-export-detail.md) — `importScene` + `enableOverlapGroupsOptions(IsEnabled=false)` rule.

This workflow covers two related but distinct user needs:

| Variant | Trigger phrases | What you do |
|---------|------------------|-------------|
| **A — Full augmentation** (trees/buildings + roads + elevation) | "augment the scene with trees/buildings", "add static objects from lidar to my OSM scene", "I have a lat/lon and want a realistic scene" | Run the full pipeline below — segment ground vs. non-ground, run RandLA-Net on the non-ground points, extract building/tree cuboids, combine with OSM roads, write `.rrhd`. |
| **B — Elevation/banking only** (no static objects) | "improve my OSM map's elevation/banking/gradient/height", "OSM is flat, add real terrain" | Run **Steps 1, 2, 3, 6 (and 7 partially), and 8** below. Skip Step 4 (cuboid extraction) and Step 5 (`roadrunnerStaticObjectInfo`). Just build `rrMap`, call `addElevation(rrMap, georeferencedPointCloud)`, write the elevated map. |

## Data-source decision (ASK FIRST)

**Always ask the user up front** which entry point applies — the right answer changes which dataset they need to obtain:

> "For aerial-lidar augmentation, where is your road network located, and what data do you have?
> 1. **US location, lat/lon only** — I can pull aerial lidar from the USGS 3DEP LidarExplorer dataset (free, US-only).
> 2. **Non-US location** — You will need to provide the aerial lidar yourself as a `.las` or `.laz` file with embedded CRS info (or an explicit EPSG code). MathWorks does not provide a global aerial-lidar source.
> 3. **You already have a `.las` / `.laz` file** — I will use that directly, regardless of region."

| User has | Entry point | Notes |
|----------|-------------|-------|
| Single lat/lon (or lat/lon/alt) in US | **USGS 3DEP** (`https://apps.nationalmap.gov/lidar-explorer/`) — Ctrl-drag a rectangular AOI, download the LAZ tile | Free, well-tested. The MathWorks doc example uses a prepackaged AOI: `https://ssd.mathworks.com/supportfiles/driving/data/USGSLidarExplorerData.zip`. |
| Single lat/lon outside US | **User-provided LAS/LAZ + CRS** | MathWorks does not recommend a specific non-US source. The user must obtain aerial lidar matching their lat/lon — many national geodata portals publish equivalents (UK Environment Agency, GeoSur, GeoBasis, etc.). |
| `.las` / `.laz` already on disk | Skip the download — go straight to **Step 1**. |

If the user says "non-US" and has nothing to provide, **stop and tell them** — there is no MathWorks-provided fallback to fabricate. Do not try to substitute satellite imagery, DEM rasters, or synthesized clouds.

## Prerequisites

- Scenario Builder for Automated Driving Toolbox (support package)
- Lidar Toolbox
- Computer Vision Toolbox
- Mapping Toolbox
- Automated Driving Toolbox
- RoadRunner with **Scene Builder** license (Variant A static-object placement uses Scene Builder; Variant B elevation-only does NOT require Scene Builder, only the regular RoadRunner license to view the result)
- (Optional) RoadRunner **Asset Library Add-On** for the actual tree/building 3D meshes; without it the `.rrhd` still imports but assets render as placeholders

```matlab
% Verify the support package is present (same check the SKILL.md uses).
isfile(which("scenariobuilder.Trajectory"))
```

## Step 1 — Load aerial lidar

```matlab
%% Step 1: Load LAZ file (USGS 3DEP example, prepackaged)
dataFolder = tempdir;
lidarDataFileName = "USGSLidarExplorerData.zip";
url = "https://ssd.mathworks.com/supportfiles/driving/data/" + lidarDataFileName;
zipPath = fullfile(dataFolder, lidarDataFileName);
if ~isfile(zipPath)
    websave(zipPath, url);
end
unzip(zipPath, dataFolder);

lasfile = fullfile(dataFolder, ...
    "USGS_LPC_CA_NoCAL_3DEP_Supp_Funding_2018_D18_w2276n1958.laz");
lasReader = lasFileReader(lasfile);
registeredPointCloud = readPointCloud(lasReader);
```

For a non-US user-provided LAZ, replace the download block with their path:
```matlab
lasfile = "<user-provided>.laz";
lasReader = lasFileReader(lasfile);
registeredPointCloud = readPointCloud(lasReader);
```

The raw cloud is in a **projected CRS** — the X/Y values will be on the order of 1e6. This is normal; Step 3 transforms it to a local frame.

## Step 2 — Segment ground (and run semantic segmentation, Variant A only)

For **Variant B (elevation only)**, you only need the ground segmentation — skip the RandLA-Net call. For **Variant A**, run both.

```matlab
%% Step 2a: Ground segmentation (both variants)
[groundPtsIdx, pc, ~] = segmentGroundSMRF(registeredPointCloud);
pc = removeInvalidPoints(pc);
```

```matlab
%% Step 2b: Semantic segmentation with RandLA-Net (Variant A only)
% Uses the "dales" pretrained model. Block size 100 m × 100 m matches the
% MathWorks example. The label list covers ground/vegetation/cars/trucks/
% powerlines/fences/poles/buildings.
cmap = helperAerialLidarColorMap;
bpdSizeinMeters = [100 100];
labels = helperRandLANetSegmentObjects(pc, bpdSizeinMeters);
pc.Color = cell2mat(cmap(labels));
```

`helperRandLANetSegmentObjects` and `helperAerialLidarColorMap` are example helpers from the MathWorks doc page; copy them into the generated script's local-functions section (per Rule 9 of SKILL.md). Internally they wrap `randlanet("dales")` + `segmentObjects`.

## Step 3 — Georeference / transform to local frame (CRS handling)

This is the step that turns the projected 1e6-scale cloud into a local frame the rest of the toolchain can consume. The CRS decision is gated on whether the LAZ has CRS metadata:

```matlab
%% Step 3: Build a georeferenced (local-frame) point cloud
if ~isempty(readCRS(lasReader))
    % CRS embedded in LAZ — use it directly.
    [georeferencedPointCloud, georeference] = ...
        helperGeoreferencePointCloud(lasReader);
else
    % LAZ missing CRS — user must supply EPSG code.
    % Example: 6350 = NAD83(2011) / Conus Albers (US continental).
    code = '6350';
    [georeferencedPointCloud, georeference] = ...
        helperGeoreferencePointCloud(lasReader, code);
end
```

`helperGeoreferencePointCloud` returns:
- `georeferencedPointCloud` — the cloud in a local tangent-plane (ENU-style) frame, centered on the cloud's geometric center
- `georeference` — `[latitude longitude altitude]` of that center

**ASK the user for the EPSG code** when `readCRS` returns empty. Do not guess. EPSG codes are looked up at the EPSG home page; common US-projected codes include `6350` (Conus Albers) and the UTM zone codes `326NN` / `327NN`.

> ⚠️ For **Variant A (static objects)**, also color the georeferenced cloud so the cuboid extractor can read labels:
> ```matlab
> pccolor = 255 * ones(georeferencedPointCloud.Count, 3);
> pccolor(~groundPtsIdx, :) = cell2mat(cmap(labels));
> georeferencedPointCloud.Color = uint8(pccolor);
> ```

## Step 4 — Extract tree and building cuboids (**Variant A only — SKIP for elevation-only**)

```matlab
%% Step 4: Cluster labeled points → cuboids
labelNames = ["vegetation", "buildings"];
vegetationParams = struct("minDistance", 1.3, "NumClusterPoints", [250 1500]);
buildingParams   = struct("minDistance", 0.9, "NumClusterPoints", 700);
parameters = struct("vegetation", vegetationParams, "buildings", buildingParams);

cuboids = helperExtractCuboidsFromLidar( ...
    georeferencedPointCloud, parameters, labelNames, cmap);
```

`helperExtractCuboidsFromLidar` is a MathWorks example helper that clusters labeled points into M×9 cuboids. The two `minDistance` / `NumClusterPoints` blocks are tuning knobs — increase `minDistance` and the lower bound of `NumClusterPoints` if the result is over-segmented; decrease them if small bushes/sheds are missed.

> Tuning sub-pass (optional): the doc shows running on a small `[-150 150 -150 150]` ROI first via `findPointsInROI` + `select` so you can iterate parameters quickly without re-running the full cloud.

## Step 5 — Add elevation to cuboids and build static-object info (**Variant A only — SKIP for elevation-only**)

```matlab
%% Step 5: Pin cuboids to terrain, then build RR static-object info
numTrees = size(cuboids{1}, 1);
cuboids = cell2mat(cuboids);
elevationFixedCuboids = addElevation(cuboids, georeferencedPointCloud);

statObjs.trees     = elevationFixedCuboids(1:numTrees, :);
statObjs.buildings = elevationFixedCuboids(numTrees+1:end, :);

[statObjs.buildings, params.buildings.AssetPath] = ...
    helperGenerateAssetPaths("buildings", statObjs.buildings);

objectsInfo = roadrunnerStaticObjectInfo(statObjs, Params=params);
```

`addElevation` on M×9 cuboids snaps each cuboid Z to terrain — without it, the bird's-eye nature of aerial lidar leaves trees/buildings floating ~10 m above the road.

`helperGenerateAssetPaths` chooses RoadRunner asset meshes by building height. Reuse this helper rather than hand-writing asset paths (see [`workflow-09-static-objects.md`](workflow-09-static-objects.md) for the per-category default-dimensions table — only relevant when you don't have measured cuboids).

## Step 6 — Pull OSM roads matching the cloud's georeference

This step is **identical for both variants**. The `georeference(1:2)` from Step 3 is the lat/lon that anchors the OSM ROI — using a different center will misalign roads with the point cloud.

```matlab
%% Step 6: OSM roads at the same geo-reference
osmExtent = mean(abs([georeferencedPointCloud.XLimits ...
                      georeferencedPointCloud.YLimits]));
mapParameters = getMapROI(georeference(1), georeference(2), Extent=osmExtent);
osmFileName = websave("RoadScene.osm", mapParameters.osmUrl, ...
    weboptions(ContentType="xml"));

scenario = drivingScenario;
roadNetwork(scenario, "OpenStreetMap", osmFileName);

rrMap = getRoadRunnerHDMap(scenario);
rrMap = addElevation(rrMap, georeferencedPointCloud);   % <-- the elevation/banking lift
```

The final `addElevation(rrMap, georeferencedPointCloud)` call is what corrects the flat OSM map to real-world elevation, banking, and gradient. **This is the entire payload of Variant B.** (Optionally pass `GridStep=0.05` first for a quick check, then drop to `0.01` for final output — see [`workflow-11-point-cloud-georef.md`](workflow-11-point-cloud-georef.md).)

## Step 7 — Attach static objects to map (**Variant A only — SKIP for elevation-only**)

```matlab
%% Step 7: Attach static objects to the elevated rrMap
rrMap.StaticObjectTypes = objectsInfo.staticObjectTypes;
rrMap.StaticObjects     = objectsInfo.staticObjects;

f = figure(Position=[1000 818 700 500]);
ax = axes("Parent", f);
plot(rrMap, ShowStaticObjects=true, Parent=ax);
```

For **Variant B**, just plot:
```matlab
plot(rrMap);   % roads only, with new elevation
```

## Step 8 — Write `.rrhd` and import into RoadRunner

This step is identical for both variants. **Always disable overlap groups on import** (Rule 4 of SKILL.md):

```matlab
%% Step 8: Write rrhd and import — overlap groups disabled by default
rrMapFileName = "RoadRunnerAerialScene.rrhd";   % name as appropriate
write(rrMap, rrMapFileName);

% Reuse the rrApp single-instance guard from SKILL.md Rule 8
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    rrApp = roadrunner(rrProjectPath, InstallationFolder=rrAppPath);
end

copyfile(rrMapFileName, fullfile(rrProjectPath, "Assets"));
rrhdFile = fullfile(rrProjectPath, "Assets", rrMapFileName);

oOpts = enableOverlapGroupsOptions(IsEnabled=false);
bOpts = roadrunnerHDMapBuildOptions(EnableOverlapGroupsOptions=oOpts);
iOpts = roadrunnerHDMapImportOptions(BuildOptions=bOpts);
importScene(rrApp, rrhdFile, "RoadRunner HD Map", ImportOptions=iOpts);
```

## When this is the wrong workflow

| User's situation | Where to go instead |
|------------------|---------------------|
| Static objects from **vehicle-mounted** lidar (track/cuboid detections, not aerial) | [`workflow-09-static-objects.md`](workflow-09-static-objects.md) directly. |
| Adding **traffic signs** from recorded camera + lidar logs | [`workflow-17-traffic-signs-from-sensor-data.md`](workflow-17-traffic-signs-from-sensor-data.md). |
| Per-frame ego-relative point clouds along a trajectory | [`workflow-11-point-cloud-georef.md`](workflow-11-point-cloud-georef.md) — `egoPointCloudExtractor`. |
| OpenCRG road-surface profile (banking encoded as a CRG layer for IPG CarMaker etc.) | [`workflow-10-road-surface-opencrg.md`](workflow-10-road-surface-opencrg.md) — different pipeline (`roadSurface` + `exportToASAMOpenCRG`), not `addElevation`. |
| Pre-built scene already has terrain (HERE HD, OpenDRIVE+CRG, vendor `.rrscene`) and the user just wants ego/actor heights right | [`workflow-07-height-correction.md`](workflow-07-height-correction.md) — `adjustHeight` on the trajectory; do NOT re-elevate the map. |

## Caveats from the documentation

- Aerial bird's-eye-view means initial cuboid Z is wrong; `addElevation` on cuboids is **mandatory**, not optional.
- Low aerial-lidar resolution can place buildings closer to neighbours than reality, or rotate them slightly. Tune `minDistance` / `NumClusterPoints` if the user reports this.
- The **same georeference** must seed both the cloud transform (Step 3) and the OSM ROI (Step 6) — using different centers misaligns roads from terrain.
- OSM elevation is unreliable; expect to need Step 6's `addElevation` even on small areas where roads look flat in OSM.

----

Copyright 2026 The MathWorks, Inc.

----
