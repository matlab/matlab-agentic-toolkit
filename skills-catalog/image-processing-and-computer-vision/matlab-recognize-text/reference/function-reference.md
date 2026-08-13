# OCR Function Reference

## Key Functions

| Function | Purpose | Toolbox |
|----------|---------|---------|
| `ocr` | Recognize text in image | Computer Vision |
| `ocrText` | OCR results object (Text, Words, Confidences) | Computer Vision |
| `detectTextCRAFT` | Deep learning text detection | Computer Vision |
| `detectMSERFeatures` | MSER-based text region detection | Computer Vision |
| `imsegsam` | SAM segmentation for challenging binarization | Computer Vision |
| `imbinarize` | Binarize image (Otsu or adaptive) | Image Processing |
| `imtophat` | Remove non-uniform background | Image Processing |
| `imcomplement` | Invert image (ensure dark-on-light) | Image Processing |
| `imresize` | Scale image for better recognition | Image Processing |
| `imerode` / `imdilate` | Thin/thicken characters | Image Processing |
| `imreconstruct` | Morphological reconstruction | Image Processing |
| `bwareaopen` | Remove small noise from binary image | Image Processing |
| `padarray` | Add border padding | Image Processing |
| `medfilt2` | Remove salt-and-pepper noise | Image Processing |
| `adapthisteq` | Local contrast enhancement (CLAHE) | Image Processing |
| `imrotate` | Deskew rotated text | Image Processing |

## LayoutAnalysis Parameter

Choose based on content structure:

| Value | Use When |
|-------|----------|
| `"auto"` | Default; let OCR decide (works for full documents) |
| `"page"` | Multi-column document pages |
| `"block"` | Single block of multi-line text |
| `"word"` | ROI contains a single word |
| `"line"` | ROI contains a single text line |
| `"character"` | ROI contains a single character |
| `"none"` | Disable layout analysis (use with manual ROIs) |

**Gotcha:** When providing ROI bounding boxes from detection, set `LayoutAnalysis` to `"Word"` or `"none"` — the default `"auto"` often fails on small regions.

## Common Patterns

### CRAFT + OCR for Natural Scenes

```matlab
I = imread("streetSign.jpg");

% Detect text regions
bbox = detectTextCRAFT(I, CharacterThreshold=0.3);

% Preprocess for OCR
Igray = im2gray(I);
BW = imbinarize(Igray);

% Always check polarity — ensure dark text on light background
BW = imcomplement(BW);

% Recognize with word-level layout
results = ocr(BW, bbox, LayoutAnalysis="Word");
recognizedWords = cat(1, results(:).Words);
```

### ROI-Based with Region Filtering

```matlab
% Find text-like connected components
BW = imbinarize(im2gray(I));
cc = bwconncomp(BW);
stats = regionprops(cc, "BoundingBox", "Area");

roi = vertcat(stats(:).BoundingBox);
area = vertcat(stats(:).Area);

% Filter by area and aspect ratio
aspectRatio = roi(:,3) ./ roi(:,4);
keep = area > 100 & aspectRatio > 0.25 & aspectRatio < 1.25;
roi = double(roi(keep, :));

% Pad ROIs slightly for better polarity detection
roi(:,1:2) = roi(:,1:2) - 5;
roi(:,3:4) = roi(:,3:4) + 10;

results = ocr(I, roi, LayoutAnalysis="none");
```

### Recognition Patterns

```matlab
% Basic OCR on full image
results = ocr(I);
disp(results.Text)

% OCR with ROI — ALWAYS specify LayoutAnalysis
results = ocr(I, bbox, LayoutAnalysis="word");

% OCR with character constraint
results = ocr(BW, CharacterSet="0123456789");

% Seven-segment display
results = ocr(I, roi, Model="seven-segment", LayoutAnalysis="word");

% Non-English language
results = ocr(I, Model="french");
```

### Validation Patterns

```matlab
% Check confidence scores — low confidence indicates problems
lowConfIdx = results.CharacterConfidences < 0.5;
if any(lowConfIdx)
    suspectChars = results.Text(lowConfIdx);
    suspectBoxes = results.CharacterBoundingBoxes(lowConfIdx, :);
end

% Use word confidences for filtering
validWords = results.WordConfidences > 0.7;
cleanText = results.Words(validWords);

% Mean confidence for overall quality check
meanConf = mean(results.WordConfidences, "omitnan");
fprintf("Mean word confidence: %.2f\n", meanConf);
```


----
Copyright 2026 The MathWorks, Inc.
----
