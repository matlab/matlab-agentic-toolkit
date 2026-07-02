function isInstalled = isRequiredAddOnsInstalled(deviceName)
% isRequiredAddOnsInstalled Check if the Add-Ons required by a hardware device are installed.
%   ISINSTALLED = isRequiredAddOnsInstalled(DEVICENAME) returns true if all
%   Add-Ons (support packages) required by the specified device are
%   installed, and false otherwise.
%
%   If called with no output arguments, displays a formatted summary showing
%   each required add-on and its installation status.
%
%   The function resolves the device by name (case-insensitive partial match),
%   retrieves its base codes, and checks each against the identifiers returned
%   by matlab.addons.installedAddons.
%
%   Input:
%       deviceName - Name of the hardware device (string, partial match)
%
%   Output:
%       isInstalled - True if all required Add-Ons are installed (logical)
%
%   Examples:
%       % Check if Arduino Add-Ons are installed
%       tf = isRequiredAddOnsInstalled("Arduino")
%
%       % Display detailed installation status
%       isRequiredAddOnsInstalled("Arduino")
%
%   See also getDeviceSetupInfo, getDeviceDetails, listHardwareDevices

%   Copyright 2026 The MathWorks, Inc.

    arguments
        deviceName (1, 1) string {mustBeTextScalar, mustBeNonempty}
    end

end
