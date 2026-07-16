# Demo: DepthPro (Git Repo + pip Install with Weights)

Pattern: **C variant** — git clone + pip install from git URL + explicit weights download.

## Setup

```matlab
terminate(pyenv); clear MPyReq

MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.9");
MPyReq.gitrepo("https://github.com/apple/ml-depth-pro", Name="DepthPro");
MPyReq.pipPackage("git+https://github.com/apple/ml-depth-pro", Name="DepthProPackages");
MPyReq.weights("https://ml-site.cdn-apple.com/models/depth-pro/depth_pro.pt", ...
    DownloadTo=MPyReq.pathTo("DepthPro") + filesep + "checkpoints");
```

## Reference Python Code

```python
from PIL import Image
import depth_pro

model, transform = depth_pro.create_model_and_transforms()
model.eval()

image, _, f_px = depth_pro.load_rgb(image_path)
image = transform(image)

prediction = model.infer(image, f_px=f_px)
depth = prediction["depth"]
focallength_px = prediction["focallength_px"]
```

## Inference

```matlab
% Expects ./checkpoints folder so cd to right folder
cd(MPyReq.pathTo("DepthPro"))

mt = py.depth_pro.create_model_and_transforms();
model = mt{1}; transform = mt{2};
model.eval();

im = imread('peacock.jpg');
pim = transform(im);

pres = model.infer(pim);

mres = struct(pres);
flen = double(mres.focallength_px.numpy());
depth = double(mres.depth.numpy());

imageshow(im)
imageshow(rescale(depth))
```

## Notes

- Requires `cd(MPyReq.pathTo("DepthPro"))` because the model loads config files via relative paths.
- Uses both `gitrepo` (for the source tree) and `pipPackage` (for installing the package) — needed when the model code references local files but also needs to be importable.
- Python dict output is converted via `struct(pres)` then field access.
- Depth output is a 2D matrix — use `rescale` for visualization.

----

Copyright 2026 The MathWorks, Inc.

----
