%% NED Radar Scenario with Sensor Spherical Detections
% Ground-based radar with targets at various altitudes and bearings.

scene = radarScenario('UpdateRate', 1);

%% Radar Platform (20m tower)
radarPlat = platform(scene, 'Position', [0 0 -20]);

%% Radar Sensor
radar = radarDataGenerator(1, 'No scanning', ...
    'FieldOfView', [360; 180], ...
    'UpdateRate', 1, ...
    'HasElevation', true, ...
    'ReferenceRange', 100e3, ...
    'ReferenceRCS', 0, ...
    'DetectionProbability', 0.9, ...
    'FalseAlarmRate', 1e-6, ...
    'CenterFrequency', 3e9, ...
    'AzimuthResolution', 3, ...
    'ElevationResolution', 10, ...
    'RangeLimits', [0, 120e3], ...
    'DetectionCoordinates', 'Sensor spherical');
radarPlat.Sensors = radar;

%% Targets
% Target A: bearing 23 deg, 4 km altitude (positive elevation from radar)
tgtA = platform(scene, 'Position', [27e3*cosd(23), 27e3*sind(23), -4000]);
tgtA.Signatures = rcsSignature('Pattern', 10);

% Target B: bearing -52 deg, 8 km altitude (positive elevation from radar)
tgtB = platform(scene, 'Position', [40e3*cosd(-52), 40e3*sind(-52), -8000]);
tgtB.Signatures = rcsSignature('Pattern', 10);

% Target C: bearing 137 deg, 1.5 km BELOW radar (negative elevation from radar)
tgtC = platform(scene, 'Position', [10e3*cosd(137), 10e3*sind(137), 1500]);
tgtC.Signatures = rcsSignature('Pattern', 10);

% Target D: bearing -110 deg, 12 km altitude (positive elevation from radar)
tgtD = platform(scene, 'Position', [55e3*cosd(-110), 55e3*sind(-110), -12000]);
tgtD.Signatures = rcsSignature('Pattern', 10);

%% Run one detection pass
advance(scene);
dets = detect(scene);

%% Print detection data
fprintf('Detection count: %d\n\n', numel(dets));
for i = 1:numel(dets)
    d = dets{i};
    fprintf('Detection %d (PlatformID %d): [az=%.4f deg, el=%.4f deg, range=%.1f m]\n', ...
        i, d.ObjectAttributes{1}.TargetIndex, ...
        d.Measurement(1), d.Measurement(2), d.Measurement(3));
end

% Copyright 2026 The MathWorks, Inc.
