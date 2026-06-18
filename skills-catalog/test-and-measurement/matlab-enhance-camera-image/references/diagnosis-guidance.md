# Diagnosis Guidance — Metric Thresholds and Algorithms

## Brightness

Metric: mean pixel intensity (0–255 scale after converting to grayscale).

| Range | Assessment | Interpretation |
|-------|-----------|----------------|
| < 60 | Severe | Very underexposed — significant detail lost in shadows |
| 60–80 | Problem | Underexposed — dark but recoverable |
| 80–180 | OK | Acceptable exposure range |
| 180–200 | Problem | Overexposed — highlights starting to clip |
| > 200 | Severe | Very overexposed — significant detail lost in highlights |

Supporting metrics:
- **% dark pixels**: fraction with intensity < 50 (> 40% suggests underexposure)
- **% bright pixels**: fraction with intensity > 200 (> 30% suggests overexposure)
- **Histogram shape**: bimodal distribution often indicates backlit scene

## Clipping (Highlight / Shadow)

Metric: percentage of pixels at or near the maximum (≥ 250) or minimum (≤ 5) intensity.

| Max Clipping % | Assessment | Interpretation |
|---|---|---|
| < 5% | OK | Minimal clipping — full dynamic range preserved |
| 5–15% | Problem | Noticeable clipping — some highlight or shadow detail lost |
| > 15% | Severe | Heavy clipping — significant information loss, histogram crushed against rail |

Notes:
- Separate values reported for highlights (`highPct`) and shadows (`lowPct`); the worse of the two drives the assessment
- High highlight clipping with normal brightness strongly indicates overexposure — reduce ExposureTime
- High shadow clipping with low brightness indicates underexposure or excessive black level
- Clipping is more actionable than mean brightness alone — a scene can have "OK" brightness but 20% highlight clipping due to a bimodal histogram

## Contrast

Metric: standard deviation of pixel intensities (0–255 scale).

| Range | Assessment | Interpretation |
|-------|-----------|----------------|
| < 25 | Severe | Very flat — image appears washed out or foggy |
| 25–40 | Problem | Low contrast — lacks visual punch |
| 40–80 | OK | Normal contrast range |
| > 80 | OK | High contrast — acceptable unless clipping occurs |

Supporting metric:
- **Dynamic range utilization**: `(max - min) / 255`. Values below 0.5 indicate the sensor range is underutilized.

## Sharpness

Metric: variance of the Laplacian-filtered image (normalized 0–1 double scale).

| Range | Assessment | Interpretation |
|-------|-----------|----------------|
| < 0.0002 | Severe | Very blurry — likely out of focus or heavy motion blur |
| 0.0002–0.001 | Problem | Soft — slightly out of focus or mild motion |
| > 0.001 | OK | Acceptably sharp |

Notes:
- Laplacian kernel: `fspecial("laplacian", 0)` (standard 3×3)
- Edge content affects this metric — low-texture scenes may score low even when sharp
- If sharpness is low but scene is intentionally low-texture, verify with an edge target

## Noise

Metric: standard deviation of the difference between original and Gaussian-smoothed image (σ=1.5), scaled to 0–255.

| Range | Assessment | Interpretation |
|-------|-----------|----------------|
| < 5 | OK | Low noise — clean image |
| 5–10 | Problem | Moderate noise — visible in dark regions |
| > 10 | Severe | High noise — likely high Gain or long exposure in low light |

Notes:
- This estimates high-frequency noise by subtracting a smoothed version
- Dark regions typically show more noise due to lower signal-to-noise ratio
- For more accurate estimation, consider `estimateNoise2d` (if available) or `std2` on a flat region

## Color Balance

Metric: R/G and B/G mean intensity ratios.

| Max Deviation from 1.0 | Assessment | Interpretation |
|------------------------|-----------|----------------|
| < 0.15 | OK | Neutral color balance |
| 0.15–0.30 | Problem | Noticeable color cast |
| > 0.30 | Severe | Strong color cast — white balance is incorrect |

Interpretation of ratios:
- R/G > 1.15: warm/yellow cast (incandescent lighting)
- B/G > 1.15: cool/blue cast (shade or fluorescent lighting)
- Both elevated: magenta cast

## Backlight Detection

Metric: ratio of mean border intensity to mean center intensity.

Algorithm:
1. Define center region as the middle 50% of rows and columns (25%–75% in each dimension)
2. Define border region as all pixels outside the center region
3. Compute `ratio = mean(border) / mean(center)`

| Ratio | Assessment | Interpretation |
|-------|-----------|----------------|
| < 1.5 | OK | Uniform illumination or subject brighter than background |
| 1.5–2.0 | Problem | Mild backlighting — subject slightly darker than background |
| > 2.0 | Severe | Strong backlighting — subject silhouetted against bright background |

Notes:
- A ratio < 0.7 suggests the background is darker than the subject (front-lit, no backlight issue)
- This heuristic assumes the subject is roughly centered; off-center subjects may give false positives
- For multi-subject scenes, consider region-based analysis instead

## Adjusting Thresholds for Specific Use Cases

| Use Case | Adjustment |
|----------|-----------|
| Industrial inspection | Tighter sharpness threshold (Problem < 0.002), lower noise tolerance |
| Portrait photography | Slightly lower contrast OK range (35–70), backlight detection more critical |
| Document scanning | Brightness OK range narrower (100–160), contrast threshold higher |
| Surveillance/security | Higher noise tolerance (Problem > 8), sharpness less critical |

## Extended Metrics

These evaluation patterns cover concerns beyond the standard 6 metrics. When the user reports an issue not covered by `diagnoseImageQuality.m`, generate inline MATLAB code adapting the patterns below.

### Vignetting (corner darkening)

Compare mean brightness across quadrants versus center.

```matlab
grayImg = im2double(im2gray(img));
[rows, cols] = size(grayImg);
centerRegion = grayImg(round(rows*0.35):round(rows*0.65), round(cols*0.35):round(cols*0.65));
corners = [mean(grayImg(1:round(rows*0.2), 1:round(cols*0.2)), "all"), ...
           mean(grayImg(1:round(rows*0.2), round(cols*0.8):end), "all"), ...
           mean(grayImg(round(rows*0.8):end, 1:round(cols*0.2)), "all"), ...
           mean(grayImg(round(rows*0.8):end, round(cols*0.8):end), "all")];
vignetteRatio = mean(corners) / mean(centerRegion, "all");
% vignetteRatio < 0.75 → noticeable vignetting; < 0.6 → severe
```

### Banding / Striping (periodic artifacts)

Use FFT to detect strong periodic components in rows or columns.

```matlab
grayImg = im2double(im2gray(img));
colMean = mean(grayImg, 1);
spectrum = abs(fft(colMean - mean(colMean)));
spectrum = spectrum(2:floor(end/2));  % Exclude DC, keep first half
peakRatio = max(spectrum) / mean(spectrum);
% peakRatio > 10 → likely banding artifact
```

### Saturation Clipping

Measure percentage of pixels at maximum value in any channel.

```matlab
imgU8 = im2uint8(img);
if size(imgU8, 3) == 3
    clippedR = sum(imgU8(:,:,1) == 255, "all");
    clippedG = sum(imgU8(:,:,2) == 255, "all");
    clippedB = sum(imgU8(:,:,3) == 255, "all");
    totalPixels = numel(imgU8(:,:,1));
    clipPercent = max([clippedR, clippedG, clippedB]) / totalPixels * 100;
else
    clipPercent = sum(imgU8 == 255, "all") / numel(imgU8) * 100;
end
% clipPercent > 5% → Problem; > 15% → Severe
```

### Flicker / Frame Inconsistency

Capture multiple frames and measure inter-frame brightness variance.

```matlab
nFrames = 10;
brightness = zeros(1, nFrames);
for i = 1:nFrames
    frame = snapshot(cam);
    brightness(i) = mean(im2double(im2gray(frame)), "all");
end
flickerStd = std(brightness) * 255;
% flickerStd > 3 → noticeable flicker; > 8 → severe
```

### Chromatic Aberration (color fringing at edges)

Detect misalignment between color channel edges at the image periphery.

```matlab
imgD = im2double(img);
edgeR = edge(imgD(:,:,1), "Canny");
edgeG = edge(imgD(:,:,2), "Canny");
edgeB = edge(imgD(:,:,3), "Canny");
% Compare edge positions in border region (outer 20%)
borderMask = true(size(edgeR));
borderMask(round(end*0.2):round(end*0.8), round(end*0.2):round(end*0.8)) = false;
convergence = sum(edgeR & edgeG & edgeB & borderMask, "all") / ...
              max(sum((edgeR | edgeG | edgeB) & borderMask, "all"), 1);
% convergence < 0.4 → noticeable CA; < 0.2 → severe
```

### Lens Distortion (qualitative check)

Requires a calibration target or known straight lines. Without one, report that distortion cannot be measured from a single arbitrary scene and suggest using the Camera Calibrator app.

----

Copyright 2026 The MathWorks, Inc.

----
