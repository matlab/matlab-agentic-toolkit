---
name: workflow-11-point-cloud-georef
description: Add elevation to flat HD maps from georeferenced point clouds (addElevation), choose between addElevation and roadSurface based on simulator capability, extract per-frame ego-centric point clouds via egoPointCloudExtractor, and georeference raw lidar sequences. Loaded when user mentions point cloud georeferencing, elevation, or per-frame lidar extraction.
---

# Workflow 11 — Point Cloud Georeferencing & Elevation Pipeline

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user has georeferenced point clouds and needs elevation, lidar slicing, or stitching.
>
> **Related references:** [`workflow-10-road-surface-opencrg.md`](workflow-10-road-surface-opencrg.md) for the alternate `roadSurface` → OpenCRG path when the target simulator doesn't support 3D boundary points.

Use `addElevation` and `egoPointCloudExtractor` to work with georeferenced point clouds in the scenario pipeline.

## Choosing Between `addElevation` and `roadSurface` (OpenCRG)
| Use Case | Function | Why |
|----------|----------|-----|
| Simulator supports 3D boundary points (e.g., RoadRunner, Unreal) | `addElevation` | Adds Z directly to road/lane geometry |
| Simulator does NOT support 3D boundaries (e.g., IPG CarMaker) | `roadSurface` → `exportToASAMOpenCRG` | Encodes elevation/banking as OpenCRG surface; import OpenDRIVE + OpenCRG together to simulate banking |

> **Key insight:** Some simulators like CarMaker cannot represent banking through 3D boundary points. For these, create an ASAM OpenCRG file using `roadSurface` and pair it with the OpenDRIVE road network. The CRG encodes the road profile (elevation, cross-slope, banking) that the simulator applies on top of the flat road geometry.

## Adding Elevation to HD Maps
When you have a georeferenced point cloud (from aerial lidar, SLAM stitching, or USGS 3DEP data), add real-world elevation to flat HD maps:
```matlab
%% Add elevation to roadrunnerHDMap using georeferenced point cloud
% rrMap: flat HD map from OSM (z=0 everywhere)
% geoRefPtCloud: georeferenced pointCloud with real elevation
elevatedMap = addElevation(rrMap, geoRefPtCloud, GridStep=0.01);
write(elevatedMap, fullfile(tempdir, "elevated_roads.rrhd"));
```

**`GridStep` parameter** (default: `0.01` meters = 1cm):
- Controls the interpolation grid resolution when sampling elevation from the point cloud
- **Lower values** → higher elevation accuracy, but significantly longer processing time
- **Higher values** → faster processing, but may miss fine elevation detail
- Recommended: start with `0.05` (5cm) for quick validation, then reduce to `0.01` or lower for final output

`addElevation` also works on:
- **2D lane boundary points** (N×2 → N×3): adds Z to flat lane geometry
- **Static object cuboids** (M×9): adjusts Z position to sit on terrain

## Extracting Per-Frame Point Clouds Along Ego Path
Use `egoPointCloudExtractor` to slice a large merged point cloud into per-frame local views along the ego trajectory — useful for generating synthetic lidar data or transforming to model-input format:
```matlab
%% Extract ego-centric point cloud frames from a large merged map
pcExtractor = egoPointCloudExtractor(mergedPtCloud, egoTrajectory, ...
    MaxRange=80, Height=1.8);

fprintf("Frames available: %d\n", pcExtractor.NumPointClouds);

% Extract frame-by-frame (ego-relative coordinates)
frameIdx = 1;
while hasFrame(pcExtractor)
    localPC = extractFrame(pcExtractor);
    % localPC is in ego-relative coordinates
    % Use pctransform to convert to sensor frame if needed
    frameIdx = frameIdx + 1;
end
```

## Georeferencing Workflow (from raw lidar sequences)
This section is for **vehicle-mounted lidar sequences** that need register + stitch + georeference. For **aerial top-down lidar** (a single LAS/LAZ tile with embedded CRS or a known EPSG code), use [`workflow-16-aerial-lidar-augmentation.md`](workflow-16-aerial-lidar-augmentation.md) — it goes through `readCRS` + `helperGeoreferencePointCloud` and pairs the result with OSM at the same georeference. Do NOT try to register an already-stitched aerial tile.

To build a georeferenced point cloud from a sequence of lidar frames + GPS:
1. **Register** frames using `pcregistericp` or `pcregisterndt`
2. **Stitch** into merged cloud using `pcmerge` / `pctransform`
3. **Georeference** using GPS coordinates (align local frame to lat/lon via `LocalOrigin`)
4. **Use** the georeferenced cloud with `addElevation`, `roadSurface`, or `egoPointCloudExtractor`

----

Copyright 2026 The MathWorks, Inc.

----
