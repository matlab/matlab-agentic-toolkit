# Eval Fixture Files

Fictional dummy networks for eval `deep-learning-pitch-plugin`. These are
minimal dlnetworks (a few layers each) created solely for codegen tracing
during `validateAudioPlugin`. They produce meaningless output — they exist
only so the eval can run end-to-end without real pretrained weights.

| File | Input Layer | Output | Purpose |
|------|-------------|--------|---------|
| `crepe_tiny.mat` | imageInputLayer([1024 1 1]) | 360 classes | Pitch detection (CREPE-style) |
| `vad_model.mat` | featureInputLayer(512) | 1 sigmoid | Voice activity detection |
| `noise_classifier.mat` | imageInputLayer([256 1 1]) | 4 classes | Noise type classification |

----

Copyright 2026 The MathWorks, Inc.
