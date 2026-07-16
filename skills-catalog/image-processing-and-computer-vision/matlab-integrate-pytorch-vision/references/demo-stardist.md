# Demo: StarDist (Complex Dependency Management)

Pattern: **A** with extra complexity — multiple pip packages with version conflict resolution.

## Setup

```matlab
terminate(pyenv); clear MPyReq

useGPU = false;

MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("setuptools");
MPyReq.pipPackage("stardist");

if useGPU
    tfName = "tfcuda";
    MPyReq.pipPackage("tensorflow[and-cuda]", Name=tfName);
else
    tfName = "tf";
    MPyReq.pipPackage("tensorflow", Name=tfName);
end

% Remove newer numpy due to compatibility issues
% See: https://github.com/stardist/stardist/issues/291
isNumPy2Removed = false;
numpy2str = MPyReq.pathTo("stardist") + filesep + "numpy-2*";
numpy2dir = dir(numpy2str);
if ~isempty(numpy2dir)
    toDelete = dir(MPyReq.pathTo("stardist") + filesep + "numpy*");
    for i = 1:length(toDelete)
        if isfolder(fullfile(toDelete(i).folder, toDelete(i).name))
            rmdir(fullfile(toDelete(i).folder, toDelete(i).name), "s");
        else
            delete(fullfile(toDelete(i).folder, toDelete(i).name));
        end
    end
    isNumPy2Removed = true;
end

numpy2str = MPyReq.pathTo(tfName) + filesep + "numpy-2*";
numpy2dir = dir(numpy2str);
if ~isempty(numpy2dir)
    toDelete = dir(MPyReq.pathTo(tfName) + filesep + "numpy*");
    for i = 1:length(toDelete)
        if isfolder(fullfile(toDelete(i).folder, toDelete(i).name))
            rmdir(fullfile(toDelete(i).folder, toDelete(i).name), "s");
        else
            delete(fullfile(toDelete(i).folder, toDelete(i).name));
        end
    end
    isNumPy2Removed = true;
end

if isNumPy2Removed
    terminate(pyenv); clear MPyReq
    MPyReq.python("3.12");
    MPyReq.pipPackage("setuptools");
    MPyReq.pipPackage("stardist");
    if useGPU
        MPyReq.pipPackage("tensorflow[and-cuda]", Name=tfName);
    else
        MPyReq.pipPackage("tensorflow", Name=tfName);
    end
end

% Install and use older numpy
MPyReq.pipPackage("numpy==1.26.4");
```

## Inference

```matlab
model = py.stardist.models.StarDist2D().from_pretrained('2D_versatile_fluo');
model.config.use_gpu = useGPU;

im = uint8(py.stardist.data.test_image_nuclei_2d());
ims = im2single(im);
outputs = model.predict_instances(ims);
labels = uint16(outputs{1});
imageshow(im, OverlayData=labels)
```

## Notes

- Demonstrates handling numpy version conflicts by manually removing incompatible numpy 2.x and pinning to 1.26.4.
- After removing packages from the install folder, `terminate(pyenv); clear MPyReq` is required to reload the environment.
- GPU/CPU toggle requires a full environment reset if changed after initial setup.
- Uses `.from_pretrained()` which auto-downloads model weights.
- StarDist accepts `im2single` input directly — no manual NCHW conversion needed.

----

Copyright 2026 The MathWorks, Inc.

----
