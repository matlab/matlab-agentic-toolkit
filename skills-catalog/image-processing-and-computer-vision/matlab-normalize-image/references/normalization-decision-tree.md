# Normalization Decision Tree

Complete decision tree for normalizing images to [0,1] using base MATLAB functions.
Covers all edge cases encountered in discovery testing.

## Decision Flow

```
imread(file)
  │
  ├── Step 1: imfinfo pre-check
  │     ├── ColorType == 'indexed'?
  │     │     → STOP. Warn customer: need [X,cmap]=imread + ind2rgb (core MATLAB)
  │     │       Single-output imread returns indices, not colors.
  │     │
  │     ├── BitDepth/channels != 8 or 16?
  │     │     → Flag for post-normalization sub-range check
  │     │
  │     └── BitDepth == 32 or 64 (per channel)?
  │           → Expect float-class. Prepare for im2double no-op.
  │
  ├── Step 2: Read
  │     img = imread(file);
  │     Check: does file have alpha? → [img, ~, alpha] = imread(file)
  │
  ├── Step 3: Normalize
  │     imgNorm = im2double(img);
  │
  ├── Step 4: Validate and correct (CRITICAL)
  │     │
  │     ├── max(imgNorm(:)) > 1.0?
  │     │     → Float-class with values outside [0,1]
  │     │       im2double was a no-op.
  │     │       FIX: imgNorm = rescale(imgNorm, 0, 1);
  │     │       Alternatives: mat2gray (IPT), manual img/max(img(:))
  │     │
  │     ├── max(imgNorm(:)) < 0.1 AND image is uint16?
  │     │     → Possible bit-depth mismatch
  │     │       Check imfinfo BitDepth per channel.
  │     │       If BitDepth < 16: data uses sub-range of container.
  │     │       FIX: imgNorm = double(img) / (2^bitsPerChannel - 1);
  │     │
  │     └── Values in [0, 1]?
  │           → Normalization succeeded. Proceed.
  │
  ├── Step 5: Process (if applicable)
  │     │
  │     ├── Relative operation (brighten by %, threshold at 50%)?
  │     │     → Work in [0,1] domain
  │     │       processed = min(max(imgNorm * factor, 0), 1);
  │     │
  │     └── Absolute operation (subtract background 100)?
  │           → Work in native domain (skip im2double)
  │             result = max(double(img) - value, 0);
  │
  ├── Step 6: Display
  │     │
  │     ├── Data in [0,1]?
  │     │     → imshow(imgNorm)
  │     │
  │     └── Data outside [0,1] (float-class, or pre-normalization)?
  │           → imshow(rescale(img, 0, 1))   % works for RGB and grayscale
  │             NOTE: imshow(img, []) only auto-scales grayscale, not RGB
  │
  └── Step 7: Write
        │
        ├── Output format accepts double? (PNG, TIFF)
        │     → imwrite(imgNorm, path) works directly for [0,1] double
        │
        ├── Output format requires uint8? (JPEG)
        │     ├── Data in [0,1]?
        │     │     → Suggest im2uint8 (IPT) or uint8(round(imgNorm*255))
        │     │
        │     └── Data NOT in [0,1]?
        │           → STOP. Cannot convert. Inform customer.
        │
        └── Want to preserve uint16?
              → Suggest im2uint16 (IPT) or uint16(round(imgNorm*65535))
```

## Edge Cases by Image Type

### Float-class TIFF (e.g., satellite, scientific data)

- **Signature:** `class(img) == 'double'` or `'single'`, `max(img(:)) >> 1.0`
- **imfinfo clue:** BitDepth = 32 (single) or 64 (double) per channel
- **What im2double does:** Nothing — returns input unchanged
- **Agent failure mode:** Reports values like mean=240.9 as "normalized"
- **Detection:** `max(imgNorm(:)) > 1.0` after `im2double`
- **Correction:** `imgNorm = rescale(imgNorm, 0, 1);`

### 12-bit JPEG in uint16 container

- **Signature:** `class(img) == 'uint16'`, `imfinfo.BitDepth == 12`
- **What im2double does:** Divides by 65535 (uint16 max), not 4095 (12-bit max)
- **Agent failure mode:** Reports max=0.009, image appears near-black
- **Detection:** `max(imgNorm(:)) < 0.1` AND `imfinfo.BitDepth/channels < 16`
- **Correction:** `imgNorm = double(img) / (2^bitsPerChannel - 1);`

### Indexed PNG/GIF

- **Signature:** `imfinfo.ColorType == 'indexed'`
- **What single-output imread does:** Returns colormap indices (0–247), not actual colors
- **What im2double does on indices:** Divides indices by 255 → meaningless values
- **Agent failure mode:** Treats colormap indices as grayscale intensities
- **Detection:** `imfinfo` check BEFORE imread
- **Correction:** Use `[X, cmap] = imread(file)` then `ind2rgb(X, cmap)` (core MATLAB — no toolbox needed)

### RGBA PNG (transparency)

- **Signature:** `imfinfo.BitDepth == 32` for truecolor (8 bits × 4 channels)
- **What single-output imread does:** Returns only RGB, alpha silently discarded
- **Detection:** `imfinfo.BitDepth / 3 > 8` for truecolor, or presence of Transparency field
- **Customer communication:** "This image has an alpha (transparency) channel. Single-output imread discards it. Use `[img, ~, alpha] = imread(file)` to preserve transparency."

## Validation and Correction Template

Copy-paste ready validation block that detects and corrects normalization issues:

```matlab
function imgNorm = validateAndCorrectNormalization(imgNorm, img, info)
%validateAndCorrectNormalization Fix im2double output if normalization failed.
    arguments
        imgNorm double
        img
        info struct
    end

    maxVal = max(imgNorm(:));

    % Fix 1: Float-class no-op — rescale to [0,1]
    if maxVal > 1.0
        imgNorm = rescale(imgNorm, 0, 1);
        return
    end

    % Fix 2: Sub-range usage (bit-depth mismatch) — use actual bit depth
    bitsPerChannel = info.BitDepth / max(size(imgNorm, 3), 1);
    if isa(img, 'uint16') && bitsPerChannel < 16
        expectedMax = (2^bitsPerChannel - 1) / 65535;
        if maxVal < expectedMax * 1.5
            imgNorm = double(img) / (2^bitsPerChannel - 1);
        end
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
