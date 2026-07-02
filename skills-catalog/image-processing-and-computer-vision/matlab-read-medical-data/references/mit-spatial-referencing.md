# Spatial Referencing and Coordinate Workflows (Requires Medical Imaging Toolbox)

`medicalref3d` stores the complete mapping between voxel (intrinsic) coordinates and patient (world) coordinates for 3-D medical volumes.

## Accessing medicalref3d

Every `medicalVolume` contains a `VolumeGeometry` property of type `medicalref3d`:

```matlab
vol = medicalVolume("brain.nii");
geom = vol.VolumeGeometry;  % medicalref3d object
```

## medicalref3d Constructors

```matlab
% From volume size and uniform voxel spacing (most common for custom data)
R = medicalref3d(volumeSize, voxelSpacing);
% Example: R = medicalref3d([256 256 128], [0.5 0.5 1.0]);

% From volume size and affine transform
tform = affinetform3d(A);  % 4x4 affine matrix
R = medicalref3d(volumeSize, tform);

% From volume size, position, pixel spacing, and direction cosines
R = medicalref3d(volumeSize, position, pixelSpacing, cosines);

% From volume size, position, and voxel distance vectors
R = medicalref3d(volumeSize, position, voxelDistances);

% From volume size only (identity transform)
R = medicalref3d(volumeSize);
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `VolumeSize` | 1-by-3 vector | [rows, cols, slices] |
| `Position` | p-by-3 matrix | Patient coordinates of first voxel in each slice |
| `VoxelDistances` | 1-by-3 cell | Direction vectors between adjacent voxels |
| `PixelSpacing` | p-by-2 or 1-by-2 | In-plane spacing per slice |
| `PatientCoordinateSystem` | string | "LPS+", "RAS+", "LAS+", or "unknown" |
| `IsAffine` | logical | True if transform is affine (uniform) |
| `IsAxesAligned` | logical | True if data axes align with patient axes |
| `IsMixed` | logical | True if slice orientations vary |

## Coordinate Conversion Methods

### intrinsicToWorld — Voxel to patient coordinates

Converts voxel indices (intrinsic coordinates) to patient (world) coordinates.

```matlab
[xWorld, yWorld, zWorld] = intrinsicToWorld(geom, xIntrinsic, yIntrinsic, zIntrinsic)
```

**Critical:** Takes 3 separate numeric arguments and returns 3 separate outputs. Do NOT pass a single vector.

```matlab
geom = vol.VolumeGeometry;

% Single point
[wx, wy, wz] = intrinsicToWorld(geom, 50, 60, 30);
fprintf("World position: [%.2f, %.2f, %.2f] mm\n", wx, wy, wz);

% Multiple points (vectorized)
rows = [10, 20, 30];
cols = [50, 60, 70];
slices = [5, 10, 15];
[wx, wy, wz] = intrinsicToWorld(geom, rows, cols, slices);
```

### worldToIntrinsic — Patient to voxel coordinates

```matlab
[xIntrinsic, yIntrinsic, zIntrinsic] = worldToIntrinsic(geom, xWorld, yWorld, zWorld)
```

```matlab
% Convert a world position back to voxel indices
[vi, vj, vk] = worldToIntrinsic(geom, -76.5, -96.2, -208.8);
fprintf("Voxel position: [%.1f, %.1f, %.1f]\n", vi, vj, vk);
```

### worldToSubscript — Patient to array subscripts

Like `worldToIntrinsic` but rounds to nearest integer subscripts suitable for indexing.

```matlab
[row, col, slice] = worldToSubscript(geom, xWorld, yWorld, zWorld)
```

```matlab
[r, c, s] = worldToSubscript(geom, wx, wy, wz);
voxelValue = vol.Voxels(r, c, s);
```

### oneSliceIntrinsicToWorldMapping — Per-slice 2D transform

Get the affine transformation from intrinsic (2-D pixel) coordinates to patient (3-D world) coordinates for a specific slice. Useful for mapping 2-D pixel locations to 3-D patient space.

```matlab
tform = oneSliceIntrinsicToWorldMapping(geom, sliceNumber)
```

```matlab
% Get transform for slice 50
tform = oneSliceIntrinsicToWorldMapping(geom, 50);

% tform is an affinetform3d object
% Use it to transform 2-D pixel coordinates to 3-D world:
pixelCoords = [100, 200, 1];  % [row, col, 1] in homogeneous coords
worldCoords = transformPointsForward(tform, pixelCoords);
```

### intrinsicToWorldMapping — Full volume transform

Get the complete geometric transform for the entire volume.

```matlab
tform = intrinsicToWorldMapping(geom)
```

### contains — Check if points are inside the volume

```matlab
tf = contains(geom, xWorld, yWorld, zWorld)
```

```matlab
% Check if a world point falls within the volume bounds
isInside = contains(geom, -50.0, -80.0, -200.0);
```

## Patient Coordinate Systems

| System | Meaning | Usage |
|--------|---------|-------|
| `"LPS+"` | Left-Posterior-Superior positive | DICOM standard |
| `"RAS+"` | Right-Anterior-Superior positive | NIfTI/neuroimaging convention |
| `"LAS+"` | Left-Anterior-Superior positive | Less common |
| `"unknown"` | Not specified | Default for raw data |

```matlab
% Check coordinate system
disp(geom.PatientCoordinateSystem);

% Update coordinate system (does NOT transform data, just changes convention label)
geomUpdated = updatePatientCoordinateSystem(geom, "RAS+");
```

## Common Workflow: Voxel-to-World Round Trip

```matlab
vol = medicalVolume("ct_scan.nii.gz");
geom = vol.VolumeGeometry;

% Forward: voxel → world
[wx, wy, wz] = intrinsicToWorld(geom, 128, 128, 64);
fprintf("Voxel (128,128,64) → World (%.2f, %.2f, %.2f) mm\n", wx, wy, wz);

% Inverse: world → voxel
[vi, vj, vk] = worldToIntrinsic(geom, wx, wy, wz);
fprintf("World → Voxel (%.2f, %.2f, %.2f)\n", vi, vj, vk);

% To nearest integer subscript for indexing
[r, c, s] = worldToSubscript(geom, wx, wy, wz);
value = vol.Voxels(r, c, s);
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `intrinsicToWorld(geom, [50, 60, 30])` — single vector | `intrinsicToWorld(geom, 50, 60, 30)` — 3 separate args |
| Capturing single output from `intrinsicToWorld` | `[x, y, z] = intrinsicToWorld(...)` — always 3 outputs |
| Accessing `geom.Mapping` (doesn't exist) | Use `geom.VoxelDistances`, `geom.Position`, `geom.PixelSpacing` |
| Manual affine math for coordinate transforms | Use `intrinsicToWorld` / `worldToIntrinsic` methods |
| Manual per-slice transform computation | Use `oneSliceIntrinsicToWorldMapping(geom, sliceNum)` |
| Using `niftiinfo.Transform` for coordinate work | Use `medicalVolume.VolumeGeometry` — richer API |

----

Copyright 2026 The MathWorks, Inc.

----
