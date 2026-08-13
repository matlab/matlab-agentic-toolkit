---
name: workflow-12-3d-asset-generation
description: Generate 3D mesh assets from a single high-resolution camera image using imageAssetGenerator (TripoSR-based). Output is mesh/texture suitable for RoadRunner import or drivingScenario actor mesh. Loaded when user wants to create custom 3D assets from a photo.
---

# Workflow 12 — Generate 3D Assets from Camera Images

> **Parent skill:** [`SKILL.md`](../SKILL.md) — Loaded when user mentions generating 3D assets from photos, custom RoadRunner assets from images, or TripoSR.

Use `imageAssetGenerator` to create 3D mesh assets from a single high-resolution camera image. The image should show the object's 3D structure clearly (most of the object visible from one viewpoint).

```matlab
%% Generate 3D asset from a single camera image
assetGen = imageAssetGenerator;  % Uses TripoSR model

% Image should be high-res with the object prominently visible
img = imread("tree_photo.jpg");
[mesh, texture] = generate(assetGen, img);

% mesh: surfaceMesh or extendedObjectMesh
% Can be saved as .fbx/.obj for RoadRunner import
% Or used directly as vehicle/actor mesh in drivingScenario
```

**Best practices:**
- Use high-resolution images (cropped tightly around the object)
- Ensure most of the 3D structure is visible (not just one flat face)
- Works well for: trees, vehicles, barriers, poles, buildings, custom props
- Output can be imported into RoadRunner as a custom asset

**Python-SPKG install errors (`imageAssetGenerator` is Python-backed via TripoSR):** if construction or first run fails with a `proxyError`, `SSL: CERTIFICATE_VERIFY_FAILED`, `SSLConnectionError`, or `ReadTimeoutError: HTTPSConnectionPool(host='download.pytorch.org', ...)`, this is a known customer-network issue, not a MATLAB bug. Load [`python-spkg-install-troubleshooting.md`](python-spkg-install-troubleshooting.md) for the symptom→fix matrix (proxy / SSL → set `http_proxy`+`https_proxy`; PyTorch read timeout → reinstall the SPKG).

----

Copyright 2026 The MathWorks, Inc.

----
