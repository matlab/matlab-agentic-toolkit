# Demo: BiRefNet (Git Repo + requirements.txt + Weights)

Pattern: **C** — git clone + requirements.txt + explicit weights download.

## Setup

```matlab
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.11");
MPyReq.gitrepo("https://github.com/ZhengPeng7/BiRefNet.git");
recTxt = MPyReq.pathTo("BiRefNet") + filesep + "requirements.txt";
MPyReq.requirementTextFile(recTxt, Name="BiRefNetPackages");
MPyReq.weights("https://github.com/ZhengPeng7/BiRefNet/releases/download/v1/BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth");
```

## Inference

```matlab
birefnet = py.models.birefnet.BiRefNet(bb_pretrained=false);

modelPath = MPyReq.pathTo("BiRefNet-general-bb_swin_v1_tiny-epoch_232") ...
    + filesep + "BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth";
state_dict = py.torch.load(modelPath, map_location="cpu", weights_only=true);
state_dict = py.utils.check_state_dict(state_dict);
birefnet.load_state_dict(state_dict);
birefnet.to("cuda");
birefnet.eval();

im = imread("peppers.png");

% Convert to required input form (NCHW tensor)
inp = im2single(im);
if ismatrix(inp)
    inp = repmat(inp, [1 1 3]);
end
inp = imresize(inp, [1024 1024]);
inp = reshape(inp, [1 size(inp)]);
inp = permute(inp, [1 4 2 3]);
inp = py.torch.tensor(inp).to("cuda");

preds = birefnet(inp);

% Convert back to MATLAB image
mask = double(preds{1}.sigmoid().cpu().detach().numpy());
mask = squeeze(mask);
mask = imresize(mask, size(im, [1 2]));

imshowpair(im, mask, "montage");
```

## Notes

- Demonstrates full NCHW tensor conversion pipeline (MATLAB HWC → PyTorch NCHW).
- Output uses `.sigmoid()` to convert logits to probabilities before extracting.
- Mask is resized back to original image dimensions for overlay.
- The model requires editing `config.py` to select the backbone variant matching the weights file — see the `[6]` index in the backbone list.
- If `pyenv` is already loaded, edits to Python source files require `terminate(pyenv); clear all` to take effect.

----

Copyright 2026 The MathWorks, Inc.

----
