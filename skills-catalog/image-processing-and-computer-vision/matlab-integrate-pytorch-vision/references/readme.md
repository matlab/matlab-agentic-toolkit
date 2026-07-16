# MPyReq: MATLAB-Based Python Requirements Manager

## Overview

MPyReq is a MATLAB-based tool designed to simplify Python environment management for MATLAB projects. It simplifies installing and configuring Python environments for MATLAB projects by handling version management, package installation, Git repository cloning, and model file downloads through a streamlined API.

## Key Features

- **Python Version Management**: Specify and manage specific Python versions
- **Package Installation**: Install pip packages with dependency resolution
- **Git Integration**: Clone repositories directly
- **Model Downloads**: Fetch pre-trained models and weights
- **Environment Caching**: Maintain consistent configurations across sessions
- **Runtime Setup**: Automatic initialization on subsequent runs

## Setup Instructions

Users must first configure the installation directory:

```matlab
MPyReq.setInstallFolder(largeSSDFolder)
```

This one-time setup should point to a fast storage device (SSD recommended) with approximately 15+ GB available space, as the tool downloads substantial libraries and model files.

## Basic Usage

```matlab
% Initial setup with Python version and package
MPyReq.python("3.12");
MPyReq.pipPackage("cellpose");

% Access Python functionality
model = py.cellpose.models.CellposeModel(gpu=true);
outputs = model.eval(im);
```

## Example Workflows

The package includes demonstration scripts for:

- **demoCellpose**: Cell segmentation using Cellpose
- **demoStarDist**: Object detection with star-convex shapes
- **demoDepthPro**: Monocular depth estimation
- **demoSAM2**: Segment Anything Model 2
- **demoVGGT**: Visual Geometry Grounded Transformer
- **demoBiRefNet**: Bilateral reference segmentation

## Important Considerations

**Environment Conflicts**: The tool does not automatically resolve package version conflicts. When switching between projects with incompatible requirements, users should reset the environment:

```matlab
terminate(pyenv); clear MPyReq
```

**Platform Support**: Compatible with R2019b and later on Windows, macOS, and Linux. GPU-enabled PyTorch on Windows requires additional configuration via environment variables.

## Documentation

Access full documentation via `help MPyReq.m` in MATLAB.

----

Copyright 2026 The MathWorks, Inc.

----
