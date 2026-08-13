# Spectral Image I/O Reference

Reading, writing, and preparing hyperspectral/multispectral data using the Hyperspectral Imaging Library for Image Processing Toolbox.

**Requirement:** Desktop MATLAB only (not MATLAB Online or MATLAB Mobile). Requires the Hyperspectral Imaging Library add-on for Image Processing Toolbox.

**CRITICAL:** NEVER use the deprecated `hypercube()` constructor directly. It will be removed in a future release. Always use `imhypercube`, `geohypercube`, `immulticube`, or `geomulticube` instead.

## Core Objects

Two object types: `hypercube` (hyperspectral, uniform bands) and `multicube` (multispectral, variable resolution bands).

**Choosing the right creation function:**
| Data Type | No Geospatial | With Geospatial (needs Mapping Toolbox) |
|-----------|---------------|----------------------------------------|
| Hyperspectral (many narrow bands) | `imhypercube` | `geohypercube` |
| Multispectral (few broad bands) | `immulticube` | `geomulticube` |

**File format support:**
| Format | `imhypercube`/`geohypercube` | `immulticube`/`geomulticube` |
|--------|------------------------------|------------------------------|
| ENVI (.dat, .hdr, .bsq, .bil, .bip) | Yes | **No** |
| NITF (.ntf) | Yes | No |
| EO-1 Hyperion (.L1R) | Yes | No |
| Landsat/GeoTIFF MTL (.txt) | Yes | Yes |
| Multipage TIFF (.tif) | Yes | Yes |
| TIFF folder (directory of .tif files) | No | Yes |
| ASTER HDF (.hdf) | No | Yes |
| Sentinel-2 (.safe) | No | Yes |

### Reading Hyperspectral Data

```matlab
% WITHOUT geospatial info (returns hypercube object)
hcube = imhypercube(file)                          % from ENVI, NITF, Hyperion, GeoTIFF, multipage TIFF, Landsat MTL
hcube = imhypercube(file, wavelength)              % specify wavelengths
hcube = imhypercube(image, wavelength)             % from M-by-N-by-C numeric array
hcube = imhypercube(image, wavelength, metadata)   % with metadata struct
hcube = imhypercube(image)                         % array without wavelengths
hcube = imhypercube(___, BlockSize=blockSize)      % control memory via block size

% WITH geospatial info (requires Mapping Toolbox)
hcube = geohypercube(file)
hcube = geohypercube(file, wavelength)
hcube = geohypercube(image, wavelength)
hcube = geohypercube(image, wavelength, metadata)  % metadata must have RasterReference field
hcube = geohypercube(image)
hcube = geohypercube(___, BlockSize=blockSize)
```

### Reading Multispectral Data

```matlab
% WITHOUT geospatial info (returns multicube object)
mcube = immulticube(file)                          % from Landsat MTL .txt, multipage TIFF, ASTER .hdf, Sentinel-2 .safe, or TIFF folder path
mcube = immulticube(file, wavelength)
mcube = immulticube(image, wavelength)
mcube = immulticube(image, wavelength, metadata)
mcube = immulticube(image)
mcube = immulticube(___, BlockSize=blockSize)

% WITH geospatial info (requires Mapping Toolbox)
mcube = geomulticube(file)
mcube = geomulticube(file, wavelength)
mcube = geomulticube(image, wavelength)
mcube = geomulticube(image, wavelength, metadata)  % metadata must have RasterReference field
mcube = geomulticube(image)
mcube = geomulticube(___, BlockSize=blockSize)
```

### Object Properties

**hypercube properties (class: `hyper.io.hypercube`):**
| Property | Description |
|----------|-------------|
| `ImageDims` | Dimensions and data type string, e.g. `"[610x340x103 double]"` (Since R2025a) |
| `Wavelength` | C-element vector of center wavelengths (nm) |
| `Metadata` | Struct with fields: `Height`, `Width`, `Bands`, `DataType`, `Interleave`, `HeaderOffset`, `ByteOrder`, `WavelengthUnits`, `AcquisitionTime`, `RasterReference` |
| `BlockSize` | 2-element vector [rows cols] for block processing |

**IMPORTANT:** There are NO `NumRows`, `NumColumns`, `NumBands`, or `DataCube` properties. Access dimensions via `Metadata.Height`, `Metadata.Width`, `Metadata.Bands`. The `DataCube` property was removed in R2025a — use `gather(hcube)` instead.

**multicube properties:**
| Property | Description |
|----------|-------------|
| `ImageFiles` | File references |
| `BandSize` | Dimensions of each band |
| `Wavelength` | Center wavelengths per band |
| `Metadata` | Associated metadata struct |
| `BandResolution` | Resolution per band |
| `BlockSize` | 2-element vector [rows cols] |

## Writing Data

```matlab
% Write to ENVI format (.dat + .hdr) — HYPERCUBE ONLY
% Use for hyperspectral data (many narrow bands). NOT for multispectral satellite data (Landsat, Sentinel-2).
% Multispectral satellite data should remain in its native format (GeoTIFF, etc.)
enviwrite(hcube, filename)
enviwrite(hcube, filename, Interleave="bsq")       % "bsq" (default), "bil", or "bip"
enviwrite(hcube, filename, DataType="single")      % "uint8","uint16","uint32","uint64","int16","int32","int64","single","double"
enviwrite(hcube, filename, ByteOrder="ieee-le")    % "ieee-le" or "ieee-be"
enviwrite(hcube, filename, HeaderOffset=0)         % bytes before data start
```

## Reading ENVI Metadata

```matlab
info = enviinfo(file)   % file is .hdr path
% Returns struct with fields:
%   Required: Height, Width, Bands, DataType, Interleave, HeaderOffset, ByteOrder
%   Optional: Wavelength, FWHM, Gain, Offset, BadBands, BandNames, MapInfo
%   File info: Filename, FileModDate, FileSize, Format, RasterFormat
% Supports .hdr, .dat, .bsq, .bil, .bip, .img extensions
```

## Gathering Data Into Workspace

```matlab
% Read full data cube into memory (Since R2025a)
dataCube = gather(hcube)    % returns M-by-N-by-C numeric array
dataCube = gather(mcube)    % for multicube
```

## ROI Selection

```matlab
% Assign new data to specific locations
newspcube = assignData(spcube, row, column, band, data)
% row, column, band: positive integer scalars or vectors
% data: must match dimensions of indexed region

% Crop region of interest
newspcube = cropData(spcube, row, column)           % crop spatial region (all bands)
newspcube = cropData(spcube, row, column, band)     % crop spatial + spectral (hypercube only)
% row, column, band: vectors of indices, e.g., 1:100
```

## Band Selection, Removal, and Resampling

```matlab
% Select bands by wavelength range (hypercube only)
newhcube = selectBands(hcube, Wavelength=[minWL maxWL])

% Select bands by index (hypercube and multicube)
newspcube = selectBands(spcube, BandNumber=bands)

% Select bands by resolution (multicube only)
newmcube = selectBands(mcube, DataResolution=resolution)

% Select most informative bands for endmember discrimination (hypercube only)
[newhcube, bandIdx] = selectBands(hcube, endmembers)                    % endmembers: C-by-K matrix
[newhcube, bandIdx] = selectBands(hcube, endmembers, NumberOfBands=n)   % specify count

% Remove bands by wavelength range (hypercube only)
newhcube = removeBands(hcube, Wavelength=[Wmin1 Wmax1; Wmin2 Wmax2])  % K-by-2 matrix

% Remove bands by index (hypercube only)
newhcube = removeBands(hcube, BandNumber=band)

% Resample multicube bands to uniform resolution (Since R2025a)
newmcube = resampleBands(mcube, resolution)
newmcube = resampleBands(mcube, resolution, Method="nearest")   % "nearest" (default), "bilinear", or "cubic"
```

## Color Transformation

```matlab
% For hypercube: supports Method parameter, 2 outputs, ContrastStretching defaults to FALSE
coloredImage = colorize(hcube)                                   % default: false-colored (3 most informative bands via selectBands)
coloredImage = colorize(hcube, band)                             % specify 3 band indices (false color composite)
[coloredImage, indices] = colorize(hcube)                        % also return selected band indices (2 outputs)
coloredImage = colorize(hcube, Method="rgb")                     % true color (R:600-700, G:500-600, B:400-500 nm)
coloredImage = colorize(hcube, Method="cir")                     % color infrared (NIR:760-960, R, G)
coloredImage = colorize(hcube, Method="falsecolored")            % default method
coloredImage = colorize(hcube, ContrastStretching=true)          % apply CLAHE (default: false)

% For multicube: NO Method parameter, 1 output only, ContrastStretching defaults to TRUE
% WARNING: colorize(mcube, Method="rgb") will ERROR — Method is NOT supported for multicube
coloredImage = colorize(mcube)                                   % TRUE RGB (auto-selects R,G,B bands by wavelength)
coloredImage = colorize(mcube, band)                             % false color composite from 3 band indices
coloredImage = colorize(mcube, ContrastStretching=false)         % disable contrast stretching (default: true)

% KEY DIFFERENCES:
% | Feature              | hypercube                     | multicube                          |
% |----------------------|-------------------------------|------------------------------------|
% | Default behavior     | false-colored (informative)   | true RGB (by wavelength)           |
% | Method parameter     | "rgb","cir","falsecolored"    | NOT supported                      |
% | ContrastStretching   | default FALSE (CLAHE)         | default TRUE (imadjust)            |
% | Number of outputs    | [img, indices]                | img only                           |
%
% For multicube RGB: colorize(mcube) already gives RGB! No need to specify band indices.
% For custom band composite: colorize(mcube, [bandR bandG bandB])
% Landsat 4-5 TM bands: Band 3=Red, Band 2=Green, Band 1=Blue
% Landsat 8 OLI bands:  Band 4=Red, Band 3=Green, Band 2=Blue
```

## Block Processing (Since R2025a)

```matlab
% Apply function to each block of a large spectral image
outputCube = apply(spcube, fcn)
outputCube = apply(spcube, fcn, BlockSize=[rows cols])
% fcn: function handle that receives a hypercube/multicube block object
% Use gather(block) inside fcn to get the numeric M-by-N-by-C array
% The function is applied to each spatial block independently
% Enables out-of-memory processing for large datasets

% Example: normalize spectra block-by-block
result = apply(hcube, @(block) gather(block) ./ max(vecnorm(gather(block), 2, 3), eps));
```

## Common Workflows

### Workflow 1: Load and inspect ENVI file
```matlab
info = enviinfo("scene.hdr");
hcube = imhypercube("scene.hdr");
disp(hcube.ImageDims)
disp(hcube.Wavelength)
rgb = colorize(hcube, Method="rgb");
imshow(rgb)
```

### Workflow 2: Load large file with blocked processing
```matlab
hcube = imhypercube("large_scene.hdr", BlockSize=[512 512]);
% Process block-by-block without loading entire cube
% fcn receives a hypercube block — use gather(block) to get numeric array
result = apply(hcube, @(block) myProcessingFcn(gather(block)));
```

### Workflow 3: Load Sentinel-2 multispectral data
```matlab
mcube = immulticube("path/to/scene.SAFE/manifest.safe");
% Select specific resolution bands
mcube10m = selectBands(mcube, DataResolution=10);
rgb = colorize(mcube10m);  % multicube does not support Method param
imshow(rgb)
```

### Workflow 4: Crop and export subset
```matlab
hcube = imhypercube("scene.hdr");
% Crop spatial ROI and select VNIR bands
cropped = cropData(hcube, 100:500, 200:600, 1:100);
% Remove noisy bands
cropped = removeBands(cropped, Wavelength=[1350 1450; 1800 1950]);
enviwrite(cropped, "subset_scene")
```

### Workflow 5: Create hypercube from numeric array
```matlab
data = rand(256, 256, 224, 'single');
wavelength = linspace(400, 2500, 224);
metadata.WavelengthUnits = "Nanometers";
hcube = imhypercube(data, wavelength, metadata);
```

### Workflow 6: Load Landsat data via MTL file and get RGB
```matlab
% Landsat scenes use MTL text files that reference TIFF band files
mcube = immulticube("LC08_L1TP_MTL.txt");

% Get RGB — colorize(mcube) automatically selects R,G,B bands by wavelength
% NOTE: Do NOT use Method="rgb" — that is hypercube-only and will ERROR on multicube
rgb = colorize(mcube);         % true RGB with contrast stretching (default)
imshow(rgb)

% Without contrast stretching:
rgb = colorize(mcube, ContrastStretching=false);

% Custom false-color composite using specific band indices:
% Landsat 8 OLI: Band 4=Red, Band 3=Green, Band 2=Blue
falseColor = colorize(mcube, [5 4 3]);   % NIR, Red, Green false color
```

### Workflow 7: Resample multicube to uniform resolution
```matlab
% Load multispectral data with mixed resolutions (requires SpacecraftID in metadata)
mcube = immulticube("path/to/scene.SAFE/manifest.safe");
% Resample all bands to 10m resolution
mcube10m = resampleBands(mcube, 10);
% Now all bands have uniform spatial dimensions
dataCube = gather(mcube10m);
```

## Supported Formats

| Format | Function | File Extension |
|--------|----------|----------------|
| ENVI | `imhypercube` / `geohypercube` | `.hdr`, `.dat` |
| NITF | `imhypercube` / `geohypercube` | `.ntf`, `.nitf` |
| GeoTIFF | `imhypercube` / `immulticube` | `.tif`, `.tiff` |
| Multipage TIFF | `imhypercube` / `immulticube` | `.tif`, `.tiff` |
| ASTER HDF | `immulticube` / `geomulticube` | `.hdf` |
| Sentinel-2 | `immulticube` / `geomulticube` | `.safe` |
| Landsat (MTL) | `immulticube` / `geomulticube` | `*_MTL.txt` |
| ECOSTRESS (spectral library) | `readEcostressSig` | `.txt` (signature files, NOT satellite images) |
| Hyperion | `imhypercube` | `.hdr` |

Blocked I/O adapters (ENVI, NITF, ASTER, HDF, TIFF, Sentinel-2, Landsat MTL) are used internally when `BlockSize` is specified — no user action required beyond setting the parameter.

## Key Rules
- Use `imhypercube`/`immulticube` for data without geospatial info
- Use `geohypercube`/`geomulticube` when geospatial referencing is needed (requires Mapping Toolbox)
- `BlockSize` controls memory usage — default is [1024 1024]; read-only after creation (must recreate object to change)
- `gather` loads the full cube into memory — use only when RAM allows
- `apply` enables out-of-memory processing on blocked images; the function handle receives a hypercube/multicube block object — use `gather(block)` inside to get the numeric array (block is NOT numeric directly)
- `enviwrite` supports interleave formats: "bsq" (band sequential), "bil" (band interleaved by line), "bip" (band interleaved by pixel)
- `enviinfo` accepts extensionless files and multiple ENVI extensions (`.hdr`, `.dat`, `.bsq`, `.bil`, `.bip`, `.img`)
- `resampleBands` requires `SpacecraftID` in metadata — fails on multicubes created from numeric arrays; use `selectBands(mcube, DataResolution=res)` as alternative
- `resampleBands` supports interpolation methods: `"nearest"` (default), `"bilinear"`, `"cubic"`
- For `geohypercube`/`geomulticube`, the `RasterReference` in metadata is automatically updated when using `cropData`
- `colorize` with `ContrastStretching=true` applies adaptive histogram equalization (CLAHE) for enhanced visualization

### Multicube Limitations
- **`selectBands`**: only `DataResolution` and `BandNumber` — does NOT support `Wavelength` or endmember selection
- **`removeBands`**: NOT available for multicube — use `selectBands(mcube, BandNumber=...)` to keep desired bands
- **`cropData`**: spatial only (row, column) — does NOT accept band parameter; mixed-resolution bands will error
- **`colorize`**: does NOT support `Method` parameter (`"rgb"`, `"cir"`, `"falsecolored"` will ERROR). Default `colorize(mcube)` gives true RGB (auto-selects R/G/B by wavelength). Use band indices for custom composites: `colorize(mcube, [b1 b2 b3])`. ContrastStretching defaults to `true` (unlike hypercube which defaults to `false`)
- **`enviwrite`**: NOT available for multicube — ENVI format is for hyperspectral data only; multispectral satellite data (Landsat, Sentinel-2) should remain in native GeoTIFF format
- Must unify resolution before spatial operations: `selectBands(mcube, DataResolution=res)` or `resampleBands`

## Labeling (Since R2026a)

```matlab
% Create ground truth object for spectral images
gTruth = groundTruthSpectralImage(dataSource, labelDefs)
gTruth = groundTruthSpectralImage(dataSource, labelDefs, labelData)
gTruth = groundTruthSpectralImage(___, Resolution=resolution)

% dataSource: file path (string) or SpectralImageSource object
% labelDefs: table with REQUIRED columns:
%   LabelName (string), LabelColor (1x3 RGB), LabelID (integer),
%   LabelGroup (string), Description (string), AttributeList (cell)
% labelData: table with label mask data (optional)
% Properties: DataSource, LabelDefinitions (plural!), LabelData, Resolution

% Select labels by name or group
subGTruth = selectLabelsByName(gTruth, "Vegetation")
subGTruth = selectLabelsByGroup(gTruth, "Land")

% Merge multiple ground truth objects
mergedGTruth = merge(gTruth1, gTruth2)

% Change file paths (for relocating data — takes FOLDER paths, not file paths)
unresolvedPaths = changeFilePaths(gTruth, [oldFolder, newFolder])
% alternateFilePaths: n-by-2 string array of [oldFolder, newFolder] pairs
```

### Labeling Example
```matlab
% Create label definition table (all 6 columns required)
labelDefs = table( ...
    ["Vegetation";"Soil";"Water"], ...
    [0 1 0; 0.6 0.3 0; 0 0 1], ...
    [1;2;3], ...
    ["Land";"Land";"Water"], ...
    ["Veg areas";"Soil areas";"Water bodies"], ...
    {[];[];[]}, ...
    VariableNames=["LabelName","LabelColor","LabelID","LabelGroup","Description","AttributeList"]);
hdrFile = which("indian_pines.hdr");
gTruth = groundTruthSpectralImage(hdrFile, labelDefs);
landLabels = selectLabelsByGroup(gTruth, "Land");  % returns 2 labels
```

----

Copyright 2026 The MathWorks, Inc.
