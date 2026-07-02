function deviceInfo = listHardwareDevices(options)
% listHardwareDevices List hardware devices connected to this computer (or all supported devices).
%   DEVICEINFO = listHardwareDevices() returns a table of connected hardware
%   devices discovered through all Hardware plugins.
%
%   DEVICEINFO = listHardwareDevices(Mode="All") returns all supported devices,
%   including those not currently connected.
%
%   DEVICEINFO = listHardwareDevices(Plugin="DAQPlugin") queries only the
%   specified plugin (~2s instead of full sweep ~20s).
%
%   DEVICEINFO = listHardwareDevices(Capability="analog input") filters results
%   to devices matching the capability keyword (case-insensitive).
%
%   DEVICEINFO = listHardwareDevices(Refresh=true) forces re-enumeration,
%   ignoring cached results.
%
%   The returned table contains the following columns:
%       FriendlyName   - User-visible device name
%       VendorName     - Device vendor
%       ConnectionInfo - Connection type (USB, Serial, Ethernet, etc.)
%       IsConnected    - Whether device is currently connected
%
%   Examples:
%       % List connected devices
%       devices = listHardwareDevices()
%
%       % List all supported devices from a specific plugin
%       devices = listHardwareDevices(Mode="All", Plugin="DAQPlugin")
%
%       % Search for devices with a specific capability
%       devices = listHardwareDevices(Capability="analog input")
%
%       % Force re-enumeration
%       devices = listHardwareDevices(Refresh=true)
%
%   See also getDeviceDetails, hardwareDeviceCache

%   Copyright 2026 The MathWorks, Inc.

    arguments
        options.Mode (1, 1) string {mustBeMember(options.Mode, ["Connected", "All"])} = "Connected"
        options.Plugin (1, 1) string = ""
        options.Capability (1, 1) string = ""
        options.Refresh (1, 1) logical = false
    end

end
