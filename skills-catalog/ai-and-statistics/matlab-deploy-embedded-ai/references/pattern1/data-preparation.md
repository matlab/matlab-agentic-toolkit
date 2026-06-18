# Data Preparation

Detailed patterns for data preparation in Embedded AI Pattern 1 (lean hardware, <500KB models).

## Data Splitting

Always set the random seed before splitting for reproducibility:

```matlab
rng("default")
```

### Recommended Split Ratios

| Dataset Size     | Problem Type        | Train / Val / Test |
|------------------|---------------------|--------------------|
| < 1,000 samples  | Tabular             | 60 / 20 / 20      |
| 1,000 - 10,000   | Tabular             | 70 / 15 / 15      |
| 10,000 - 100,000  | Tabular / Signal   | 80 / 10 / 10      |
| > 100,000         | Any                | 90 / 5 / 5        |
| < 500 images      | Image              | 60 / 20 / 20      |
| > 500 images       | Image             | 70 / 15 / 15      |

**Note:** For large datasets, validation and test sets only need to be large enough
to reliably capture the output statistics — additional data beyond that is better
used for training. The ratios above are starting points; adjust based on the
complexity of the problem and the variability in the data.

### Splitting with cvpartition (Tabular Data)

```matlab
rng("default")

% Stratified split for classification
n = height(data);
cv = cvpartition(data.Label, "HoldOut", 0.3);

trainData = data(training(cv), :);
tempData  = data(test(cv), :);

% Split remaining 30% into validation (15%) and test (15%)
cv2 = cvpartition(tempData.Label, "HoldOut", 0.5);
valData  = tempData(training(cv2), :);
testData = tempData(test(cv2), :);
```

### Splitting with splitEachLabel (Image Data)

```matlab
rng("default")

imds = imageDatastore("path/to/images", ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");

[imdsTrain, imdsVal, imdsTest] = splitEachLabel(imds, 0.7, 0.15, 0.15, "randomized");
```

### Splitting with randperm (General Purpose)

```matlab
rng("default")

n = size(X, 1);
idx = randperm(n);

nTrain = round(0.7 * n);
nVal   = round(0.15 * n);

trainIdx = idx(1:nTrain);
valIdx   = idx(nTrain+1:nTrain+nVal);
testIdx  = idx(nTrain+nVal+1:end);

XTrain = X(trainIdx, :);  YTrain = Y(trainIdx);
XVal   = X(valIdx, :);    YVal   = Y(valIdx);
XTest  = X(testIdx, :);   YTest  = Y(testIdx);
```

## Datastore Patterns (Large Data)

Use datastores when data does not fit in memory.

### tabularTextDatastore (Large CSV Files)

```matlab
tds = tabularTextDatastore("path/to/csvfiles", ...
    SelectedVariableNames=["Var1","Var2","Var3","Label"]);

tds.ReadSize = 1000;  % Rows per read
```

### imageDatastore (Large Image Datasets)

```matlab
imds = imageDatastore("path/to/images", ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");

% Apply augmentation for training
augmenter = imageDataAugmenter( ...
    RandRotation=[-20 20], ...
    RandXReflection=true);

augImds = augmentedImageDatastore([224 224 3], imds, ...
    DataAugmentation=augmenter);
```

### audioDatastore (Audio Files)

```matlab
ads = audioDatastore("path/to/audiofiles", ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");
```

### arrayDatastore (In-Memory Arrays Wrapped as Datastore)

```matlab
dsX = arrayDatastore(XTrain, IterationDimension=1);
dsY = arrayDatastore(YTrain, IterationDimension=1);
dsTrain = combine(dsX, dsY);
```

## Data Preprocessing Patterns

### Normalization

```matlab
% Z-score normalization
[XTrain, mu, sigma] = normalize(XTrain);
XVal  = normalize(XVal, "center", mu, "scale", sigma);
XTest = normalize(XTest, "center", mu, "scale", sigma);

% Save normalization parameters for deployment
save("normParams.mat", "mu", "sigma");
```

### Feature Extraction for Time-Series

```matlab
% Windowing for sequence data
windowSize = 50;
stepSize   = 10;

numWindows = floor((size(data, 1) - windowSize) / stepSize) + 1;
windows = zeros(numWindows, windowSize, size(data, 2));

for i = 1:numWindows
    startIdx = (i-1) * stepSize + 1;
    windows(i, :, :) = data(startIdx:startIdx+windowSize-1, :);
end
```

### Formatting Sequence Data for trainnet

> **CRITICAL:** trainnet requires sequence data as cell arrays of **[T x C] single** matrices (time-steps x channels). The format is **[T x C], NOT [C x T]**. Getting this wrong produces an "Invalid size of channel dimension" error.

Convert loaded data to the correct format:

```matlab
% From a matrix where rows are time steps and columns are features
% Split into individual sequences (e.g., by trial or segment)
numSequences = numel(segmentIdx);
XTrain = cell(numSequences, 1);
YTrain = cell(numSequences, 1);
for i = 1:numSequences
    idx = segmentIdx{i};
    XTrain{i} = single(data(idx, featureCols));  % [T x numFeatures] single
    YTrain{i} = single(data(idx, responseCols));  % [T x numResponses] single
end

% Verify format
assert(iscolumn(XTrain), "Must be N-by-1 cell array");
assert(isa(XTrain{1}, "single"), "Each cell must be single precision");
fprintf("Sequence 1: [%d x %d] — %d time steps, %d features\n", ...
    size(XTrain{1}, 1), size(XTrain{1}, 2), size(XTrain{1}, 1), size(XTrain{1}, 2));
```

### Handling Missing Data

```matlab
% Check for missing values
missingCount = sum(ismissing(data));

% Options: remove, fill, or interpolate
data = rmmissing(data);                    % Remove rows with missing values
data = fillmissing(data, "linear");        % Linear interpolation
data = fillmissing(data, "previous");      % Forward fill
```


Copyright 2026 The MathWorks, Inc.
