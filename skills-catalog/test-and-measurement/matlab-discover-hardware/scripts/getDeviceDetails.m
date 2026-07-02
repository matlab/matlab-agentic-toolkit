function deviceDetails = getDeviceDetails(deviceName)
% getDeviceDetails Get details about a specific hardware device.
%   DETAILS = getDeviceDetails(DEVICENAME) returns a struct with information
%   about the specified device, including basic info, support packages,
%   capabilities, documentation, and custom data.
%
%   getDeviceDetails(DEVICENAME) without an output argument displays a formatted
%   summary of the device details.
%
%   Input:
%       DEVICENAME - Name or partial name of the device (case-insensitive match).
%                    Must be a non-empty string scalar.
%
%   Output:
%       DETAILS - Struct (or struct array for multiple matches) with fields:
%                 BasicInfo              - Name, vendor, model, connection, IDs
%                 SupportInfo            - Base codes, support packages, URL
%                 Capabilities           - String array of capabilities
%                 RequiredAddOnBaseCodes  - Base codes from device feature entries
%                 Documentation          - String with documentation references
%                 CustomData             - Toolbox-specific data (e.g., serial port info)
%                 DeviceCardDisplayInfo   - Display info from the device card
%
%   Examples:
%       % Get details for Arduino Uno
%       details = getDeviceDetails("Arduino Uno")
%
%       % Display formatted details for any NI device
%       getDeviceDetails("NI")
%
%   See also listHardwareDevices, hardwareDeviceCache

%   Copyright 2026 The MathWorks, Inc.

    arguments
        deviceName (1, 1) string {mustBeTextScalar, mustBeNonempty}
    end

end
