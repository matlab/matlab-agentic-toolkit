# Batch Pipeline for Multiple Images

When the user has several representative images from their application and wants a reusable pipeline, build a function that processes any image from that domain. Develop the pipeline on 2-3 sample images, then generalize.

## Pipeline Function Template

```matlab
function results = ocrPipeline(imagePath, opts)
% ocrPipeline  OCR pipeline tuned for [application domain]
%   results = ocrPipeline(imagePath) reads text from the image.
%   results = ocrPipeline(imagePath, CharacterSet="0-9") constrains output.
arguments
    imagePath (1,1) string
    opts.CharacterSet (1,1) string = ""
    opts.LayoutAnalysis (1,1) string = "word"
end

I = imread(imagePath);
Igray = im2gray(I);

% Preprocessing tuned for this application
BW = imbinarize(Igray);
if mean(BW(:)) > 0.5
    BW = imcomplement(BW);  % Fix polarity
end
if size(I,1) < 50
    Igray = imresize(Igray, 4, "bicubic");
    BW = imbinarize(Igray);
end

% Recognition
ocrArgs = {"LayoutAnalysis", opts.LayoutAnalysis};
if opts.CharacterSet ~= ""
    ocrArgs = [ocrArgs, {"CharacterSet", opts.CharacterSet}];
end
results = ocr(BW, ocrArgs{:});
end
```

## Workflow for Building a Batch Pipeline

1. Run the full diagnostic workflow (Steps 1-5) on 2-3 representative images
2. Identify which preprocessing steps are common across all images
3. Wrap those steps into a function with `arguments` block for configurability
4. Test on all sample images — verify consistent results
5. Save as a `.m` file the user can call in a loop or with `imageDatastore`

## Processing All Images in a Folder

```matlab
% Process all images in a folder
imds = imageDatastore("path/to/images");
allText = strings(numel(imds.Files), 1);
for i = 1:numel(imds.Files)
    results = ocrPipeline(imds.Files{i}, CharacterSet="0123456789");
    allText(i) = strtrim(results.Text);
end
```

## Tips

- Start with the hardest image in the set — if your pipeline handles the worst case, it handles the rest
- Use `CharacterSet` to constrain output if all images contain the same character domain (e.g., serial numbers = digits + uppercase letters)
- Add early exit: if `ocr()` returns high confidence on raw grayscale, skip heavy preprocessing
- Log per-image confidence so the user can spot which images need manual review


----
Copyright 2026 The MathWorks, Inc.
----
