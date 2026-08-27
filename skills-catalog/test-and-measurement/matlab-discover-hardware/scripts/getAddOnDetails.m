function info = getAddOnDetails(baseCode)
% getAddOnDetails Get details of a MathWorks add-on (support package) by base code.
%   INFO = getAddOnDetails(BASECODE) returns a struct describing the add-on
%   identified by BASECODE. The struct contains the input base code and the
%   base code of the required (dependent) toolbox product, as reported by
%   matlab.hwmgr.internal.DataStore.getSpkgRequiredProduct.
%
%   If called with no output arguments, displays a formatted summary.
%
%   The datastore object is cached in a persistent variable so that the
%   relatively expensive matlab.hwmgr.internal.DataStoreHelper.getDataStore
%   call happens at most once per MATLAB session.
%
%   Input:
%       baseCode - Add-on / support package base code (string scalar)
%
%   Output:
%       info - Struct with fields:
%           BaseCode                - The input base code (string)
%           RequiredProductBaseCode - Base code of the required toolbox
%                                     product, e.g. "ML" or "SL" (string)
%
%   Examples:
%       % Get add-on details for the MATLAB Support Package for Arduino
%       info = getAddOnDetails("ML_ARDUINO")
%
%       % Display formatted summary for the Simulink Support Package for Arduino
%       getAddOnDetails("ARDUINO")
%
%   See also getDeviceDetails, getDeviceSetupInfo, isRequiredAddOnsInstalled

%   Copyright 2026 The MathWorks, Inc.


    arguments
        baseCode (1, 1) string {mustBeTextScalar, mustBeNonempty}
    end

end
