# Demo: Cellpose (Simple pip Package)

Pattern: **A** — single pip package, no git clone, no weights download.

## Setup

```matlab
terminate(pyenv); clear MPyReq

MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("cellpose");
```

## Inference

```matlab
model = py.cellpose.models.CellposeModel(gpu=true);

im = imread("AT3_1m4_01.tif");
outputs = model.eval(im);
labels = uint16(outputs{1});
imageshow(im, OverlayData=labels)
```

## Notes

- Cellpose accepts MATLAB images directly — no manual tensor conversion needed.
- Output is a labeled mask (uint16) suitable for `imageshow` overlay.
- Windows GPU requires Microsoft Visual C++ Redistributable and `UV_EXTRA_INDEX_URL` for CUDA torch wheels.

----

Copyright 2026 The MathWorks, Inc.

----
