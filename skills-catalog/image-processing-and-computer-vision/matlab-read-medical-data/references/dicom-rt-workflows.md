# DICOM RT Structure Workflows

Full lifecycle for DICOM Radiation Therapy structure sets: read, inspect, modify (add/delete), convert to label map, and write to DICOM. Uses `dicomContours` from Image Processing Toolbox (R2020a+).

## dicomContours — Extract ROI Data

Creates a contour object from DICOM-RT structure set metadata. Provides a clean table interface instead of manual nested struct parsing.

**Constructor:** `contours = dicomContours(info)` where `info` is a struct from `dicominfo`.

**Critical:** Pass a `dicominfo` struct, NOT a file path.

```matlab
info = dicominfo("rtstruct.dcm");
contours = dicomContours(info);

% Access ROI table
roiTable = contours.ROIs;
disp(roiTable(:, ["Number", "Name"]));
```

## ROIs Table Columns

| Column | Type | Description |
|--------|------|-------------|
| `Number` | double | ROI number (stable identifier from DICOM) |
| `Name` | character vector | ROI name (e.g., 'GTV-1', 'Lung-Left') |
| `ContourData` | cell | Cell array of Nx3 point matrices per slice |
| `GeometricType` | character vector | Contour type (e.g., 'CLOSED_PLANAR') |
| `Color` | double | RGB color [R, G, B] from 0-255 |

```matlab
% Get ROI names as string array
roiNames = string(contours.ROIs.Name);  % Cell array → string
roiNumbers = contours.ROIs.Number;
```

## Pattern: Delete Contours

`deleteContour` returns a NEW object (immutable pattern) — always capture the output.

Uses the ROI **Number** (stable identifier), NOT the row position. Numbers do NOT shift after deletion.

```matlab
% Delete a specific contour by ROI number
contours = deleteContour(contours, 5);

% Delete multiple contours at once — pass a vector
contours = deleteContour(contours, [1 2 5]);

% Delete all contours
contours = deleteContour(contours, contours.ROIs.Number);
```

**Do NOT** call sequentially assuming numbers shift:
```matlab
% WRONG — after deleting ROI #2, ROI #2 no longer exists
contours = deleteContour(contours, 2);
contours = deleteContour(contours, 2);  % ERROR

% CORRECT — pass both at once
contours = deleteContour(contours, [2 3]);
```

## Pattern: Add a Contour

```matlab
number = 5;
name = 'Organ';
contourData = {[0,0,0; 1,1,0; 2,2,0]; [0,0,1; 1,1,1; 2,2,1]}; % Cell array of Nx3 matrices per slice
geometricType = {'CLOSED_PLANAR'; 'CLOSED_PLANAR'};  % One per slice
color = [0; 127; 127];  % RGB (0-255)

contours = addContour(contours, number, name, contourData, geometricType, color);
```

## Pattern: Write Modified Contours to DICOM

Use `convertToInfo` to reconstruct the full DICOM metadata struct, then `dicomwrite` with `CreateMode="Copy"`.

```matlab
% Convert contours back to DICOM info struct
infoNew = convertToInfo(contours);

% Write to DICOM file
dicomwrite([], "output_rtstruct.dcm", infoNew, CreateMode="Copy");
```

**Critical rules:**
- `convertToInfo` takes ONLY the dicomContours object — no second argument
- RT Structure files REQUIRE `CreateMode="Copy"` — the SOP class is not supported in full verification mode
- Do NOT pass the original `dicominfo` struct to `convertToInfo`

```matlab
% WRONG — convertToInfo does not accept a second argument
infoNew = convertToInfo(contours, info);

% CORRECT
infoNew = convertToInfo(contours);
```

## Full Workflow: Read → Inspect → Modify → Write

```matlab
% 1. Read RT Structure file
info = dicominfo("rtstruct.dcm");
contours = dicomContours(info);

% 2. Inspect ROIs
disp(contours.ROIs(:, ["Number", "Name"]));

% 3. Delete specific ROIs (capture output!)
contours = deleteContour(contours, [1 2]);

% 4. Convert to DICOM metadata and write
infoModified = convertToInfo(contours);
dicomwrite([], "modified_rtstruct.dcm", infoModified, CreateMode="Copy");
```

## Pattern: Convert Contours to Label Map

Create a 3-D binary mask from RT structure contours overlaid on the corresponding CT volume.

```matlab
% Read CT volume spatial info
[V, spatial] = dicomreadVolume(ctFolder);

% Read RT Structure
info = dicominfo("rtstruct.dcm");
contours = dicomContours(info);

% Create mask for a specific ROI (by ROI Number)
mask = createMask(contours, 2, spatial);
% mask is logical array matching CT volume dimensions
```

## Pattern: Multi-Label Volume from All ROIs

```matlab
info = dicominfo("rtstruct.dcm");
contours = dicomContours(info);
[V, spatial] = dicomreadVolume(ctFolder);

% Initialize label volume
labelVol = zeros(size(squeeze(V)), "uint8");

% Create mask for each ROI and assign label
for i = 1:height(contours.ROIs)
    roiNum = contours.ROIs.Number(i);
    mask = createMask(contours, roiNum, spatial);
    labelVol(mask) = i;
end
```

## Pattern: Copy Contours Between Files

```matlab
info1 = dicominfo("other_rtstruct.dcm");
contours1 = dicomContours(info1);

% Copy all contours from contours1 into contours
for i = 1:height(contours1.ROIs)
    contours = addContour(contours, contours1.ROIs.Number(i), ...
        contours1.ROIs.Name{i}, contours1.ROIs.ContourData{i}, ...
        contours1.ROIs.GeometricType{i}, contours1.ROIs.Color{i});
end
```

## Pattern: Display RT Structure Data

Two approaches depending on whether you have the corresponding image volume:

### Contours overlaid on CT slices (preferred when referenced CT is available)

The CT volume's `FrameOfReferenceUID` and the RTSTRUCT's `ReferencedFrameOfReferenceUID` must match.

```matlab
% Read CT volume
ctVol = medicalVolume("0.000000-NA-82046/");

% Get spatial referencing from medical volume
mv_ref = ctVol.VolumeGeometry;  % medicalref3d object
vol_size = mv_ref.VolumeSize;   % [rows cols slices]

% Create imref3d for mask creation
[X, Y, Z] = intrinsicToWorld(mv_ref, [1; vol_size(1)], ...
    [1; vol_size(2)], [1; vol_size(3)]);
xlim = [X(1, 1) X(2, 1)];
ylim = [Y(1, 1) Y(2, 1)];
zlim = [Z(1, 1) Z(2, 1)];
spatial_ref = imref3d(vol_size, xlim, ylim, zlim);

% Read RT struct
info = dicominfo("RTSTRUCT-VS-SEG-001.dcm");
rtContours = dicomContours(info);

% Create mask from a specific ROI, matched to the CT volume
roiIdx = rtContours.ROIs.Number;
roi_mask = createMask(rtContours, roiIdx(1), spatial_ref);

% Permute to match volume orientation
roi_mask = permute(roi_mask, [2 1 3]);
segVolume = medicalVolume(roi_mask, mv_ref);

% Display CT slice with mask overlay
sliceIdx = 50;
ctSlice = extractSlice(ctVol, sliceIdx, "transverse");
rtMask = extractSlice(segVolume, sliceIdx, "transverse");

imageshow(ctSlice, DisplayRange=[-1000 400], ...
    OverlayData=rtMask, OverlayAlpha=0.5);
```

### Contours as 3D point clouds (standalone, no referenced images needed)

```matlab
info = dicominfo("rtstruct.dcm");
rtContours = dicomContours(info);

% Plot all ROIs in 3D
plotContour(rtContours);

% Plot a specific ROI by number
plotContour(rtContours, 3);
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Parsing `info.StructureSetROISequence` manually | Use `dicomContours(info)` — gives clean `.ROIs` table |
| Passing file path to `dicomContours` | Pass `dicominfo` struct: `dicomContours(dicominfo(file))` |
| `deleteContour` without capturing output | Always: `contours = deleteContour(contours, nums)` |
| Calling `deleteContour` sequentially for multiple ROIs | Pass all numbers in one call: `deleteContour(c, [1 2 3])` |
| `convertToInfo(contours, info)` — extra argument | `convertToInfo(contours)` — no second arg |
| `dicomwrite` without `CreateMode="Copy"` for RT | RT SOP class requires `CreateMode="Copy"` |
| Using `dicomread` on RT struct file | RT structs have no pixel data — use `dicominfo` only |

----

Copyright 2026 The MathWorks, Inc.

----
