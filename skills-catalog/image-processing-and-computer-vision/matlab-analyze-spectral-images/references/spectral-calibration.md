# Spectral Calibration & Correction Reference

Radiometric calibration, atmospheric correction, spectral correction, and filtering/enhancement using the Hyperspectral Imaging Library for Image Processing Toolbox.

**Requirement:** Desktop MATLAB only (not MATLAB Online or MATLAB Mobile). Requires the Hyperspectral Imaging Library add-on for Image Processing Toolbox.

## Radiometric Calibration

```matlab
% Convert digital number to radiance (requires Gain/Offset in Metadata)
newspcube = dn2radiance(spcube)
newspcube = dn2radiance(spcube, BlockSize=[rows cols])

% Convert digital number to reflectance (requires reflectance gain in Metadata)
newspcube = dn2reflectance(spcube)
newspcube = dn2reflectance(spcube, BlockSize=[rows cols])

% Convert radiance to reflectance (TOA reflectance)
newspcube = radiance2Reflectance(spcube)
newspcube = radiance2Reflectance(spcube, BlockSize=[rows cols])
```
- Input: `hypercube` or `multicube` object
- For `multicube`, all bands must have uniform resolution
- `BlockSize` enables memory-efficient processing of large datasets
- **Metadata requirements:**
  - `dn2radiance`: requires non-empty `Gain` and `Offset` in Metadata
  - `dn2reflectance`: requires non-empty, non-NaN `ReflectanceGain` in Metadata
  - `radiance2Reflectance`: requires floating-point input (single/double, NOT uint16 — call AFTER `dn2radiance`), plus `SunElevation` and `SolarIrradiance` in Metadata
- **L2 products (Landsat L2SP, Sentinel-2 L2A) are already surface reflectance** — this pipeline is for L1 (raw/TOA) data only
- Research datasets (Indian Pines, PaviaU, Jasper Ridge) typically lack calibration metadata — these functions will fail on them

## Atmospheric Correction

```matlab
% Out-of-band correction using sensor spectral response
[newspcube, oobEffect] = correctOOB(spcube, spectralResponse)
[newspcube, oobEffect] = correctOOB(spcube, spectralResponse, RegionMask=mask)
newspcube = correctOOB(spcube, spectralResponse, BlockSize=[rows cols])
% spectralResponse: K-by-(C+1) matrix, first col = wavelength (1nm resolution, must be positive integers)
% The wavelength column values are used as array indices — they MUST be positive integers
% mask: M-by-N logical, 1 = homogeneous region
% Works with both hypercube and multicube. Wavelength range in spectralResponse must cover the cube's full range.

% Empirical line calibration (hypercube only)
newhcube = empiricalLine(hcube, imgSpectra, fieldSpectra, fieldWL)
% imgSpectra: N-by-1 cell array, each cell = C-by-1 vector (image spectra at calibration targets)
% fieldSpectra: N-by-1 cell array, each cell = field reflectance vector
% fieldWL: N-by-1 cell array, each cell = wavelength vector for field spectra (nm)

% Fast in-scene atmospheric correction (input should be TOA reflectance)
newspcube = fastInScene(spcube)
% Returns surface reflectance values
% Works with both hypercube and multicube; no special metadata required

% Flat field correction
correctedData = flatField(inputData, roi)
% inputData: hypercube, multicube, or M-by-N-by-C array
% roi: [xmin ymin width height] defining homogeneous region
% ROI must fit within image bounds AND the ROI region must not contain dark/zero pixels
% (error: "Mean spectra contains dark pixels" if ROI has zeros)

% Internal average relative reflectance (IARR)
correctedData = iarr(inputData)
% Divides each pixel spectrum by the scene mean spectrum

% Log residual correction
correctedData = logResiduals(inputData)
% Divides by spectral and spatial geometric means to get pseudoreflectance

% Remote sensing reflectance (for water scenes — best results with multispectral data)
[newspcube, mask] = rrs(spcube)
% Input must be TOA radiance; returns remote sensing reflectance
% mask: binary matrix indicating clear water regions
% Required metadata: SunElevation, SunAzimuth, EarthSunDistance, SensorLookAngle, SatelliteAzimuthAngle
% Required bands: Blue (~440-480nm), Green (~550nm), Red (~655nm), SWIR (~2200nm)
% Input must be 3-D, no NaN/Inf values
% Works with Sentinel-2 (has all required metadata). Landsat may fail if SensorLookAngle is missing.
% Research datasets (Indian Pines, PaviaU) will fail — no satellite metadata.

% SHARC atmospheric correction (hypercube only)
newhcube = sharc(hcube)
newhcube = sharc(hcube, AtmosphericModel="1962 US Standard")  % default
% Models: "Tropical","Midlatitude Summer","Midlatitude Winter","Subarctic Summer","Subarctic Winter"
newhcube = sharc(hcube, DarkPixelLocation=[x y])              % specify dark pixel
newhcube = sharc(hcube, AdjacencyWindow=5)                    % window size (default: 5)
% Input must be TOA radiance or reflectance with full sensor metadata:
%   SolarIrradiance, SunElevation, SunAzimuth, SensorLookAngle,
%   WaterVapourAbsorption, OxygenAbsorption, OzoneAbsorption
% Must contain blue-green bands (440-600nm); input must be 3-D
% Will FAIL on research datasets (no SolarIrradiance) and on multicube objects.
% Designed for raw airborne/satellite hyperspectral sensors with full calibration metadata.

% Dark pixel subtraction
correctedData = subtractDarkPixel(inputData)                   % auto-detect dark pixels
correctedData = subtractDarkPixel(inputData, darkPixels)       % specify values to subtract
correctedData = subtractDarkPixel(inputData, BlockSize=[rows cols])
% darkPixels: scalar, C-element vector, 2-D or 3-D array
```

## Spectral Correction

```matlab
% Reduce spectral smile effect (HYPERCUBE ONLY — fails on multicube)
correctedData = reduceSmile(hcube)
correctedData = reduceSmile(hcube, Method="SpectralSmoothing")  % default (no FWHM needed)
correctedData = reduceSmile(hcube, Method="MNF")                % requires FWHM in Metadata
correctedData = reduceSmile(hcube, SpectralWindow=3)            % window size (default: 3, max recommended: 9)
correctedData = reduceSmile(hcube, BlockSize=[rows cols])

% Compute smile metrics (HYPERCUBE ONLY — requires FWHM in Metadata + O2/CO2 absorption bands)
[oxystd, carbonstd, oxyderiv, carbonderiv] = smileMetric(hcube)
% oxystd/carbonstd: scalar std deviation (lower = less smile)
% oxyderiv/carbonderiv: N-element row vectors of column derivatives
% Needs VNIR (760-785nm) for oxygen, SWIR (2010-2025nm) for carbon
% Will FAIL on research datasets (Indian Pines, PaviaU) that lack FWHM in Metadata
```

## Filtering and Enhancement

```matlab
% Denoise using non-local meets global (NGMeet) — HYPERCUBE ONLY (fails on multicube)
outputData = denoiseNGMeet(inputData)
outputData = denoiseNGMeet(inputData, Sigma=sigma)            % default: 0.1*noise_variance
outputData = denoiseNGMeet(inputData, SpectralSubspace=6)     % low-rank bands (default: 6)
outputData = denoiseNGMeet(inputData, NumIterations=2)        % iterations (default: 2)
% inputData: hypercube object or M-by-N-by-C array (M,N > 16) — NOT multicube
% Output: hypercube if input is hypercube; M-by-N-by-C array if input is array
% Constraint: SpectralSubspace + 2*(NumIterations-1) <= C
% For large images (Landsat 7000x7000, Sentinel-2 10980x10980): crop first to avoid memory crash

% Sharpen using coupled nonnegative matrix factorization (CNMF)
outputData = sharpencnmf(lrData, hrData)
outputData = sharpencnmf(lrData, hrData, MaxConvergenceIterations=25)
outputData = sharpencnmf(lrData, hrData, MaxOptimizationIterations=2)
outputData = sharpencnmf(lrData, hrData, ConvergenceThreshold=0.0001)
outputData = sharpencnmf(lrData, hrData, NumEndmembers=40)
% lrData: low-res hyperspectral — MUST be hypercube object or 3-D array (multicube FAILS)
% hrData: high-res multispectral/panchromatic (hypercube, multicube, 3-D array, or matrix)
% Output: spatial resolution of hrData, spectral bands of lrData
% Default NumEndmembers = min(40, countEndmembersHFC(lrData))
% lrData spatial dims MUST be smaller than hrData spatial dims
% lrData MUST have more spectral bands than hrData
```

## Key Rules

### Processing Pipeline
- Radiometric calibration order: DN -> radiance -> reflectance -> atmospheric correction
- Apply smile correction BEFORE denoising (reduce spectral artifacts first, then spatial noise)
- For `multicube`, ensure uniform resolution before processing (use `selectBands` with `DataResolution`)
- `BlockSize` parameter available on calibration/correction functions for memory-efficient large data processing

### Atmospheric Correction Selection
| Method | Supported Input Types | Input Required | Best For |
|--------|----------------------|---------------|----------|
| `sharc` | hypercube ONLY | TOA radiance/reflectance + gaseous absorption metadata | Physics-based, known atmosphere |
| `empiricalLine` | hypercube ONLY | Min 2 calibration targets | Ground-truthed calibration |
| `fastInScene` | hypercube, multicube | TOA reflectance | Quick in-scene, no external data |
| `correctOOB` | hypercube, multicube | Sensor spectral response matrix | Out-of-band correction |
| `rrs` | hypercube, multicube | TOA radiance | Water/ocean scenes (best for multispectral) |
| `flatField` | hypercube, multicube, numeric array | Homogeneous ROI [xmin ymin w h] | Relative correction |
| `iarr` | hypercube, multicube, numeric array | None | Scene-average normalization |
| `logResiduals` | hypercube, multicube, numeric array | None | Log residual pseudoreflectance |
| `subtractDarkPixel` | hypercube, multicube, numeric array | None (auto) or dark values | Simple baseline removal |

### Critical Constraints
- **`denoiseNGMeet`**: Spatial dims must be > 16; constraint: `SpectralSubspace + 2*(NumIterations-1) <= C` (number of bands)
- **`sharpencnmf`**: Low-res spatial dims < high-res spatial dims; low-res bands > high-res bands
- **`empiricalLine`**: Accepts 1 or more calibration targets; 2+ targets recommended for robust linear fit
- **`smileMetric`**: Requires FWHM in metadata; needs VNIR (760-785 nm) for oxygen, SWIR (2010-2025 nm) for carbon
- **`correctOOB`**: spectralResponse must be at 1 nm wavelength resolution, K-by-(C+1) format; wavelength range must cover the cube's full range; input must not contain NaN/Inf; supports multicube

### Parallelism Restrictions
- These functions do NOT support `parfor`: `fastInScene`, `sharc`

----

Copyright 2026 The MathWorks, Inc.
