---
name: matlab-setup-gpu
description: >
  Detect and validate GPU availability for MATLAB GPU computing.
  Use when the user can't use their GPU, or is setting up or
  selecting a GPU. Triggers on: gpuDevice, GPU setup, check GPU, GPU
  not found, GPU not working, can't use GPU, GPU not available,
  unable to find a supported GPU device, compatible GPU,
  canUseGPU, validateGPU.
license: MathWorks BSD-3-Clause
compatibility: ">=R2024b"
metadata:
  author: MathWorks
  version: "1.0"
---

# Set Up GPU for MATLAB

Detect whether a compatible GPU is available, validate it works, and diagnose common failure modes.

## When to Use

- User wants to check if their system can run GPU code in MATLAB
- User gets errors when calling `gpuDevice` or `gpuArray`
- User wants to set up or select a specific GPU in a multi-GPU system
- User needs to troubleshoot why GPU computing isn't working
- As a prerequisite check before any GPU-accelerated workflow

## When NOT to Use

- Writing or optimizing GPU-accelerated code — this skill only detects and diagnoses GPU availability
- Monitoring GPU memory or utilization during computation — use `gpuDevice` properties directly or NVIDIA tools
- Distributing work across multiple GPUs with parallel pools — use `parpool` workflows

## Conventions

- Use MATLAB-native APIs (`canUseGPU`, `gpuDeviceTable`, `gpuDevice`) for detection and properties — reserve `nvidia-smi` for information MATLAB cannot provide
- Prefer `canUseGPU` over `gpuDeviceCount == 0` or `isempty(gpuDeviceTable)` for availability checks — `canUseGPU` also verifies licensing and toolbox state
- If recommending a driver update, fetch the **GPU Computing Requirements** documentation page for the user's MATLAB release to check the driver selection policy

## Workflow

### 1. Is a GPU available?

```matlab
canUseGPU
```

Returns `true` if PCT is installed, licensed, GPU support is present, and a device is available. If true, proceed to step 3 (list available devices).

### 2. If `canUseGPU` returns `false` — diagnose

```matlab
validateGPU("all")
```

**If the output contains "requires a newer graphics driver":** this does not guarantee a newer driver exists. Do not state that the GPU is unsupported or end-of-life — direct the user to verify on the **GPU Computing Requirements** page for this MATLAB release before drawing any conclusion about hardware compatibility.

For all other failures, interpret using the **Troubleshooting** table.

### 3. List available devices

```matlab
gpuDeviceTable          % List all GPUs and indices (no memory allocation)
```

Always run `gpuDeviceTable` before selecting a device — it confirms which devices are visible and their MATLAB indices.

### 4. Select device and query properties

```matlab
d = gpuDevice(N);       % Select GPU N
properties(d)           % List available device properties
```

### 5. Check driver model (Windows only)

```matlab
d = gpuDevice;              % returns device already selected
d.DriverModel
d.KernelExecutionTimeout
```

If WDDM: the GPU is shared with the display — long-running kernels may be killed by the OS watchdog, and the GPU may exhibit unstable behaviour when low on memory. If `d.KernelExecutionTimeout` is `true`, kernel timeouts are active.

TCC or MCDM avoid these issues but are only available on select professional and data centre GPUs not connected to a display. If switching is not an option, and user experiences kernel timeouts, advise: increase TDR timeout in Windows Registry, close other GPU-accelerated apps, or break computation into smaller chunks.

### 6. Benchmark GPU performance (optional)

To qualify the GPU's computing power, suggest the user run `gpuBench` (available from the MATLAB File Exchange, not shipped with MATLAB). It benchmarks memory bandwidth, single/double precision compute, compares GPU vs CPU performance, and provides comparison data against other popular GPUs.

## Troubleshooting

| Symptom | Cause | Resolution |
|---------|-------|------------|
| `canUseGPU` returns `false`, no error | PCT not licensed | Check `license('test','Distrib_Computing_Toolbox')`. If false, user needs a PCT license. |
| `validateGPU` not found | PCT not installed or pre-R2024b | Check `ver('parallel')` — if empty, PCT is not installed; if version is below 24.2 (R2024b), `validateGPU` is not available in that release. |
| "requires a newer graphics driver" or validateGPU: platform or driver check FAILED | NVIDIA driver too old, or driver support for the GPU architecture may have ended | Does not guarantee a newer driver exists. Consult the **GPU Computing Requirements** documentation page for the user's release to confirm the GPU is still supported before advising a driver update. |
| validateGPU: "Device available" FAILED | Prohibited or exclusive compute mode | Check the message: if "prohibited" — vGPU graphics-only profile ("B" suffix, e.g. A16-2B), requires compute-enabled profile (Q or C suffix), advise user to escalate to system administrator. If "exclusive" — GPU in use by another process, free it or select a different device. |
| validateGPU: device count is 0 | Device not visible to MATLAB | If running in a container, verify GPU passthrough is configured. Otherwise, consult the **GPU Computing Requirements** documentation page for the user's release to confirm supported hardware. |
| GPU kernel killed mid-computation (Windows) | WDDM driver model with TDR active | See step 5 for driver model implications and remediation |

## Key Functions

| Function | Purpose |
|----------|---------|
| `canUseGPU` | Quick availability check — true if PCT licensed and a usable GPU device exists |
| `validateGPU` | Structured diagnostic — tests each layer and reports results |
| `gpuDeviceTable` | List all visible GPUs with indices, names, and status (no memory allocation) |
| `gpuDevice` | Select a GPU by index, or return the current device (no argument) |

----

Copyright 2026 The MathWorks, Inc.

----
