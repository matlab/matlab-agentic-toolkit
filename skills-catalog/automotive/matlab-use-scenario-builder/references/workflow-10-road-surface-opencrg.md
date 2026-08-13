---
name: workflow-10-road-surface-opencrg
description: Extract high-resolution road surface profiles from lidar point clouds using roadSurface, export to ASAM OpenCRG (.crg) for vehicle dynamics simulation, query elevation, derive lane boundaries for RoadRunner/OpenDRIVE, and export curved-grid mesh for Unreal. Loaded when user mentions road surface, OpenCRG, vehicle dynamics from lidar, or chassis testing.
---

# Workflow 10 — Road Surface Extraction & ASAM OpenCRG Export

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user needs sub-millimeter road surface profiles for vehicle dynamics or chassis testing.
>
> **Related references:** [`workflow-11-point-cloud-georef.md`](workflow-11-point-cloud-georef.md) for upstream point cloud georeferencing and the `addElevation` vs `roadSurface` decision.

Use `roadSurface` to extract high-resolution road surface profiles from lidar point cloud data. The output supports vehicle dynamics, chassis, and kinematics testing via ASAM OpenCRG, and can also feed into RoadRunner, Unreal Engine, and Simscape workflows.

**Resolution:** Accuracy depends on lidar resolution — with high-res lidar, surface detail can reach sub-millimeter (down to ~1mm). Control via `gridResolution` parameter (lateral × longitudinal step size in meters).

## Inputs
- **Point cloud** — georeferenced `pointCloud` object (from lidar stitching/aerial scan)
- **Road reference line** — N×3 matrix, trajectory object, or ego path
- **Road width** — scalar (symmetric) or `[left, right]` from reference line
- **Grid resolution** — `[lateral, longitudinal]` in meters (e.g., `[0.01, 0.01]` for 1cm). Lower values → higher resolution surface (more detail) but longer processing time; higher values → faster but coarser

## Step 1: Create road surface object
```matlab
%% Extract road surface from georeferenced point cloud
% ptCloud: merged/stitched lidar point cloud (georeferenced)
% refLine: road centerline or ego trajectory
% width: road width from reference line [left, right] in meters
% resolution: [lateral, longitudinal] grid step in meters

rsObj = roadSurface(ptCloud, refLine, [5 5], [0.01 0.01], ...
    LocalOrigin=geoReference, ...
    InterpolationMethod="linear");

% Visualize
show(rsObj);
```

## Step 2: Export to ASAM OpenCRG (vehicle dynamics testing)
```matlab
%% Export OpenCRG file — used directly by vehicle dynamics simulators
crgFile = fullfile(dataDir, "road_surface.crg");
exportToASAMOpenCRG(rsObj, crgFile);
fprintf("OpenCRG exported: %s\n", crgFile);

% The .crg file can be used in:
% - Simscape Multibody (vehicle dynamics)
% - IPG CarMaker, VIRES VTD, dSPACE ASM
% - Any ASAM OpenCRG-compatible simulator
```

## Step 3: Query elevation at arbitrary points
```matlab
%% Use evaluate() to get elevation at specific (s, t) coordinates
% s = longitudinal distance along reference line
% t = lateral offset from reference line
sQuery = [0:0.5:100]';  % every 0.5m along road
tQuery = zeros(size(sQuery));  % at centerline
elevations = evaluate(rsObj, sQuery, tQuery);
```

## Step 4: Extract road boundaries → RoadRunner / OpenDRIVE
```matlab
%% getRoadBoundaries returns laneBoundarySegment objects
lbSegments = getRoadBoundaries(rsObj);

% Feed into RoadRunner HD Map pipeline
lbGroup = laneBoundaryGroup(lbSegments);
rrMap = getLanesInRoadRunnerHDMap(lbGroup);
write(rrMap, fullfile(tempdir, "road_from_surface.rrhd"));

% Or export to OpenDRIVE via drivingScenario → roadNetwork
```

## Step 5: Export mesh for Unreal Engine workflows
```matlab
%% Get curved grid point cloud (for mesh generation / Unreal import)
pcGrid = getCurvedGridPointCloud(rsObj);
% pcGrid is a pointCloud object representing the road surface mesh
% Can be exported as .ply/.obj for Unreal Engine terrain import
pcwrite(pcGrid, fullfile(dataDir, "road_mesh.ply"));
```

## Georeferencing with LocalOrigin
The `LocalOrigin` property (`[lat lon alt]`) anchors the road surface to geographic coordinates. This ensures alignment when combining with OSM roads, HD maps, or GPS trajectories:
```matlab
% Create with geo-reference (aligns with OSM/trajectory coordinate system)
rsObj = roadSurface(ptCloud, egoTrajectory, [6 6], [0.02 0.02], ...
    LocalOrigin=egoTrajectory.LocalOrigin);
```

## Downstream Consumers

| Output | Method | Consumer |
|--------|--------|----------|
| ASAM OpenCRG `.crg` | `exportToASAMOpenCRG` | Vehicle dynamics (Simscape, CarMaker, dSPACE) |
| Elevation query | `evaluate(rsObj, s, t)` | Custom analysis, height correction |
| Road boundaries | `getRoadBoundaries` → `laneBoundarySegment` | RoadRunner HD Map, OpenDRIVE |
| Point cloud mesh | `getCurvedGridPointCloud` | Unreal Engine, 3D visualization |
| Grid resolution update | `updateGridResolution` | Trade off detail vs file size |

----

Copyright 2026 The MathWorks, Inc.

----
