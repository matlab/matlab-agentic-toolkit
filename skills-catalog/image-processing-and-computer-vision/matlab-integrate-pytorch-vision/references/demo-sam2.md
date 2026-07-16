# Demo: SAM2 (Git+pip Package with Weights)

Pattern: **B** — pip-installable git repo + explicit weights download.

## Setup

```matlab
terminate(pyenv); clear MPyReq

MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("git+https://github.com/facebookresearch/sam2.git", ...
    Name="SAM2");
MPyReq.weights("https://dl.fbaipublicfiles.com/segment_anything_2/092824/" + ...
    "sam2.1_hiera_tiny.pt", ...
    DownloadTo=MPyReq.pathTo("SAM2") + filesep + "sam2" + filesep + "checkpoints");
```

## Reference Python Code

```python
import torch
from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor
checkpoint = "./checkpoints/sam2.1_hiera_large.pt"
model_cfg = "configs/sam2.1/sam2.1_hiera_l.yaml"
predictor = SAM2ImagePredictor(build_sam2(model_cfg, checkpoint))
with torch.inference_mode(), torch.autocast("cuda", dtype=torch.bfloat16):
    predictor.set_image(<your_image>)
    masks, _, _ = predictor.predict(<input_prompts>)
```

## Inference

```matlab
build_sam2 = py.importlib.import_module('sam2.build_sam').build_sam2;
SAM2ImagePredictor = py.importlib.import_module('sam2.sam2_image_predictor').SAM2ImagePredictor;
checkpoint = MPyReq.pathTo("SAM2") ...
    + filesep + "sam2" + filesep + "checkpoints" + filesep + "sam2.1_hiera_tiny.pt";
model_cfg = "configs/sam2.1/sam2.1_hiera_t.yaml";
predictor = SAM2ImagePredictor(build_sam2(model_cfg, checkpoint));

im = imread("AT3_1m4_02.tif");
im = repmat(im, [1 1 3]);  % SAM needs RGB
predictor.set_image(im);

point_coords_py = py.torch.tensor(int32([70, 300; 70 300]));
point_labels_py = py.torch.tensor(int32([1, 1]));
outputs = predictor.predict(point_coords=point_coords_py, ...
    point_labels=point_labels_py);
mask = single(outputs{1});
mask = permute(mask, [2 3 1]);
imageshow(labeloverlay(im, mask(:,:,3)))
```

## Notes

- Uses `py.importlib.import_module` for deep submodule access.
- SAM2 requires RGB input — replicate grayscale with `repmat(im, [1 1 3])`.
- Mask output is permuted from Python's CHW to MATLAB's HWC ordering.
- The `with torch.inference_mode()` context manager is NOT used — MATLAB cannot call dunder methods.

----

Copyright 2026 The MathWorks, Inc.

----
