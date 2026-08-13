---
name: matlab-analyze-spectral-images
description: >-
  Work with hyperspectral and multispectral images in MATLAB. Covers reading/writing
  (ENVI, NITF, TIFF, Sentinel-2, Landsat, ASTER), ECOSTRESS spectral libraries, processing (calibration,
  atmospheric correction, denoising, sharpening, dimensionality reduction, endmember
  extraction, unmixing, target/anomaly detection, spectral indices, segmentation),
  labeling (Spectral Image Labeler app, ground truth objects, automation algorithms),
  and deep learning (pixel classification CNNs, unmixing autoencoders, transfer learning).
  Use when reading, writing, processing, analyzing, classifying, labeling, or applying
  deep learning to hyperspectral or multispectral images.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Spectral Imaging Skill

Generate MATLAB code for working with hyperspectral and multispectral data using the Hyperspectral Imaging Library for Image Processing Toolbox. Requires desktop MATLAB (not MATLAB Online or MATLAB Mobile) and the Hyperspectral Imaging Library add-on.

## When to Use

- Reading/writing hyperspectral or multispectral images (ENVI, NITF, GeoTIFF, TIFF, ASTER, Sentinel-2, Landsat)
- Reading ECOSTRESS spectral library signatures (`readEcostressSig`)
- Creating hypercube/multicube objects, band selection, cropping, block processing
- Radiometric calibration, atmospheric correction, spectral correction
- Denoising, sharpening, dimensionality reduction (PCA, MNF)
- Endmember extraction, spectral unmixing, abundance estimation
- Spectral matching, target detection, anomaly detection
- Computing spectral indices (NDVI, EVI, custom)
- Segmentation (spectral clustering, superpixels, ISODATA)
- Labeling with the Spectral Image Labeler app
- Creating ground truth objects for spectral labeling
- Deep learning classification or unmixing of spectral images
- Semantic segmentation of multispectral satellite imagery (DeepLabV3+ with multi-channel input)

## When NOT to Use

- General image reading/writing (use `imread`/`imwrite`)
- Non-spectral 3-D volume data (use Medical Imaging or Image Processing Toolbox)
- General image classification not involving spectral cubes (use Deep Learning Toolbox)
- Non-spectral semantic segmentation of RGB/grayscale images (use Computer Vision Toolbox)
- Point spectra or spectral libraries without spatial dimensions

## Prerequisite Check

If you suspect the Hyperspectral Imaging Library might not be installed (e.g., user reports errors), verify with `exist('imhypercube','file')`. If not installed, suggest installing via Add-On Explorer and fall back to `multibandread`/`imread`. Do NOT run this check if you are confident the library is available.

## Quick Start

```matlab
% Read hyperspectral data
hcube = imhypercube("scene.hdr");

% Visualize — colorize syntax (NO name-value for basic usage):
falseColor = colorize(hcube);              % false-colored image (default, 3 most informative bands)
rgb = colorize(hcube, Method="rgb");       % true RGB (hypercube ONLY — needs R/G/B wavelengths)
cir = colorize(hcube, Method="cir");       % color infrared (hypercube ONLY)
custom = colorize(hcube, [30 20 10]);      % false color from specific band INDICES (not wavelengths)
imshow(falseColor)

% Radiometric pipeline
hcube = dn2radiance(hcube);
hcube = radiance2Reflectance(hcube);
hcube = fastInScene(hcube);

% Compute NDVI
ndviMap = ndvi(hcube);

% Endmember extraction and unmixing
numEM = countEndmembersHFC(hcube);
endmembers = nfindr(hcube, numEM);
abundance = estimateAbundanceLS(hcube, endmembers, Method="fcls");

% Anomaly detection
rxScore = anomalyRX(hcube);

% Segmentation
L = hyperseganchor(hcube, 8);

% Launch viewer app
hyperspectralViewer(hcube)

% Launch labeler app (Since R2026a)
spectralImageLabeler(hcube)
```

## Essential Syntax (use without reading reference files)

### colorize — Visualization
```matlab
% HYPERCUBE (supports Method, 2 outputs, ContrastStretching default=false)
falseColor = colorize(hcube)                        % false-colored (default)
rgb = colorize(hcube, Method="rgb")                 % true color RGB
cir = colorize(hcube, Method="cir")                 % color infrared
custom = colorize(hcube, [b1 b2 b3])               % 3 band indices
[img, indices] = colorize(hcube)                    % also get band indices used
img = colorize(hcube, ContrastStretching=true)      % with CLAHE

% MULTICUBE (NO Method param, 1 output, ContrastStretching default=true)
rgb = colorize(mcube)                               % true RGB (auto-selects by wavelength)
custom = colorize(mcube, [b1 b2 b3])               % false color from band indices
img = colorize(mcube, ContrastStretching=false)     % disable contrast stretching
```

### I/O and Band Management
```matlab
hcube = imhypercube("file.hdr");                    % read ENVI/NITF/TIFF
mcube = immulticube("MTL.txt");                     % read Landsat (pass *_MTL.txt file)
mcube = immulticube("manifest.safe");              % read Sentinel-2 (pass manifest.safe file, NOT .SAFE folder)
mcube = immulticube("AST_L1T.hdf");                % read ASTER HDF
cropped = cropData(hcube, 30:110, 30:110);          % row indices, col indices (NOT [x y w h])
vnir = selectBands(hcube, Wavelength=[400 1000]);   % by wavelength range
subset = selectBands(hcube, BandNumber=[1 10 20]);  % by band index
cleaned = removeBands(hcube, Wavelength=[1350 1450]); % remove wavelength range
data = gather(hcube);                               % get M-by-N-by-C numeric array

% ACCESSING DIMENSIONS — NO NumRows/NumColumns/NumBands properties exist:
height = hcube.Metadata.Height;                     % number of rows (M)
width  = hcube.Metadata.Width;                      % number of columns (N)
bands  = hcube.Metadata.Bands;                      % number of spectral bands (C)
% For multicube: use mcube.BandSize(1,1) for height, mcube.BandSize(1,2) for width

% RESAMPLING vs SELECTING (multicube only):
mcubeUniform = resampleBands(mcube, 30);                       % RESAMPLE all bands TO 30m (keeps ALL bands, changes spatial size)
mcubeUniform = resampleBands(mcube, 30, Method="bilinear");    % interpolation: "nearest"(default),"bilinear","cubic"
mcube30m = selectBands(mcube, "DataResolution", 30);           % KEEP only bands already at 30m (DISCARDS others)
% When asked to "resample" or "match resolution" → use resampleBands
% When asked to "select" or "filter" bands by resolution → use selectBands
```

### Spectral Indices (NEVER compute manually — use built-in functions)
```matlab
% NDVI — use built-in ndvi() function (supports block processing natively)
ndviMap = ndvi(spcube);                             % direct numeric M-by-N output, range [-1,1]
ndviMap = ndvi(spcube, BlockSize=[512 512]);        % with block processing for large data

% Standard indices — use spectralIndices() (returns struct with .IndexName and .IndexImage)
indices = spectralIndices(spcube, "NDVI");          % single index → struct
indices = spectralIndices(spcube, ["NDVI","EVI"]);  % multiple → struct array
indices = spectralIndices(spcube, "all");           % all 16 supported indices
indices = spectralIndices(spcube, "NDVI", BlockSize=[512 512]);  % with block processing
% Supported: "NDVI","EVI","NDBI","NBR","MNDWI","MSI","GVI","OSAVI","SR","CMR","MCARI","MTVI","PRI","NDNI","NDMI","CAI"

% Custom formula — use customSpectralIndex() (3 required args: cube, wavelengths, @func)
indexImage = customSpectralIndex(spcube, [800 670], @(nir,red) (nir-red)./(nir+red));
indexImage = customSpectralIndex(spcube, [800 670 475], @(nir,red,blue) 2.5*(nir-red)./(nir+6*red-7.5*blue+1));
indexImage = customSpectralIndex(spcube, [560 1650], @(g,swir) (g-swir)./(g+swir), BlockSize=[512 512]);
% DO NOT manually extract bands and compute — always use these built-in functions
```

### Detection, Matching, and Processing
```matlab
% Target detection — method is POSITIONAL (3rd arg, not Name=Value)
target = resampleSignature(libData(1), hcube.Wavelength); % resample library spectrum to cube wavelengths
score = detectTarget(hcube, target, "ACE");         % "CEM","ACE","SignedACE","MF","GLRT","AMSD","OSP"
rxScore = anomalyRX(hcube);                         % higher = more anomalous

% Similarity scores — cube first, reference second (lower = better match)
score = sam(hcube, refSpectrum);                    % spectral angle mapper [0, pi]
score = sid(hcube, refSpectrum);                    % spectral information divergence

% spectralMatch — UNUSUAL ARG ORDER: library struct FIRST, then cube/spectrum
% DO NOT pass numeric vectors — first arg MUST be a struct with .Reflectance and .Wavelength fields
libData = readEcostressSig("vegetation.txt");       % returns 1-by-K struct array
score = spectralMatch(libData, hcube);              % returns M-by-N-by-K (one score map per signature)
score = spectralMatch(libData, hcube, Method="sam");% "sam"(default),"sid","sidsam","jmsam","ns3"
score = spectralMatch(libData, reflectance, wavelength); % compare against single spectrum (returns K-vector)
% Lower score = stronger match. Returns NaN when bandwidth overlap < MinBandWidth (default 300nm)
% For direct numeric comparison without library: use sam(hcube, target) or sid(hcube, target)

% Spectral clustering / segmentation (use INSTEAD of kmeans for spectral data)
L = hyperseganchor(hcube, numClusters);             % spectral-aware clustering (1 output)
[L, n] = hyperslic(hcube, K);                       % spectral superpixels (2 outputs)

% Block processing — callback receives OBJECT, must use gather()
result = apply(hcube, @(block) mean(gather(block), 3));
```

## Workflow

For functions fully documented in the Essential Syntax and Common Mistakes sections above, generate code directly — those sections provide complete API signatures and constraints.

**Read a reference file ONLY when:**
- Using a function NOT covered in Essential Syntax (e.g., `sharc`, `empiricalLine`, `sharpencnmf`, `spectralImageLabeler`)
- Unsure about argument order or constraints for a complex workflow
- The task involves the Spectral Image Labeler app or ground truth objects

**Reference Files (consult only when needed):**

- [references/spectral-io.md](references/spectral-io.md) — I/O, band selection, cropping, block processing, colorize, enviwrite
- [references/spectral-calibration.md](references/spectral-calibration.md) — Radiometric calibration, atmospheric correction, spectral correction, denoising, sharpening
- [references/spectral-analysis.md](references/spectral-analysis.md) — PCA/MNF, unmixing, spectral matching, target/anomaly detection, indices, segmentation
- [references/spectral-deep-learning.md](references/spectral-deep-learning.md) — Labeler app, groundTruthSpectralImage, deep learning pipelines
- [references/dl-classification.md](references/dl-classification.md) — 3-D CNN, 1-D CNN, ground truth to training data workflows
- [references/dl-advanced.md](references/dl-advanced.md) — Unmixing autoencoder, transfer learning, DeepLabV3+ semantic segmentation

## CRITICAL: Common Mistakes to Avoid

These are the most frequent errors. Violating any of these will cause runtime failures:

1. NEVER use `hypercube()` — deprecated. Use `imhypercube()` or `geohypercube()`.
2. `cropData(hcube, 30:110, 30:110)` — row/col INDEX VECTORS, not `[x y w h]`
3. `selectBands`/`removeBands` require Name=Value: `selectBands(hcube, BandNumber=[1 10 20])`, `removeBands(hcube, Wavelength=[1350 1450])`. `removeBands` errors if range outside cube's actual wavelengths.
4. `customSpectralIndex(spcube, [800 670], @(nir,red) (nir-red)./(nir+red))` — 3 args required
5. `apply(hcube, @(block) mean(gather(block), 3))` — callback receives OBJECT, use `gather()`
6. `inverseProjection(pcaCube, coeff)` — data first, coefficients second
7. `spectralMatch(libData, hcube)` — struct from `readEcostressSig` FIRST. For numeric: use `sam(hcube, target)` directly.
8. `L = hyperseganchor(hcube, 8)` (1 output); `[L, n] = hyperslic(hcube, 100)` (2 outputs)
9. `immulticube` does NOT support ENVI. Sentinel-2: pass `manifest.safe` (NOT `.SAFE` folder). Landsat: `*_MTL.txt`. ASTER: `.hdf`.
10. `spectralIndices(hcube, "NDVI")` → struct with `.IndexName`/`.IndexImage`. Use `ndvi(hcube)` for numeric.
11. `hyperslic` with 3 bands: `hyperslic(data, 100, IsInputDimReduced=true)`. Only params: `NumIterations` (max 30), `IsInputDimReduced`. NO `Compactness`.
12. `detectTarget(hcube, target, "ACE")` — method is POSITIONAL, not Name=Value
13. `denoiseNGMeet`: needs spatial dims > 16. Crop large images to ≤1024x1024 first.
14. `flatField(hcube, [xmin ymin width height])` — rect vector, NOT index vectors like `cropData`
15. `colorize(mcube)` → true RGB (NO `Method` param!). `colorize(mcube, [b1 b2 b3])` for false-color. `colorize(hcube, Method="rgb")` only works on hypercube.
16. `resampleBands(mcube, 30)` = resizes all bands to target res. `selectBands(mcube, "DataResolution", 30)` = keeps only bands already at that res.
17. NO `NumRows`/`NumColumns`/`NumBands` properties. Use `hcube.Metadata.Height/Width/Bands`. Multicube: `mcube.BandSize(1,1)`/`mcube.BandSize(1,2)`.
18. NEVER manually compute indices. Use `ndvi(spcube)`, `spectralIndices(spcube, "NDVI")`, or `customSpectralIndex(spcube, [wl1 wl2], @(b1,b2) formula)`.
19. `sam`/`sid` refSpectra must be C-element VECTOR, not matrix.
20. `assignData(hcube, rows, cols, bands, data)` — 5 args with index ranges
21. `enviwrite(hcube, "output")` — hypercube ONLY, not multicube
22. `groundTruthSpectralImage` labelDefs: 6 columns required including `AttributeList`. Property: `LabelDefinitions` (plural).

## Key Rules

- Pipeline: DN → radiance → reflectance → atmospheric correction. Smile correction BEFORE denoising.
- L2 products already have surface reflectance — DN pipeline is for L1 only.
- Research datasets (Indian Pines, PaviaU) lack calibration metadata.
- **hypercube ONLY**: `denoiseNGMeet`, `hyperpca`, `hypermnf`, `inverseProjection`, `sharpencnmf`, `countEndmembersHFC`, `nfindr`, `ppi`, `estimateAbundanceLS`, `anomalyRX`, `sam`, `sid`, `spectralMatch`, `hyperslic`, `sharc`, `empiricalLine`, `reduceSmile`
- **hypercube + multicube**: `dn2radiance`, `radiance2Reflectance`, `fastInScene`, `detectTarget`, `ndvi`, `spectralIndices`, `customSpectralIndex`, `hyperseganchor`
- **+ numeric array**: `flatField`, `iarr`, `logResiduals`, `subtractDarkPixel`
- Deep learning: `trainnet` + `dlnetwork` (not `trainNetwork`). Use `hyperpca` before CNN.
- Valid `spectralIndices` names: ndvi, osavi, sr, evi, gvi, ndni, pri, cai, mcari, mtvi, msi, cmr, nbr, ndbi, ndmi, mndwi (NOT "ndwi")
- Labeler (R2026a+): `groundTruthSpectralImage` properties are read-only after creation

----

Copyright 2026 The MathWorks, Inc.
