%% RoadRunner Core Commands — Pattern Reference
%
% This file is NOT executed as a whole. The agent reads the relevant %%
% section and reproduces the exact pattern via evaluate_matlab_code,
% substituting placeholder variables with actual values.
%
% Placeholders (used across sections):
%   rrApp        — roadrunner handle (produced by rrCoreInitialize)
%   projectPath  — string, absolute path, e.g. "D:/Projects/MyRRProject"
%   sceneName    — string, e.g. "MyScene.rrscene" (extension optional)
%   scenarioName — string, e.g. "MyScenario"
%   lat, lon     — double, geospatial coordinates (WGS84)
%   x, y         — double, scene center in meters
%   w, h         — double, scene extents in meters
%
% Copyright 2026 The MathWorks, Inc.

%% INIT
% Agent must addpath the skill's scripts folder before calling rrCoreInitialize.
% Use the actual absolute path to this skill's scripts/ directory.
addpath("SKILL_SCRIPTS_DIR");
rrCoreInitialize;

%% CONNECT_ONLY
% Connect to an already-running instance without launching a new one.
% Use when user explicitly says "connect to existing" or you must not launch.
try
    rrApp = roadrunner.connect();
catch ME
    error("rrCore:NoRunningInstance", ...
        "No running RoadRunner instance found.\n" + ...
        "Start RoadRunner manually or ask user for permission to launch.\nError: %s", ME.message);
end
fprintf("Connected to RoadRunner %s\n", rrApp.Version);

%% =========================================================================
%% PROJECT
%% =========================================================================

%% NEW_PROJECT
if isfolder(projectPath)
    entries = dir(projectPath);
    entries = entries(~ismember({entries.name}, {'.', '..'}));
    if ~isempty(entries)
        error("rr_core:FolderNotEmpty", ...
            "Folder exists and is not empty: %s\nUse OPEN_PROJECT instead.", projectPath);
    end
end
newProject(rrApp, projectPath);

%% NEW_PROJECT_WITH_ASSETS
if isfolder(projectPath)
    entries = dir(projectPath);
    entries = entries(~ismember({entries.name}, {'.', '..'}));
    if ~isempty(entries)
        error("rr_core:FolderNotEmpty", ...
            "Folder exists and is not empty: %s\nUse OPEN_PROJECT instead.", projectPath);
    end
end
newProject(rrApp, projectPath, AssetLibraries="RoadRunner_Asset_Library");

%% OPEN_PROJECT
if ~isfolder(projectPath)
    error("rr_core:FolderNotFound", ...
        "Folder not found: %s\nUse NEW_PROJECT instead.", projectPath);
end
openProject(rrApp, projectPath);
clear rrApi rrScene rrProject rrs phaseLogic

%% SAVE_PROJECT
saveProject(rrApp);

%% =========================================================================
%% SCENE
%% =========================================================================

%% NEW_SCENE
% AGENT: Check for unsaved changes and ASK the user before saving.
% Do NOT auto-save — saving overwrites the original and can break backwards compatibility.
rrStatus = status(rrApp);
if rrStatus.Scene.UnsavedChanges && strlength(rrStatus.Scene.Filename) > 0
    fprintf("Current scene has unsaved changes: %s\n", rrStatus.Scene.Filename);
    % STOP — ask user whether to save, save-as, or discard before proceeding.
end
newScene(rrApp);
clear rrApi rrScene rrProject rrs phaseLogic

%% OPEN_SCENE
openScene(rrApp, sceneName);
clear rrApi rrScene rrProject rrs phaseLogic

%% SAVE_SCENE
saveScene(rrApp);

%% SAVE_SCENE_AS
saveScene(rrApp, sceneName);

%% LIST_SCENES
rrStatus = status(rrApp);
projectFolder = rrStatus.Project.Filename;
scenesDir = fullfile(projectFolder, "Scenes");
sceneFiles = dir(fullfile(scenesDir, "**", "*.rrscene"));
fprintf("Available scenes in %s:\n", scenesDir);
for i = 1:numel(sceneFiles)
    fprintf("  %s\n", sceneFiles(i).name);
end

%% =========================================================================
%% SCENARIO
%% =========================================================================

%% NEW_SCENARIO
% AGENT: Check for unsaved changes and ASK the user before saving.
% Do NOT auto-save — saving overwrites the original and can break backwards compatibility.
rrStatus = status(rrApp);
if ~isempty(rrStatus.Scenario) && isstruct(rrStatus.Scenario) ...
        && rrStatus.Scenario.UnsavedChanges
    fprintf("Current scenario has unsaved changes: %s\n", rrStatus.Scenario.Filename);
    % STOP — ask user whether to save, save-as, or discard before proceeding.
end
newScenario(rrApp);
clear rrs phaseLogic

%% OPEN_SCENARIO
openScenario(rrApp, scenarioName);
clear rrs phaseLogic

%% SAVE_SCENARIO
saveScenario(rrApp);

%% LIST_SCENARIOS
rrStatus = status(rrApp);
projectFolder = rrStatus.Project.Filename;
scenariosDir = fullfile(projectFolder, "Scenarios");
scenarioFiles = dir(fullfile(scenariosDir, "**", "*.rrscenario"));
fprintf("Available scenarios in %s:\n", scenariosDir);
for i = 1:numel(scenarioFiles)
    fprintf("  %s\n", scenarioFiles(i).name);
end

%% =========================================================================
%% WORLD SETTINGS
%% =========================================================================

%% CHANGE_WORLD_ORIGIN
changeWorldSettings(rrApp, WorldOrigin=[lat lon]);

%% CHANGE_SCENE_BOUNDS
changeWorldSettings(rrApp, SceneCenter=[x y], SceneExtents=[w h]);

%% CHANGE_SCENE_CENTER
changeWorldSettings(rrApp, SceneCenter=[x y]);

%% CHANGE_SCENE_EXTENTS
changeWorldSettings(rrApp, SceneExtents=[w h]);

%% CLEAR_WORLD_PROJECTION
changeWorldSettings(rrApp, ClearWorldProjection=true);

%% =========================================================================
%% STATUS AND CLOSE
%% =========================================================================

%% STATUS
rrStatus = status(rrApp);
fprintf("Project:  %s\n", rrStatus.Project.Filename);
fprintf("Scene:    %s\n", rrStatus.Scene.Filename);
if ~isempty(rrStatus.Scenario) && isstruct(rrStatus.Scenario)
    fprintf("Scenario: %s\n", rrStatus.Scenario.Filename);
    hasUnsavedScenario = rrStatus.Scenario.UnsavedChanges;
else
    fprintf("Scenario: (none)\n");
    hasUnsavedScenario = false;
end
if rrStatus.Project.UnsavedChanges || rrStatus.Scene.UnsavedChanges || hasUnsavedScenario
    fprintf("Unsaved:  ");
    if rrStatus.Project.UnsavedChanges, fprintf("Project "); end
    if rrStatus.Scene.UnsavedChanges, fprintf("Scene "); end
    if hasUnsavedScenario, fprintf("Scenario "); end
    fprintf("\n");
end

%% CLOSE
% AGENT: Check for unsaved changes and ASK the user before saving.
% Do NOT auto-save — saving overwrites the original and can break backwards compatibility.
rrStatus = status(rrApp);
unsavedItems = "";
if rrStatus.Scene.UnsavedChanges && strlength(rrStatus.Scene.Filename) > 0
    unsavedItems = unsavedItems + "Scene ";
end
if ~isempty(rrStatus.Scenario) && isstruct(rrStatus.Scenario) ...
        && rrStatus.Scenario.UnsavedChanges
    unsavedItems = unsavedItems + "Scenario ";
end
if rrStatus.Project.UnsavedChanges
    unsavedItems = unsavedItems + "Project ";
end
if strlength(unsavedItems) > 0
    fprintf("Unsaved changes in: %s\n", unsavedItems);
    % STOP — ask user what to save before closing.
end
close(rrApp);
clear rrApp rrApi rrScene rrProject rrs phaseLogic
