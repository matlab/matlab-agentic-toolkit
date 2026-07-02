function result = hardwareDeviceCache(action, varargin)
% hardwareDeviceCache Shared in-memory cache for hardware device enumeration results.
%   hardwareDeviceCache(ACTION, ...) manages a persistent cache of device
%   enumeration results, keyed by plugin name. Used internally by all
%   Layer 1 and Layer 2 discovery functions to avoid repeated full sweeps.
%
%   Actions:
%     hardwareDeviceCache("set", pluginName, pluginClass, pluginObj, devices)
%       Store or update a cache entry for the given plugin.
%
%     result = hardwareDeviceCache("get", pluginName)
%       Return cached entry for a plugin. Returns [] if expired or missing.
%       Use pluginName="" to return all valid entries.
%
%     tf = hardwareDeviceCache("isValid", pluginName)
%       Return true if the cache entry exists and is within TTL.
%       Use pluginName="" to check if any entries exist.
%
%     hardwareDeviceCache("clear", pluginName)
%       Clear a specific plugin entry. Use pluginName="" to clear all.
%
%     result = hardwareDeviceCache("all")
%       Return a struct with Devices (cell array) and PluginNames (string
%       array) aggregated across all valid cache entries.
%
%     result = hardwareDeviceCache("find", deviceName)
%       Case-insensitive partial match on FriendlyName across all cached
%       devices. Returns struct with Devices, PluginNames, and Count.

%   Copyright 2026 The MathWorks, Inc.

    arguments
        action (1, 1) string {mustBeMember(action, ["set", "get", "isValid", "clear", "all", "find"])}
    end

end
