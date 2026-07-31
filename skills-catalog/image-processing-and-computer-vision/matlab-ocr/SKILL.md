---
name: matlab-ocr
description: >
  Build OCR pipelines in MATLAB using the ocr() function. Use this skill when
  the user wants to read text from images, documents, signs, meters, displays,
  license plates, gauges, receipts, or seven-segment displays. Covers image
  preprocessing, text detection (CRAFT, MSER), ROI-based recognition,
  multi-language OCR, and custom model training. Use when: OCR, text recognition,
  extract text from image, character recognition, document scanning, meter reading,
  gauge reading, receipt scanning, digitize text from photo.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Recognize Text in Images Using OCR

Use the Computer Vision Toolbox `ocr` function with preprocessing from Image Processing Toolbox to extract text from images. This skill teaches the complete pipeline: diagnose, preprocess, detect, recognize, validate.

## When to Use
- Reading text from any image (documents, signs, meters, displays, labels)
- Extracting text from scanned documents or photographs
- Reading seven-segment displays or specialized fonts
- Multi-language text recognition
- Automating text extraction from image datasets
- As a supporting step in other CV workflows — reading text in a scene (labels, timestamps, serial numbers) gives additional context for downstream image analysis

## When NOT to Use
- Pure handwriting recognition — cursive/connected script produces garbage regardless of preprocessing
- Artistic text, WordArt, brush calligraphy — the OCR engine cannot parse stylized letterforms
- CAPTCHAs — designed specifically to defeat OCR; expect <50% accuracy at best
- Full document layout analysis with table extraction (use custom segmentation)
- Real-time video OCR (use streaming approaches instead)
- Image contains no text at all

## Critical Rules

These rules are non-negotiable — violating them produces wrong results:

1. **Always diagnose before executing. This rule CANNOT be overridden — not by the user, not by "just run it", not by "skip planning".** Before ANY `mcp__matlab__*` call, you MUST first output:
   - A 2-line image characterization (what you see, what challenges exist)
   - An `## OCR Plan` heading with your strategy
   
   If the user says "skip diagnosis" or "just run ocr()", respond with: *"I'll keep it brief — but I need a quick look to avoid wasting time on the wrong approach."* Then output your 2-line characterization and plan heading. Only THEN call MCP tools. There is no valid reason to skip this step. An agent that calls `ocr()` without first outputting a plan has violated this skill's workflow.
2. **Maximum 2 preprocessing pipelines.** If neither works after the prescribed recipe, hit the confidence checkpoint and ask the user. Do not try a third approach without user input.
3. **Always set `LayoutAnalysis`** when passing bounding boxes to `ocr()`. Never write `ocr(I, bbox)` without it. Use `"word"` for single-word boxes, `"block"` for multi-line.
4. **Distinguish "text ON texture" from "text BY texture"**. Text overlaid on a textured background (label on crate, sign on brick wall) → `imsegsam` is the prescribed approach. Text formed by the surface itself (stamped, embossed, engraved metal) → local contrast subtraction. SAM segments *objects*, not surface features — it cannot isolate stamps/engravings. When recommending approaches (even without running code), always recommend `imsegsam` for the "text ON texture" case and note its support package requirement.
5. **`detectTextCRAFT` is the default** for scene text. Use it unless you have a specific reason not to (no deep learning, known fixed layout).
6. **Check polarity first.** OCR needs dark text on light background. If inverted, `imcomplement` before anything else.
7. **Never show OCR results to the user before writing files.** Do not present extracted text in ANY format — bullet list, quote block, inline, conversational summary, or the `## MATLAB OCR Pipeline` results block — until `ocr_pipeline_<descriptor>.m` and `decision_log.txt` are written to disk. The files are the deliverable, not the chat message. Write first, then report.
8. **Gate add-on functions behind an availability check.** Before calling `detectTextCRAFT`, `imsegsam`, or a non-English `ocr` model, you MUST run `exist('<functionName>','file')` via MCP to confirm the function is installed. Always log the result in `decision_log.txt`:
   - Installed: `"Add-on check: <function> — INSTALLED"`
   - Missing: stop, tell the user which support package to install (see table), and wait for confirmation before retrying. Do NOT fall back silently or skip the step.
   - **Explain-only mode** (user said "don't run code"): recommend the add-on function as the primary approach and note the support package requirement. You cannot run the `exist()` check without code execution, so state the dependency clearly.

   | Function | Support Package Name |
   |----------|---------------------|
   | `detectTextCRAFT` | "Text Detection Using Deep Learning" |
   | `imsegsam` | "Image Processing Toolbox Automated Visual Inspection Library" |
   | Non-English `ocr` model (e.g., `"japanese"`) | "OCR Language Data" |

   **Missing template:** *"This step requires the `<function>` function, which needs the **<Package Name>** support package. Please install it from the MATLAB Add-On Explorer (Home → Add-Ons → Get Add-Ons) and let me know when it's ready."*

## Anti-Patterns — Do NOT Do This

- **Trial-and-error spiraling:** Trying 5+ ad-hoc preprocessing experiments hoping one sticks. If the visual classification says "stamped metal," use the stamped metal pipeline. Period.
- **Skipping the plan:** "I'll just try one quick thing first." No. Diagnose → plan → execute.
- **Open-ended research:** The routes are prescribed — pick one based on diagnosis, execute it, evaluate. This is not exploratory research.
- **Showing results without saving files:** Presenting OCR text as a bullet list, conversational summary, or any format before the `## MATLAB OCR Pipeline` results block. That block can only appear after files are written to disk. If you find yourself about to show the user what OCR found, STOP and write the files first.

## Workflow

### Progress Reporting + Output Template

Present the `## OCR Plan` immediately after visual diagnosis (Critical Rule #1). Then execute the pipeline. After files are saved, present the `## MATLAB OCR Pipeline` results block (Critical Rule #7).

#### OCR Plan (output before any MATLAB code runs)

```
## OCR Plan

**Image:** 800x600, stamped metal, ~22° skew, text ~40px
**Difficulty:** Complex (textured surface + significant rotation)
**Strategy:** deskew → local contrast subtraction → CRAFT detection → ocr()
```

For simple images:

```
## OCR Plan

**Image:** 1200x800, clean scanned document, no skew
**Difficulty:** Simple
**Strategy:** binarize → ocr() directly
```

#### Results Block (output ONLY after files are written to disk)

```
## MATLAB OCR Pipeline: SUCCESS

**Pipeline:** deskew (22.6°) → local contrast subtraction → CRAFT detection → ocr() per region

| Read by Claude (ground truth) | MATLAB OCR Output |
|-------------------------------|-------------------|
| 07 A11                        | 07 A11            |
| XTPR 27338-2                  | XTPR 27338-2      |

**Metrics** (via `evaluateOCR`): CER 0.00 | WER 0.00
**Files written:**
- `ocr_pipeline_stamped_metal.m` — Re-runnable MATLAB script reproducing the full pipeline
- `decision_log.txt` — Diagnosis, routing decisions, and confidence scores
```

For failures:

```
## MATLAB OCR Pipeline: FAILED

**Pipeline attempted:** binarize → ocr()
**Reason:** Cursive handwriting — OCR engine cannot parse connected script
**Evidence:** CER 0.91 | WER 1.00

| Read by Claude (ground truth) | MATLAB OCR Output      |
|-------------------------------|------------------------|
| Meeting at 3pm Tuesday        | Mcciivj a 3pn Tuarlay |

**Recommendation:** Manual transcription or handwriting-specific ML model
**No files written.**
```

#### GATE (Critical Rule #7)

Do NOT present the `## MATLAB OCR Pipeline` results block until files are confirmed on disk. No bullet lists, no quotes, no summaries — nothing that reveals extracted text before files are written.

### Step 1: Diagnose

**Always start here.** Look at the image, visually read the text (this becomes your ground truth), classify the image, and present the `## OCR Plan` — all before any MATLAB code runs.

Your visual classification determines the preprocessing route:

| Visual Classification | Preprocessing Route |
|----------------------|-------------------|
| Clean document, minimal skew | Binarize → OCR directly (skip to Step 4) |
| Low contrast / uneven lighting | `imtophat` or `adapthisteq` → binarize |
| Stamped / embossed / engraved (text IS the surface) | Local contrast subtraction (Step 2) |
| Text overlaid on textured background (label on crate, sign on wall) | `imsegsam` SAM segmentation (Step 3) |
| Significant skew (>10°) | Deskew FIRST, then preprocess |
| Tiny text (<50px) | `imresize` 4-8x first |

After classification, confirm via MATLAB: binarization check, skew measurement, and quick experiments.

```matlab
% TEMPLATE — not executable
I = imread("yourImage.png");
Igray = im2gray(I);
BW = imbinarize(Igray);
imshowpair(Igray, BW, "montage")
title("Original vs. What OCR Sees")
```

**Skew measurement must be deterministic.** The centroid fitting method is sensitive to which blobs are included. To ensure reproducibility:
- Use ALL text-sized blobs (filter by area range, e.g., 50-5000px), not "top N by area"
- Alternatively, use the Hough transform (`hough` + `houghpeaks` + `houghlines`) on edges for a robust angle estimate
- The pipeline `.m` script must reproduce the exact same skew angle on re-run — if it doesn't, the deskew approach is fragile and must be replaced

**Binarization diagnostic:**
- Text clearly legible → Skip to Step 4
- Text faint/merged/noisy → Preprocessing (Step 2)
- White on black → `imcomplement`
- Too small (<50px) → `imresize` 4-8x
- Rotated/skewed → Deskew BEFORE other preprocessing
- Characters too bold/bleeding → `imerode(BW, strel("disk",1))`
- Characters too thin/broken → `imdilate(BW, strel("disk",1))`
- Dark borders/scan frame → `imclearborder(BW)` or crop
- Metal texture dominates → Local contrast subtraction

**Escalation rule:** If 2+ preprocessing attempts still produce garbled results or <80% confidence, identify the root cause:
- **Image too small (sub-50px)?** → Resize 4-8x is the fix
- **Text overlaid on textured background?** → `imsegsam` (SAM)
- **Text formed by surface texture (stamped/embossed)?** → Local contrast subtraction
- **Font unrecognizable (handwriting, calligraphy)?** → OCR engine limitation; consider `trainOCR`

**MANDATORY Confidence warning:** High confidence does NOT guarantee correctness. OCR can report >0.9 confidence on completely wrong text, especially on small or unusual images. Always validate results against expected content.

### Step 2: Preprocess the Image

Apply preprocessing based on your diagnosis. See [reference/preprocessing-guide.md](reference/preprocessing-guide.md) for full code examples.

**Pipeline routing:**

| Classification | Method | Key function |
|---------------|--------|-------------|
| Uneven lighting | Top-hat illumination correction | `imtophat` + `imreconstruct` |
| Stamped/embossed/engraved | Local contrast subtraction | `imgaussfilt(Igray,30) - Igray` |
| Skewed >10° | Deskew FIRST via centroid fitting | `imrotate` |
| Small text <50px | Scale up 4-8x | `imresize` |
| Inverted polarity | Complement | `imcomplement` |

**Key rules:**
- **Deskew BEFORE other preprocessing** — rotation invalidates morphological operations
- OCR expects **dark text on light background** — use `imcomplement` if inverted
- For small clean images, try OCR on resized grayscale before binarizing — anti-aliasing helps
- Add **10px white border** with `padarray(BW, [10 10], 1)` if text touches edges

### Step 3: Detect Text Regions (Critical)

**For natural scenes (street signs, product labels, meter faces), isolating text regions before calling `ocr` is critical.** These images have complex backgrounds that confuse the OCR engine. For scanned documents with uniform backgrounds, this step is less important — `ocr` has built-in page layout analysis that handles well-formatted documents automatically.

**Default choice: `detectTextCRAFT`.** Unless you have a specific reason to use another method (no deep learning available, known fixed layout, etc.), always prefer CRAFT for scene text. It outperforms MSER on complex backgrounds.

**MANDATORY before using CRAFT or SAM:** Run `exist('detectTextCRAFT','file')` or `exist('imsegsam','file')` via MCP. If the result is `0`, stop and ask the user to install the required support package (Critical Rule #8). Do NOT proceed without confirmation.

Choose a detection method based on your image type:

| Image Type | Method | When to Use |
|-----------|--------|-------------|
| Natural scene (signs, products) | `detectTextCRAFT` | Preferred for complex backgrounds |
| Document with sparse text | `detectMSERFeatures` | Classic approach, no deep learning needed |
| Known fixed location | Manual ROI `[x y w h]` | Consistent image layout (e.g., meter face always in same spot) |
| Text on uniform background | `regionprops` on binary | Find connected components by area/aspect ratio |
| Color-distinct text | Color segmentation | Isolate text by color channel thresholding |
| Text overlaid on textured background | `imsegsam` (SAM) | Label on crate, sign on brick wall (text is a separate object) |
| Simple clean document | None (use `ocr` directly) | Clean scans with uniform background |

**SAM warning:** Do NOT use SAM for stamped, embossed, engraved, or etched text — these are surface features, not objects. Use **local contrast subtraction** (Step 2) instead. SAM takes ~60-120s and needs full resolution (never downscale).

See [reference/detection-methods.md](reference/detection-methods.md) for code examples of each method (CRAFT, MSER, SAM, manual ROI, connected components, color segmentation).

### Step 4: Recognize Text

**RULE: Always set `LayoutAnalysis` when passing bounding boxes to `ocr()`.** Never call `ocr(I, bbox)` without it — the default `"auto"` fails on small regions. Use `"word"` for single-word boxes, `"block"` for multi-line regions.

Common patterns: `ocr(I)`, `ocr(I, bbox, LayoutAnalysis="word")`, `ocr(BW, CharacterSet="0123456789")`, `ocr(I, roi, Model="seven-segment", LayoutAnalysis="word")`. See [reference/function-reference.md](reference/function-reference.md) for full examples.

**If detection succeeded but recognition returns garbage:** The problem is preprocessing or skew, not detection. Return to Step 2:
- Skew >10° causes total failure even on clean binary images
- Try local contrast subtraction if the image is textured
- Try OCR on preprocessed grayscale rather than binary — anti-aliasing helps

### Step 5: Validate Results

Filter by `results.WordConfidences > 0.7`. Check `results.CharacterConfidences` for suspect characters. See [reference/function-reference.md](reference/function-reference.md) for validation code patterns.

**MANDATORY ACTION: Run `evaluateOCR` with ground truth.**

You MUST compute OCR metrics using `evaluateOCR`. The ground truth is either:
1. **Text you (Claude) read visually from the image** — use this by default
2. **Text the user provided** — use this if the user supplies expected text or corrects your read

Run this via MCP after recognition:

```matlab
% evaluateOCR signature:
%   metrics = evaluateOCR(ocrTextObj, groundTruthCellArray)
%   - ocrTextObj: the ocrText object returned directly by ocr()
%   - groundTruthCellArray: cell array of strings, one per expected text region
metrics = evaluateOCR(results, {"07 A11"; "XTPR 27338-2"});
fprintf("Character Error Rate (CER): %.2f\n", metrics.CharacterErrorRate);
fprintf("Word Error Rate (WER): %.2f\n", metrics.WordErrorRate);
```

Always run `evaluateOCR` via MCP and report the actual CER and WER values.

**MANDATORY ACTION: Confidence checkpoint — when to ask the user:**

If ANY of these are true, show the user what you got and ask them to confirm or correct:
- Mean word confidence < 0.6
- CER > 0.10 or WER > 0.20
- You attempted 2+ preprocessing approaches and results still look wrong
- The recognized text doesn't make semantic sense AND you can't read it yourself in the image
- OCR returns fewer words than you can visually count in the image

Ask clearly: *"I'm not confident in this result. OCR returned `[text]` (CER: 0.12, WER: 0.20). Can you tell me what the text actually says? I'll use that to tune the pipeline."*

If the user provides ground truth, re-run `evaluateOCR` with the corrected ground truth and adjust preprocessing to minimize CER/WER.

**After validation, proceed immediately to Step 6 — do not present results until files are on disk.**

### Step 6: Save Pipeline + Log

**Save the pipeline as a `.m` script** that is re-runnable on different images. Never hardcode values computed interactively — include all detection code (skew angle measurement, threshold selection, ROI detection).

**Naming:** `ocr_pipeline_<descriptor>.m` (e.g., `ocr_pipeline_stamped_metal.m`)

**MANDATORY Requirements:**
- Include comments explaining each DECISION (why this approach, not just what)
- Always show diagnostic figures (`imshowpair`, `insertShape` for bounding boxes, `insertObjectAnnotation` for boxes and text)
- Use `detectTextCRAFT` + per-region `ocr()` with `CharacterSet` and `LayoutAnalysis="word"` for textured/complex images (not full-image `LayoutAnalysis="block"` which gives lower confidence)
- Always include timestamp of when file is created. And include comment that says "Created using matlab-ocr Skill".
**Also produce a `decision_log.txt`** — one line per decision point, format: `[step] TYPE: description`. Types: VISUAL, EXPERIMENT, DECISION, RESULT, GAP. Example:

```
[1] VISUAL: Stamped metal, ~20° skew, embossed characters
[2] DECISION: Local contrast subtraction (stamped text confirmed)
[3] EXPERIMENT: Centroid fitting → skew angle = 22.6°
[4] RESULT: "07 AN / XTPR 27338-2" — confidence 0.74 mean
[5] GAP: "A11" misread as "AN" — thin stamps merge at this resolution
```
This file is what the user sends back if the skill didn't fully work.

## Quick Reference

**LayoutAnalysis rule:** Always set `LayoutAnalysis` when passing ROI boxes (`"word"`, `"block"`, or `"none"`). Default `"auto"` fails on small regions.

**Key functions:** `ocr`, `detectTextCRAFT`, `imsegsam`, `imbinarize`, `imtophat`, `imcomplement`, `imresize`, `bwareaopen`, `imrotate`. See [reference/function-reference.md](reference/function-reference.md) and [reference/batch-pipeline.md](reference/batch-pipeline.md).

## Custom Model Training

**MANDATORY: Present the gating checklist BEFORE recommending training.** Train only if ALL are true: (1) preprocessing + parameter tuning still fails, (2) font/charset not in built-in models, (3) you have labeled ground truth, (4) use case is high-volume/repeated. Try first: `Model="seven-segment"`, `Model="french"`, `CharacterSet`, `LayoutAnalysis`.

**Programmatic API (always use these, not the ocrTrainer app):** `trainOCR`, `ocrTrainingOptions`, `ocrTrainingData`. See [reference/training-guide.md](reference/training-guide.md) for full workflow.

## Multi-Language Support

**MANDATORY before using a non-English model:** Run `exist('ocrLanguageData','dir')` via MCP. If the result is `0`, stop and ask the user to install the "OCR Language Data" support package (Critical Rule #8). Do NOT proceed without confirmation.

Use `Model="japanese"` (or `"french-fast"` for quantized). Requires OCR Language Data support package. See [reference/supported-languages.md](reference/supported-languages.md).

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Empty results | Light text on dark background | `imcomplement(imbinarize(Igray))` |
| Garbage characters | No preprocessing | Binarize, crop to ROI, use `CharacterSet` |
| "O"→"0" or "l"→"1" | Ambiguous glyphs | `CharacterSet` to exclude impossible chars |
| Seven-segment wrong | Layout splits lines | `LayoutAnalysis="word"` |
| Text too small | <20px tall | `imresize(I, 3)` before OCR |
| Words split oddly | Skewed text | Deskew via centroid fitting + `imrotate` |

**When OCR fails**, return to Step 1 and re-inspect the binarized output. Do not loop on unsolvable cases (cursive handwriting, CAPTCHAs, <30px text, curved/arc text) — tell the user early. See [reference/limitations.md](reference/limitations.md).

----

Copyright 2026 The MathWorks, Inc.

----
