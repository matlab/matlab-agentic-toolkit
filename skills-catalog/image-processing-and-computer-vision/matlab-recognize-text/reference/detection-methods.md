# Text Detection Methods

Code examples for each detection method. Choose based on the routing table in SKILL.md Step 3.

## CRAFT Detection (Recommended for Scenes)

```matlab
% Detect text regions using deep learning
bbox = detectTextCRAFT(I, CharacterThreshold=0.3);

% Visualize detected regions
Iout = insertShape(I, "rectangle", bbox, LineWidth=3);
imshow(Iout)
title("CRAFT Text Detection")

% Per-region OCR — ALWAYS use LayoutAnalysis with bboxes
allText = strings(size(bbox, 1), 1);
for k = 1:size(bbox, 1)
    r = ocr(I, bbox(k,:), CharacterSet="A-Z0-9", LayoutAnalysis="word");
    allText(k) = strtrim(r.Text);
end
```

**Key parameters:**
- `CharacterThreshold` (0-1): Lower = more detections, more false positives. Default 0.5. Use 0.15-0.3 for faint text.
- `LinkThreshold` (0-1): Controls word grouping. Default 0.4.

## MSER Detection (No Deep Learning)

```matlab
Igray = im2gray(I);
[mserRegions, mserCC] = detectMSERFeatures(Igray, ...
    RegionAreaRange=[200 8000], ThresholdDelta=4);

% Convert to bounding boxes
bbox = vertcat(mserRegions.Location) - vertcat(mserRegions.Axes(:,1:2));
% Or use regionprops on the connected components:
stats = regionprops(mserCC, "BoundingBox");
bbox = vertcat(stats.BoundingBox);

% Filter by aspect ratio (text characters are roughly square or tall)
aspectRatio = bbox(:,3) ./ bbox(:,4);
textLike = aspectRatio > 0.2 & aspectRatio < 5;
bbox = bbox(textLike, :);
```

**Key parameters:**
- `RegionAreaRange`: Min/max pixel area. Adjust for text size.
- `ThresholdDelta`: Stability threshold. Lower = more regions. Default 2.

## SAM Segmentation (Text ON Textured Background)

Use when text is a **separate physical object** on a textured surface — label on crate, sticker on concrete, sign on brick wall.

**Do NOT use for:** stamped, embossed, engraved text (surface features, not objects).

**Do NOT downscale** — SAM needs full resolution. Only scale up if text is small.

**Execution time:** ~60-120 seconds.

```matlab
% Scale up for better segmentation (2-3x)
I_scaled = imresize(I, 3);

% Segment using SAM — produces clean binary of all foreground objects
% Models: "sam2-small" (default), "sam2-large"
% If SAM 2 fails, try SAM 1: "sam-base", "sam-large", "sam-huge"
cc = imsegsam(I_scaled, ModelName="sam-base");
BW = cc2bw(cc);

% OCR on the clean binary
results = ocr(BW, CharacterSet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", LayoutAnalysis="word");
disp(results.Text)
```

## Manual ROI (Fixed Layout)

For consistent image layouts where text is always in the same location:

```matlab
% Define ROI as [x y width height]
roi = [50 100 200 30];

% ALWAYS specify LayoutAnalysis with ROI
results = ocr(I, roi, LayoutAnalysis="word");
disp(results.Text)
```

## Connected Components (Binary Images)

For text on uniform backgrounds after binarization:

```matlab
BW = imbinarize(im2gray(I));
cc = bwconncomp(BW);
stats = regionprops(cc, "BoundingBox", "Area");

% Filter by size and shape
bbox = vertcat(stats.BoundingBox);
area = [stats.Area]';
aspectRatio = bbox(:,3) ./ bbox(:,4);
keep = area > 100 & aspectRatio > 0.2 & aspectRatio < 5;
bbox = bbox(keep, :);

% OCR on filtered regions
results = ocr(BW, bbox, LayoutAnalysis="word");
```

## Color Segmentation

For colored text that is distinct from background:

```matlab
% Try individual channels
R = I(:,:,1); G = I(:,:,2); B = I(:,:,3);

% Find channel with best text/background contrast
% (visually inspect or compute std of each)
bestChannel = R;  % example: red text on green/blue background

BW = imbinarize(bestChannel);
results = ocr(BW, LayoutAnalysis="block");
```


----
Copyright 2026 The MathWorks, Inc.
----
