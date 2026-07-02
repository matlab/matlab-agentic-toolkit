function setupInfo = getDeviceSetupInfo(deviceName)
% getDeviceSetupInfo Get setup and installation requirements for a specific hardware device.
%   setupInfo = getDeviceSetupInfo(deviceName) returns a struct containing support package
%   information and installation status for the specified device.
%
%   If called with no output arguments, displays a formatted summary to the command window.
%
%   Input:
%       deviceName - Name of the hardware device (string)
%
%   Output:
%       setupInfo - Struct with fields:
%           DeviceName              - Resolved device name (string)
%           RequiredAddOnBaseCodes  - All required base codes (from device + features)
%           SupportPackageNames     - Human-readable package names (string array)
%           IsInstalled             - True if all required add-ons are installed
%           AddOnStatus             - Table with columns: BaseCode, FullName, Installed
%           HardwareSupportUrl      - URL for hardware support page (string)

%   Copyright 2026 The MathWorks, Inc.

    arguments
        deviceName (1, 1) string {mustBeTextScalar, mustBeNonempty}
    end

end
