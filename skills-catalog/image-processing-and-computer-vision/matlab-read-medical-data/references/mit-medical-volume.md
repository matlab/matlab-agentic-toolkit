# Medical Volume and Medical Image (Requires Medical Imaging Toolbox)

Unified data containers for reading, processing, and writing medical imaging data. `medicalVolume` handles 3-D volumes (DICOM folders, NIfTI, NRRD). `medicalImage` handles 2-D images (single DICOM files).

## medicalImage — Single DICOM Files

Read a single DICOM file into a `medicalImage` object. Provides pixel data and metadata in one object with automatic rescaling.

### Constructors

```matlab
img = medicalImage(filename);          % Single DICOM file path
img = medicalImage(dirname);           % Directory with single DICOM file
img = medicalImage(sourceTable);       % From dicomCollection table
img = medicalImage(sourceTable, row);  % Specific row of dicomCollection
img = medicalImage(pixels, info);      % From raw data + dicominfo struct
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Pixels` | m-by-n-by-t-by-c numeric | Pixel data (auto-rescaled to calibrated units) |
| `PixelSpacing` | 1-by-2 vector | [rowSpacing, colSpacing] in mm |
| `Modality` | string | "CT", "MR", "US", etc. |
| `NumFrames` | numeric | Number of frames (1 for single image) |
| `SpatialUnits` | string | "mm" or "unknown" |
| `WindowCenter` | numeric | DICOM window center |
| `WindowWidth` | numeric | DICOM window width |

### Methods

```matlab
X = extractFrame(img, frameNum);  % Extract one frame from multi-frame image
implay(img);                      % View image sequence in Video Viewer
```

## medicalVolume — 3-D Volumes

Read any medical volume format into a `medicalVolume` object with automatic spatial referencing and rescaling.

### Constructors

```matlab
vol = medicalVolume(dirname);            % DICOM folder
vol = medicalVolume(filename);           % NIfTI (.nii, .nii.gz) or NRRD (.nrrd)
vol = medicalVolume(sourceTable);        % First row of dicomCollection
vol = medicalVolume(sourceTable, row);   % Specific row (name or index)
vol = medicalVolume(imds);               % ImageDatastore of DICOM files
vol = medicalVolume(voxels, spatialRef); % Raw data + medicalref3d object
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Voxels` | m-by-n-by-p numeric (or N-D) | Voxel data (auto-rescaled to calibrated units) |
| `VolumeGeometry` | medicalref3d | Spatial referencing object |
| `VoxelSpacing` | 1-by-3 vector | [dx dy dz] in mm |
| `Orientation` | string | "transverse", "coronal", "sagittal", "mixed", "oblique", "unknown" |
| `SpatialUnits` | string | "mm" or "unknown" |
| `Modality` | string | "CT", "MR", etc. |
| `NumCoronalSlices` | numeric | Slices in coronal direction |
| `NumSagittalSlices` | numeric | Slices in sagittal direction |
| `NumTransverseSlices` | numeric | Slices in transverse direction |
| `PlaneMapping` | 1-by-3 string | Maps data dims to anatomical planes |
| `DataDimensionMeaning` | 1-by-3 string | Maps data dims to anatomical axes |
| `NormalVector` | 1-by-3 vector | Unit vector normal to first slice |
| `WindowCenters` | numeric | DICOM window center(s) |
| `WindowWidths` | numeric | DICOM window width(s) |

### Methods

#### extractSlice — Extract oriented slice

Do NOT manually index `vol.Voxels(:,:,n)`. Use `extractSlice` which handles dimension mapping regardless of acquisition orientation.

```matlab
[sliceData, position, spacings] = extractSlice(vol, sliceIndex, direction)
```

- `sliceIndex` — positive integer (1 to number of slices in that direction)
- `direction` — `"transverse"`, `"coronal"`, or `"sagittal"`
- `sliceData` — 2-D numeric array
- `position` — [x, y, z] of upper-left pixel in patient coordinates
- `spacings` — [rowSpacing, colSpacing] in the slice plane

```matlab
[axial, pos, sp] = extractSlice(vol, 50, "transverse");
[coronal, pos, sp] = extractSlice(vol, 30, "coronal");
[sagittal, pos, sp] = extractSlice(vol, 45, "sagittal");
```

**Argument order:** `(vol, sliceIndex, direction)` — numeric index before direction string.

#### updateOrientation — Change volume orientation (R2025a+)

Returns a NEW `medicalVolume` with reoriented voxels and updated spatial metadata. Do NOT use `permute`.

```matlab
medVolReoriented = updateOrientation(vol, direction)
medVolReoriented = updateOrientation(vol, orientationCode)
```

- `direction` — `"transverse"`, `"coronal"`, or `"sagittal"`
- `orientationCode` — 3-element string array for custom orientation

```matlab
vol = medicalVolume("brain.nii");
disp(vol.Orientation);  % "transverse"

coronalVol = updateOrientation(vol, "coronal");
disp(coronalVol.Orientation);  % "coronal"
```

**Important:** Returns a new object — always capture the output. Introduced in **R2025a**.

#### write — Write to NIfTI

Writes volume to NIfTI format with spatial referencing preserved in the header.

```matlab
write(vol, filename)
write(vol, filename, info)  % With custom NIfTI metadata
```

```matlab
vol = medicalVolume("dicom_folder/");
write(vol, "output.nii.gz");  % Compressed NIfTI
```

**Note:** `write` only supports NIfTI output (.nii, .nii.gz). There is no public NRRD write function in R2026a.

#### resample — Transform volume to a different coordinate system

Resamples voxel data to align with a target patient coordinate system defined by a `medicalref3d` object. Use this when two volumes have different coordinate systems and you need to bring one into the other's space.

```matlab
medVolResampled = resample(vol, targetRef)
medVolResampled = resample(vol, targetRef, Method=method, FillValue=val)
```

- `targetRef` — `medicalref3d` object defining the target coordinate system
- `Method` — interpolation: `"cubic"` (default), `"linear"`, or `"nearest"`
- `FillValue` — value for out-of-bounds voxels (default `0`)

```matlab
% Resample moving volume to match fixed volume's patient coordinate system
fixedVol = medicalVolume("ct_series/");
movingVol = medicalVolume("pet_series/");

% Get the target coordinate system from the fixed volume
targetRef = fixedVol.VolumeGeometry;

% Resample — aligns movingVol to fixedVol's grid and coordinate system
movingResampled = resample(movingVol, targetRef);
```

#### Other methods

| Method | Purpose |
|--------|---------|
| `replaceSlice(vol, sliceIdx, direction, newData)` | Replace voxel values for one slice |
| `resample(vol, targetRef)` | Resample to match a different patient coordinate system |
| `reposition(vol, newPosition)` | Update position in patient coordinates |
| `sliceCorners(vol, sliceIdx, direction)` | Corner voxel coordinates for a slice |
| `sliceLimits(vol, sliceIdx, direction)` | X/Y/Z limits for a slice |
| `volshow(vol)` | Display in patient coordinates (auto-sets transform) |
| `montage(vol)` | Display slices as montage |

### Creating medicalVolume from raw data

```matlab
% From numeric array + voxel spacing
voxelSpacing = [1 1 2.5];  % [dx dy dz] in mm
spatialRef = medicalref3d(size(V), voxelSpacing);
vol = medicalVolume(V, spatialRef);

% From tiffreadVolume output
V = tiffreadVolume("mri_stack.tif");
spatialRef = medicalref3d(size(V), [0.5 0.5 1.0]);
vol = medicalVolume(V, spatialRef);
```

## Visualization

```matlab
% Interactive 3-D viewer (R2026a+)
medicalVolumeViewer(vol);

% With label overlay
medicalVolumeViewer(vol, labelVol);

% volshow — preserves spatial transform automatically
volshow(vol);

% Orthogonal slice viewer
orthosliceViewer(vol);
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `extractSlice(vol, "coronal", 50)` — wrong arg order | `extractSlice(vol, 50, "coronal")` — index before direction |
| `updateOrientation(vol, "coronal")` without capturing output | `newVol = updateOrientation(vol, "coronal")` — returns new object |
| Using `nrrdwrite(vol, file)` | Not a public function in R2026a. Write to NIfTI with `write(vol, file)` |
| `medicalref3d(size, affinetform3d(eye(4)))` for simple spacing | `medicalref3d(size, voxelSpacing)` — just pass spacing vector |
| Using `volumeViewer` for medical data | `medicalVolumeViewer` (R2026a+) or `volshow(vol)` |

----

Copyright 2026 The MathWorks, Inc.

----
