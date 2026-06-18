%% Missed Detections Scenario
% Ground-based radar with 5 targets — only 2 are being detected.
% The user wants to know why targets C, D, and E are not detected,
% and why target B is intermittent.

%% Scenario Setup
scene = radarScenario('UpdateRate', 10);

%% Radar Platform (20m tower height)
radarPlat = platform(scene, 'Position', [0 0 -20]);  % NED: -20 = 20m above ground

%% Radar Sensor
radar = radarDataGenerator(1, 'Sector', ...
    'UpdateRate', 1, ...
    'FieldOfView', [3; 20], ...
    'MechanicalAzimuthLimits', [-45 45], ...
    'ReferenceRange', 80e3, ...
    'ReferenceRCS', 0, ...
    'DetectionProbability', 0.9, ...
    'FalseAlarmRate', 1e-6, ...
    'DetectionCoordinates', 'Scenario', ...
    'CenterFrequency', 3e9, ...
    'AzimuthResolution', 3);
radarPlat.Sensors = radar;

%% Target A: 30 km, in-sector, 1 km altitude (WORKS)
tgtA = platform(scene, 'Position', [30e3 0 -1000]);  % NED
tgtA.Signatures = rcsSignature('Pattern', 0);  % 0 dBsm = 1 m^2

%% Target B: 50 km, in-sector, 500m altitude (INTERMITTENT)
tgtB = platform(scene, 'Position', [50e3 0 -500]);
tgtB.Signatures = rcsSignature('Pattern', -3);  % -3 dBsm = 0.5 m^2, Swerling I

%% Target C: 150 km, in-sector, 10 km altitude (NEVER DETECTED)
tgtC = platform(scene, 'Position', [150e3 0 -10000]);
tgtC.Signatures = rcsSignature('Pattern', 10);  % 10 dBsm

%% Target D: 40 km, azimuth 60 degrees (NEVER DETECTED)
% Position at 60 degrees azimuth in NED: [range*cos(az), range*sin(az), alt]
tgtD = platform(scene, 'Position', [40e3*cosd(60) 40e3*sind(60) -5000]);
tgtD.Signatures = rcsSignature('Pattern', 0);

%% Target E: 80 km, in-sector, 50m altitude (NEVER DETECTED)
tgtE = platform(scene, 'Position', [80e3 0 -50]);
tgtE.Signatures = rcsSignature('Pattern', 5);  % 5 dBsm

%% Run Simulation
numDetections = zeros(5, 1);
numSteps = 0;

while advance(scene)
    dets = detect(scene);
    numSteps = numSteps + 1;
    for d = 1:numel(dets)
        tIdx = dets{d}.ObjectAttributes{1}.TargetIndex;
        if tIdx >= 2 && tIdx <= 6  % platforms 2-6 are targets A-E
            numDetections(tIdx - 1) = numDetections(tIdx - 1) + 1;
        end
    end
    if scene.SimulationTime > 30
        break
    end
end

%% Results
fprintf('Detection counts over %d steps (30 seconds):\n', numSteps);
fprintf('  Target A (30 km, 1 km alt): %d detections\n', numDetections(1));
fprintf('  Target B (50 km, 500m alt): %d detections\n', numDetections(2));
fprintf('  Target C (150 km, 10 km alt): %d detections\n', numDetections(3));
fprintf('  Target D (40 km, az=60 deg): %d detections\n', numDetections(4));
fprintf('  Target E (80 km, 50m alt): %d detections\n', numDetections(5));

% Copyright 2026 The MathWorks, Inc.
