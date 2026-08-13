# OCR Image Preprocessing Guide

Complete reference for preprocessing images before calling `ocr()`. Apply steps based on what `imbinarize` reveals about your image.

## Diagnostic: What Does OCR See?

```matlab
Igray = im2gray(I);
BW = imbinarize(Igray);
imshowpair(Igray, BW, "montage")
```

| Symptom in Binary Image | Cause | Fix |
|------------------------|-------|-----|
| Text invisible or merged with background | Non-uniform illumination | `imtophat` or `adapthisteq` |
| Metal texture dominates, text barely visible | Stamped/embossed/engraved text | Local contrast subtraction |
| Excessive noise dots | Image noise | `medfilt2` or `imgaussfilt` then `bwareaopen` |
| Text too thin/broken | Low contrast or erosion | `imdilate` with small structuring element |
| Text too thick/merged | Bold/bleeding ink | `imerode` with small structuring element |
| Text is white on black | Inverted polarity | `imcomplement` |
| Text rotated/skewed | Camera angle or scan | `imrotate` after detecting angle |
| Text too small | Low resolution | `imresize(I, scaleFactor)` |
| Dark borders around scan | Scanner artifacts | `imclearborder` or crop |

## Preprocessing Pipeline (Ordered)

Apply in this order — skip steps that don't apply:

### 1. Color Conversion

```matlab
Igray = im2gray(I);  % or rgb2gray(I)
```

For colored text on colored background, L*a*b* color space may separate better:
```matlab
lab = rgb2lab(I);
Igray = lab(:,:,1);  % Lightness channel
```

### 2. Resize for Resolution

OCR needs at least 300 DPI. Capital letters should be ~30-50 pixels tall.

```matlab
% Scale up 2x for small text
Iresized = imresize(Igray, 2, "bicubic");

% Or scale to target height for text region
targetHeight = 40;  % pixels
scaleFactor = targetHeight / currentTextHeight;
Iresized = imresize(Igray, scaleFactor);
```

### 3. Noise Removal

```matlab
% Salt-and-pepper noise
Iclean = medfilt2(Igray, [3 3]);

% Gaussian noise
Iclean = imgaussfilt(Igray, 1);

% Adaptive noise removal (preserves edges best)
Iclean = wiener2(Igray, [5 5]);

% Edge-preserving (best for text, preserves sharp edges)
Iclean = imbilatfilt(Igray);
```

### 4. Contrast Enhancement

```matlab
% Global contrast stretch
Ienhanced = imadjust(Igray);

% Local adaptive contrast (CLAHE) — best for uneven lighting
Ienhanced = adapthisteq(Igray, ClipLimit=0.02);

% Sharpen text edges
Ienhanced = imsharpen(Igray, Radius=2, Amount=1);
```

### 5. Illumination Correction

For non-uniform backgrounds (keypads, labels, photographed documents):

```matlab
% Top-hat: removes dark background, keeps bright text
Icorrected = imtophat(Igray, strel("disk", 15));

% Bottom-hat: removes light background, keeps dark text
Icorrected = imbothat(Igray, strel("disk", 15));

% Full reconstruction cleanup
Icorrected = imtophat(Igray, strel("disk", 15));
marker = imerode(Icorrected, strel("line", 10, 0));
Iclean = imreconstruct(marker, Icorrected);
```

Adjust disk radius based on text size — should be larger than stroke width but smaller than character height.

### 5b. Local Contrast Subtraction (Stamped/Embossed/Engraved Text)

For text formed by shallow surface relief (stamps, engravings, etchings on metal/plastic), standard illumination correction fails because the texture noise is amplified along with the text signal. Local contrast subtraction works by isolating regions that are locally darker than their surroundings:

```matlab
% Background estimate (large-sigma Gaussian smoothing)
Ibg = imgaussfilt(Igray, 30);

% Local darkness map — positive where text is darker than background
Idiff = max(double(Ibg) - double(Igray), 0);
Idiff = mat2gray(Idiff);

% Binarize with lower threshold (text signal is subtle)
BW = imbinarize(Idiff, 0.25);
BW = bwareaopen(BW, 150);  % remove noise
```

**Sigma tuning:** The sigma (30 above) should be larger than character stroke width but smaller than spacing between text lines. Try 20-50 for most stamped metal text.

**Why imtophat/imbothat fail here:** They use flat structuring elements that amplify brushed metal texture patterns along with the text. The Gaussian approach averages over a larger area, smoothing out texture.

### 6. Deskewing (Rotation Correction)

**Critical:** Skew >10° causes total OCR failure (not gradual degradation). Always deskew before other preprocessing.

**Method 1: Centroid fitting (preferred for multi-word scenes and textured images):**

Fits a line through the centroids of the largest character blobs to get the text baseline angle. More robust than Hough on textured images where edges are noisy.

```matlab
BW_rough = bwareaopen(imbinarize(Igray), 100);
props = regionprops(BW_rough, "Centroid", "Area");
[~, idx] = sort([props.Area], "descend");
topCents = vertcat(props(idx(1:min(10,end))).Centroid);
skewAngle = atand(polyfit(topCents(:,1), topCents(:,2), 1));
Icorrected = imrotate(Igray, -skewAngle, "bilinear", "crop");
```

**Method 2: Hough transform (for clean documents with strong horizontal lines):**

```matlab
BW = edge(imbinarize(Igray), "canny");
[H, theta, rho] = hough(BW);
peaks = houghpeaks(H, 5);
lines = houghlines(BW, theta, rho, peaks);
angles = [lines.theta];
skewAngle = median(angles);
Icorrected = imrotate(Igray, -skewAngle, "bilinear", "crop");
```

**Note on regionprops Orientation:** `regionprops(BW, "Orientation")` gives the orientation of individual connected components (characters), NOT the text line angle. For vertical strokes (like "I", "l", "1"), orientation is ~90° regardless of text line angle. Do not use this for deskewing multi-character text.

### 7. Binarization

```matlab
% Global (Otsu) — good for uniform backgrounds
BW = imbinarize(Igray);

% Adaptive — good for uneven illumination
T = adaptthresh(Igray, 0.4);
BW = imbinarize(Igray, T);

% Manual threshold
level = graythresh(Igray);
BW = imbinarize(Igray, level * 0.9);  % adjust multiplier
```

### 8. Post-Binarization Cleanup

```matlab
% Remove small noise (specks smaller than N pixels)
BW = bwareaopen(BW, 20);

% Fill holes in characters
BW = imfill(BW, "holes");

% Connect broken character strokes
BW = imdilate(BW, strel("line", 2, 0));  % horizontal
BW = imclose(BW, strel("disk", 1));       % all directions

% Thin overly bold characters
BW = imerode(BW, strel("disk", 1));

% Remove objects touching border (scan artifacts)
BW = imclearborder(BW);
```

### 9. Inversion (Polarity Correction)

OCR requires dark text on light background:

```matlab
% If text is light on dark background
BW = imcomplement(BW);
```

### 10. Border Padding

Text touching image edges causes recognition failures:

```matlab
% Add 10-pixel white border
BW = padarray(BW, [10 10], 1);  % 1 = white for binary

% For grayscale
Igray = padarray(Igray, [10 10], 255);  % 255 = white for uint8
```

## Function Quick Reference

| Function | Purpose | Key Parameters |
|----------|---------|----------------|
| `im2gray` | RGB to grayscale | — |
| `imresize` | Scale image | scale factor or `[rows cols]` |
| `medfilt2` | Median filter (noise) | `[m n]` neighborhood size |
| `imgaussfilt` | Gaussian smoothing | sigma value |
| `wiener2` | Adaptive denoise | `[m n]` neighborhood |
| `imbilatfilt` | Bilateral filter | DegreeOfSmoothing |
| `imadjust` | Contrast stretch | `[low high]` input range |
| `adapthisteq` | CLAHE | ClipLimit, NumTiles |
| `imsharpen` | Sharpen edges | Radius, Amount |
| `imtophat` | Remove dark background | `strel` structuring element |
| `imbothat` | Remove light background | `strel` structuring element |
| `imreconstruct` | Morphological reconstruction | marker, mask |
| `imrotate` | Rotate/deskew | angle, interpolation, bbox |
| `imbinarize` | Binarize | threshold or `"adaptive"` |
| `adaptthresh` | Local threshold | sensitivity (0-1) |
| `graythresh` | Otsu threshold | — |
| `bwareaopen` | Remove small components | min pixel count |
| `imfill` | Fill holes | `"holes"` |
| `imdilate` | Thicken strokes | `strel` element |
| `imerode` | Thin strokes | `strel` element |
| `imclose` | Close gaps | `strel` element |
| `imcomplement` | Invert image | — |
| `padarray` | Add border | `[rows cols]`, pad value |
| `imclearborder` | Remove border objects | — |
| `strel` | Structuring element | shape, size |


----
Copyright 2026 The MathWorks, Inc.
----
