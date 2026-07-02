# Modeling Dynamic Optical Systems in Simulink

Use this when the user asks about Simulink, dynamic optical systems, time-varying parameters, scanning systems and control algorithms for optical components.

The Optical Design and Simulation Library does **not** support code generation. However, optical system operations can run inside a **MATLAB Function block** in Simulink by marking the optics function as `coder.extrinsic`. This allows time-varying inputs from Simulink to drive the optical system and return measurable outputs at each timestep.

---

## Pattern: MATLAB Function Block + Extrinsic Optics Function

The MATLAB Function block has two parts:

1. **The block code** — declares the extrinsic function and calls it with Simulink inputs
2. **The optics function** — creates the system once (using `persistent`), updates parameters from inputs, runs analysis, and returns outputs

---

## Example: F-Theta Scan Lens

A scanning mirror sweeps through angles over time. At each timestep, the mirror tilt is updated and the RMS spot size on the image plane is computed.

**MATLAB Function Block code:**

```matlab
function rmsSpot = fcn(yScanAngle)
%#codegen

% Declare the optics function as extrinsic (runs in MATLAB, not compiled)
coder.extrinsic('computeSpotForScanAngle');

% Initialize output for code generation
rmsSpot = 0;

% Call the extrinsic optics function
rmsSpot = computeSpotForScanAngle(yScanAngle);
end
```

**Extrinsic optics function** (`computeSpotForScanAngle.m`):

```matlab
function rmsSpot = computeSpotForScanAngle(yScanAngle)
% computeSpotForScanAngle  Compute RMS spot size for a given scan angle.
%   Called from a MATLAB Function block as a coder.extrinsic function.

    persistent opsys

    % Create optical system once on first call
    if isempty(opsys)
        opsys = zmximport("FThetaLensWithMirror.zmx");
    end

    % Update scan mirror tilt angle
    opsys.Components(1).TiltAngles = [yScanAngle 0 0];

    % Trace on-axis field point and compute spot
    fp = fieldPoint();
    spr = spot(opsys, FieldPoint=fp);
    rmsSpot = spr.RMS;
end
```

---

## Key Points

- **`persistent`** — The optical system is created once and reused across timesteps. This avoids the overhead of reconstructing or re-importing the system every simulation step.
- **`coder.extrinsic`** — Tells Simulink that this function runs in interpreted MATLAB, not generated code. Without this, code generation will fail on optics calls.
- **Initialize outputs** — In the MATLAB Function block, initialize output variables (e.g., `rmsSpot = 0`) before the extrinsic call so that code generation knows the output type and size.
- **Performance** — The extrinsic function runs interpreted, so each timestep incurs MATLAB call overhead. Use variable-step solvers or coarser time steps if simulation speed is a concern.

----

Copyright 2026 The MathWorks, Inc.

----
