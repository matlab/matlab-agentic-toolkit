# Demo: VGGT (Git Repo + requirements.txt, Point Cloud Output)

Pattern: **C** — git clone + requirements.txt, with 3D point cloud visualization.

## Setup

```matlab
terminate(pyenv); clear MPyReq

MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.gitrepo("https://github.com/facebookresearch/vggt.git");
reqTxt = MPyReq.pathTo("vggt") + filesep + "requirements.txt";
MPyReq.requirementTextFile(reqTxt, Name="vggtPackages");
```

## Reference Python Code

```python
import torch
from vggt.models.vggt import VGGT
from vggt.utils.load_fn import load_and_preprocess_images

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.bfloat16 if torch.cuda.get_device_capability()[0] >= 8 else torch.float16

model = VGGT.from_pretrained("facebook/VGGT-1B").to(device)

image_names = ["path/to/imageA.png", "path/to/imageB.png", "path/to/imageC.png"]
images = load_and_preprocess_images(image_names).to(device)

with torch.no_grad():
    with torch.cuda.amp.autocast(dtype=dtype):
        predictions = model(images)
```

## Inference

```matlab
model = py.vggt.models.vggt.VGGT.from_pretrained("facebook/VGGT-1B").to("cuda");

image_names = {'1.jpeg', '2.jpeg', '3.jpeg'};
images = py.vggt.utils.load_fn.load_and_preprocess_images(image_names).to("cuda");
py.torch.no_grad();
py.torch.cuda.amp.autocast(dtype="torch.bfloat16");
predictions = model(images);

% Extract and visualize point cloud
wp = double(predictions{'world_points'}.cpu().detach().numpy());
xyz = permute(squeeze(wp(1,1,:,:,:)), [1 2 3]);
c = im2uint8(permute(squeeze(wp(1,:,:,:,1)), [2 3 1]));
pcshow(xyz);
figure, montage(image_names);
```

## Notes

- Uses `.from_pretrained()` which auto-downloads weights from HuggingFace — no `MPyReq.weights()` needed.
- `torch.no_grad()` and `torch.cuda.amp.autocast()` are called as functions (not context managers) since MATLAB cannot use `with` statements.
- Dict-style output access uses `predictions{'world_points'}` syntax.
- Point cloud output is visualized with `pcshow` — requires Computer Vision Toolbox.
- Multi-image input is passed as a cell array of filenames.

----

Copyright 2026 The MathWorks, Inc.

----
