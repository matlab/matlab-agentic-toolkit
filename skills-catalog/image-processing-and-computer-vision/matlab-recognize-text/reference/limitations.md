# OCR Limitations

**Tell the user early** when their image falls outside what MATLAB OCR can handle. Do not waste their time with endless preprocessing attempts on fundamentally unsolvable cases.

## Unsolvable Cases

| Image Type | Why OCR Cannot Work | What to Tell the User |
|---|---|---|
| Cursive handwriting | The OCR engine is trained on printed characters; connected script is unrecognizable regardless of preprocessing | "MATLAB's ocr() cannot read cursive handwriting. You would need a dedicated handwritten text recognition (HTR) model trained on handwriting datasets." |
| Artistic/brush calligraphy, WordArt | Stylized letterforms bear no resemblance to training data | "These decorative fonts are outside the OCR engine's capability. Consider trainOCR with labeled examples of this specific style." |
| CAPTCHAs | Intentionally designed to defeat automated text recognition | "CAPTCHAs are engineered to resist OCR. Expect <50% character accuracy even with heavy preprocessing." |
| Extremely degraded images (<30px text height) | Insufficient pixel information to distinguish characters even after upscaling | "The text is too small to recover — upscaling beyond 8-10x introduces more artifacts than information. A higher-resolution source image is needed." |
| Curved/arc text (badges, seals) | No single rotation straightens all characters; per-character segmentation is fragile | "Text on a curved path requires specialized dewarping. The skill's Hough deskewing handles linear skew, not arcs. Consider per-character detection or a custom approach." |

## How to Communicate Limitations

When you hit a limitation:

1. Inform the user clearly in 1-2 sentences
2. Explain *why* it won't work (not just that it won't)
3. Suggest the next step (trainOCR, higher-res source, different tool)

Do not silently loop through preprocessing attempts on a case you can diagnose as unsolvable from the initial inspection.

## Boundary Cases (Might Work with Effort)

| Image Type | Approach | Expected Outcome |
|---|---|---|
| Heavily degraded printed text | SAM + resize + CharacterSet constraint | ~60-80% accuracy possible |
| Non-Latin scripts (CJK, Arabic) | Built-in language models | Good for printed; fails on handwritten |
| Low-contrast embossed text | SAM segmentation | Works if texture provides contrast |
| Partially occluded text | Crop visible portions, OCR separately | Partial results only |


----
Copyright 2026 The MathWorks, Inc.
----
