# Spectral Analysis Reference

Dimensionality reduction, unmixing, spectral matching, target/anomaly detection, indices, and segmentation using the Hyperspectral Imaging Library for Image Processing Toolbox.

**Requirement:** Desktop MATLAB only (not MATLAB Online or MATLAB Mobile). Requires the Hyperspectral Imaging Library add-on for Image Processing Toolbox.

## Dimensionality Reduction

```matlab
% Principal Component Analysis (PCA) — HYPERCUBE ONLY (fails on multicube)
[outputDataCube, coeff, var] = hyperpca(inputData, numComponents)
[outputDataCube, coeff, var] = hyperpca(inputData, numComponents, Method="svd")   % default
[outputDataCube, coeff, var] = hyperpca(inputData, numComponents, Method="eig")
[outputDataCube, coeff, var] = hyperpca(inputData, numComponents, MeanCentered=true) % default
% inputData: hypercube object or M-by-N-by-C array — NOT multicube
% outputDataCube: M-by-N-by-numComponents
% coeff: C-by-numComponents transformation matrix
% var: variance retained per component (%), length = numComponents
%   Total variance retained = sum(var), NOT sum(var(1:n))/sum(var)*100
% For multicube data, convert first:
%   hcube = imhypercube(im2double(gather(mcube)), mcube.Wavelength)
%   Use im2double to avoid NaN variance from integer (uint16) data
%   Ensure cropped region contains valid (non-zero) pixels — nodata regions cause NaN

% Maximum Noise Fraction (MNF) transform — HYPERCUBE ONLY (fails on multicube)
[outputDataCube, coeff] = hypermnf(inputData, numComponents)
[outputDataCube, coeff] = hypermnf(inputData, numComponents, MeanCentered=true)
% Ordered by decreasing image quality (signal-to-noise)
% inputData: hypercube object or M-by-N-by-C array — NOT multicube

% Inverse projection (reconstruct from PCA/MNF)
% WARNING: argument order is (dataCube, coeff) — NOT (coeff, dataCube)
reconstructedData = inverseProjection(pcDataCube, coeff)
% pcDataCube: M-by-N-by-P transformed cube (FIRST argument)
% coeff: C-by-P coefficient matrix from hyperpca or hypermnf (SECOND argument)
% Returns: M-by-N-by-C reconstructed data
```

## Spectral Unmixing

**ALL unmixing functions are HYPERCUBE ONLY — they fail on multicube objects.**
For multicube data, convert first: `hcube = imhypercube(gather(mcube), mcube.Wavelength)`

```matlab
% Count endmembers using HFC/NWHFC (HYPERCUBE ONLY)
numEndmembers = countEndmembersHFC(inputData)
numEndmembers = countEndmembersHFC(inputData, PFA=1e-3)          % probability of false alarm (default: 1e-3)
numEndmembers = countEndmembersHFC(inputData, NoiseWhiten=true)  % NWHFC (default: true)

% Extract endmembers - N-FINDR (HYPERCUBE ONLY)
endmembers = nfindr(inputData, numEndmembers)
endmembers = nfindr(inputData, numEndmembers, NumIterations=15)         % default: 3*numEndmembers
endmembers = nfindr(inputData, numEndmembers, ReductionMethod="MNF")    % "MNF" (default) or "PCA"
% Returns: C-by-numEndmembers matrix

% Extract endmembers - Pixel Purity Index (PPI) (HYPERCUBE ONLY)
endmembers = ppi(inputData, numEndmembers)
endmembers = ppi(inputData, numEndmembers, NumVectors=10000)            % skewers (default: 10000)
endmembers = ppi(inputData, numEndmembers, ReductionMethod="MNF")       % "MNF","PCA","None"

% Extract endmembers - Fast Iterative PPI (FIPPI) (HYPERCUBE ONLY)
endmembers = fippi(inputData, numEndmembers)
endmembers = fippi(inputData, numEndmembers, ReductionMethod="MNF")     % "MNF" (default) or "PCA"

% Estimate abundance maps
abundanceMap = estimateAbundanceLS(inputData, endmembers)
abundanceMap = estimateAbundanceLS(inputData, endmembers, Method="ucls")  % unconstrained (default)
abundanceMap = estimateAbundanceLS(inputData, endmembers, Method="ncls")  % nonnegative constrained
abundanceMap = estimateAbundanceLS(inputData, endmembers, Method="fcls")  % fully constrained
% endmembers: C-by-P matrix
% abundanceMap: M-by-N-by-P double (proportion of each endmember per pixel; output always double regardless of input type)
```

## Spectral Matching and Similarity

**ALL similarity functions are HYPERCUBE ONLY — they fail on multicube objects.**
For multicube data, convert first: `hcube = imhypercube(gather(mcube), mcube.Wavelength)`

**IMPORTANT: `refSpectra` must be a C-element VECTOR (not a matrix).** To compare against multiple references, call the function once per reference spectrum in a loop, or use `spectralMatch(libData, hcube)` for library-based matching.

```matlab
% Spectral Angle Mapper (SAM) - angle in radians [0, pi] (HYPERCUBE ONLY)
score = sam(inputData, refSpectra)       % inputData: hypercube or M-by-N-by-C array; refSpectra: C-element vector; returns M-by-N
score = sam(testSpectra, refSpectra)     % two C-element vectors, returns scalar

% Spectral Information Divergence (SID) (HYPERCUBE ONLY)
score = sid(inputData, refSpectra)
score = sid(testSpectra, refSpectra)

% SID-SAM hybrid (HYPERCUBE ONLY)
score = sidsam(inputData, refSpectra)
score = sidsam(testSpectra, refSpectra)

% Jeffries-Matusita SAM (JMSAM) (HYPERCUBE ONLY)
score = jmsam(inputData, refSpectra)
score = jmsam(testSpectra, refSpectra)

% Normalized Spectral Similarity Score (NS3) (HYPERCUBE ONLY)
score = ns3(inputData, refSpectra)
score = ns3(testSpectra, refSpectra)
% All: lower score = stronger match

% Spectral matching with library
% WARNING: libData MUST be a struct (from readEcostressSig), NOT a numeric array.
% For numeric target comparison, use sam()/sid()/sidsam()/jmsam()/ns3() directly.
score = spectralMatch(libData, hcube)
score = spectralMatch(libData, reflectance, wavelength)
score = spectralMatch(libData, hcube, Method="sam")          % "sam"(default),"sid","sidsam","jmsam","ns3"
score = spectralMatch(libData, hcube, MinBandWidth=300)      % min overlap bandwidth in nm (default: 300)
% libData: struct from readEcostressSig with Reflectance and Wavelength fields (NOT a numeric vector)
% score: M-by-N-by-K when K library entries passed (one score map per signature)

% Read ECOSTRESS spectral library
libData = readEcostressSig(filenames)             % specific files
libData = readEcostressSig(dirname)               % all files in directory
libData = readEcostressSig(dirname, keyword)      % filter by keyword
% Returns: 1-by-K struct array with Reflectance, Wavelength, and 24 metadata fields

% Resample signature to match target wavelengths (Since R2024a)
resampledRef = resampleSignature(reflectance, reqWavelength)
resampledRef = resampleSignature(reflectance, reqWavelength, origWavelength)
[resampledRef, commonWL, index] = resampleSignature(reflectance, reqWavelength)
% reflectance: struct (from readEcostressSig with Reflectance+Wavelength fields) or numeric vector
% reqWavelength: target wavelength vector (nm or um, must match units of reflectance)
% origWavelength: required when reflectance is numeric vector (length must match)
% commonWL: wavelengths present in both spectra; index: [start end] indices within reqWavelength
% NOTE: output may have FEWER bands than reqWavelength if library range doesn't cover all target wavelengths

% Remove continuum (normalize spectral signature) — WORKS WITH BOTH hypercube AND multicube
continuumRemovedRef = removeContinuum(reflectance)
continuumRemovedRef = removeContinuum(reflectance, wavelength)
continuumRemovedRef = removeContinuum(reflectance, Method="division")    % "division"(default) or "subtraction"
% reflectance: struct, hypercube, multicube, numeric vector, or 3-D array
% wavelength: required when reflectance is numeric vector or 3-D array (must match spectral dimension length)
% For multicube: all bands must have uniform resolution
% Tip: "division" works best with SAM matching; "subtraction" works best with SID/SIDSAM
```

## Target and Anomaly Detection

```matlab
% Anomaly detection using Reed-Xiaoli (RX) detector — HYPERCUBE ONLY (fails on multicube)
rxScore = anomalyRX(inputData)
% inputData: hypercube object or M-by-N-by-C array — NOT multicube
% rxScore: M-by-N matrix (higher = more anomalous, uses Mahalanobis distance)

% Target detection (multiple algorithms)
score = detectTarget(spcube, target, method)
score = detectTarget(spcube, target, method, numEndmember=5)
% spcube: hypercube, multicube, or 3-D array (must be 3-D, not 2-D)
% target: C-element single or double vector (must match number of bands in spcube exactly)
% method: "CEM" | "ACE" | "SignedACE" | "MF" | "GLRT" | "AMSD" | "OSP"
% numEndmember: for AMSD and OSP only (warns if used with other methods)
% score: M-by-N double matrix (higher = higher probability of target; always double output)
```

## Spectral Indices

```matlab
% Compute standard indices
indices = spectralIndices(spcube)                            % all applicable indices
indices = spectralIndices(spcube, indexNames)                % specific indices
indices = spectralIndices(spcube, "all")                     % all supported
indices = spectralIndices(spcube, indexNames, BlockSize=[rows cols])
% Broadband (hyperspectral + multispectral): "NDVI","EVI","NDBI","NBR","MNDWI","MSI","GVI","OSAVI","SR","CMR"
% Narrowband (hyperspectral only): "MCARI","MTVI","PRI","NDNI","NDMI","CAI"
% Returns: struct (single index) or 1-by-K struct array (multiple indices)
%   Each struct has fields: .IndexName (string) and .IndexImage (M-by-N numeric)
%   Access the image data via: indices.IndexImage or indices(k).IndexImage
% Default (no indexNames): returns only EVI, MCARI, SR — use "all" for full set
% Tip: For direct numeric NDVI output (not struct), use ndvi(spcube) instead

% NDVI specifically
output = ndvi(spcube)
output = ndvi(spcube, BlockSize=[rows cols])
% output: M-by-N matrix, range [-1, 1]. Formula: (NIR_800nm - R_670nm) / (NIR_800nm + R_670nm)

% Custom spectral index
indexImage = customSpectralIndex(spcube, wavelengths, func)
indexImage = customSpectralIndex(spcube, wavelengths, func, BlockSize=[rows cols])
% wavelengths: numeric vector of wavelengths to extract (nm)
% func: function handle, e.g., @(b1,b2) (b1-b2)./(b1+b2)
% Example:
indexImage = customSpectralIndex(hcube, [800 670], @(nir,red) (nir-red)./(nir+red));
```

## Segmentation

```matlab
% Fast spectral clustering with anchor graphs (Since R2024a) — WORKS WITH BOTH hypercube AND multicube
L = hyperseganchor(spcube, K)
L = hyperseganchor(spcube, K, NumAnchor=5)         % anchor points (generates 2*NumAnchor anchors)
L = hyperseganchor(spcube, K, NumNeighbor=5)       % neighbors per pixel
L = hyperseganchor(spcube, K, NumAttempts=3)       % clustering repetitions
L = hyperseganchor(spcube, K, MaxIterations=100)
L = hyperseganchor(spcube, K, Threshold=1e-4)      % convergence threshold
% spcube: hypercube, multicube, or M-by-N-by-C array
% K: number of clusters. Constraint: K <= 2*NumAnchor, M*N >= 2*NumAnchor, NumNeighbor <= 2*NumAnchor-1
% L: M-by-N label matrix (uint8 if K<=255, uint16 if K<=65535, uint32 if K<=2^32-1, double otherwise)
% Also accepts M-by-N 2-D array (single band) as input

% Superpixel oversegmentation (Since R2023b) — HYPERCUBE ONLY (fails on multicube)
[L, numLabels] = hyperslic(hcube, K)
[L, numLabels] = hyperslic(hcube, K, NumIterations=10)           % max 30
[L, numLabels] = hyperslic(hcube, K, IsInputDimReduced=false)    % set true if already reduced to 3 bands
% hcube: hypercube object or M-by-N-by-C array (min 3 bands) — NOT multicube
% K: desired number of superpixels
% L: M-by-N label matrix; numLabels: actual superpixel count
% Tip: set IsInputDimReduced=true when input is already PCA-reduced to 3 bands

% ISODATA unsupervised classification (Since R2024b; multicube support Since R2025a) — WORKS WITH BOTH
[L, C] = imsegisodata(inputData)
[L, C] = imsegisodata(inputData, InitialNumClusters=5)
[L, C] = imsegisodata(inputData, MaxIterations=10)             % default: 10
[L, C] = imsegisodata(inputData, MaxStandardDeviation=2)
[L, C] = imsegisodata(inputData, MinNumPixelsPerCluster=10)
[L, C] = imsegisodata(inputData, MinSamples=1)                 % min pixels per cluster before discard
[L, C] = imsegisodata(inputData, MinClusterSeparation=1)       % min distance to avoid merging
[L, C] = imsegisodata(inputData, MaxPairsToMerge=2)            % max cluster pairs merged per iteration
[L, C] = imsegisodata(inputData, NormalizeInput=true)          % normalize features (default: true)
% inputData: hypercube, multicube, 2-D grayscale, RGB, or M-by-N-by-C array
% L: M-by-N label matrix; C: K-by-C cluster centers
% Automatically determines optimal cluster count via split/merge iterations
% Tip: pass informative bands (via selectBands with endmember signatures) for better results
```

## Hyperspectral Viewer App

```matlab
% Launch viewer
hyperspectralViewer                         % open empty
hyperspectralViewer(spcube)                 % load hypercube or multicube
hyperspectralViewer(spcube, resolution)     % multicube with specific resolution (Since R2025a)
hyperspectralViewer(cube)                   % load 3-D array (limited features)
hyperspectralViewer close                   % close all instances
```

## Key Rules

### Critical Constraints
- **`nfindr`**: `numEndmembers` must be > 1 and <= C (number of spectral bands)
- **`hyperseganchor`**: K (clusters) <= 2*NumAnchor; M*N (pixels) >= 2*NumAnchor; NumNeighbor <= 2*NumAnchor-1
- **`hyperslic`**: Minimum 3 spectral bands required; if exactly 3 bands, must set `IsInputDimReduced=true`; K must not exceed total pixel count (M*N); max 30 iterations
- **`spectralIndices`** with no arguments: returns only EVI, MCARI, SR (not all indices) — pass `"all"` for full set
- **`detectTarget`**: target vector must have exactly C elements (same as datacube bands), must be single or double; input must be 3-D; output is always double
- **`removeContinuum`**: Use `"division"` with SAM-based matching; use `"subtraction"` with SID/SIDSAM

### Endmember & Unmixing
- `nfindr` (fast, reliable), `ppi` (robust, 10000 skewers default), `fippi` (fastest iterative)
- `fippi` may return more endmembers than requested (iterative algorithm finds at least numEndmembers)
- All extraction methods support `ReductionMethod`: `"MNF"` (default) or `"PCA"`
- Abundance: `"fcls"` (sum-to-one + non-negative), `"ncls"` (non-negative only), `"ucls"` (unconstrained, default)

### Target/Anomaly Detection
- `detectTarget` methods: `"CEM"`, `"ACE"`, `"SignedACE"`, `"MF"`, `"GLRT"`, `"AMSD"`, `"OSP"`
- `"AMSD"` and `"OSP"` require `numEndmember` parameter (default: 5)
- `anomalyRX`: higher score = more anomalous (Mahalanobis distance from background)
- `detectTarget` scores: **higher = more likely target**; similarity scores: **lower = better match**
- SAM: insensitive to illumination (shape); SID: good for mixed pixels; JMSAM: discriminates spectrally close targets

### Parallelism Restrictions
- These functions do NOT support `parfor`: `sam`, `sid`, `jmsam`, `ns3`, `spectralMatch`

----

Copyright 2026 The MathWorks, Inc.
