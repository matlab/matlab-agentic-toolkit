---
name: matlab-read-medical-data
description: >
  Read, write, and manipulate medical imaging data (DICOM, NIfTI, NRRD)
  in MATLAB. Covers Image Processing Toolbox functions (dicomreadVolume,
  niftiread, dicomContours, dicomanon) and Medical Imaging
  Toolbox enhanced APIs (medicalVolume, medicalImage, medicalref3d,
  extractSlice, updateOrientation). Use when reading
  medical files, listing DICOM series, extracting spatial referencing, changing
  orientation, working with RT structures, or anonymizing
  DICOM data. Some features require Medical Imaging Toolbox — see skill body
  and references for details.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Read and Write Medical Data

Read, write, and manipulate medical imaging data in MATLAB. This skill covers both Image Processing Toolbox (IPT) functions and Medical Imaging Toolbox (MIT) enhanced APIs.

## When to Use

- Reading or writing DICOM, NIfTI, or NRRD files
- Listing DICOM series with `dicomCollection`
- Extracting spatial referencing or coordinate transforms
- Changing volume orientation or extracting oriented slices
- Working with DICOM RT structures (contours, masks, modify/write)
- Anonymizing DICOM data

## When NOT to Use

- Displaying or visualizing volumes (use `matlab-display-volume` skill)
- Displaying 2-D medical images with annotations (use `matlab-display-image` skill)
- Reading non-medical image formats (PNG, TIFF, JPEG) — use `imread`

## Toolbox Detection — CRITICAL FIRST STEP

**Always check which toolboxes are available before choosing an approach.** If Medical Imaging Toolbox is installed, prefer its APIs. If only Image Processing Toolbox is available, use IPT patterns.

## Task → Function Quick Reference

| Task | IPT only | With Medical Imaging Toolbox (preferred) |
|------|----------|------------------------------------------|
| Read single DICOM file | `dicomread` + `dicominfo` | `medicalImage` |
| Read DICOM folder | `dicomreadVolume` | `medicalVolume` |
| Read NIfTI | `niftiread` + `niftiinfo` | `medicalVolume` |
| Read NRRD | — (requires MIT) | `medicalVolume` or `nrrdread` + `nrrdinfo` |
| List DICOM series | `dicomCollection` | `dicomCollection` |
| Spatial referencing | `imref3d` | `medicalref3d` |
| Extract oriented slice | Manual indexing | `extractSlice` |
| Change orientation | Manual `permute` | `updateOrientation` |
| Read DICOM RT structure | `dicomContours(dicominfo(file))` | Same |
| Anonymize DICOM | `dicomanon` + `dicomuid` | Same |
| Visualize volume | `volumeViewer` | `medicalVolumeViewer` or `volshow(medVol)` |

## Top 4 Patterns

### 1. Read DICOM folder

Call `medicalVolume` or `dicomreadVolume` directly on the DICOM folder path. Do NOT call `dicomCollection` first — it is unnecessary when reading a single-series folder.

```matlab
% WITH Medical Imaging Toolbox (preferred):
medVol = medicalVolume("path/to/dicom/folder");
V = medVol.Voxels;               % Auto-rescaled (e.g., HU for CT)
spacing = medVol.VoxelSpacing;   % [dx dy dz] in mm
orientation = medVol.Orientation; % "transverse", "coronal", "sagittal"
modality = medVol.Modality;       % "CT", "MR"

% Access spatial referencing via VolumeGeometry (medicalref3d object)
geom = medVol.VolumeGeometry;
geom.VolumeSize;                  % [rows cols slices]
geom.PatientCoordinateSystem;     % "LPS+" or "RAS+"
geom.Position;                    % [slices×3] slice positions in patient coords
geom.VoxelDistances;              % {[slices×3] [slices×3] [slices×3]} per-axis distances
geom.PixelSpacing;                % [slices×2] in-plane pixel spacing per slice
geom.IsAffine;                    % true if uniform spacing (affine transform)
geom.IsAxesAligned;               % true if volume axes align with patient axes
geom.IsMixed;                     % true if slices have varying pixel spacing

% IPT only:
[V, spatial, dim] = dicomreadVolume("path/to/dicom/folder");
V = squeeze(V);  % Remove singleton 4th dimension
```

### 2. Read NIfTI file

```matlab
% WITH Medical Imaging Toolbox (preferred):
medVol = medicalVolume("path/to/file.nii.gz");

% IPT only:
V = niftiread("path/to/file.nii.gz");
info = niftiinfo("path/to/file.nii.gz");
voxelSize = info.PixelDimensions(1:3);
```

### 3. List DICOM series and read one

Use `dicomCollection` only when:
- The user says the folder contains **multiple series or volumes**
- `medicalVolume` or `dicomreadVolume` **fails** with an error (e.g., "not a DICOM file" or "multiple volumes detected")
- You need to **identify what series exist** before deciding which one to read

`dicomCollection` scans the directory, excludes non-DICOM files, and returns a table where each row is one series. It does not read pixel data.

```matlab
collection = dicomCollection("path/to/directory");
disp(collection);  % Table with Modality, SeriesDescription, Rows, Columns, Frames

% WITH Medical Imaging Toolbox:
medVol = medicalVolume(collection, "s1");

% IPT only:
[V, spatial] = dicomreadVolume(collection, "s1");
```

### 4. Extract slice / change orientation (Requires Medical Imaging Toolbox)

```matlab
medVol = medicalVolume("path/to/file.nii");

% Extract slices — works for any orientation
[axialSlice, position, spacings] = extractSlice(medVol, 50, "transverse");
[coronalSlice, ~, ~] = extractSlice(medVol, 30, "coronal");
[sagittalSlice, ~, ~] = extractSlice(medVol, 45, "sagittal");

% If medVol.Orientation is not empty, use it as the third input
[sliceData, position, spacings] = extractSlice(medVol, 50, medVol.Orientation);

% Change orientation — do NOT use permute
medVolCoronal = updateOrientation(medVol, "coronal");  % Returns NEW object
```

`updateOrientation` was introduced in **R2025a**.

## Detailed Reference Files

**IMPORTANT: Before generating code for any task below, read the matching reference file first.**

| Task trigger | Reference | Read BEFORE |
|--------------|-----------|-------------|
| Reading/writing DICOM or NIfTI with IPT | `references/ipt-reading-writing.md` | Writing `dicomreadVolume`, `niftiread`, `imref3d`, or rescale logic |
| Using `medicalVolume`, `medicalImage`, slices, or orientation | `references/mit-medical-volume.md` | Writing `medicalImage`, `medicalVolume`, `extractSlice`, or `updateOrientation` calls |
| Spatial referencing or coordinate transforms | `references/mit-spatial-referencing.md` | Writing `medicalref3d`, `intrinsicToWorld`, or `worldToIntrinsic` calls |
| RT structures (contours, labelmaps, RTSTRUCT) | `references/dicom-rt-workflows.md` | Reading, editing, displaying, or plotting contours/RTSTRUCT files, or writing any `dicomContours`, `plotContour`, `createMask`, `addContour`, `deleteContour` call |
| Anonymizing DICOM files | `references/dicom-anonymization.md` | Writing any `dicomanon` or `dicomuid` call |

## Legacy Patterns to Avoid

| Do NOT use | Use instead | Why |
|------------|-------------|-----|
| `dicomread` + `dicominfo` for single file | `medicalImage` (MIT) | Unified access, auto-rescale |
| `dicomreadVolume` for DICOM folder | `medicalVolume` (MIT) | Preserves spatial referencing |
| `niftiread` + `niftiinfo` | `medicalVolume` (MIT) | Unified container |
| `V.Voxels(:,:,n)` or `V(:,:,n)` for slice extraction | `extractSlice(medVol, n, medVol.Orientation)` (MIT) | Handles orientation, spatial metadata, works regardless of storage order |
| Manual `permute` for orientation | `updateOrientation(medVol, orient)` (MIT) | Updates spatial metadata |
| Manual struct parsing for RT | `dicomContours(info)` | Clean tabular output |
| `volumeViewer` | `medicalVolumeViewer` (MIT, R2026a) | Medical-specific features |
| `imshow` for medical images | `imageshow` | Better defaults for medical data |

## Conventions

- Always detect available toolboxes before choosing functions
- Prefer Medical Imaging Toolbox APIs (`medicalVolume`, `medicalImage`) when available
- Always capture output from immutable methods (`deleteContour`, `updateOrientation`)
- Always use `CreateMode="Copy"` when writing RT Structure DICOM files
- Do NOT call `dicomCollection` before `medicalVolume`/`dicomreadVolume` by default — call the reader directly on the folder path
- Use `dicomCollection` only when: the folder contains multiple series, `medicalVolume` fails with an error, or you need to identify what series exist without reading pixel data
- Always `squeeze` the output of `dicomreadVolume` for grayscale data
- Always use `extractSlice` to get slices from a `medicalVolume` — never use `V.Voxels(:,:,n)` manual indexing. `extractSlice` handles orientation, spatial metadata, and works correctly regardless of how the volume is stored on disk
- Never manually parse nested DICOM structs — use `dicomContours`
- `extractSlice` argument order: `(vol, sliceIndex, direction)` — numeric before string
- `intrinsicToWorld` returns 3 separate outputs: `[x, y, z]` — not a single vector

----

Copyright 2026 The MathWorks, Inc.

----
