---
name: matlab-integrate-pytorch-vision
description: >-
  Creates MATLAB interfaces to Python image processing and computer vision models
  from GitHub repositories or pip-installable packages using MPyReq.
  Use when asked to interface MATLAB with a Python CV/image model (segmentation,
  depth estimation, object detection, image generation, super-resolution, etc.),
  given a GitHub repo URL for an image/vision model, or asked to create an MPyReq
  demo for a deep-learning vision pipeline.
  Do NOT use for general-purpose Python-MATLAB interfacing, non-vision models (NLP,
  tabular, audio), model deployment/serving, or MATLAB-only image processing workflows.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MPyReq MATLAB Interface Builder

Build a MATLAB interface to a Python/PyTorch model repository using the MPyReq framework.

## When to Use

- User asks to interface MATLAB with a Python image processing or computer vision model (segmentation, depth estimation, object detection, image generation, super-resolution, pose estimation, optical flow, salient object detection, etc.)
- User provides a GitHub repository URL for a vision/image model and wants to call it from MATLAB
- User asks to "create an MPyReq wrapper" or "MPyReq demo" for an image/CV model
- User wants to run a pip-installable vision model library (e.g., Cellpose, SAM2, Depth-Pro, BiRefNet, StarDist) from MATLAB

## When Not to Use

- General-purpose Python-MATLAB interfacing (no vision/image model involved)
- Non-vision models: NLP, audio, tabular, reinforcement learning, time-series
- Model deployment, containerization, or inference servers
- Pure MATLAB image processing workflows with no Python dependency
- Creating Python code (this skill creates MATLAB code that calls Python)

## Prerequisites: MPyReq on the MATLAB Path

Before generating any demo script, verify that MPyReq is available. Run `which MPyReq` via the MATLAB MCP server (if available) or ask the user to confirm.

### If MPyReq is NOT on the MATLAB path:

1. **Download MPyReq** from the MATLAB File Exchange:
   https://mathworks.com/matlabcentral/fileexchange/182230-matlab-based-python-requirements-manager
2. **Install it** — either:
   - Open the downloaded `.mltbx` file in MATLAB (double-click), which installs it as a MATLAB Add-On automatically, or
   - Extract the files and add the folder containing `MPyReq.m` to the MATLAB path:
     ```matlab
     addpath("/path/to/mpyreq");
     savepath; % persist across sessions
     ```
3. **Verify** by running `which MPyReq` in MATLAB — it should return the path to `MPyReq.m`.

Do not proceed with demo generation until MPyReq is confirmed on the path.

## Input

Ask the user for:
1. **GitHub repository URL** — the Python model repository to interface with
2. **What the model does** (optional) — to help identify the right inference example

## Step 1: Analyze the Repository

Fetch and analyze the GitHub repository to determine:

- **Python version requirement** — check `setup.py`, `setup.cfg`, `pyproject.toml`, or README for the required Python version. Default to `"3.12"` if not specified. Use `"3.11"` if the project needs older compatibility.
- **Installation method** — determine how the project is installed:
  - If it uses `torch.hub.load()`: only need `torch` and `torchvision` as pip packages (model downloads automatically)
  - If it's a pip-installable package: use `MPyReq.pipPackage()`
  - If it's a non-packaged git repo: use `MPyReq.gitrepo()` + `MPyReq.requirementTextFile()` if a `requirements.txt` exists
  - If it needs `pip install git+<url>`: use `MPyReq.pipPackage("git+<url>", Name="<ProjectName>")`
- **Additional dependencies** — any extra pip packages needed (e.g., `torch`, `torchvision`, etc.)
- **Model weights** — determine how weights are loaded:
  - `torch.hub.load()` — weights download automatically, no `MPyReq.weights()` needed
  - Direct URL download — use `MPyReq.weights()` with the checkpoint URL
  - HuggingFace `.from_pretrained()` — weights download automatically via the library
- **Inference example** — locate the primary inference/prediction code in the README or example scripts
- **Preprocessing requirements** — check if the model requires specific input normalization (e.g., ImageNet mean/std), resizing, or center cropping

## Step 2: Generate the MPyReq Setup Script

Create a MATLAB `.m` file that sets up the Python environment. Follow these patterns from the demo files:

### MANDATORY: Installation folder setup
Every generated script MUST begin with `MPyReq.setInstallFolder()`. This tells MPyReq where to download Python, packages, and model weights. Without this, MPyReq will show a GUI dialog which blocks non-interactive execution. Also include `MPyReq.autoAcceptDownloadPrompts(true)` to avoid interactive confirmation prompts.

```matlab
% Set installation folder (SSD recommended, ~15+ GB free space)
% Change this path to a suitable location on your machine
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
```

### Pattern A: Simple pip package (like Cellpose)
```matlab
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("<package_name>");
```

### Pattern B: Git repo as pip package (like SAM2)
```matlab
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("git+https://github.com/<org>/<repo>.git", Name="<RepoName>");
```

### Pattern C: Git repo + requirements.txt (like VGGT, BiRefNet)
```matlab
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.11");
MPyReq.gitrepo("https://github.com/<org>/<repo>.git");
reqTxt = MPyReq.pathTo("<repo>") + filesep + "requirements.txt";
MPyReq.requirementTextFile(reqTxt, Name="<repo>Packages");
```

### Pattern D: torch.hub model (like DINOv2, ResNet, etc.)
When the model uses `torch.hub.load()`, no git clone or weights download is needed — just install torch/torchvision:
```matlab
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("3.12");
MPyReq.pipPackage("torch");
MPyReq.pipPackage("torchvision");
% Model loads automatically via torch.hub:
model = py.torch.hub.load('org/repo', 'model_name');
```

### Weights download pattern
Only needed when weights are NOT handled by `torch.hub.load()` or `.from_pretrained()`:
```matlab
MPyReq.weights("<weights_url>", DownloadTo=MPyReq.pathTo("<RepoName>") + filesep + "checkpoints");
```

## Step 3: Create the MATLAB Inference Interface

Translate the Python inference example to MATLAB. Refer to these resource files for conversion rules and patterns:

- [references/python_matlab_conversions.md](references/python_matlab_conversions.md) — Python-to-MATLAB syntax conversion table
- [references/image_conversion_patterns.md](references/image_conversion_patterns.md) — Image tensor conversions (MATLAB to Python and back), dimension reordering, display patterns

## Step 4: Assemble the Final Script

Create a single `demo<ModelName>.m` file with clear sections:

```matlab
%% Setup Python Environment
% Start with clean state (only if switching projects)
% terminate(pyenv); clear MPyReq

% Set installation folder (SSD recommended, ~15+ GB free space)
% Change this path to a suitable location on your machine
MPyReq.setInstallFolder(fullfile(tempdir, "MPyReq"));
MPyReq.autoAcceptDownloadPrompts(true);
MPyReq.python("<version>");
% ... package installation calls ...

%% Reference Python Code
%{
<paste the original Python inference code as a comment block>
%}

%% Load Model
% ... model loading code ...

%% Run Inference
% ... load input, run model, extract results ...

%% Visualize Results
% ... display/plot results ...
```

## Step 5: Test with MATLAB MCP Server

Check if a MATLAB MCP server tool is available in the current session (look for MCP tools like `matlabRunCode`, `matlab_run`, or similar).

### If MATLAB MCP server IS available:

1. **Run the setup section** — execute the `MPyReq.python()` and package installation calls through the MATLAB MCP server to verify the Python environment installs correctly.
2. **Run the inference section** — execute the model loading and inference code to verify end-to-end functionality.
3. **Iterate on errors** — if any step fails, read the error output, fix the generated code, and re-run.

#### Attempt Limit and Graceful Fallback

Track each fix-and-retry cycle as one attempt. **Stop after a maximum of 5 attempts** (combined across setup and inference). If the code is not fully working after 5 attempts:

1. **Stop iterating.** Do not continue retrying the same or similar approaches.
2. **Save the best version** of `demo<ModelName>.m` — the version that got furthest (e.g., setup succeeded but inference failed, or partial inference ran).
3. **Return the script to the user** with a structured handoff:

```
## What Works
- <list sections/steps that executed successfully>

## What Needs Attention
- <describe the remaining failure: error message, which line/section fails>
- <root cause hypothesis if known>

## Recommended Next Steps
1. <most likely fix — e.g., "Try Python 3.11 instead of 3.12 due to package compatibility">
2. <alternative approach — e.g., "Install system dependency X before running">
3. <manual verification — e.g., "Run `pip install <pkg>` in the MPyReq venv directly to check build logs">

## Environment Details
- Python version attempted: <version>
- Platform: <OS>
- Errors encountered: <brief summary of distinct errors across attempts>
```

4. **Mark clearly in the script** which sections are verified vs. unverified using comments:
```matlab
%% Setup Python Environment — VERIFIED
% ... (code that ran successfully) ...

%% Run Inference — NEEDS MANUAL VERIFICATION
% The following section encountered errors during automated testing.
% See recommended next steps above.
% ... (best-effort code) ...
```

#### Early exit conditions (stop before 5 attempts):

- **Same error repeats 2+ times** with no new information — stop immediately
- **Environment/platform issue** outside MATLAB's control (e.g., missing system library, network block, GPU driver mismatch) — stop and report
- **Package build failure** requiring system-level intervention (e.g., C compiler missing, CUDA version mismatch) — stop and report

### If MATLAB MCP server is NOT available:

1. **Return the generated `demo<ModelName>.m` file** to the user.
2. Provide **setup instructions** summarizing:
   - Prerequisites (MATLAB version, MPyReq on path)
   - The MPyReq commands that will run and what they install
   - Expected first-run behavior (downloads Python, packages — may take several minutes)
   - How to run: open the script in MATLAB and run section-by-section (`Ctrl+Enter`)
3. Note any **platform-specific considerations** (e.g., Windows CUDA setup, `UV_EXTRA_INDEX_URL`).

## Important Notes

- **NEVER modify the cloned repository's source code** (e.g., editing config files, patching Python modules) without explicitly asking the user for permission first. If a workaround requires source edits, describe the change and let the user decide.
- **NEVER use Python dunder methods** (`__enter__`, `__exit__`, `__init__`, etc.) in MATLAB — double underscores are invalid MATLAB syntax. For context managers like `torch.no_grad()` or `torch.inference_mode()`, use the equivalent functional API (e.g., `py.torch.set_grad_enabled(false/true)`) instead of the `with` statement pattern.
- **Always permute outputs back to MATLAB dimension ordering** — PyTorch uses NCHW (batch first, channels second). MATLAB expects batch last and channels second-to-last (H x W x C x B). Use `permute` to reorder, then `squeeze` to remove singleton batch dims.
- **Convert bounding boxes to MATLAB format** — Python models typically return `[x1, y1, x2, y2]` (corner pairs). MATLAB expects M x 4 as `[startX, startY, width, height]`. Convert with: `boxes(:,3) - boxes(:,1)` for width, `boxes(:,4) - boxes(:,2)` for height.
- **Always use `imread`** for loading images — never use Python image libraries (PIL, OpenCV, etc.). Keep image I/O on the MATLAB side and convert to tensors for Python.
- Always include the original Python inference code as a `%{ %}` comment block for reference
- Use `py.importlib.import_module()` when direct `py.module.submodule` doesn't work (deep nesting)
- For Windows GPU/CUDA support, note that `UV_EXTRA_INDEX_URL` may need to be set
- If the repo requires `cd` to a specific directory (e.g., for relative config paths), use `cd(MPyReq.pathTo("<Name>"))`
- Test that the generated code handles both GPU and CPU paths where applicable
- Keep the MATLAB interface idiomatic — use MATLAB image types, display functions, and data structures

For additional gotchas (class ID mapping, opencv-python issues, `insertObjectAnnotation` tips), see [references/common_gotchas.md](references/common_gotchas.md).

## Reference Files

The following reference files are bundled with this skill. Read them from the skill's `references/` directory:

### Demo examples (expected output format)
- [references/demo-cellpose.md](references/demo-cellpose.md) — simple pip package pattern
- [references/demo-sam2.md](references/demo-sam2.md) — git+pip pattern with weights
- [references/demo-depthpro.md](references/demo-depthpro.md) — git repo + pip install pattern with weights
- [references/demo-birefnet.md](references/demo-birefnet.md) — git repo + requirements.txt + weights
- [references/demo-stardist.md](references/demo-stardist.md) — complex dependency management
- [references/demo-vggt.md](references/demo-vggt.md) — git repo + requirements.txt, point cloud output

### Conversion guides
- [references/python_matlab_conversions.md](references/python_matlab_conversions.md) — Python-to-MATLAB syntax conversion table
- [references/image_conversion_patterns.md](references/image_conversion_patterns.md) — Image tensor conversions and display patterns
- [references/common_gotchas.md](references/common_gotchas.md) — Class ID mapping, opencv-python issues, annotation tips

### MPyReq documentation
- [references/readme.md](references/readme.md) — MPyReq documentation overview

The MPyReq class is in the project's `mpyreq/MPyReq.m`.

## Skill Feedback

If this skill's guidance was wrong, incomplete, or didn't work, emit a plain-text
feedback marker in your response, then continue with the task.

Format: `IPCV-SKILL-FEEDBACK [matlab-integrate-pytorch-vision] [category]: what failed; what you did instead`
Categories: `wrong-command` (incorrect/outdated), `missing-guidance` (omitted step),
`discovery-failure` (suggested approach didn't work), `platform-issue` (environment-specific)

----

Copyright 2026 The MathWorks, Inc.

----
