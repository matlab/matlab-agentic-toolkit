# Troubleshooting -- Pattern 2 (PyTorch/LiteRT Code Generation)

Common errors when using `loadPyTorchExportedProgram` and the PyTorch/LiteRT code
generation pipeline. Note: error messages may reference internal TOSA operations.

## Codegen Failures

### Error: DeepLearningConfig not set / library not found

**Cause:** Default config tries to use CUDNN/TensorRT/oneDNN which aren't installed.

**Fix:**
```matlab
cfg.DeepLearningConfig = coder.DeepLearningConfig('none');
```

This generates fully portable C with zero external dependencies.

### Error: Unsupported TOSA operation

**Cause:** A PyTorch op lowered to a TOSA primitive that MATLAB's backend doesn't implement yet.
This is rare but possible for uncommon ops.

**Diagnosis:**
```matlab
% The codegen error message will name the specific TOSA op
% e.g., "tosa.scatter is not supported for code generation"
```

**Fix options:**
1. Check if a newer MATLAB release supports the op (MathWorks adds TOSA coverage each release)
2. Restructure the PyTorch model to avoid the unsupported op before re-exporting
3. If the op is at the output stage (e.g., argmax, topk), consider removing it from the
   PyTorch model and implementing it in the MATLAB entry-point function instead

### Error: Input size mismatch

**Cause:** The `coder.typeof` input specification doesn't match what the .pt2 model expects.

**Fix:** The input type must exactly match the shape used during `torch.export`:
```matlab
% If PyTorch was exported with: torch.randn(1, 10, 5)
% Then MATLAB must use:
inputType = coder.typeof(single(zeros(1, 10, 5)), [1 10 5], [false false false]);
```

The third argument `[false false false]` means all dimensions are fixed (not variable-size).
For embedded codegen, all dimensions should be fixed.

---

## Import / Loading Failures

### Error: loadPyTorchExportedProgram not found

**Cause:** MATLAB Coder Support Package for PyTorch and LiteRT Models not installed.

**Fix:**
```matlab
% Check availability
exist('loadPyTorchExportedProgram', 'file')
```
Install via Add-On Explorer (Home > Add-Ons > Get Add-Ons).

### Error: Python environment not configured

**Cause:** MATLAB can't find Python with torch installed.

**Fix:**
```matlab
% Windows: pyenv('Version', 'C:\Users\<user>\AppData\Local\Programs\Python\Python311\python.exe')
% macOS/Linux: pyenv('Version', '/usr/local/bin/python3')
pyenv('Version', '<path to python executable>')
pyenv  % Verify -- should show the Python path and version
```

The Python environment must have `torch >= 2.0` installed.

### Error: Failed to load .pt2 file

**Cause:** The .pt2 file was created with an incompatible torch version, or the export was incomplete.

**Fix:**
1. Verify the .pt2 loads in Python first:
   ```python
   ep = torch.export.load('model.pt2')
   out = ep.module()(example_input)  # Should run without error
   ```
2. Re-export with the same torch version that MATLAB's support package expects
3. Ensure `model.eval()` was called before export

---

## Configuration Mistakes

### InstructionSetExtensions on wrong object

```matlab
% WRONG -- dlcfg does not have this property
dlcfg = coder.DeepLearningConfig('none');
dlcfg.InstructionSetExtensions = 'Neon v7';   % ERROR: Unrecognized property

% CORRECT -- it belongs to cfg (the coder config, not the DL config)
cfg.InstructionSetExtensions = 'Neon v7';
```

### Invalid hardware names

```matlab
% These are NOT valid Embedded Coder hardware names:
'ARM Cortex-A embedded platform'    % Not recognized
'ARM Cortex-A'                      % Not recognized
'STM32F746G-Discovery'              % Only if STM32 support pkg installed

% Valid names (require corresponding support packages):
'Raspberry Pi'
'BeagleBone Black'
'NVIDIA Jetson'
```

### OpenMP on single-core MCU

```matlab
% WRONG for Cortex-M (single-core) -- adds threading overhead for no benefit
cfg.EnableOpenMP = true;

% CORRECT for Cortex-M
cfg.EnableOpenMP = false;

% CORRECT for Cortex-A (quad-core) -- measured 3x speedup
cfg.EnableOpenMP = true;
```

---

## C Compilation Issues

### Missing MATLAB runtime headers

**Error:** `rtwtypes.h not found` or `tmwtypes.h not found`

**Fix:** Add MATLAB extern include path to your compiler command:
```bash
gcc -I"$MATLAB_ROOT/extern/include" ...
```

Where `MATLAB_ROOT` is typically:
- **Windows:** `C:\Program Files\MATLAB\R2026a`
- **macOS:** `/Applications/MATLAB_R2026a.app`
- **Linux:** `/usr/local/MATLAB/R2026a`

### Linker errors when using LargeConstantThreshold = 0

**Error:** Undefined reference to `fopen`, `fread` -- the generated code tries to load .bin files.

**Fix:** Ensure stdio is available on your target. For bare-metal MCU without a filesystem,
use a high `LargeConstantThreshold` value (or omit the setting) to embed weights inline:
```matlab
% For targets WITH filesystem (Linux, RTOS with FS)
cfg.LargeConstantThreshold = 0;  % Weights in .bin files

% For bare-metal targets WITHOUT filesystem
% Don't set LargeConstantThreshold -- weights inline in .c
```

### Wrong output from generated C

**Most common cause:** Input layout mismatch. The MLIR/TOSA path generates C code that expects
**column-major** input arrays. If you're feeding row-major data (the default in C/Python), the
results will be wrong.

**Fix:** Transpose in the test harness:
```c
// Row-major [t][f] --> column-major [t + f * SEQ_LEN]
for (int t = 0; t < SEQ_LEN; t++)
    for (int f = 0; f < NUM_FEATURES; f++)
        c_input[t + f * SEQ_LEN] = row_major_input[t * NUM_FEATURES + f];
```

See [`architecture-patterns.md`](architecture-patterns.md) for format details per model type.

---

## PyTorch Export Issues

### torch.export fails with dynamic control flow

**Error:** `torch._dynamo.exc.Unsupported: ...`

**Cause:** The model uses Python `if/else` on tensor values or data-dependent loops.

**Fix:** Restructure the model to use static control flow:
```python
# WRONG -- dynamic control flow
def forward(self, x):
    if x.sum() > 0:  # Data-dependent branch
        return self.path_a(x)
    else:
        return self.path_b(x)

# CORRECT -- static (always runs both, selects via mask)
def forward(self, x):
    a = self.path_a(x)
    b = self.path_b(x)
    mask = (x.sum() > 0).float()
    return a * mask + b * (1 - mask)
```

### torch.export fails with in-place operations

**Error:** `RuntimeError: Mutations on a value inside the trace`

**Cause:** In-place operations like `x.add_(y)` or `x[0] = val`

**Fix:** Replace with out-of-place equivalents:
```python
# WRONG
x.add_(y)

# CORRECT
x = x + y
```

---

## Diagnostic Commands

```matlab
% Check if support package is installed
exist('loadPyTorchExportedProgram', 'file')

% Check Python environment
pyenv

% Verify .pt2 loads
net = loadPyTorchExportedProgram('model.pt2');
out = net.invoke(single(randn(inputShape)));
disp(size(out))

% Generate codegen report (even if codegen fails, report has diagnostics)
codegen -config cfg predict_fn -args {inputType} -report
```

## Quick Decision Matrix

| Symptom | Most Likely Cause | Fix |
|---------|------------------|-----|
| `loadPyTorchExportedProgram` not found | Support package not installed | Install via Add-On Explorer |
| Python error during load | pyenv not configured | `pyenv('Version', '<path to python executable>')` |
| Codegen fails with library error | DeepLearningConfig not set | Set to `'none'` |
| Codegen fails on unsupported op | TOSA op gap | Restructure model or update MATLAB |
| C output is wrong | Column-major vs row-major | Transpose input in C harness |
| C compilation fails on headers | Missing MATLAB include path | Add `-I$(MATLAB_ROOT)/extern/include` |
| C fails to load weights | No filesystem on MCU | Remove `LargeConstantThreshold = 0` |
| Performance is slow | OpenMP/SIMD not enabled | See [`coder-configuration.md`](coder-configuration.md) |


Copyright 2026 The MathWorks, Inc.
