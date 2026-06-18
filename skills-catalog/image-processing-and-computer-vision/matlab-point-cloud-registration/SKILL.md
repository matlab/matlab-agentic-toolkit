---
name: matlab-point-cloud-registration
description: Register 3-D point clouds using ICP, NDT, LOAM, FGR, phase correlation, and CPD algorithms. Use when registering or aligning 3-D point clouds, choosing a registration algorithm, tuning registration parameters, preprocessing point clouds for registration or combining point clouds after registration.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Point Cloud Registration

Select `pcregistericp` with `Metric="planeToPlane"` as the starting point, evaluate algorithm accuracy using RMSE, and align the point clouds using `pcalign`.

## When to Use

- User asks to register, align or match 3-D point clouds represented as `pointCloud` objects
- User needs to choose or tune a registration algorithm
- User wants to build a map from multiple lidar scans
- User wants to combine or merge registered point clouds
- User asks about initial transformation estimation for registration
- User asks to preprocess point clouds before registration

## When NOT to Use

- User wants to register 2-D point clouds (use `matchScans`, `matchScansGrid`, or `matchScansLine`)
- User wants image registration (use `imregtform` or `imregcorr` from Image Processing Toolbox)

## Required Toolboxes

- Computer Vision Toolbox
- Lidar Toolbox

## Legacy Patterns to Avoid

| Do NOT use | Use instead | Why |
|------------|-------------|-----|
| `rigid3d` for InitialTransform | `rigidtform3d` | `rigidtform3d` uses the premultiply transformation convention, which is more commonly used.|

## Algorithm Selection Guide

### Local Registration

If you have an initial transformation or the point clouds are only slightly misaligned, try these local registration methods in this order. Use the RMSE output as the accuracy metric to minimize.

| Algorithm | Function | Notes |
|-----------|----------|-------|
| Generalized ICP (plane-to-plane) | `pcregistericp` with `Metric="planeToPlane"` | Default starting point. Additionally, try `"planeToPlaneWithColor"` if the point cloud has color. |
| ICP (point-to-plane) | `pcregistericp` with `Metric="pointToPlane"`  | Additionally, try `"pointToPlaneWithColor"` if the point cloud has color. |
| ICP (point-to-point) | `pcregistericp` with `Metric="pointToPoint"` | Simplest metric. Try if plane-based metrics are inaccurate. |
| LOAM | `pcregisterloam` | Requires organized point clouds. If the point cloud is not organized, but you have the lidar parameters available, use `pcorganize` to organize the point cloud. Use `detectLOAMFeatures` first to tune feature detection. It gives you more flexibility on the accuracy vs speed tradeoff since `detectLOAMFeatures` has parameters to control the number of features. |
| NDT | `pcregisterndt` | Tune the `gridStep` parameter for the scale of the scene. |

### Ground Data Registration

If you don't have an initial transformation, but you know that the data corresponds to ground data, try phase correlation.

| Algorithm | Function | Notes |
|-----------|----------|-------|
| Phase Correlation | `pcregistercorr` | Specifically designed for ground data. Not a local registration method. |

### Global Registration

If there is no initial transformation and the point clouds are significantly misaligned (overlap less than 50%), first use a global registration approach to align the moving point cloud to the fixed point cloud, then optionally use a local registration method as a refinement step to improve accuracy. Note that global registration approaches are usually slower than local ones.

| Algorithm | Function | Notes |
|-----------|----------|-------|
| FGR | `pcregisterfgr` | Feature-based approach. |
| CPD (rigid) | `pcregistercpd` with `Transform="Rigid"` | Probabilistic framework. It handles outliers well. Use for small point clouds. |
| CPD (nonrigid) | `pcregistercpd` with `Transform="Nonrigid"` | Only option for non-rigid/deformable registration. |
| FPFH feature matching | `extractFPFHFeatures` + `pcmatchfeatures` + `estgeotform3d` | Extract FPFH descriptors, match features, and estimate the transformation using the MSAC algorithm (a variant of RANSAC). Tune `NumNeighbors` in `extractFPFHFeatures` and `gridStep` in `pcdownsample` to ensure enough features and feature matches. |

### General Guidelines

- The initial transformation is the transformation that aligns the moving point cloud to the fixed point cloud. It is important to set the `InitialTransform` name-value argument for local registration algorithms when an estimate is available. If registering a sequence of point clouds and no other estimate is available, assume constant speed and set the initial transformation to the transformation estimated between the previous pair of point clouds.
- The RMSE output of `pcregisterfgr` is not comparable to the RMSE output of the other registration functions because it is the root mean squared error between only inlier points. Use the Point Cloud Registration Analyzer app for comparable RMSE values between all registration approaches.
- When comparing registration algorithms, check if the point clouds are organized (i.e., `ndims(ptCloud.Location) == 3`). If they are organized, include LOAM in the comparison. If they are not organized, but lidar parameters are available (e.g., from the sensor metadata or the user), use `pcorganize` to organize the point clouds and include LOAM in the comparison. Exclude LOAM when the point clouds are unorganized and no lidar parameters are available.
- When registering a sequence of organized point clouds with LOAM, use `pcmaploam` to refine the transformations and improve map accuracy in addition to pairwise `pcregisterloam` registration.
- Use `pcshowpair` to visualize the alignment between a pair of registered point clouds.

### Preprocessing Steps

- When using `select` to filter points from an organized point cloud, always set `OutputSize="full"` to preserve the organized structure.
- To improve the speed and accuracy of the registration, use `findPointsInCylinder` as a cylindrical filter to remove artifacts from the ego vehicle and noise from distant points. Only use `findPointsInCylinder` for point clouds from spinning lidar sensors.
- Downsampling can speed up registration and improve accuracy by removing the effects of noisy points. Use `pcdownsample` to downsample the point clouds before registration. The recommended approach for registration is the `gridAverage` or the `gridNearest` methods. `gridAverage` is faster and `gridNearest` returns more accurate color, normal, and intensity values if available in the point cloud.
- Ground removal is not recommended since it can introduce misalignment in the XY plane. In some scenarios it helps speed up registration and improve accuracy, but first evaluate registration results without ground removal. Then, use either `segmentGroundSMRF` for more accurate ground removal or `pcfitplane` to get a faster approximation of the ground points.

### Parameter Tuning

When tuning parameters, try a range of values between the typical values listed below (choose a step so that it does not exceed 10 values to try). Then, narrow it down further by trying values closer to the best result from that round. The best result corresponds to the lowest RMSE.

#### Preprocessing Functions

| Function | Parameter | Typical Range | Tuning Strategy |
|----------|-----------|---------------|-----------------|
| `findPointsInCylinder` | `radius(2)` (max radius) | 90%–100% of point cloud extent | Compute extent as `max(abs([ptCloud.XLimits, ptCloud.YLimits]))`. Try without `findPointsInCylinder` too. |
| `findPointsInCylinder` | `radius(1)` (min radius) | 0–10 | Must be less than `radius(2)`. Keep small until it fully removes the ego vehicle. |
| `pcdownsample` | `gridStep` | 0.01–1.0 | |

#### Registration Functions

| Function | Parameter | Typical Range | Tuning Strategy |
|----------|-----------|---------------|-----------------|
| `pcregistericp` | `Metric` | All metric values | Try each metric. |
| `pcregistericp` | `InlierRatio` | 0.5–1.0 (default: 1) | |
| `pcregisterndt` | `gridStep` | 0.01–1.5 | |
| `pcregisterndt` | `OutlierRatio` | 0.1–1.0 (default: 0.55) | |
| `pcregisterloam` / `LOAMPoints` / `downsampleLessPlanar` | `gridStep` | 0.1–2.0 | |
| `pcregisterloam` / `detectLOAMFeatures` | `NumRegionsPerLaser` | 4-15 (default: 6) | Try increasing to extract more features. The value must be an integer. |
| `pcregisterloam` / `detectLOAMFeatures` | `MaxSharpEdgePoints`, `MaxPlanarSurfacePoints` | Above defaults of 1 | Try increasing to extract more features. The value must be an integer. |
| `pcmaploam` | `voxelSize` | 0.1–2.0 | |
| `pcmaploam` / `findPose` | `SearchRadius` | 2–5 (default: 3) | |
| `pcregisterfgr` | `gridSize` | 0.01–1.5 | |
| `pcregistercpd` | `OutlierRatio` | 0.1–0.9 (default: 0.1) | |
| `pcregistercorr` | `gridSize` | 50–250 | |
| `pcregistercorr` | `gridStep` | 0.01–1.5 | |
| `pcmatchfeatures` | `MatchThreshold` | 0.01–1.0 (default: 0.01) | Increase to allow more matches. |
| `pcmatchfeatures` | `RejectRatio` | 0.9–0.99 (default: 0.95) | Increase if getting 0 matches. |
| `estgeotform3d` | `MaxDistance` | 0.1–5.0 (default: 1.0) | Decrease for stricter inlier filtering. |

### Combining Point Clouds

- If you found transformations that align a sequence of point clouds, use `pcalign` to combine them efficiently. `pcalign` applies a grid filter across the resulting point cloud to eliminate duplicate points, producing a uniformly dense point cloud.
- If you are combining point clouds that were already transformed using `pctransform` and you need to preserve every point without any downsampling, use `pccat`. `pccat` is the fastest approach since it only concatenates points, but results in a larger point cloud with potential duplicates that can affect the speed and accuracy of downstream workflows.
- If you are combining just 2 point clouds at a time that were already transformed using `pctransform` and you want to downsample only the region of overlap to remove duplicate points, use `pcmerge`. Note that the density of the resulting point cloud may not be uniform since downsampling is only applied to the overlap area. `pcalign` is recommended over `pcmerge` because it is faster, supports more than 2 point clouds, produces uniform density, and performs the alignment of the point clouds using the transformation from registration.

### Interactive Comparison

Use the **Point Cloud Registration Analyzer** app to visually compare algorithms, tune parameters, and analyze results interactively:

```matlab
pointCloudRegistrationAnalyzer
```

The app supports ICP, NDT, LOAM, FGR, Phase Correlation, and CPD. It provides preprocessing (ROI, downsample, ground removal), side-by-side comparison, and it exports the results to the workspace. It supports registration of a pair of point clouds and currently, it does not support the `planeToPlaneWithColor` and `pointToPlaneWithColor` metrics of ICP.

## Patterns

### Basic Registration

```matlab
fixedPtCloud = pcread("scan1.pcd");
movingPtCloud = pcread("scan2.pcd");

[tform,movingReg,rmse] = pcregistericp(movingPtCloud,fixedPtCloud,Metric="planeToPlane");
pcshowpair(movingReg,fixedPtCloud)
```

### Preprocessing: Cylindrical Filter and Downsample

```matlab
radius = [4 100];
idx = findPointsInCylinder(ptCloud,radius);
ptCloudFiltered = select(ptCloud,idx,OutputSize="full");
gridStep = 0.1;
ptCloudDownsampled = pcdownsample(ptCloudFiltered,"gridAverage",gridStep);
```

### Registration with Preprocessing

```matlab
fixedPtCloud = pcread("scan1.pcd");
movingPtCloud = pcread("scan2.pcd");

% Preprocess
radius = [4 100];
gridStep = 0.1;
fixedIdx = findPointsInCylinder(fixedPtCloud,radius);
fixedFiltered = select(fixedPtCloud,fixedIdx,OutputSize="full");
fixedDownsampled = pcdownsample(fixedFiltered,"gridAverage",gridStep);
movingIdx = findPointsInCylinder(movingPtCloud,radius);
movingFiltered = select(movingPtCloud,movingIdx,OutputSize="full");
movingDownsampled = pcdownsample(movingFiltered,"gridAverage",gridStep);

% Register
[tform,movingReg,rmse] = pcregistericp(movingDownsampled,fixedDownsampled,Metric="planeToPlane");
pcshowpair(movingReg,fixedDownsampled)
```

### Global-to-Local Refinement with FGR and ICP

```matlab
gridSize = 0.5;
tformGlobal = pcregisterfgr(movingPtCloud,fixedPtCloud,gridSize);

alignedPtCloudGlobal = pctransform(movingPtCloud,tformGlobal);

[tform,movingReg,rmse] = pcregistericp(alignedPtCloudGlobal,fixedPtCloud, ...
    Metric="planeToPlane");

pcshowpair(movingReg,fixedPtCloud)
```

### NDT Registration

```matlab
fixedPtCloud = pcread("scan1.pcd");
movingPtCloud = pcread("scan2.pcd");

gridStep = 0.5;
[tform,movingReg,rmse] = pcregisterndt(movingPtCloud,fixedPtCloud,gridStep);
pcshowpair(movingReg,fixedPtCloud)
```

### LOAM with Feature Detection

```matlab
movingFeatures = detectLOAMFeatures(movingOrganized);
fixedFeatures = detectLOAMFeatures(fixedOrganized);

gridStep = 1;
movingFeatures = downsampleLessPlanar(movingFeatures,gridStep);
fixedFeatures = downsampleLessPlanar(fixedFeatures,gridStep);

[tform,rmse] = pcregisterloam(movingFeatures,fixedFeatures);
alignedMovingOrganized = pctransform(movingOrganized,tform);

pcshowpair(alignedMovingOrganized,fixedOrganized)
```

### Phase Correlation for Ground Data

```matlab
fixedPtCloud = pcread("scan1.pcd");
movingPtCloud = pcread("scan2.pcd");

% Align ground planes to the X-Y plane
maxDistance = 0.4;
referenceVector = [0 0 1];
groundFixed = pcfitplane(fixedPtCloud,maxDistance,referenceVector);
groundMoving = pcfitplane(movingPtCloud,maxDistance,referenceVector);
tformFixed = normalRotation(groundFixed,referenceVector);
tformMoving = normalRotation(groundMoving,referenceVector);
fixedCorrected = pctransform(fixedPtCloud,tformFixed);
movingCorrected = pctransform(movingPtCloud,tformMoving);

% Register using phase correlation
gridSize = 100;
gridStep = 0.5;
[tform,rmse] = pcregistercorr(movingCorrected,fixedCorrected,gridSize,gridStep);

movingReg = pctransform(movingPtCloud,rigidtform3d(tformFixed.A * tformMoving.A * tform.A));
pcshowpair(movingReg,fixedPtCloud)
```

### FPFH Feature-Based Registration

```matlab
fixedPtCloud = pcread("scan1.pcd");
movingPtCloud = pcread("scan2.pcd");

% Downsample
gridStep = 0.5;
fixedDownsampled = pcdownsample(fixedPtCloud,"gridAverage",gridStep);
movingDownsampled = pcdownsample(movingPtCloud,"gridAverage",gridStep);

% Extract FPFH features
neighbors = 40;
[fixedFeature,fixedValidInds] = extractFPFHFeatures(fixedDownsampled, ...
    NumNeighbors=neighbors);
[movingFeature,movingValidInds] = extractFPFHFeatures(movingDownsampled, ...
    NumNeighbors=neighbors);

fixedValidPtCloud = select(fixedDownsampled,fixedValidInds);
movingValidPtCloud = select(movingDownsampled,movingValidInds);

% Match features
indexPairs = pcmatchfeatures(movingFeature,fixedFeature,movingValidPtCloud, ...
    fixedValidPtCloud,Method="Exhaustive",MatchThreshold=1,RejectRatio=0.99);

matchedFixedPtCloud = select(fixedValidPtCloud,indexPairs(:,2));
matchedMovingPtCloud = select(movingValidPtCloud,indexPairs(:,1));

% Estimate the transformation that aligns the matched pairs
tform = estgeotform3d(matchedMovingPtCloud.Location, ...
    matchedFixedPtCloud.Location,"rigid",MaxDistance=2,MaxNumTrials=3000);

movingReg = pctransform(movingPtCloud,tform);
pcshowpair(movingReg,fixedPtCloud)
```

### Combining Registered Point Clouds

```matlab
ptCloudArr = [ptCloud1 ptCloud2 ptCloud3 ptCloud4];
tforms = [tform1 tform2 tform3 tform4];
gridStep = 0.01;
ptCloudAligned = pcalign(ptCloudArr,tforms,gridStep);
```

### Incremental Map Building

```matlab
ptCloudFiles = dir("scans/*.pcd");
numPtClouds = numel(ptCloudFiles);

tforms = repmat(rigidtform3d(),numPtClouds,1);
ptCloudArr = repmat(pointCloud(zeros(0,3)),numPtClouds,1);

% Preprocessing parameters
radius = [4 100];
downsampleGridStep = 0.1;

% Load and preprocess first frame
ptCloud = pcread(fullfile(ptCloudFiles(1).folder,ptCloudFiles(1).name));
idx = findPointsInCylinder(ptCloud,radius);
ptCloudFiltered = select(ptCloud,idx);
ptCloudArr(1) = pcdownsample(ptCloudFiltered,"gridAverage",downsampleGridStep);

initTform = rigidtform3d();

for i = 2:numPtClouds
    % Load and preprocess
    ptCloud = pcread(fullfile(ptCloudFiles(i).folder,ptCloudFiles(i).name));
    idx = findPointsInCylinder(ptCloud,radius);
    ptCloudFiltered = select(ptCloud,idx);
    ptCloudArr(i) = pcdownsample(ptCloudFiltered,"gridAverage",downsampleGridStep);

    [relTform,~,rmse] = pcregistericp(ptCloudArr(i),ptCloudArr(i-1),Metric="planeToPlane",InitialTransform=initTform);
    tforms(i) = rigidtform3d(tforms(i-1).A * relTform.A);

    initTform = relTform;
end

gridStep = 0.01;
ptCloudMap = pcalign(ptCloudArr,tforms,gridStep);
pcviewer(ptCloudMap)
```

### LOAM Map Building

```matlab
voxelSize = 0.1;
loamMap = pcmaploam(voxelSize);
relPose = rigidtform3d();

gridStep = 1;
ptCloud = ptCloudArr(1);
points = detectLOAMFeatures(ptCloud);
points = downsampleLessPlanar(points,gridStep);
addPoints(loamMap,points,rigidtform3d())

tforms = repmat(rigidtform3d(),numPtClouds,1);

for viewId = 2:numPtClouds
   prevPoints = points;
   ptCloud = ptCloudArr(viewId);
   points = detectLOAMFeatures(ptCloud);
   points = downsampleLessPlanar(points,gridStep);

   relPose = pcregisterloam(points,prevPoints,InitialTransform=relPose);

   [absPose,~,rmseRefinement] = findPose(loamMap,points,relPose);
   addPoints(loamMap,points,absPose);
   tforms(viewId) = absPose;
end

ptCloudMap = pcalign(ptCloudArr,tforms,voxelSize);
pcshow(ptCloudMap)
```

----

Copyright 2026 The MathWorks, Inc.

----
