# Spectral Image Deep Learning Reference

Ground truth labeling and deep learning workflows using the Hyperspectral Imaging Library for Image Processing Toolbox.

## Spectral Image Labeler App (Since R2026a)

```matlab
% Launch
spectralImageLabeler                    % new session
spectralImageLabeler(spcube)            % load hypercube or multicube object
spectralImageLabeler(cube)              % load 3-D numeric array (limited features)
spectralImageLabeler(gTruth)            % resume from existing groundTruthSpectralImage
spectralImageLabeler close              % close all instances
```

### App Workflow

1. **Load data** — from file (formats supported by `imhypercube`/`immulticube`/`geohypercube`/`geomulticube`), from workspace, or from MAT file containing `groundTruthSpectralImage`
2. **Visualize** — false color, RGB, CIR, or custom band composites; adjust brightness/contrast
3. **Define labels** — create label definitions with name, color, ID, group, description, and attributes (List, Numeric, String, Logical)
4. **Label manually** — draw polygon ROIs (click vertices, double-click to close); merge ROIs with Ctrl+select; erase portions
5. **Automate labeling** — select built-in or custom algorithm from Automate tab, configure parameters, run, review, undo if needed
6. **Export** — to workspace or MAT file as `groundTruthSpectralImage`; to TIF image file; to shapefile (if geospatial, requires Mapping Toolbox)

### Built-in Automation Algorithms

| Algorithm | Class Name | Type |
|-----------|-----------|------|
| K-means Clustering | `hyperspectral.labeler.KMeansAutomationAlgorithm` | Unsupervised |
| ISODATA Clustering | `hyperspectral.labeler.ISODATAAutomationAlgorithm` | Unsupervised |
| Anchor Graph Clustering | `hyperspectral.labeler.HyperseganchorAutomationAlgorithm` | Unsupervised |
| Spectral Indices | `hyperspectral.labeler.SpectralIndicesAutomationAlgorithm` | Signature-based |
| Spectral Match with ECOSTRESS | `hyperspectral.labeler.SpectralMatchWithEcostress` | Signature-based |

### Blocked Image Support

Large images that exceed memory can be imported as blocked images. Limitations: spectral signature visualization and automated labeling are unavailable for blocked images.

## Ground Truth Object (Since R2026a)

### Creating groundTruthSpectralImage

```matlab
gTruth = groundTruthSpectralImage(dataSource, labelDefs)
gTruth = groundTruthSpectralImage(dataSource, labelDefs, labelData)
gTruth = groundTruthSpectralImage(__, Resolution=resolution)
```

**Arguments:**
- `dataSource` — string/char file path (preferred) or `hyper.labeler.loading.SpectralImageSource` object
- `labelDefs` — table with ALL 6 required columns: `LabelName` (string), `LabelColor` (1x3, 0–1; use empty [] for auto-assigned), `LabelID` (integer 1–255; use 0 for auto-assigned), `LabelGroup` (string, e.g., "None"), `Description` (string), `AttributeList` (cell, use {} for no attributes). All columns must be present even if some values are empty.
- `labelData` — table where each column matches a label name; each cell contains a scalar struct with `ROI` (`polyshape`) and optional `ROIName` (char; auto-assigned if omitted); multiple ROIs per label use multiple rows in the table
- `Resolution` — positive integer for multicube band resampling

### AttributeList Column Format

Each attribute is a scalar struct. For multiple attributes per label, use cell indexing on the table column:

```matlab
% Numeric attribute
numAttr.AttributeType = "Numeric";
numAttr.AttributeName = "score";
numAttr.DefaultValue = 10;           % numeric scalar or []
numAttr.AttributeDescription = "";

% String attribute
strAttr.AttributeType = "String";
strAttr.AttributeName = "category";
strAttr.DefaultValue = "default";
strAttr.AttributeDescription = "";

% Logical attribute
logAttr.AttributeType = "Logical";
logAttr.AttributeName = "isValid";
logAttr.DefaultValue = true;         % logical scalar or 'true'/'false'
logAttr.AttributeDescription = "";

% List attribute
listAttr.AttributeType = "List";
listAttr.AttributeName = "priority";
listAttr.ListItems = {'High'; 'Medium'; 'Low'};
listAttr.AttributeDescription = "";

% Add multiple attributes to labelDefs using cell indexing
labelDefs.AttributeList{1} = numAttr;
labelDefs.AttributeList{1,2} = strAttr;
labelDefs.AttributeList{1,3} = logAttr;
```

### Properties (all read-only)

| Property | Type | Description |
|----------|------|-------------|
| `DataSource` | `hyper.labeler.loading.SpectralImageSource` | Source of spectral image data |
| `LabelDefinitions` | table | Label metadata (LabelName, LabelColor, LabelID, LabelGroup, Description, AttributeList) |
| `LabelData` | table | ROI annotations per label |
| `Resolution` | positive integer or `[]` | Band resolution for multicube |

### SpectralImageSource (Since R2026a)

```matlab
dataSource = hyper.labeler.loading.SpectralImageSource(filename)
```
- `filename` — path to file supported by `imhypercube`/`geohypercube`/`immulticube`/`geomulticube`, or MAT file containing a sole `hypercube`/`multicube` variable
- Property: `Filename` (read-only, char) — the resolved file path
- Automatically created internally when you pass a file path string to `groundTruthSpectralImage`
- **Preferred pattern:** Pass the file path directly to `groundTruthSpectralImage` — no need to create `SpectralImageSource` explicitly

### Object Functions

```matlab
% Merge multiple ground truth objects (must share same data source and resolution)
gTruthMerged = merge(gTruth1, gTruth2, ..., gTruthN)
% After merge: ROINames are regenerated to avoid duplicates; LabelIDs are reassigned to be unique

% Select labels by group
gTruthNew = selectLabelsByGroup(gTruth, labelGroups)
% labelGroups: string scalar, string array, char, or cell array of char
% Error: 'hyperspectral:groundTruthSpectralImage:GroupNotFound' if group doesn't exist

% Select labels by name
gTruthNew = selectLabelsByName(gTruth, labelNames)
% labelNames: string scalar, string array, char, or cell array of char
% Error: 'hyperspectral:groundTruthSpectralImage:LabelNameNotFound' if name doesn't exist

% Change file paths (for portability across machines)
unresolvedPaths = changeFilePaths(gTruth, alternateFilePaths)
% gTruth: single object or array of groundTruthSpectralImage objects
% alternateFilePaths: n-by-2 string array [currentFolderPath newFolderPath]
% Specify folder paths only (not filenames); data source file must be same
% Returns empty if all paths resolve; otherwise returns unresolved file paths
```

## Deep Learning Workflows

> Full workflow code: classification in `references/dl-classification.md`, advanced (autoencoder, transfer learning, DeepLabV3+) in `references/dl-advanced.md`.

| Workflow | Description | Key Functions |
|----------|-------------|---------------|
| 3-D CSCNN Classification | PCA reduction + 25x25 spatial patches + 3-D CNN | `hyperpca`, `trainnet`, `dlnetwork`, `image3dInputLayer`, `convolution3dLayer` |
| 1-D Spectral CNN | Per-pixel classification using spectral dimension only | `image3dInputLayer([C 1 1])`, `convolution3dLayer([k 1 1], ...)` |
| Ground Truth → Training Data | Convert `groundTruthSpectralImage` ROIs to pixel masks and patch arrays | `poly2mask`, `gTruth.LabelDefinitions`, `gTruth.LabelData` |
| Unmixing Autoencoder | Self-supervised encoder-decoder for abundance estimation | `featureInputLayer`, `softmaxLayer`, `"mse"` loss, `net.Learnables` |
| Transfer Learning | PCA to 3 bands + pretrained ResNet-18 fine-tuning | `hyperpca(data, 3)`, `imagePretrainedNetwork`, `replaceLayer` |
| Semantic Segmentation (DeepLabV3+) | Full-tile segmentation of multispectral satellite imagery | `deeplabv3plus`, `replaceLayer`, `pixelLabelDatastore`, `semanticseg`, `evaluateSemanticSegmentation`, `focalCrossEntropy` |

### Key API Pattern

```matlab
% Modern training pipeline (use for all DL workflows)
net = dlnetwork(layers);
options = trainingOptions("adam", MaxEpochs=100, MiniBatchSize=256, ...);
net = trainnet(data, targets, net, "crossentropy", options);

% Modern inference pipeline
scores = minibatchpredict(net, dsTest);
YPred = scores2label(scores, categories(YTest));
accuracy = mean(YPred == YTest);
confusionchart(YTest, YPred);
```

## Key Rules

### Labeler & Ground Truth
- Spectral Image Labeler requires desktop MATLAB (not MATLAB Online/Mobile) and Hyperspectral Imaging Library add-on (Since R2026a)
- All `groundTruthSpectralImage` properties are read-only after creation
- Property name is `LabelDefinitions` (plural with 's'), not `LabelDefinition`
- `LabelID`, `LabelColor`, and `ROIName` are auto-assigned if omitted or empty in the input
- ROIs within the same label must be non-overlapping (error: `OverlapPolyshape`)
- `merge` requires all objects share the same `DataSource` and `Resolution`; after merge, ROINames are regenerated and LabelIDs reassigned to be unique
- `changeFilePaths` takes folder paths only (not filenames); supports arrays of gTruth objects; returns unresolved file paths or empty on success
- Label/group/ROI/attribute names must be valid MATLAB variable names
- `LabelID` range: 1–255 recommended (higher values work at API level but may cause issues during TIF export)
- `LabelColor` range: 0–1 per channel (auto-assigned if omitted)
- `AttributeList` supports 4 types: Numeric, String, Logical, List — each with `AttributeType`, `AttributeName`, `AttributeDescription`, and either `DefaultValue` or `ListItems`
- Multiple attributes per label: use cell indexing `labelDefs.AttributeList{row, col}` — NOT struct arrays

### Deep Learning Training
- Use `trainnet` (not deprecated `trainNetwork`) with `dlnetwork` objects
- Use `minibatchpredict` for inference (not deprecated `predict` on `SeriesNetwork`/`DAGNetwork`)
- Use `scores2label` to convert prediction scores to categorical labels
- For 3-D CNN: input shape is H-by-W-by-D (spectral)-by-Ch (typically 1)-by-N
- For 1-D spectral CNN: treat spectrum as a 1-D "image" with `image3dInputLayer([C 1 1])`
- Apply PCA (`hyperpca`) before CNN to reduce spectral dimensionality and training time
- Normalize per-band by standard deviation for stable training
- Use `augmentedImageDatastore` for patch-based training with consistent input size
- Use `arrayDatastore` + `combine` for custom datastore pipelines
- `dividerand` for train/val/test splits; `cvpartition` for cross-validation

### Unmixing Autoencoders
- Softmax layer enforces sum-to-one abundance constraint (physical plausibility)
- Decoder weights approximate endmember spectra
- Self-supervised: input equals target (reconstruction loss)
- Compare against `estimateAbundanceLS` with `Method="fcls"` as baseline
- Extract decoder weights via `net.Learnables` filtering by layer name and parameter type

### Data Preparation
- Unlabeled pixels (class 0 or `<undefined>`) must be excluded from training
- Patch extraction: zero-pad image borders to handle edge pixels
- For transfer learning: reduce to 3 bands via PCA to match pretrained RGB networks
- Resize patches to 224x224 for standard pretrained architectures (ResNet, etc.)

----

Copyright 2026 The MathWorks, Inc.
