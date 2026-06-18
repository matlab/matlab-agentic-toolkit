---
name: matlab-enhance-camera-image
description: >
  Read BEFORE troubleshooting or enhancing camera image quality.
  Diagnoses and enhances image quality from cameras connected via Image Acquisition
  Toolbox or USB Webcams support package. Discovers camera capabilities at runtime,
  analyzes captured images for quality issues (brightness, contrast, sharpness, noise,
  color balance, backlighting), suggests hardware setting adjustments tailored to the
  specific camera, and applies Image Processing Toolbox enhancement functions. Use when
  a user wants to improve camera image quality, troubleshoot dark/blurry/noisy/grainy/
  overexposed/washed out/color cast images, or optimize camera settings.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

## Purpose

Diagnose image quality issues from any connected camera and improve them through a combination of hardware setting adjustments and software post-processing. Operates in a hardware-first, software-second philosophy: always try to fix at the source before resorting to post-processing.

## When to Use

- User complains about poor image quality from a camera (too dark, blurry, noisy, washed out)
- User asks how to improve or optimize camera settings
- User captures an image and wants to enhance it
- User mentions backlit subject, underexposed, overexposed, or out of focus

## When NOT to Use

- General image processing on files not from a camera (use IPT directly)
- Building an image acquisition pipeline from scratch (use Image Acquisition Toolbox docs)
- Camera geometric calibration (use Camera Calibrator app)

## Reference Documents (load when needed)

- Read [references/diagnosis-guidance.md](references/diagnosis-guidance.md) for detailed metric thresholds and backlight detection algorithms
- Read [references/hardware-tuning-guidance.md](references/hardware-tuning-guidance.md) for property discovery patterns, camera-type property tables, and safe adjustment strategies (applicable to all camera types)
- Read [references/enhancement-guidance.md](references/enhancement-guidance.md) for IPT function parameters, pipeline ordering, and common errors

## Script Entrypoints

- `scripts/diagnoseImageQuality.m` — reusable diagnostic function; takes an image, returns a struct of quality metrics with assessments

## Hard Requirements

- Call `detect_matlab_toolboxes` first to confirm Image Acquisition Toolbox and Image Processing Toolbox are installed
- Call `check_matlab_code` on any script before executing it
- Never hardcode camera property names — always discover at runtime

## Protocol

### Step 1 — Connect and Discover Camera Capabilities

**API selection:** When Image Acquisition Toolbox is available, always prefer `videoinput` over other interfaces like `webcam()`. `videoinput` exposes more properties (via `propinfo`), supports bulk frame acquisition (`getdata`), and provides `FramesAcquiredFcn` for streaming. Use `webcam()` only when Image Acquisition Toolbox is not installed and the user has the MATLAB Support Package for USB Webcams instead.

Connect to the camera and enumerate all available properties:

```matlab
% For videoinput (preferred when Image Acquisition Toolbox is available):
vid = videoinput(adaptorName, deviceID, format);
vid.ReturnedColorSpace = 'rgb';  % Critical for YUY2 cameras
src = getselectedsource(vid);
props = properties(src);

% For webcam (fallback when only USB Webcams support package is installed):
cam = webcam();
props = properties(cam);
```

Classify each discovered property by function:

| Problem Domain | Common Property Names |
|---|---|
| Brightness/Exposure | Exposure, ExposureTime, ExposureMode, Brightness, Gain, BacklightCompensation |
| Focus | Focus, FocusMode |
| Color | WhiteBalance, WhiteBalanceMode, Hue, Saturation, ColorEnable |
| Contrast/Tone | Contrast, Gamma, Sharpness |

Record valid ranges for each property. Report discovered capabilities to the user.

For properties that do NOT match the classification table above, apply the advanced property investigation protocol:
1. Group unrecognized properties by naming pattern (e.g., names containing "Trigger", "Pixel", "Bin", "LUT", "ROI", "Offset", "Decimation")
2. For `videoinput` sources, use `propinfo(src, propName)` to determine type, constraint, range, and read-only status
3. Classify as **quality-relevant** (likely affects image appearance: Binning, BlackLevel, LUT, DigitalGain, HDR) vs **functional** (affects acquisition mode, not quality: TriggerMode, PixelFormat, PacketSize, AcquisitionFrameRate)
4. Report all discovered properties to the user, distinguishing standard (known) from advanced (discovered)
5. For quality-relevant unknowns, follow the safe investigation protocol in [references/hardware-tuning-guidance.md](references/hardware-tuning-guidance.md)

### Step 2 — Capture Baseline Image

**For videoinput objects (preferred):**

```matlab
% Warm up the camera (critical — first frames are often blank or poorly exposed)
preview(vid);
pause(2);
closepreview(vid);

% Capture the reference image
baselineImg = getsnapshot(vid);
imshow(baselineImg);
title("Baseline Image");
```

**For webcam objects (fallback):**

```matlab
% Warm up the camera (critical — first frames are often blank or poorly exposed)
preview(cam);
pause(2);
closePreview(cam);

% Capture the reference image
baselineImg = snapshot(cam);
imshow(baselineImg);
title("Baseline Image");
```

Note: `snapshot()` is webcam-only. For videoinput, use `getsnapshot(vid)`. Both `webcam` and `videoinput` objects support `preview()`.

Record current property values as baseline for comparison.

### Step 3 — Understand User Concern

Before running diagnostics, identify what the user is trying to fix:

- If the user already stated a specific complaint (e.g., "image is too dark", "I see banding"), note it as the primary concern
- If the user has not stated a specific issue, ask: "What specific quality issue are you seeing, or would you like me to run a general assessment?"
- If the user says "just make it better" or has no specific concern, proceed with the standard 6-metric evaluation only

Map the user's concern to one of these categories:
- **Standard metrics** (covered by `diagnoseImageQuality.m`): brightness, contrast, sharpness, noise, color balance, backlighting
- **Extended concerns** (require dynamic inline evaluation): vignetting, banding/striping, saturation clipping, flicker/inconsistency, chromatic aberration, distortion, or other

If the concern is an extended one, note it for dynamic evaluation in Step 4.

### Step 4 — Diagnose Image Quality

Run the diagnostic script (always — provides the standard baseline):

```matlab
addpath("scripts");
results = diagnoseImageQuality(baselineImg);
disp(results);
```

The function returns a struct with fields:
- `brightness` — mean intensity, assessment
- `clipping` — highlight clipping (% pixels ≥ 250) and shadow clipping (% pixels ≤ 5), assessment
- `contrast` — standard deviation, assessment
- `sharpness` — Laplacian variance, assessment
- `noise` — estimated noise level, assessment
- `colorBalance` — R/G and B/G ratios, assessment
- `backlightRatio` — center-vs-border brightness ratio, assessment

Each field has `.value` (numeric or struct) and `.assessment` ("OK", "Problem", or "Severe").

Identify the primary issue(s) — focus on fields assessed as "Problem" or "Severe".

**Dynamic evaluation for extended concerns:** If the user's concern from Step 3 is not covered by the standard 6 metrics, generate inline MATLAB code to evaluate it. See [references/diagnosis-guidance.md](references/diagnosis-guidance.md) § "Extended Metrics" for evaluation patterns and code templates. Report the extended metric result alongside the standard results.

### Step 5 — Suggest Hardware Adjustments

Map diagnosed problems to available camera properties using the decision table below. Only suggest adjustments for properties the camera actually has.

Apply settings, re-capture, and compare metrics. Change one property at a time.

**For videoinput objects (preferred):**

```matlab
% Example: increase exposure for dark image
src.Exposure = src.Exposure + 2;
newImg = getsnapshot(vid);
newResults = diagnoseImageQuality(newImg);
```

**For webcam objects (fallback):**

```matlab
% Example: increase exposure for dark image
cam.Exposure = cam.Exposure + 2;
newImg = snapshot(cam);
newResults = diagnoseImageQuality(newImg);
```

Note: With videoinput, set properties on the source object (`src`), not the videoinput object. Use `getsnapshot(vid)` instead of `snapshot()`.

Iterate if needed until metrics improve or hardware options are exhausted.

### Step 6 — Apply Post-Processing Enhancement

Based on remaining issues after hardware adjustment, apply IPT functions in the correct order:

1. **Brighten** (if still dark): `imlocalbrighten`, `imadjust`, gamma correction
2. **Contrast** (if still flat): `locallapfilt`, `adapthisteq` on luminance channel
3. **Sharpen** (if still soft): `imsharpen` — always last

```matlab
enhanced = baselineImg;

% Example: brighten a backlit image
enhanced = imlocalbrighten(enhanced, 0.8);

% Example: enhance local contrast
enhanced = locallapfilt(enhanced, 0.3, 1.5);

% Example: sharpen (last step)
enhanced = imsharpen(enhanced, 'Radius', 1.5, 'Amount', 1.0);
```

Display before/after comparison:

```matlab
montage({baselineImg, enhanced}, 'Size', [1 2]);
title("Before vs After Enhancement");
```

### Step 7 — Report and Generate Reusable Pipeline

Summarize the full workflow:
1. Original problem identified
2. Hardware adjustments applied and their effect
3. Software enhancements applied
4. Final metrics comparison (before vs after)

**Generate a reusable `.m` function file** that the user can call for future captures without the agent. Write it to a user-specified folder if provided, otherwise to the current MATLAB working directory (`pwd`). Do NOT write it to the skill's `scripts/` folder — that is reserved for the skill's own helper functions.

After writing the file:
- Run `check_matlab_code` on it to verify syntax
- Show the user how to call it
- Explain which settings and enhancements are baked in

#### Single-Shot Pipeline

The function should:
1. Connect to the camera with the discovered adaptor, device ID, and format
2. Set `ReturnedColorSpace = 'rgb'` if the camera outputs YUY2 or other non-RGB format
3. Apply the tuned hardware property settings that improved metrics
4. Warm up the camera (discard initial frames)
5. Capture a frame
6. Apply only the post-processing steps that measurably improved quality (in correct order)
7. Clean up (stop and delete the videoinput object)
8. Return the enhanced image

## Decision Table

| Diagnosed Problem | Hardware Fix (if available) | Software Fix (IPT) |
|---|---|---|
| Subject too dark (backlit) | BacklightCompensation ↑, Exposure ↑, Brightness ↑ | `imlocalbrighten`, inverted `imreducehaze` |
| Overall underexposed | Exposure ↑, Gain ↑, Brightness ↑ | Gamma correction (`.^ 0.7`), `imadjust` |
| Overall overexposed | Exposure ↓, Brightness ↓ | `imadjust` with output range `[0 0.8]` |
| Low contrast | Contrast ↑, Gamma adjust | `locallapfilt`, `adapthisteq` on luminance |
| Motion blur | Exposure ↓ (faster shutter) | `imsharpen` (limited), deconvolution |
| Out of focus | Focus adjust (if available) | `imsharpen` (limited help) |
| High noise | Gain ↓, Exposure ↑ instead | `imgaussfilt`, `imnlmfilt`, `wiener2` |
| Color cast | WhiteBalance adjust, WhiteBalanceMode=auto | Manual white point correction |
| Washed out | Gamma ↓, Contrast ↑ | `imadjust`, `locallapfilt` |

## Generated Pipeline Templates

Replace placeholders with discovered values. Only include enhancement steps that measurably improved metrics.

### Single-Shot Template (videoinput)

```matlab
function img = acquireEnhancedImage()
%acquireEnhancedImage Capture and enhance image from <camera name>.
%   img = acquireEnhancedImage() returns an enhanced RGB image.

    vid = videoinput('<adaptor>', <deviceID>, '<format>');
    vid.ReturnedColorSpace = 'rgb';
    src = getselectedsource(vid);

    % Tuned hardware settings
    src.<Property1> = <value>;
    src.<Property2> = <value>;

    % Warm up
    preview(vid);
    pause(2);
    closepreview(vid);

    % Capture
    img = getsnapshot(vid);
    delete(vid);

    % Enhancement pipeline (only steps that helped)
    img = imlocalbrighten(img, <amount>);
    img = imgaussfilt(img, <sigma>);
end
```

Naming: use `acquireEnhancedImage` as default, or ask user for a preferred name. Follow lowerCamelCase. See [references/enhancement-guidance.md](references/enhancement-guidance.md) § "Generating Reusable Functions" for parameterization and optional-input guidance.

## Gotchas

- **`localtonemap` requires `single` input** — always convert with `im2single()` first; passing uint8 throws an error
- **Camera warm-up is critical** — first 5–10 frames are often blank or poorly exposed. Use `preview()` or discard initial snapshots before capturing
- **`adapthisteq` (CLAHE) needs a single-channel image** — apply on V channel (HSV) or L channel (Lab), not directly on RGB
- **Prefer Exposure over Gain** — when a camera has both, increasing Exposure gives cleaner results; Gain amplifies noise
- **BacklightCompensation range varies** — some cameras 0–1, others 0–2, others 0–255. Always check range at runtime
- **`imlocalbrighten` only lifts dark regions** — preserves already-bright areas; preferred over global brightness increase for backlit scenes
- **Post-processing order matters** — brighten first, then local contrast, then sharpen last. Sharpening amplifies noise if applied before denoising
- **Auto modes override manual values** — set ExposureMode/WhiteBalanceMode to manual before adjusting the corresponding value
- **Resolution changes may reset properties** — re-check property values after changing resolution
- **YUY2 cameras need `ReturnedColorSpace = 'rgb'`** — many USB webcams (e.g., Microsoft LifeCam) only output YUY2. Without setting `vid.ReturnedColorSpace = 'rgb'`, `getsnapshot` returns raw YCbCr data misinterpreted as RGB, causing wrong colors in display AND incorrect results from IPT functions and diagnostic metrics
- **`snapshot` vs `getsnapshot`** — `snapshot(cam)` is webcam-only; `getsnapshot(vid)` is for videoinput objects. They are not interchangeable
- **`closePreview` vs `closepreview`** — webcam uses camelCase `closePreview(cam)`; videoinput uses lowercase `closepreview(vid)`. Using the wrong case throws "Undefined command/function"
- **videoinput prefers bulk `getdata`** — for multi-frame capture with videoinput, use `getdata(vid, N)` instead of looping `getsnapshot`. It fetches N frames in one call with less overhead and lets the adaptor run at full speed
- **Use `fullfile` for file saves** — when saving images or generated files, use `fullfile(pwd, 'filename.png')` to avoid path resolution errors across platforms

----

Copyright 2026 The MathWorks, Inc.

----
