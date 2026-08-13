# Code Generation Workflow (Shared)

Common code generation steps for both PyTorch (.pt2) and LiteRT (.tflite)
models using the MATLAB Coder Support Package for PyTorch and LiteRT Models.

This reference covers the shared mechanics — MEX generation, verification,
library/executable generation, and conventions. For framework-specific details
(load functions, data layout, entry-point examples), see `pytorch-workflow.md`
or `litert-workflow.md`.

## Entry-Point Pattern

Both frameworks follow the same entry-point structure:

```matlab
function out = mInvoke(modelPath, input) %#codegen
    model = <loadFunction>(modelPath);
    out = invoke(model, input);
end
```

Where `<loadFunction>` is `loadPyTorchExportedProgram` (PyTorch) or
`loadLiteRTModel` (LiteRT).

**Why `coder.Constant` for the model path:** The model file path must be known
at compile time so the code generator can resolve the model at build time.
Pass it as `coder.Constant("model.pt2")` or `coder.Constant("model.tflite")`
in the `-args` list.

**Alternative:** Hardcode the path directly in the entry-point:

```matlab
function out = mInvoke(input) %#codegen
    model = loadLiteRTModel("/path/to/model.tflite");
    out = invoke(model, input);
end
```

## Generate MEX

Always generate and verify a MEX first before proceeding to library or
executable targets.

**CPU MEX:**

```matlab
cfg = coder.config("mex");
input = ones(<shape>, "single");  % match model's inputSpecifications
codegen -config cfg -args {coder.Constant("model_file"), input} mInvoke
```

**CUDA MEX (GPU acceleration):**

```matlab
cfg = coder.gpuConfig("mex");
input = ones(<shape>, "single");  % match model's inputSpecifications
codegen -config cfg -args {coder.Constant("model_file"), input} mInvoke
```

Key points:
- `coder.Constant` makes the model filename a compile-time constant
- Input shape and type must match `inputSpecifications` exactly
- PyTorch uses NCHW layout; LiteRT uses NHWC layout

## Verify MEX Output

Compare MEX output against MATLAB reference to confirm numeric equivalence:

```matlab
refOut = mInvoke("model_file", input);
mexOut = mInvoke_mex("model_file", input);
testCase = matlab.unittest.TestCase.forInteractiveUse;
testCase.verifyThat(mexOut, matlab.unittest.constraints.IsEqualTo(refOut, ...
    'Within', matlab.unittest.constraints.AbsoluteTolerance(single(1e-5))));
```

## Generate Library/Executable

Once MEX is verified, generate production code:

**CPU targets:**

```matlab
cfgLib = coder.config("lib");   % static library
codegen -config cfgLib -args {coder.Constant("model_file"), input} mInvoke
```

Other CPU targets: `coder.config("dll")` (dynamic library),
`coder.config("exe")` (executable).

**CUDA targets:**

```matlab
cfgLib = coder.gpuConfig("lib");   % CUDA static library
codegen -config cfgLib -args {coder.Constant("model_file"), input} mInvoke
```

Other CUDA targets: `coder.gpuConfig("dll")`, `coder.gpuConfig("exe")`.

## coder.DeepLearningConfig

The MATLAB Coder Support Package for PyTorch and LiteRT Models path **ignores**
`coder.DeepLearningConfig`. It generates code directly from the model object
without requiring an external deep learning library (cuDNN, MKL-DNN, TensorRT).
Setting it won't cause errors but has no effect.

To explicitly disable DL library backends (ensuring plain-C codegen):

```matlab
cfg.DeepLearningConfig = coder.DeepLearningConfig("none");
```

See `dnn-codegen-options.md` for details on DL target library configuration.

## Conventions

- Always check `inputSpecifications` for correct input shape and type
- Always generate MEX first, verify numerics, then proceed to lib/exe
- Always use `coder.Constant` for the model file path argument
- Input data is typically single-precision (check `inputSpecifications`)
- Do NOT use `coder.loadDeepLearningNetwork` or `dlarray` on this path
- For generic performance tuning (SIMD, OpenMP), see the `matlab-generate-code` skill
- For DNN-inference-specific tuning (weight serialization, DLTargetLibrary),
  see `dnn-codegen-options.md`

----

Copyright 2026 The MathWorks, Inc.

----
