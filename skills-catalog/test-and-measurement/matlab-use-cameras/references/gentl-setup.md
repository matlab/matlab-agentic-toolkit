# GenTL Producer Setup

## Installing the GenTL adaptor

The GenTL adaptor requires the "Image Acquisition Toolbox Support Package for GenICam Interface." Install via:

1. MATLAB Add-On Explorer: search for "GenICam Interface"
2. Or from the command line: `matlab.addons.install("GenICam Interface")`

## GenTL Producer Configuration

A GenTL producer is a vendor-provided library that enables communication with GenICam-compliant cameras (GigE Vision, USB3 Vision).

For detailed setup instructions on obtaining and configuring the correct GenTL producer for your camera, refer to:
https://www.mathworks.com/matlabcentral/answers/2089171-how-can-i-use-my-gige-vision-or-usb3-vision-camera-in-matlab

## Verifying installation

```matlab
% Check if gentl adaptor is available
info = imaqhwinfo;
assert(ismember("gentl", string(info.InstalledAdaptors)), ...
    "GenTL adaptor not found. Install the GenICam Interface support package.");

% List devices visible to GenTL
gentlInfo = imaqhwinfo("gentl");
disp(gentlInfo.DeviceInfo)
```

## Common issues

- **No devices found:** Ensure the GenTL producer (.cti file) from your camera vendor is installed and its path is registered
- **Adaptor not listed:** Install "Image Acquisition Toolbox Support Package for GenICam Interface" via Add-On Explorer
- **Camera visible but connection fails:** Check network configuration (for GigE) or USB permissions (for USB3 Vision)

----

Copyright 2026 The MathWorks, Inc.

----
