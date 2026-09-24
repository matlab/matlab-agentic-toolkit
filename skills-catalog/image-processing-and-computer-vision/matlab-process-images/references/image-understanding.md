# Image Data Understanding

Guidance for characterizing image data using MATLAB before designing a processing pipeline. **Always inspect the data first** — never guess at image properties or resort to external tools (Python, shell commands) for tasks MATLAB handles natively.

> **Often loaded with:** `image-io.md` (reading files), then task-specific references based on what data inspection reveals.

## Critical Rule

**ALL image inspection and characterization MUST be done in MATLAB.** Do NOT:
- Write Python scripts (PIL, OpenCV, numpy) to read or inspect images
- Use shell commands (`file`, `identify`, `exiftool`, `ffprobe`)
- Call external tools or libraries for format detection, metadata, or pixel statistics

MATLAB provides `imfinfo`, `imread`, `imageDatastore`, and the functions below for every characterization task. There is never a reason to leave MATLAB for image understanding.

## File Format Triage

Before processing, determine what kind of image file you're dealing with. This is critical because several format families require dedicated read functions — `imread` will fail or produce wrong results on them.

```matlab
function fileType = triageImageFile(filename)
    % Determine file type and recommend read path
    %
    % Returns: "dicom", "raw", or "standard"

    % 1. Check for DICOM (files often have no extension)
    try
        info = dicominfo(filename);
        fprintf("DICOM file detected — Modality: %s, Patient: %s\n", ...
            info.Modality, info.PatientName.FamilyName);
        fileType = "dicom";
        return
    catch
        % Not DICOM — continue
    end

    % 2. Check for camera RAW by extension
    [~, ~, ext] = fileparts(filename);
    rawExts = [".nef",".cr2",".cr3",".crw",".arw",".dng",".orf",".rw2",".raf",".srw",".pef"];
    if any(strcmpi(ext, rawExts))
        info = rawinfo(filename);
        fprintf("Camera RAW file — Sensor: %s, CFA size: %s\n", ...
            info.CFASensorType, mat2str(info.CFAImageSize));
        fileType = "raw";
        return
    end

    % 3. Standard image format
    fileType = "standard";
end
```

### Routing Based on File Type

| Detected type | Read with | Next step |
|---------------|-----------|-----------|
| `"dicom"` | `dicomread` + `dicominfo` (IPT) or `medicalImage` (Medical Imaging Toolbox) | Use **`matlab-read-medical-data`** skill |
| `"raw"` | `rawread` then `demosaic` | See `image-io.md` Camera RAW section |
| `"standard"` | `imread` | Continue with characterization below |

### Other Specialized Formats (not handled by `imread`)

| Extension / Format | Read with | Notes |
|---|---|---|
| `.nii`, `.nii.gz` (NIfTI) | `niftiread` + `niftiinfo` | Medical/neuro volumes — use **`matlab-read-medical-data`** skill |
| `.nrrd`, `.nhdr` (NRRD) | `nrrdread` + `nrrdinfo` | Medical/scientific volumes — use **`matlab-read-medical-data`** skill |
| `.exr` (OpenEXR) | `exrread` | HDR/VFX — float data, often linear color space |
| `.fits`, `.fts` (FITS) | `fitsread` + `fitsinfo` | Astronomy — may be multi-extension |
| `.dpx` (DPX) | `dpxread` + `dpxinfo` | Film/broadcast — 10-bit log encoding |
| Interfile (`.hdr` + `.img`) | `interfileread` + `interfileinfo` | Nuclear medicine (SPECT/PET) |
| Multi-frame TIFF volumes | `tiffreadVolume` | 3-D stacks stored as multi-page TIFF |

### Detecting DICOM in a Folder

DICOM files often have no extension or use `.dcm`, `.ima`, or numbered names. When inspecting a folder of unknown files:

```matlab
files = dir(fullfile(folder, "*"));
files = files(~[files.isdir]);

isDicom = false(numel(files), 1);
for i = 1:numel(files)
    try
        dicominfo(fullfile(folder, files(i).name));
        isDicom(i) = true;
    catch
        % Not DICOM
    end
end

if any(isDicom)
    fprintf("%d of %d files are DICOM — use medicalVolume or dicomreadVolume\n", ...
        nnz(isDicom), numel(files));
end
```

## Quick Characterization — Single Image

```matlab
% File-level metadata (no pixel loading)
info = imfinfo("image.tif");
fprintf("Format: %s\n", info.Format);
fprintf("Dimensions: %d x %d\n", info.Width, info.Height);
fprintf("Color type: %s\n", info.ColorType);   % "truecolor", "grayscale", "indexed"
fprintf("Bit depth: %d\n", info.BitDepth);
fprintf("File size: %.1f KB\n", info.FileSize/1024);

% STOP: Check dimensions before loading pixels
if info.Width * info.Height > 100e6
    % Large image (>100 MP) — load matlab-process-large-images skill
    return
end

% Pixel-level characterization (requires loading)
img = imread("image.tif");
fprintf("Class: %s\n", class(img));
fprintf("Size: %s\n", mat2str(size(img)));
fprintf("Data range: [%g, %g]\n", min(img(:)), max(img(:)));
```

### Key `imfinfo` Fields

| Field | What it tells you |
|-------|------------------|
| `ColorType` | `"truecolor"`, `"grayscale"`, or `"indexed"` |
| `BitDepth` | Bits per pixel (8, 16, 24, 48, etc.) |
| `Colormap` | Non-empty if indexed image — the palette |
| `Transparency` | `"none"`, `"alpha"`, or `"simple"` (PNG) |
| `BitsPerSample` | Bits per channel (TIFF) |
| `SamplesPerPixel` | Number of channels (TIFF) — 4 may indicate alpha |
| `NumberOfFrames` | Multi-frame file count (GIF) |
| `SignificantBits` | Actual significant bits (PNG — rare but definitive) |

**Multi-frame files:** `numel(imfinfo("stack.tif"))` gives the frame count without loading pixels.

## Detecting Indexed Images

```matlab
info = imfinfo(filename);
if strcmp(info.ColorType, "indexed")
    [X, map] = imread(filename);  % X = index matrix, map = Nx3 colormap
    fprintf("Palette size: %d colors\n", size(map, 1));
    % Convert to RGB for processing
    rgbImg = ind2rgb(X, map);     % Returns double [0,1]
end
```

**Common mistake:** Reading an indexed image with `img = imread(...)` (one output) silently returns the index matrix. It looks like a grayscale image but the pixel values are palette indices, not intensities.

## Detecting Effective Bit Depth

Sensors often produce 10-bit or 12-bit data stored in a 16-bit container. The file says "16-bit" but data only uses a fraction of the range.

```matlab
img = imread(filename);
if isa(img, "uint16")
    maxVal = double(max(img(:)));
    sensorBits = [10 12 14 16];
    effectiveBits = sensorBits(find(maxVal <= 2.^sensorBits - 1, 1));
    fprintf("Stored as 16-bit, effective depth: %d-bit (max value: %d)\n", ...
        effectiveBits, maxVal);
end
```

**Caveat:** This heuristic reports the minimum bit depth that could contain the max value. An underexposed 16-bit image may report as "12-bit" simply because pixel values are low. Confirm with the camera/sensor spec when possible.

### Display Implications

Use `imageshow` with the appropriate `DisplayRangeMode` for correct visualization:

```matlab
imageshow(img, DisplayRangeMode="12-bit");   % Range [0, 4095]
imageshow(img, DisplayRangeMode="10-bit");   % Range [0, 1023]
imageshow(img, DisplayRangeMode="data-range"); % Range [min(img), max(img)]
```

**Do NOT use** `DisplayRangeMode="type-range"` (the default) for sub-range data — the image will appear very dark because values occupy only a small fraction of [0, 65535].

## Detecting Alpha Channels

```matlab
% PNG: alpha is the third output of imread
info = imfinfo(filename);
hasAlpha = ~strcmp(info.Transparency, "none");
[img, ~, alpha] = imread(filename);  % alpha is non-empty if PNG has transparency

% TIFF: alpha is packed into the image array (M×N×4), third output is always empty
% SamplesPerPixel == 4 could be RGBA or CMYK — check ColorType to distinguish
info = imfinfo(filename);
if info.SamplesPerPixel == 4 && strcmp(info.ColorType, "truecolor")
    data = imread(filename);          % M×N×4
    img   = data(:,:,1:3);            % RGB
    alpha = data(:,:,4);              % Alpha
end
```

> **Caution:** The three-output form `[img, ~, alpha] = imread(...)` returns alpha only for **PNG, CUR, and ICO**. For TIFF, it always returns empty — use the approach above instead.

## Detecting Grayscale Stored as RGB

Some pipelines save grayscale images as 3-channel RGB where all channels are identical. This wastes memory 3x.

```matlab
if size(img, 3) == 3
    if isequal(img(:,:,1), img(:,:,2)) && isequal(img(:,:,2), img(:,:,3))
        img = img(:,:,1);  % Collapse to true grayscale
        fprintf("Converted gray-as-RGB to grayscale (3x memory saved)\n");
    end
end
```

## Dataset Characterization — Folder of Images

**When asked to look at, understand, explore, describe, or characterize images in a folder, use this `imageDatastore` pattern.** Do not use `dir` to list files and inspect them ad hoc — `imageDatastore` handles format detection, subfolder traversal, and class labeling automatically:

```matlab
dataFolder = "path/to/Data";
imds = imageDatastore(dataFolder, IncludeSubfolders=true, ...
    LabelSource="foldernames");

%% 1. Dataset overview
fprintf("=== Dataset Overview ===\n");
fprintf("Total images: %d\n", numel(imds.Files));
fprintf("Classes:\n");
disp(countEachLabel(imds));

%% 2. File format distribution
exts = strings(numel(imds.Files), 1);
for i = 1:numel(imds.Files)
    [~, ~, exts(i)] = fileparts(imds.Files{i});
end
[uniqueExts, ~, idx] = unique(exts);
counts = accumarray(idx, 1);
fprintf("Formats: ");
for i = 1:numel(uniqueExts)
    fprintf("%s (%d)  ", uniqueExts(i), counts(i));
end
fprintf("\n");

%% 3. Sample characterization — read a few to understand properties
numSamples = min(10, numel(imds.Files));
sampleIdx = round(linspace(1, numel(imds.Files), numSamples));
fprintf("\n=== Sample Characterization ===\n");
for i = sampleIdx
    info = imfinfo(imds.Files{i});
    info = info(1);
    fprintf("  %s: %dx%d, %s, %d-bit\n", ...
        info.Format, info.Width, info.Height, info.ColorType, info.BitDepth);
end

%% 4. Pixel statistics from samples
fprintf("\n=== Pixel Statistics ===\n");
for i = sampleIdx(1:min(3,end))
    img = imread(imds.Files{i});
    fprintf("  %s — class: %s, range: [%g, %g]\n", ...
        imds.Files{i}, class(img), min(img(:)), max(img(:)));
end

%% 5. Visual overview — show sample grid
montage(imds, Indices=sampleIdx, ThumbnailSize=[128 128]);
```

## Data Quality Checks

| Check | Code | What it detects |
|-------|------|----------------|
| Constant image | `max(img(:)) == min(img(:))` | Blank/corrupted files |
| Clipped highlights | `nnz(img == intmax(class(img))) / numel(img) > 0.01` | Overexposed regions |
| Clipped shadows | `nnz(img == 0) / numel(img) > 0.05` | Underexposed regions |
| Near-empty dynamic range | `(double(max(img(:))) - double(min(img(:)))) < 0.1 * double(intmax(class(img)))` | Low contrast |
| Size inconsistency | Compare `size(imread(...))` across samples | Mixed resolutions |
| Corrupt files | `try/catch` around `imread` | Unreadable files |

```matlab
% Quick corruption check
badFiles = {};
for i = 1:numel(imds.Files)
    try
        imread(imds.Files{i});
    catch
        badFiles{end+1} = imds.Files{i}; %#ok<SAGROW>
    end
end
if ~isempty(badFiles)
    fprintf("Found %d corrupt files\n", numel(badFiles));
end
```

## Content-Level Characterization

**Do NOT run all subsections below.** Select only the 1–2 analyses relevant to your specific task. Run on a single representative image, not the entire dataset.

### Noise Estimation

Estimate noise standard deviation to decide whether denoising is needed. Two methods are available depending on installed toolboxes:

```matlab
gray = im2single(im2gray(img));

if ~isempty(ver("wavelet"))
    % Wavelet MAD estimator (more accurate, requires Wavelet Toolbox)
    [~, ~, ~, d] = dwt2(gray, "haar");         % Single-level 2-D DWT, diagonal detail
    noiseStd = median(abs(d(:))) / 0.6745;     % Robust MAD estimator
else
    % Laplacian-based estimator (Immerkaer 1996, IPT only)
    kern = [1 -2 1; -2 4 -2; 1 -2 1];
    filtered = imfilter(gray, kern, "symmetric");
    [H, W] = size(gray);
    noiseStd = sqrt(0.5*pi) / (6*W*H) * sum(abs(filtered(:)));
end
fprintf("Estimated noise std: %.4f\n", noiseStd);
```

**Decision guidance (for single [0,1] range):**

| Noise std | Interpretation | Recommended action |
|-----------|----------------|-------------------|
| < 0.01 | Clean image | No denoising needed |
| 0.01–0.05 | Moderate noise | `imgaussfilt` or `imnlmfilt` |
| 0.05–0.10 | Heavy noise | `imnlmfilt` with higher `DegreeOfSmoothing` |
| > 0.10 | Severe noise | Consider `medfilt2` (if salt & pepper) or multiple passes |

See `filtering.md` for denoising function details.

### Histogram Shape — Segmentation Planning

The histogram shape directly determines which segmentation approach to use:

```matlab
gray = im2gray(img);
[counts, binLocs] = imhist(gray);

% Compute number of significant peaks (modes)
smoothCounts = smoothdata(double(counts), "gaussian", 7);  % 1-D smoothing
peaks = islocalmax(smoothCounts, MinProminence=max(smoothCounts)*0.05);
numModes = nnz(peaks);
fprintf("Histogram modes: %d\n", numModes);
```

**Decision guidance:**

| Modes | Histogram shape | Segmentation approach |
|-------|----------------|----------------------|
| 2 | Bimodal (clear foreground/background) | `imbinarize` (global Otsu) |
| 2 (but uneven peak heights) | Bimodal with uneven illumination | `imbinarize("adaptive")` |
| 3–5 | Multimodal | `multithresh` + `imquantize` |
| 1 or smooth | Unimodal/flat | Clustering (`imsegkmeans`) or edge-based methods |

### Blur / Sharpness Estimation

Estimate whether the image is in focus using Laplacian variance:

```matlab
gray = im2double(im2gray(img));
lap = imfilter(gray, fspecial("laplacian", 0), "replicate");
sharpness = var(lap(:));
fprintf("Sharpness (Laplacian variance): %.6f\n", sharpness);
```

**Decision guidance:**

| Sharpness | Interpretation | Action |
|-----------|----------------|--------|
| > 0.01 | Sharp / in focus | No deblurring needed |
| 0.001–0.01 | Mild blur | Consider `imsharpen` |
| < 0.001 | Significantly blurred | Deblurring needed — see `deblurring.md` |

**Note:** These thresholds are image-dependent. Compare across a dataset to establish baseline, or use no-reference quality metrics (`niqe`, `brisque`) for a more robust assessment.

### Illumination Uniformity

Detect uneven illumination that would break global thresholding:

```matlab
gray = im2double(im2gray(img));

% Estimate background with large Gaussian
background = imgaussfilt(gray, 50);

% Measure variation in background
bgRange = max(background(:)) - min(background(:));
bgStd = std(background(:));
fprintf("Background range: %.3f, std: %.3f\n", bgRange, bgStd);
```

**Decision guidance:**

| Background std | Interpretation | Recommended correction |
|---------------|----------------|----------------------|
| < 0.05 | Uniform illumination | Global methods work fine |
| 0.05–0.15 | Moderate unevenness | `imflatfield` or adaptive thresholding |
| > 0.15 | Severe unevenness | `imflatfield` before any segmentation |

See `preprocessing.md` for `imflatfield` usage details.

### Foreground/Background Structure

Characterize objects in the image to inform segmentation strategy:

```matlab
% Quick binary estimate
bw = imbinarize(im2gray(img));
bw = bwareaopen(bw, 20);  % Remove tiny specks
cc = bwconncomp(bw);

fprintf("Estimated objects: %d\n", cc.NumObjects);

if cc.NumObjects > 0
    props = regionprops("table", cc, "Area", "Eccentricity", "Solidity");
    fprintf("Area range: [%d, %d] pixels\n", min(props.Area), max(props.Area));
    fprintf("Median eccentricity: %.2f\n", median(props.Eccentricity));
    fprintf("Median solidity: %.2f\n", median(props.Solidity));

    % Detect touching objects (low solidity + large area suggests merged blobs)
    if any(props.Solidity < 0.7 & props.Area > median(props.Area)*3)
        fprintf("Warning: likely touching/overlapping objects — consider watershed\n");
    end
end
```

**Decision guidance:**

| Observation | Suggests |
|-------------|----------|
| Few large objects, high solidity | Simple thresholding sufficient |
| Many small objects, uniform size | Particle analysis — `bwareaopen` + `regionprops` |
| Low solidity on large regions | Touching objects — need watershed or SAM |
| Very few objects detected | Threshold may be wrong, or image needs preprocessing first |
| Objects vary wildly in size | May need multi-scale approach or size-based filtering |

### Content Type Heuristics

Identify what kind of image you're dealing with to select appropriate processing:

```matlab
gray = im2gray(img);
[h, w, c] = size(img);

% Compute diagnostic features
edgeDensity = nnz(edge(gray, "Canny")) / numel(gray);
if isinteger(gray)
    uniqueColors = numel(unique(gray(:))) / double(intmax(class(gray)));
    entropy_val = entropy(gray);
else
    uniqueColors = numel(unique(gray(:))) / numel(gray);
    entropy_val = entropy(im2uint8(mat2gray(gray)));
end

fprintf("Edge density: %.3f\n", edgeDensity);
fprintf("Color utilization: %.1f%%\n", uniqueColors * 100);
fprintf("Entropy: %.2f\n", entropy_val);
```

**Characteristic signatures:**

| Content type | Edge density | Entropy | Disambiguating clues |
|-------------|-------------|---------|---------------------|
| Natural photo | 0.05–0.15 | 6–7.5 | RGB, moderate size (1–20 MP), smooth gradients |
| Document/scan | 0.01–0.05 | 2–5 | Bimodal histogram, very high contrast, often grayscale |
| Microscopy | 0.05–0.20 | 5–7 | uint16, many small objects, uneven illumination, often grayscale |
| Satellite/aerial | 0.10–0.20 | 6–7.5 | Large image (>2000×2000), multi-band, regular texture |
| Synthetic/rendered | 0.02–0.10 | 4–6 | Very low noise (std < 0.005), perfectly sharp edges, flat regions |
| Medical (CT/MRI) | 0.03–0.10 | 4–6 | int16, narrow dynamic range, often 3-D or DICOM source |

When ranges overlap, use the "Disambiguating clues" column — check data type, image dimensions, and file source metadata to resolve.

**Processing implications:**

| Content type | Typical pipeline |
|-------------|-----------------|
| Natural photo | Color correction → denoising → enhancement |
| Document/scan | Binarization → morphological cleanup → OCR |
| Microscopy | Flat-field correction → denoising → segmentation → measurement |
| Satellite | Normalization → index computation → classification |
| Medical | Window/level → segmentation → volumetric analysis |

## Summarize Before Processing

After characterizing data, summarize findings before proposing a pipeline. Include both file-level and content-level observations:

```matlab
fprintf("\n=== Summary ===\n");
fprintf("Format: %s, %dx%d, %s, %d-bit\n", format, width, height, colorType, bitDepth);
fprintf("Data class: %s, range: [%g, %g]\n", dataClass, minVal, maxVal);
fprintf("Sharpness: %.5f | BG uniformity: %.3f\n", sharpness, bgStd);
fprintf("Histogram modes: %d | Objects detected: %d\n", numModes, numObjects);

% Actionable recommendations
if sharpness < 0.001, fprintf("→ Image is blurred — consider deblurring\n"); end
if bgStd > 0.05,   fprintf("→ Uneven illumination — apply imflatfield\n"); end
if numModes == 2,   fprintf("→ Bimodal histogram — imbinarize should work well\n"); end
```

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Using `imshow` for display | Lacks `DisplayRangeMode`, `OverlayData`, and modern features | Use `imageshow` (R2024b+) |
| Using Python/shell to inspect images | MATLAB has `imfinfo`, `imread`, `imageDatastore` | Use MATLAB functions shown above |
| Assuming all images are uint8 RGB | Data may be uint16, indexed, grayscale, or float | Check `imfinfo` and `class(imread(...))` |
| Displaying 12-bit data with default range | Image appears very dark (values << 65535) | Use `DisplayRangeMode="12-bit"` |
| Reading indexed image with one output | Gets index matrix, not true color | Use `[X, map] = imread(...)` then `ind2rgb` |
| Loading all images to check properties | Wastes time and memory | Use `imfinfo` for metadata (no pixel load) |
| Not checking for alpha channel | Alpha ignored, transparency lost | Use 3-output `imread` or check `imfinfo.Transparency` |
| Assuming consistent resolution | Dataset may have mixed sizes | Sample multiple files before batch processing |
| `imhist` on float data outside [0,1] | Silently clips to [0,1] — bins cover only 0–1 even if data ranges to 5.0 | Use `histogram(img(:))` for arbitrary-range float data |

----

Copyright 2026 The MathWorks, Inc.

----
