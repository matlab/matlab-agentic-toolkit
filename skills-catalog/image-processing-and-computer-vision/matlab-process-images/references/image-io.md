# Image I/O, Conversion & Batch Processing

Gotchas, non-obvious patterns, and decision guidance for image file I/O, type conversion, HDR, video, and batch workflows.

> **Often loaded with:** `image-understanding.md` (inspect before processing), `filtering.md` / `preprocessing.md` (next pipeline step).

## Medical Formats

**Decision flow:**

1. Check: `hasMIT = ~isempty(ver("medical"));`
2. If MIT is available → **STOP** — use the **`matlab-read-medical-data`** skill instead (provides `medicalVolume`, `medicalImage`, spatial referencing, RT structures, orientation)
3. If MIT is NOT available → use the IPT-only patterns below

### Quick DICOM Read (IPT Only — use only when MIT is unavailable)

Use `dicomread` + `dicominfo`:

```matlab
% Single DICOM file
info = dicominfo("slice.dcm");
pixels = dicomread(info);

% CRITICAL: dicomread returns RAW stored values — NOT calibrated units.
% For CT, convert to Hounsfield Units:
img_hu = double(pixels) * info.RescaleSlope + info.RescaleIntercept;
```

For reading an entire DICOM folder as a volume, use `dicomreadVolume`:

```matlab
[V, spatial, dim] = dicomreadVolume("path/to/dicom/folder");
V = squeeze(V);  % Always squeeze — removes singleton 4th dim for grayscale
```

### Quick NIfTI Read (IPT Only)

```matlab
V = niftiread("brain.nii.gz");
info = niftiinfo("brain.nii.gz");

% Key metadata
voxelSize = info.PixelDimensions(1:3);  % [dx dy dz] in mm
imageSize = info.ImageSize;              % [rows cols slices]

% Writing
niftiwrite(V, "output.nii.gz");          % Compressed automatically (R2024a+)
niftiwrite(V, "output.nii");             % Uncompressed
```

### Reminder: Check MIT First

If you skipped the decision flow above: always check `~isempty(ver("medical"))` before using the IPT-only patterns. The **`matlab-read-medical-data`** skill provides superior APIs (`medicalImage`, `medicalVolume`) that auto-apply rescaling and preserve spatial metadata.

## Type Awareness — Critical Rule

IPT functions behave differently based on input class. This is the #1 source of silent bugs:

| Input class | Assumed range | Consequence |
|-------------|---------------|-------------|
| `uint8` | [0, 255] | Arithmetic saturates — `uint8(200) + uint8(100)` = 255, not 300 |
| `double`/`single` | [0.0, 1.0] | Values outside [0,1] clip silently on `imwrite` |
| `double`/`single` outside [0,1] | Arbitrary | Scientific/computed data — use `rescale` or `mat2gray` before display/write |
| `int16` | [-32768, 32767] | Used for some medical/scientific data |
| `logical` | 0 or 1 | Many format writers reject logical (use PNG, not JPEG) |

Most IPT functions accept integer types directly — only convert to floating-point when doing manual pixel arithmetic (e.g., weighted blending, subtraction). See `preprocessing.md` for detailed guidance on when to convert.

### I/O-Related Conversions

| Function | Purpose | When to use |
|----------|---------|-------------|
| `im2uint8` | Float [0,1] → `uint8` [0,255] | Before `imwrite` for float data |
| `mat2gray` | Arbitrary range → `double` [0,1] | Non-image data (e.g., FFT magnitude) before saving |
| `ind2rgb` | Indexed + colormap → RGB `double` | After `[X,map] = imread(...)` for indexed images |

For floating-point conversion guidance (`im2single` vs `im2double`), see `preprocessing.md`.

## JPEG Is Not for Analysis

**Never use JPEG for image analysis pipelines.** JPEG's lossy compression discards pixel data in 8×8 blocks — this corrupts edges, introduces block artifacts, and alters intensity values. Use PNG or TIFF (lossless) for any intermediate or final images that will be measured, segmented, or compared quantitatively.

JPEG is acceptable only for final display/presentation output where exact pixel values don't matter.

## Write Gotchas

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| `imwrite(doubleImg, "out.png")` | Values > 1 clip silently | `imwrite(im2uint8(doubleImg), ...)` |
| `imwrite(logical, "out.jpg")` | JPEG rejects binary | Use PNG, or convert to `uint8` |
| Writing 16-bit to JPEG | JPEG is 8-bit only | Use TIFF or PNG |
| Saving analysis images as JPEG | Lossy compression corrupts measurements | Use PNG or TIFF for analysis |
| Forgetting `"WriteMode","append"` | Overwrites previous frames | See multi-frame TIFF below |

## Exif Orientation — `AutoOrient`

JPEG and TIFF files from cameras/phones often contain an Exif Orientation tag indicating how the image should be rotated/flipped for correct display. By default, `imread` ignores this tag and returns raw pixel data (which may appear rotated or mirrored).

```matlab
% Without AutoOrient — image may appear sideways/flipped
img = imread("photo.jpg");

% With AutoOrient — automatically rotates/flips according to Exif tag
img = imread("photo.jpg", AutoOrient=true);
```

Use `AutoOrient=true` when reading camera photos or user-supplied images where orientation matters. Check for the tag with `imfinfo`:

```matlab
info = imfinfo("photo.jpg");
if isfield(info, 'Orientation')
    fprintf("Exif Orientation tag: %d\n", info.Orientation);
end
```

## HEIC/HEIF Files (R2025a)

iPhone and modern cameras often save as HEIC/HEIF. Read with standard `imread`:

```matlab
img = imread("photo.heic");                     % Standard read
img = imread("photo.heic", AutoOrient=true);    % With orientation correction
```

No special function needed — `imread` handles HEIC natively since R2025a. Note: **WebP is not supported** by MATLAB — convert externally before reading.

## Camera RAW Files — `rawread`

**Do not use `imread` for camera RAW files.** On some RAW formats (CR2, DNG), `imread` may appear to work but returns only the embedded 8-bit preview thumbnail — not the full-resolution sensor data. Use `rawread` or `raw2rgb` instead:

```matlab
cfa = rawread("photo.NEF");          % Returns uint16 Bayer CFA data
rgb = demosaic(cfa, "rggb");         % Demosaic to full-color RGB

% Include non-visible frame area (e.g., dark reference columns)
cfa = rawread("photo.DNG", VisibleImageOnly=false);
```

**Key points:**
- Returns raw sensor data (Color Filter Array) — no white balance, no tone curve
- Output is `uint16` or `single` depending on the file
- Does not support RAW formats that use JPEG compression
- Use `demosaic` to convert CFA pattern to RGB (pattern is camera-specific: `"rggb"`, `"bggr"`, `"grbg"`, `"gbrg"`)
- For sensors with non-standard bit depth (e.g., 12-bit in 16-bit container), specify `BitsPerSample`: `demosaic(cfa, "rggb", BitsPerSample=12)` (R2025a)

**Simpler path — `raw2rgb`:** If you just want an RGB image (with white balance and color space applied automatically):

```matlab
rgb = raw2rgb("photo.NEF");                          % Full processing, uint16 output
rgb = raw2rgb("photo.NEF", BitsPerSample=8);         % uint8 output
rgb = raw2rgb("photo.NEF", ColorSpace="adobe-rgb-1998");
```

**Full manual RAW→sRGB chain** (when you need control over each stage):

```matlab
info = rawinfo("photo.NEF");
cfa  = rawread("photo.NEF");
rgb  = im2single(demosaic(cfa, info.CFALayout));
rgb  = rescale(rgb, InputMin=info.ColorInfo.BlackLevel, ...
               InputMax=info.ColorInfo.WhiteLevel);       % Correct n-bit scaling
rgb  = rgb * info.ColorInfo.CameraTosRGB';                % Camera → sRGB matrix
rgb  = chromadapt(rgb, info.ColorInfo.D65Illuminant, ColorSpace="linear-rgb");
rgb  = lin2rgb(rgb);                                      % Linear → sRGB gamma
```

> **Do not skip `CameraTosRGB`** — without it, colors are visibly wrong (ΔE > 2 on every pixel). Use `ColorSpace="linear-rgb"` with `chromadapt` because demosaiced RAW data is linear.

Use `rawread` + `demosaic` when you need access to the raw CFA data. Use `raw2rgb` when you just want a usable RGB image.

## PNG Alpha Channel

PNG files can contain transparency. The alpha channel is the **third** output of `imread`, not embedded in the RGB data:

```matlab
[img, ~, alpha] = imread("icon.png");  % alpha is [] if no transparency
if ~isempty(alpha)
    % alpha is same size as img(:,:,1), uint8 [0=transparent, 255=opaque]
    composite = im2double(img) .* double(alpha)/255 + background .* (1 - double(alpha)/255);
end
```

**Gotcha:** The second output is the colormap (empty for RGB). Do not skip it — `[img, alpha] = imread(...)` puts the colormap in `alpha`.

## Indexed Images

Some older formats (GIF, 8-bit PNG, BMP with palette) return an indexed image + colormap:

```matlab
[X, map] = imread("indexed.gif");
% X is uint8 indices, map is Nx3 double colormap [0,1]

% Convert to RGB for processing
rgb = ind2rgb(X, map);  % Returns double [0,1] RGB
```

**Gotcha:** If you call `imread` with one output on an indexed image, you get indices that look like a dark grayscale image — not the actual colors.

## Animated GIF Writing

Writing animated GIFs requires indexed frames and a specific append pattern:

```matlab
for i = 1:numFrames
    % Convert each frame to indexed color (required for GIF)
    [A, map] = rgb2ind(frames{i}, 256);

    if i == 1
        imwrite(A, map, "animation.gif", "gif", ...
            LoopCount=Inf, DelayTime=0.05);
    else
        imwrite(A, map, "animation.gif", "gif", ...
            WriteMode="append", DelayTime=0.05);
    end
end
```

**Key parameters:**
- `LoopCount` — number of loops (`Inf` = forever, `0` = play once). Only specify on the first frame's `imwrite` call.
- `DelayTime` — seconds between frames (0.05 = 20 fps)
- All frames should use the same colormap for best results

## Write Options — JPEG & TIFF

```matlab
% JPEG quality (0–100, default 75)
imwrite(img, "out.jpg", Quality=95);

% TIFF compression
imwrite(img, "out.tif", Compression="lzw");       % Lossless, good general choice
imwrite(img, "out.tif", Compression="packbits");   % Fast, moderate compression
imwrite(img, "out.tif", Compression="none");       % No compression, largest file
```

| Format | Parameter | Values |
|--------|-----------|--------|
| JPEG | `Quality` | 0–100 (default 75). Use 90–95 for archival or when downstream processing needs high fidelity. Use 50–75 for web or storage-constrained use. Below 50 introduces visible artifacts. |
| TIFF | `Compression` | `"none"`, `"lzw"`, `"packbits"`, `"deflate"` |
| PNG | `BitDepth` | 8 or 16 |

## Multi-Frame TIFF

The append pattern is non-obvious — first frame uses default write, subsequent frames must specify `"WriteMode","append"`:

```matlab
for i = 1:numFrames
    if i == 1
        imwrite(frames{i}, "stack.tif");
    else
        imwrite(frames{i}, "stack.tif", WriteMode="append");
    end
end
```

Reading specific frames: `imread("stack.tif", frameIndex)`

Frame count: `numel(imfinfo("stack.tif"))`

### Low-Level TIFF — `Tiff` Class

For tiles, strips, custom tags, or BigTIFF:

```matlab
t = Tiff("image.tif", "r");
data = read(t);
nextDirectory(t);    % Move to next frame
close(t);
```

## HDR & EXR Images

High Dynamic Range (HDR) and OpenEXR (EXR) images have floating-point values that can exceed 1.0.

```matlab
% Radiance .hdr format
hdr = hdrread("scene.hdr");       % Returns M×N×3 float, values can exceed 1.0
hdrwrite(hdr, "output.hdr");

% OpenEXR format (R2022b+) — common in VFX/compositing
[img, alpha] = exrread("scene.exr");  % Float data + optional alpha channel
exrwrite(img, "output.exr");
info = exrinfo("scene.exr");          % Metadata (channels, resolution, etc.)
```

**Tone mapping (HDR → displayable LDR).** Input must be `single` or `double`:
```matlab
ldr = tonemap(hdr);                                    % Global → uint8
ldr = localtonemap(hdr, RangeCompression=0.8, ...
    EnhanceContrast=0.5);                              % Local contrast-aware
```

**Create HDR from bracketed exposures:**
```matlab
files = ["under.jpg", "normal.jpg", "over.jpg"];
hdr = makehdr(files, RelativeExposure=[1 4 16]);  % Relative exposure ratios
ldr = localtonemap(hdr);
```

## Video I/O

### Key Gotcha: Memory

`read(v)` loads ALL frames into memory. For large videos, iterate instead:

```matlab
v = VideoReader("clip.mp4");
while hasFrame(v)
    frame = readFrame(v);
    % Process frame...
end
```

For specific frame ranges: `frames = read(v, [10 20]);`

### VideoWriter — Always Close

An unclosed `VideoWriter` produces a corrupt file. Use `onCleanup`:

```matlab
vw = VideoWriter("output.mp4", "MPEG-4");
cleanup = onCleanup(@() close(vw));
vw.FrameRate = 30;
vw.Quality = 95;
open(vw);
for i = 1:numFrames
    writeVideo(vw, frames(:,:,:,i));
end
```

**Profiles:** `"MPEG-4"` (.mp4), `"Motion JPEG AVI"`, `"Grayscale AVI"`, `"Uncompressed AVI"`

## Batch Processing with Datastores

### `transform` — Process on Read

```matlab
imds = imageDatastore("data/", IncludeSubfolders=true);

% Apply processing lazily — images are transformed when read, not upfront
tds = transform(imds, @(x) imresize(im2gray(x), [256 256]));
img = read(tds);  % Returns processed 256×256 grayscale
```

### `combine` — Pair input/label datastores

```matlab
inputDS = imageDatastore("images/");
labelDS = imageDatastore("masks/");
paired = combine(inputDS, labelDS);
data = read(paired);  % Returns {inputImg, maskImg}
```

### Folder-Based Labels

```matlab
imds = imageDatastore("data/", ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");  % Subfolder names become labels
```

**Note:** `augmentedImageDatastore` requires Deep Learning Toolbox — see `references/deep-learning-imaging.md`.

## Partial Reads

For large images, avoid loading the full file:

```matlab
sub = imread("big.tif", PixelRegion={[1 500], [1 500]});  % Rows 1-500, cols 1-500
```

For very large images (gigapixel), use `matlab-process-large-images` skill instead.

## Synthetic Test Images

| Function | What it creates | Key detail |
|----------|----------------|------------|
| `phantom(N)` | Shepp-Logan phantom | Returns `double`, range includes negative values near zero |
| `checkerboard(tileSize, M, N)` | Checkerboard pattern | Returns `double` [0,1], size is `2*M*tileSize × 2*N*tileSize` (a tile is a 2×2 block of squares) |
| `imnoise(img, type, ...)` | Noisy copy | Accepts and returns same class as input |

Noise types: `"gaussian"` (mean, var), `"salt & pepper"` (density), `"speckle"` (var), `"poisson"`

## Functions That Do NOT Exist

These are commonly hallucinated — do not generate calls to them:

| Hallucinated function | What to use instead |
|-----------------------|--------------------|
| `estimateNoise` | See noise estimation in `image-understanding.md` |
| `imreadstack` | Loop with `imread(filename, frameIdx)` for multi-frame TIFF |
| `iminfo` | Correct name is `imfinfo` |
| `imread3d` | Use `dicomreadVolume`, `niftiread`, or loop over slices |
| `imwriteall` | Loop with `imwrite(..., WriteMode="append")` |
| `rgb2grayscale` | Use `im2gray` |
| `imresize3d` | Correct name is `imresize3` |

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Arithmetic on `uint8` | Saturates at 0/255, no negatives | Convert to `single` first, or use `imadd`/`imsubtract` |
| Assuming `imread` returns `double` | Returns `uint8` by default | Always convert or check `class(img)` |
| Using `rgb2gray` | Errors on non-RGB input | Use `im2gray` — handles more input types |
| `imwrite(floatImg, ...)` without converting | Clips silently outside [0,1] | Use `im2uint8` or `mat2gray` first |
| `read(v)` on large video | Loads ALL frames into memory | Use `hasFrame`/`readFrame` loop |
| `imread("photo.NEF")` for camera RAW | Silently returns only the embedded 8-bit preview thumbnail, not full-resolution sensor data | Use `rawread` then `demosaic` |
| `[img, alpha] = imread("file.png")` | Second output is colormap, not alpha | `[img, ~, alpha] = imread(...)` |
| `imwrite(rgb, "out.gif")` | GIF requires indexed color | `[A,map] = rgb2ind(rgb, 256)` then `imwrite(A, map, ...)` |
| `imwrite(..., "JPEGQuality", 95)` | Wrong parameter name | Use `Quality=95` for JPEG |
| Saving analysis images as JPEG | Lossy compression corrupts pixel values for measurement | Use PNG or TIFF for any image that will be analyzed |
| `niftiwrite(V, "out.nii.gz", Compressed=true)` | Verbose since R2024a | `niftiwrite(V, "out.nii.gz")` — auto-detects from extension |
| `imread` for EXR files | `imread` does not support EXR | Use `exrread` (R2022b+) |

----

Copyright 2026 The MathWorks, Inc.

----
