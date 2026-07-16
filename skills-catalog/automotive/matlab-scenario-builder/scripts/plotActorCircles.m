function img = plotActorCircles(img, frameIdx, camObj, trackData, intrinsics, opts)
%plotActorCircles Overlay filled circles at actor center positions
%
%   img = plotActorCircles(img, frameIdx, camObj, trackData, intrinsics)
%   projects ego-relative actor positions onto the image and draws a
%   colored filled circle plus track-ID label per visible actor.
%
%   intrinsics is a struct with fields:
%     fx, fy   — focal lengths (pixels)
%     cx, cy   — principal point (pixels)
%     camHeight — camera mounting height above the ego origin (meters)
%
%   Optional:
%     ClassificationMap — containers.Map keyed by TrackID string, values
%       are structs with at least .RRCategory (e.g. "Sedan", "SUV").
%       When provided, label shows "ID <tid> | <RRCategory>".

arguments
    img
    frameIdx (1,1) double
    camObj   scenariobuilder.CameraData
    trackData scenariobuilder.ActorTrackData
    intrinsics (1,1) struct
    opts.ClassificationMap = []
end

ts = camObj.Timestamps(frameIdx);
[~, idx] = min(abs(trackData.Timestamps - ts));

trackIDs = trackData.TrackID{idx};
positions = trackData.Position{idx};

if isempty(trackIDs)
    return;
end

% Ego to camera: X-fwd,Y-left,Z-up -> X-right,Y-down,Z-forward
R_ego2cam = [0 -1 0; 0 0 -1; 1 0 0];
t_ego2cam = [0; intrinsics.camHeight; 0];

[h, w, ~] = size(img);
numActors = size(positions, 1);
pts = zeros(numActors, 2);
depths = zeros(numActors, 1);
labels = cell(numActors, 1);
nValid = 0;

for i = 1:numActors
    pos_ego = positions(i, :)';
    pos_ego(3) = 0.75; % approximate vehicle half-height (center of object)

    pos_cam = R_ego2cam * pos_ego + t_ego2cam;

    if pos_cam(3) <= 0
        continue;
    end

    u = intrinsics.fx * pos_cam(1) / pos_cam(3) + intrinsics.cx;
    v = intrinsics.fy * pos_cam(2) / pos_cam(3) + intrinsics.cy;

    if u >= 1 && u <= w && v >= 1 && v <= h
        nValid = nValid + 1;
        pts(nValid, :) = [round(u), round(v)];
        depths(nValid) = pos_cam(3);
        tid = char(trackIDs(i));
        if ~isempty(opts.ClassificationMap) && isKey(opts.ClassificationMap, tid)
            cls = opts.ClassificationMap(tid);
            labels{nValid} = sprintf('ID %s | %s %s', tid, cls.Color, cls.RRCategory);
        else
            labels{nValid} = tid;
        end
    end
end

pts = pts(1:nValid, :);
depths = depths(1:nValid);
labels = labels(1:nValid);

if nValid > 0
    % Distinct colors for different track IDs
    colors = [0 255 255; 255 100 100; 100 255 100; 255 200 0; ...
              200 100 255; 255 150 50; 100 200 255; 255 100 200; ...
              150 255 150; 255 255 100];

    % Scale radius based on image resolution and actor depth.
    % Base radius: 12px for 1920-wide image, scale proportionally.
    baseRadius = 12 * (w / 1920);
    refDepth = 20; % meters — reference depth for base radius

    for k = 1:nValid
        % Scale radius inversely with depth (farther = smaller).
        radius = max(4, round(baseRadius * refDepth / depths(k)));
        fontSize = max(10, round(16 * (w / 1920) * refDepth / depths(k)));

        cidx = mod(sum(double(labels{k})), size(colors,1)) + 1;
        c = colors(cidx,:);
        img = insertShape(img, "FilledCircle", [pts(k,:) radius], ...
            Color=c, Opacity=0.8);
        img = insertShape(img, "Circle", [pts(k,:) radius], ...
            Color="blue", LineWidth=2);
        img = insertText(img, pts(k,:) + [radius+3 -radius], labels{k}, ...
            FontSize=fontSize, TextColor=c, BoxColor="black", BoxOpacity=0.6);
    end
end

end

%% ----
% Copyright 2026 The MathWorks, Inc.
% ----
