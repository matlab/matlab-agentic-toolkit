---
name: matlab-process-images
description: >
  Load this first for any task involving images, pictures, photos, scans, frames,
  volumes, or visual data — including reading, writing, filtering, enhancing,
  denoising, sharpening, deblurring, thresholding, segmenting, masking,
  detecting, finding or counting objects, removing backgrounds, measuring,
  comparing, registering, stitching, aligning, cropping, resizing, transforming,
  or analyzing. Use for image I/O (TIFF, PNG, JPEG, RAW, HDR), histograms,
  edge detection, color processing, morphology, geometric transforms, deep
  learning for images, quality assessment, and 3-D volume processing. Also
  triggers when users describe image problems (dark, noisy, blurry, low contrast,
  uneven lighting, hazy, color cast) or data exploration tasks (folder of images,
  characterize data, understand format). Handles microscopy (cells, particles)
  and general scientific imaging. Routes to sibling skills for medical imaging
  (DICOM, NIfTI), hyperspectral data, and visual inspection.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Image Processing

Process, analyze, and transform images using MATLAB Image Processing Toolbox (IPT). This skill routes you to the correct reference for your task and provides core conventions that apply across all IPT work.

## When to Use

Loaded for general-purpose IPT work: file and batch I/O, filtering, restoration,
morphology, segmentation, measurement, geometric transforms, color, texture,
quality metrics, deep learning on images, and image apps.
Non-medical microscopy — cell and particle counting on plain IPT — is in scope.

Hand off (and co-load) instead of answering alone: see the handoff table under `## Routing`.

## When NOT to Use

- Training a network with no image-specific preprocessing — use Deep Learning Toolbox directly
- Simulink or Stateflow video blocks — use Simulink directly
- C/C++ code generation, MEX, GPU acceleration and deployment — use MATLAB Coder / GPU Coder directly
- Point clouds, 3-D reconstruction, and video stabilization — use Computer Vision Toolbox directly
- General MATLAB questions unrelated to images

## Core Conventions

### Image Data Types

| Type | Range | When to use |
|------|-------|-------------|
| `uint8` | 0–255 | Display, file I/O, memory-efficient storage |
| `uint16` | 0–65535 | High dynamic range sensors, medical. **Camera RAW** is n-bit in a uint16 container — rescale with `rawinfo` `BlackLevel`/`WhiteLevel`, not 65535 |
| `single` / `double` | 0.0–1.0 | Arithmetic, filtering, computation |
| `logical` | 0 or 1 | Binary masks, segmentation results |

Most IPT functions accept integer types directly — do not convert to floating-point unless required.

### Default Coordinate Conventions

- MATLAB images are **(row, col)** — row is Y (down), column is X (right)
- `size(img)` returns `[height, width, channels]`
- Spatial functions use **(x, y)** order for coordinates (e.g., `imref2d`, `regionprops` centroids)
- Pixel centers are at integer intrinsic coordinates; in default world referencing, pixel (1,1) center is at world (1.0, 1.0) and the image edge starts at 0.5
- `imref2d` and `imref3d` can specify non-default spatial referencing to place images into world coordinate systems. By default they use the unit-spaced, integer-pixel-centered coordinate system described here, e.g. `Rout = imref2d(imageSize)`. Functions that do not accept spatial referencing objects assume this intrinsic coordinate system for any operation requiring spatial referencing.

### Multichannel Images

- Grayscale: `M×N` or `M×N×1`
- RGB: `M×N×3`
- With alpha: read using `[img, ~, alpha] = imread(...)` (alpha is the third output)
- Convert: `rgb2gray`, `im2gray` (preferred, handles more input types)

### Display Functions

Always use `imageshow` instead of `imshow` (R2024b+). `imageshow` handles sub-bit-depth containers (e.g., 12-bit in uint16) via `DisplayRangeMode`, supports `OverlayData` for label/mask overlays, and works with `viewer2d`. Do not fall back to `imshow` — it lacks these capabilities.

### Code Execution

**Execute code blocks via `evaluate_matlab_code` before presenting them to the user.** If it errors, fix and re-run. This catches type mismatches, wrong argument orders, and nonexistent functions before the user sees them. If execution requires user data or toolboxes not available in the current session, present the code with a note that it should be run with the user's own data — do not loop trying to synthesize stand-in data.

### Error Recovery

If code throws an error after execution, load the `matlab-read-documentation` skill and look up the function's doc page to verify syntax, required arguments, and supported input types before retrying.

### When to Ask the User

Ask for clarification before proceeding when:
- The image type/format is ambiguous and affects the processing approach
- Multiple valid approaches exist with different tradeoffs (speed vs quality, lossy vs lossless)
- The task requires choosing parameters that depend on domain knowledge (e.g., object size thresholds, noise characteristics)
- The user's MATLAB release is unknown and the recommended function may not be available

## Routing

Match your task in the tables below. **Check the handoff table first.** If the task belongs to
another skill, load that skill **in addition to** this one — the Core Conventions above (data
types, coordinate order, code execution) apply to all image data. Do not re-derive them from
the sibling. If a row in both tables fits, the handoff table wins on *workflow*; this skill
still owns *conventions*.

- **Unfamiliar data?** Load `references/image-understanding.md` first — but only when class, range, or content is unknown.
- **Starting from a function name, not a task?** The function column is illustrative, not exhaustive. To locate any function: `grep -rln '<functionName>' references/`. To look up syntax details, load `matlab-read-documentation`.
- **Pipeline tasks:** load several references; cap at three unless the task genuinely spans more.
- **Follow the patterns in loaded references.** References contain specific code patterns and workflows — use them instead of improvising equivalent code from general knowledge.
- **No row matches?** Name the owning product, state the closest IPT fallback, and say so — do not guess a reference.

### Check first: is this another skill's job?

| If the task involves... | Also load |
|---|---|
| DICOM, NIfTI, NRRD, DICOM-RT, patient metadata, anonymizing, `medicalVolume`, reading/writing medical formats | `matlab-read-medical-data` |
| Segmenting anatomy — tumor, lesion, organ, vessel — in CT, MRI, PET, ultrasound; MedSAM; radiomics | No skill covers this — Medical Imaging Toolbox (`segmentMedicalImage`, `groundTruthMedical`); look up the doc page |
| Displaying or viewing a 2-D image: `imshow`, `imageshow`, `viewer2d`, montage, mask overlay, annotation, colorbar, colormap, figure export | `matlab-display-image` |
| Displaying a 3-D volume: `volshow`, `viewer3d`, isosurface rendering, slice viewer, orthogonal views | `matlab-display-volume` |
| Hyperspectral or multispectral cubes, spectral indices, unmixing, ENVI, band selection | `matlab-analyze-spectral-images` |
| Calling a PyTorch or ONNX vision model from MATLAB | `matlab-integrate-pytorch-vision` |
| Gigapixel, whole-slide, or out-of-memory images; `blockedImage`, tiled workflows, image pyramids | `matlab-process-large-images` |
| OCR, text recognition, reading text out of an image | `matlab-recognize-text` (requires Computer Vision Toolbox) |
| Factory-floor visual inspection: anomaly detection, defect/scratch/dent detection, gauging, pass/fail counting | `matlab-use-visual-inspection` (requires Visual Inspection Toolbox, R2026b+) |
| Barcode or QR reading, camera calibration | No skill covers this — Computer Vision Toolbox (`readBarcode`, `estimateCameraParameters`); look up the doc page |
| Optical system design: lens import, prescription-side MTF, spot diagrams, ray tracing, tolerance analysis | `matlab-model-optics` |

### In scope: pick the reference

| If the task or the user's words involve... | Illustrative functions | Load |
|---|---|---|
| inspect, understand, characterize, explore data, look at my images, what kind of image, what am I working with, what's in this folder, describe the data, summarize the dataset, what format, bit depth, class and range, indexed image, alpha channel, metadata, file info, dataset characterization, before I start processing | `imfinfo`, `imhist`, `countEachLabel` | `references/image-understanding.md` |
| read, write, load, save, import, export, open an image, convert format, batch, folder of images, video, footage, frames, TIFF, PNG, JPEG, RAW, HDR, test pattern | `imread`, `imwrite`, `imageDatastore`, `VideoReader`, `hdrread` | `references/image-io.md` |
| smooth, blur an image, sharpen, denoise, noise, grainy, filter, kernel, padding, edge-preserving, bilateral, non-local means, frequency filter | `imgaussfilt`, `medfilt2`, `imsharpen`, `imbilatfilt`, `imnlmfilt`, `imdiffusefilt`, `imfilter`, `ordfilt2`, `locallapfilt`, `wiener2` | `references/filtering.md` |
| contrast, brighten, darken, too dark, washed out, enhance, improve, histogram, equalize, CLAHE, normalize, rescale, blend, arithmetic, type convert, flat-field, illumination correction, vignetting, uneven lighting | `imadjust`, `stretchlim`, `adapthisteq`, `histeq`, `rescale`, `mat2gray`, `im2single`, `imadd`, `imlincomb`, `imblend`, `imflatfield` | `references/preprocessing.md` |
| erode, dilate, open, close, structuring element, 2-D morphology, fill holes, remove small objects, skeletonize, thin, tidy up a binary result | `strel`, `imerode`, `imdilate`, `imopen`, `imclose`, `imfill`, `bwareaopen`, `bwskel`, `imtophat`, `imreconstruct` | `references/morphological-ops.md` |
| deblur, blurry, unfocused, out of focus, motion blur, camera shake, restore a blurred image, deconvolution, PSF estimation | `deconvblind`, `deconvlucy`, `deconvwnr`, `deconvreg` | `references/deblurring.md` |
| resize, rotate, crop, warp, scale, flip, straighten, affine, projective, perspective, undistort, lens distortion, spatial referencing, world coordinates, voxel coordinates, pixel coordinates, coordinate conversion | `imresize`, `imrotate`, `imcrop`, `imwarp`, `imtranslate`, `affinetform2d`, `imref2d` | `references/geometric-transforms.md` |
| align two images, stitch, mosaic, panorama, overlapping shots, seam, motion correction, multi-modal alignment, control points, non-rigid, deformable, homography **(feature-based requires Computer Vision Toolbox)** | `imregister`, `imregtform`, `imregdemons`, `imregcorr`, `detectSIFTFeatures`, `matchFeatures`, `estgeotform2d` **(last three: Computer Vision Toolbox)**, `imregdeform` **(Medical Imaging Toolbox)** | `references/registration.md` |
| segment or threshold with no user input: binarize, Otsu, watershed, k-means or colour clustering, `imsegsam` automatic mode, deep-learning segmentation | `imbinarize`, `graythresh`, `multithresh`, `adaptthresh`, `watershed`, `imsegkmeans`, `imsegkmeans3`, `imsegisodata`, `imsegsam` | `references/segmentation-automated.md` |
| segment **with user input**: clicks, points, boxes, scribbles, seeds, prompted SAM, grabcut, active contours, region growing, lazy snapping, superpixels, App Designer segmentation UIs | `segmentAnythingModel`, `grabcut`, `activecontour`, `lazysnapping`, `imsegfmm`, `grayconnected`, `superpixels` | `references/segmentation-interactive.md` |
| measure, count objects, how many, area, perimeter, centroid, size, shape, width, thickness, gap, diameter, Feret, orientation, detect edges, circles, lines, boundary tracing, ROI, world units, metrology, region, region properties, analysis | `regionprops`, `bwconncomp`, `bwareafilt`, `bwpropfilt`, `bwlabel`, `edge`, `imfindcircles`, `hough`, `bwboundaries` | `references/analysis-measurement.md` |
| quality, PSNR, SSIM, sharpness, noise level, is it blurry, compare two images, difference, before/after, MTF (camera/chart SFR), test chart, artifact **(register first — full-reference metrics need pixel correspondence)** | `psnr`, `ssim`, `multissim`, `immse`, `brisque`, `niqe`, `piqe`, `measureSharpness`, `esfrChart` | `references/quality-assessment.md` |
| texture, repetitive pattern, frequency domain, Fourier, FFT, DCT, Radon, Gabor, co-occurrence, GLCM | `graycomatrix`, `graycoprops`, `entropyfilt`, `fft2`, `dct2`, `radon`, `gabor` | `references/texture-transforms.md` |
| color space, LAB, HSV, hue, saturation, white balance, color cast, color correction, color balance, ICC profile, grayscale conversion | `rgb2lab`, `lab2rgb`, `rgb2hsv`, `chromadapt`, `illumwhite`, `makecform`, `deltaE`, `decorrstretch` | `references/color-processing.md` |
| 3-D array, volume, volumetric, voxel, slice stack, z-stack — filtering, 3-D morphology, 3-D transforms, or measurement applied to a volume | `imgaussfilt3`, `medfilt3`, `imresize3`, `regionprops3`, `bwvolumefilt` **(R2026b)**, `bwpropfilt3` **(R2026b)** | `references/3d-volume-processing.md` |
| deep learning, neural network, train, U-Net, semantic segmentation networks, classify images, pretrained model, transfer learning, fine-tune, inference, augment, training dataset **(requires DLT, often CVT)** | `unet`, `deeplabv3plus`, `trainnet`, `semanticseg`, `imageDataAugmenter`, `augmentedImageDatastore` | `references/deep-learning-imaging.md` |
| build your own image app or GUI: sliders, live preview, parameter tuning, ROI widgets | `uifigure`, `uigridlayout`, `uislider`, `drawrectangle` | `references/app-building.md` |

## Toolbox Detection

When unsure what's available, check installed toolboxes:

```matlab
hasIPT = ~isempty(ver('images'));
hasCVT = ~isempty(ver('vision'));
hasDLT = ~isempty(ver('nnet'));
hasMIT = ~isempty(ver('medical'));
hasWavelet = ~isempty(ver('wavelet'));
```

Most functions in this skill require Image Processing Toolbox. The `deep-learning-imaging` reference also requires Deep Learning Toolbox. Feature-based registration (`detectSIFTFeatures`, `matchFeatures`, `estgeotform2d`) requires Computer Vision Toolbox.

### Release-Gated Features

This skill targets R2024b+ but some features require newer releases. References annotate these with the required release. Key ones:

- **R2024b:** `imageshow`, `imblend`, `viewer2d`
- **R2026a:** `uidraw`, `uipaint`, `linkviewers`
- **R2026b:** `bwvolumefilt`, `bwpropfilt3`, `uiannotate`

If targeting an older release, check with `isMATLABReleaseOlderThan("R2026a")` and use the fallback patterns documented in the references. To check release notes for a specific function, load `matlab-read-documentation`.

----

Copyright 2026 The MathWorks, Inc.

----
