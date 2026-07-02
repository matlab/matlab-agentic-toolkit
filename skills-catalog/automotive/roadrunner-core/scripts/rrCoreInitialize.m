%% rrCoreInitialize — RoadRunner Core Initialization
% Ensures RoadRunner is configured, on the MATLAB path, connected, and
% validated. Handles first-time setup automatically.
%
% Produces:
%   rrApp — validated roadrunner application handle in base workspace
%
% First-time setup (one-time, persists across sessions):
%   Tier 1: Already configured — settings valid + class on path → skip
%   Tier 2: Paths provided as variables (installFolder, projectPath) →
%           programmatic setup, no GUI
%
% No GUI dialogs. If paths are not provided and not configured, errors
% with a clear message asking the user to provide them.
%
% Copyright 2026 The MathWorks, Inc.

%% Tier 1: Check if already configured
alreadyConfigured = exist('roadrunner', 'class');
if alreadyConfigured
    s = settings;
    try
        instDir = s.roadrunner.application.InstallationFolder.ActiveValue;
        projDir = s.roadrunner.application.ProjectFolder.ActiveValue;
        if strlength(instDir) == 0 || strlength(projDir) == 0
            alreadyConfigured = false;
        end
    catch
        alreadyConfigured = false;
    end
end

%% Tier 2 & 3: First-time setup (runs only if not configured)
if ~alreadyConfigured
    % Tier 2: Programmatic setup if paths are provided as workspace variables
    hasInstallFolder = exist('installFolder', 'var') && strlength(installFolder) > 0;
    hasProjectPath   = exist('projectPath', 'var') && strlength(projectPath) > 0;

    if hasInstallFolder && hasProjectPath
        % Validate installation folder
        apiPath = fullfile(installFolder, "bin", computer('arch'), "Tools", "MATLAB", "api");
        if ~isfolder(apiPath)
            error("rrCoreInitialize:InvalidInstall", ...
                "RoadRunner API folder not found at:\n  %s\nCheck your installation path.", apiPath);
        end

        % Add API to MATLAB path (persists)
        addpath(apiPath);
        savepath;

        % Save to MATLAB settings (persists)
        s = settings;
        s.roadrunner.application.InstallationFolder.PersonalValue = installFolder;
        s.roadrunner.application.ProjectFolder.PersonalValue = projectPath;

        fprintf("RoadRunner configured programmatically.\n");
        fprintf("  Installation: %s\n", installFolder);
        fprintf("  Project:      %s\n", projectPath);

    else
        % No paths available — error with clear message (no GUI)
        error("rrCoreInitialize:PathsRequired", ...
            "RoadRunner is not configured.\n" + ...
            "Please provide:\n" + ...
            "  1. installFolder — RoadRunner installation path (e.g., ""C:\\Program Files\\RoadRunner R2026a"")\n" + ...
            "  2. projectPath — an existing RoadRunner project folder\n" + ...
            "Once configured, use newProject(rrApp, path) to create new projects.");
    end
end

%% Connection (idempotent)
if ~exist('rrApp', 'var') || ~isvalid(rrApp)
    % Strategy: try connecting to an already-running instance first,
    % then fall back to launching a new instance.
    connected = false;

    % Attempt 1: Connect to existing RoadRunner instance
    try
        rrApp = roadrunner.connect();
        connected = true;
    catch
        % Connection failed — instance may not be running
    end

    % Attempt 2: Launch RoadRunner using saved defaults
    if ~connected
        try
            rrApp = roadrunner();
        catch ME
            error("rrCoreInitialize:LaunchFailed", ...
                "Cannot connect to or launch RoadRunner.\n" + ...
                "Check that Installation and Project folders are set correctly.\nError: %s", ME.message);
        end
    end
end

%% Validate
try
    rrStatus = status(rrApp);
catch ME
    error("rrCoreInitialize:ConnectionFailed", ...
        "Cannot reach RoadRunner. Is it running?\nError: %s", ME.message);
end

%% Report version
fprintf("RoadRunner connected successfully.\n");
fprintf("  Version: %s\n", rrApp.Version);
fprintf("  Project: %s\n", rrStatus.Project.Filename);
