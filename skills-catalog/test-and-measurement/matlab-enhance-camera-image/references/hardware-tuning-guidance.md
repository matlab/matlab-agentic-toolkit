# Hardware Tuning Guidance — Property Discovery and Camera-Type Patterns

## Property Discovery: webcam Objects

```matlab
cam = webcam();              % Connect to default camera
cam = webcam(deviceName);    % Connect by name
props = properties(cam);     % List all settable properties
```

To inspect a specific property's current value:
```matlab
cam.Brightness              % Direct property access
```

To check available values (for enumerated properties like Resolution):
```matlab
cam.AvailableResolutions    % Cell array of resolution strings
```

Webcam objects expose properties directly as object fields. There is no `propinfo` equivalent — valid ranges must be discovered by trial or documentation.

## Property Discovery: videoinput Objects

```matlab
vid = videoinput(adaptorName, deviceID, format);
src = getselectedsource(vid);
props = properties(src);          % All source property names
info = propinfo(src, 'Brightness'); % Detailed property info
```

`propinfo` returns a struct with:
- `Type`: 'double', 'integer', 'string', 'enum'
- `Constraint`: 'bounded', 'enum', 'none'
- `ConstraintValue`: [min max] for bounded, cell array for enum
- `DefaultValue`: factory default
- `ReadOnly`: 'always', 'whileRunning', 'never'

Always use `propinfo` to discover valid ranges before suggesting values.

## Common Camera Types and Typical Properties

### USB Webcams (via webcam() or winvideo/linuxvideo/macvideo adaptor)

| Property | Typical Range | Notes |
|----------|--------------|-------|
| Brightness | 0–255 or -64 to 64 | Midpoint is neutral |
| Contrast | 0–255 or 0–100 | |
| Saturation | 0–255 or 0–100 | |
| Sharpness | 0–255 or 0–7 | Camera-side sharpening |
| Gamma | 72–500 or 1–10 | Often stored as 100× actual value |
| Exposure | -13 to -1 or -11 to 1 | Log2 scale (negative = faster) |
| ExposureMode | auto / manual | Auto overrides manual Exposure value |
| Gain | 0–255 or 0–100 | Amplifies signal and noise |
| BacklightCompensation | 0–1, 0–2, or 0–255 | Range varies widely by camera |
| WhiteBalance | 2800–6500 | Color temperature in Kelvin |
| WhiteBalanceMode | auto / manual | Auto overrides manual WhiteBalance |
| Focus | 0–255 or 0–40 | |
| FocusMode | auto / manual | |

### GigE / GenICam Industrial Cameras

| Property | Typical Range | Notes |
|----------|--------------|-------|
| ExposureTime | 10–1000000 μs | Direct microsecond control |
| Gain | 0–48 dB | Often fine-grained (0.1 dB steps) |
| GainAuto | Off / Once / Continuous | |
| BalanceWhiteAuto | Off / Once / Continuous | |
| BalanceRatio | 0.5–4.0 | Per-channel (Red, Blue selectable) |
| Gamma | 0.25–4.0 | Actual gamma value |
| BlackLevel | 0–255 | Offset added to sensor output |
| ExposureAuto | Off / Once / Continuous | |

### DCAM / IIDC Cameras (firewire, legacy)

| Property | Typical Range | Notes |
|----------|--------------|-------|
| Brightness | 0–255 | DC offset |
| Shutter | 0–4095 | Exposure time (camera-specific units) |
| Gain | 0–255 | Analog gain |
| WhiteBalance | Two values (U, V) | Separate blue/red balance |
| Gamma | 0–1 | On/off only on some cameras |

## Safe Adjustment Strategy

1. **Change one property at a time** — multiple simultaneous changes make it impossible to determine which helped
2. **Re-capture after each change** — wait for 2-3 frames to stabilize (auto-exposure/auto-WB may need time)
3. **Compare metrics quantitatively** — use `diagnoseImageQuality` before and after
4. **Record baseline** — save initial property values so you can revert
5. **Prefer hardware over software** — fixing at the source preserves full dynamic range

## Adjustment Priority Order

For a given problem, try properties in this order (most effective first):

| Problem | Priority Order |
|---------|---------------|
| Too dark | Exposure ↑ → Brightness ↑ → Gain ↑ (last resort) |
| Too bright | Exposure ↓ → Brightness ↓ |
| Backlit | BacklightCompensation ↑ → Exposure ↑ → Gamma ↑ |
| Noisy | Gain ↓ → Exposure ↑ (compensate) |
| Blurry (motion) | Exposure ↓ (faster shutter) |
| Blurry (focus) | FocusMode=manual → Focus adjust |
| Color cast | WhiteBalanceMode=auto → WhiteBalance manual adjust |
| Low contrast | Contrast ↑ → Gamma adjust |

## Investigating Unfamiliar Properties

When a camera exposes properties not listed in the tables above, use this protocol to reason about them safely.

### Naming Heuristics

| Name Pattern | Likely Function | Quality-Relevant? |
|---|---|---|
| Binning, BinningHorizontal, BinningVertical | Pixel binning (combines adjacent pixels) | Yes — affects resolution and noise |
| BlackLevel, BlackLevelRaw | Sensor offset / pedestal | Yes — affects shadow detail |
| DigitalGain, DigitalShift | Digital amplification after ADC | Yes — amplifies noise like analog Gain |
| LUTEnable, LUTIndex, LUTValue | Look-up table for tone mapping | Yes — remaps pixel values |
| HDRMode, WDR | High dynamic range mode | Yes — changes exposure strategy |
| ROI, OffsetX, OffsetY, Width, Height | Region of interest | Partially — changes captured region, not quality |
| TriggerMode, TriggerSource, TriggerDelay | External trigger configuration | No — acquisition timing, not quality |
| PixelFormat, PixelSize | Data format (Mono8, BayerRG12, etc.) | Partially — bit depth affects dynamic range |
| PacketSize, StreamBytesPerSecond | Network transport (GigE) | No — bandwidth, not quality |
| AcquisitionFrameRate, FrameRate | Frame rate control | Indirectly — may constrain max exposure time |
| DeviceTemperature, DeviceLinkSpeed | Sensor/device status | No — read-only diagnostics |

### Scoping Discovery on Feature-Rich Cameras

GenICam-compliant cameras (GigE Vision, USB3 Vision) often expose 200+ properties via the full SFNC surface. Investigating every one is impractical. Scope the discovery by skipping infrastructure property groups that do not affect image quality:

- Skip: `Ptp*`, `Sequencer*`, `Counter*`, `Chunk*`, `Serial*`, `Action*`, `Timer*`, `Event*`, `DeviceLink*`, `Transport*`
- Keep: properties matching the naming heuristics table above, plus any containing `Exposure`, `Gain`, `Balance`, `Gamma`, `Black`, `Sharp`, `Bright`, `Contrast`, `HDR`, `LUT`, `Bin`

Report the skipped groups to the user (e.g., "Skipped 45 transport/sequencer/timing properties not relevant to image quality") so they can request deeper investigation if needed.

### Safe Exploration Protocol

For properties classified as potentially quality-relevant:

1. **Read first** — get current value, type, range, and read-only status via `propinfo(src, propName)`
2. **Record baseline** — save the current value before any changes
3. **Understand constraints** — if bounded, note min/max; if enum, list valid values
4. **Try a small perturbation** — change by ~10% of the range (or one enum step) toward a direction that should help the diagnosed problem
5. **Capture and measure** — take a new image, run `diagnoseImageQuality`, compare metrics
6. **Revert if no improvement** — restore the saved baseline value
7. **Report to user** — describe what the property appears to do based on the observed metric change

```matlab
% Example: investigating an unfamiliar property
propName = "BlackLevel";
info = propinfo(src, propName);
baseline = src.(propName);
fprintf("Property: %s, Type: %s, Range: [%g %g], Current: %g\n", ...
    propName, info.Type, info.ConstraintValue(1), info.ConstraintValue(2), baseline);

% Try small increase
step = (info.ConstraintValue(2) - info.ConstraintValue(1)) * 0.1;
src.(propName) = baseline + step;
pause(0.5);
testImg = getsnapshot(vid);
testResults = diagnoseImageQuality(testImg);

% Compare and decide
src.(propName) = baseline;  % Revert
```

### When to Involve the User

Ask the user before changing properties that:
- Sound mode-changing or potentially destructive (TriggerMode, AcquisitionMode, PixelFormat)
- Have the word "Reset" or "Default" in the name
- Are enum-typed with values you don't recognize
- Affect resolution or frame geometry (Width, Height, Binning, Decimation)

### Properties to Leave Alone

Unless the user explicitly asks, do not modify:
- TriggerMode, TriggerSource — can break acquisition entirely
- PixelFormat — changing mid-session may require reconnecting
- PacketSize, StreamBytesPerSecond — transport parameters, not quality
- DeviceReset, UserSetLoad — destructive operations

## Property Interaction Gotchas

- **ExposureMode=auto overrides manual Exposure**: Always set mode to manual first, then adjust value
- **WhiteBalanceMode=auto overrides WhiteBalance**: Same pattern — manual mode first
- **Gain amplifies noise**: Increasing Gain is tempting for dark images but degrades SNR. Prefer longer Exposure when motion blur is acceptable
- **BacklightCompensation range varies wildly**: Some cameras use 0–1 (on/off), others 0–255 (graduated). Always check range at runtime
- **Auto modes may take several frames to converge**: After enabling auto exposure/WB, discard 5–10 frames before capturing the final image
- **Resolution changes may reset other properties**: On some cameras, changing Resolution reverts Exposure/Gain to defaults
- **Preview vs snapshot**: `preview(cam)` shows live video and triggers auto-adjustments; a cold `snapshot(cam)` may capture before auto-modes converge

----

Copyright 2026 The MathWorks, Inc.

----
