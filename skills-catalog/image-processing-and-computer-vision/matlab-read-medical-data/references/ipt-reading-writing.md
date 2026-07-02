# IPT Reading and Writing Patterns

Read and write medical imaging data using Image Processing Toolbox functions. Use these patterns when Medical Imaging Toolbox is NOT available.

## Reading DICOM

### Single DICOM file

```matlab
info = dicominfo("slice.dcm");
pixels = dicomread(info);

% Access metadata
modality = info.Modality;
pixelSpacing = [info.PixelSpacing(1), info.PixelSpacing(2)]; % [row, col] in mm
```

### DICOM folder (single series)

```matlab
[V, spatial, dim] = dicomreadVolume(dicomFolder);
V = squeeze(V);  % ALWAYS squeeze — removes singleton 4th dim for grayscale

% spatial struct fields:
%   spatial.PixelSpacings    — Nx2 matrix, [rowSpacing colSpacing] per slice
%   spatial.PatientPositions — Nx3 matrix, [x y z] of first pixel per slice
%   spatial.PatientOrientations — 2x3xN, direction cosines per slice

pixelSpacing = spatial.PixelSpacings(1, :);   % [Δrow Δcol] in mm
positions = spatial.PatientPositions;          % Nx3
sliceSpacing = abs(positions(2,3) - positions(1,3)); % slice thickness from positions
```

### DICOM collection (multiple series)

```matlab
% List all series in a directory (includes subfolders by default)
collection = dicomCollection(parentDir, IncludeSubfolders=true);

% Table columns: Filenames, Rows, Columns, Channels, Frames,
%                StudyDescription, SeriesDescription, Modality,
%                PatientName, PatientID, StudyDate, SeriesNumber

% Read a specific series by row name
[V, spatial] = dicomreadVolume(collection, "s2");
V = squeeze(V);
```

## Reading NIfTI

```matlab
V = niftiread(niftiFile);           % Numeric array
info = niftiinfo(niftiFile);        % Metadata struct

% Key info fields:
%   info.ImageSize          — [rows cols slices]
%   info.PixelDimensions    — [dx dy dz] voxel spacing in mm
%   info.Transform          — affine3d object (intrinsic to world)
%   info.Datatype           — 'uint16', 'int16', 'single', etc.
%   info.SpaceUnits         — 'Millimeter', 'Meter', etc.

voxelSize = info.PixelDimensions(1:3);
```

## Rescale Slope / Intercept

`dicomread` returns **raw stored values** — it does NOT apply RescaleSlope/RescaleIntercept. For CT data, convert to Hounsfield Units manually:

```matlab
img = dicomread("ct_slice.dcm");
info = dicominfo("ct_slice.dcm");

% Apply rescaling to get calibrated units (e.g., Hounsfield Units for CT)
img_hu = double(img) * info.RescaleSlope + info.RescaleIntercept; % RescaleSlope must not be empty
```

Note: `medicalVolume` and `medicalImage` (Medical Imaging Toolbox) auto-apply rescaling — their `Voxels`/`Pixels` property is already in calibrated units.

## Writing DICOM

```matlab
% Write a single slice
dicomwrite(uint16(sliceData), "output.dcm");

% Write with metadata (copy from original)
info = dicominfo("original.dcm");
dicomwrite(uint16(sliceData), "output.dcm", info, CreateMode="Copy");
```

**Key:** RT Structure files require `CreateMode="Copy"` — the SOP class is not supported in full verification mode.

## Writing NIfTI

```matlab
% Basic write (no spatial metadata)
niftiwrite(V, "output.nii");

% Write with metadata (preserves voxel spacing, transform)
info = niftiinfo("original.nii");
info.Datatype = class(V);
niftiwrite(V, "output.nii", info);

% Compressed output
niftiwrite(V, "output.nii.gz", info, Compressed=true);
```

**Limitation:** `niftiwrite` with a manually constructed info struct is error-prone. If Medical Imaging Toolbox is available, use `write(medVol, "output.nii")` instead.

## Building imref3d (Spatial Referencing for Registration)

`imref3d` maps voxel indices to world coordinates. Required for registration functions.

```matlab
% From NIfTI info
ref = imref3d(size(V), ...
    info.PixelDimensions(2), ...  % XWorldLimits (col spacing)
    info.PixelDimensions(1), ...  % YWorldLimits (row spacing)
    info.PixelDimensions(3));     % ZWorldLimits (slice spacing)

% From dicomreadVolume spatial struct
ref = imref3d(size(V), ...
    spatial.PixelSpacings(1, 2), ...  % col spacing
    spatial.PixelSpacings(1, 1), ...  % row spacing
    abs(spatial.PatientPositions(2,3) - spatial.PatientPositions(1,3))); % slice spacing
```

**Argument order:** `imref3d(imageSize, xSpacing, ySpacing, zSpacing)` — x is columns, y is rows.

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Not using `squeeze` on `dicomreadVolume` output | Always `squeeze(V)` for grayscale data |
| Using `dicomreadVolume` per folder to list series | `dicomCollection(dir)` then read selected |
| `imref3d(size, ySpacing, xSpacing, z)` — swapped x/y | `imref3d(size, xSpacing, ySpacing, zSpacing)` — x is columns |
| Using raw `dicomread` values as Hounsfield Units | Apply `RescaleSlope * value + RescaleIntercept` |
| Building NIfTI info struct from scratch | Use `niftiinfo` on existing file, or `medicalVolume.write` |

----

Copyright 2026 The MathWorks, Inc.

----
