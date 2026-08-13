function plotBEVAndCamera(trackData, cameraData)
%plotBEVAndCamera Side-by-side BEV actor plot and camera replay
%   plotBEVAndCamera(trackData, cameraData) displays a bird's-eye-view plot
%   of actor tracks alongside camera frames. Use when camera intrinsics are
%   NOT available (cannot project tracks onto image).
%
%   Supports both image-sequence cameras (Frames property with image files)
%   and video cameras (VideoFile property with .mp4/.avi).
%
%   IMPORTANT: Camera and track data MUST be synchronized (same number of
%   samples) before calling this function. If they are not, use the
%   "Crop & Sync" tab in the Driving Log Analyzer app to apply offset
%   correction and resample the data to matching rates.
%
%   Inputs:
%     trackData  — scenariobuilder.ActorTrackData object (normalized/synced)
%     cameraData — scenariobuilder.CameraData object (normalized/synced)

arguments
    trackData  scenariobuilder.ActorTrackData
    cameraData scenariobuilder.CameraData
end

% Verify data is synchronized (same number of samples)
assert(trackData.NumSamples == cameraData.NumSamples, ...
    "plotBEVAndCamera:unsynchronizedData", ...
    "Camera (%d samples) and track (%d samples) data are not synchronized. " + ...
    "Use the 'Crop & Sync' tab in the Driving Log Analyzer app to apply " + ...
    "offset correction and resample to matching rates.", ...
    cameraData.NumSamples, trackData.NumSamples);

% Detect if camera data is video-based or image sequence
% Video-based CameraData has Frames like "path/video.mp4/frame_N"
isVideo = false;
if cameraData.NumSamples > 0
    firstFrame = cameraData.Frames(1);
    % Check if it's a virtual frame path (contains video extension + /frame_)
    if contains(firstFrame, "/frame_") || contains(firstFrame, "\frame_")
        % Extract video file path (everything before /frame_N)
        parts = split(firstFrame, "/frame_");
        if isscalar(parts)
            parts = split(firstFrame, "\frame_");
        end
        videoFilePath = parts(1);
        if isfile(videoFilePath)
            isVideo = true;
            vidReader = VideoReader(videoFilePath);
        end
    end
end
if ~isVideo && cameraData.NumSamples > 0 && ~isfile(cameraData.Frames(1))
    % Fallback: if frames aren't readable files, try finding a video in the folder
    error("plotBEVAndCamera:unreadableFrames", ...
        "Cannot read camera frames. Frames path '%s' is not a valid file.", cameraData.Frames(1));
end

% Create side-by-side figure
f = figure(Position=[100 100 1400 550]);
tl = tiledlayout(f, 1, 2, TileSpacing="compact", Padding="compact");
camAx = nexttile(tl);
title(camAx, "Camera");
axis(camAx, "off");

bevAx = nexttile(tl);
bep = birdsEyePlot(Parent=bevAx, XLimits=[0 80], YLimits=[-30 30]);
trPlotter = trackPlotter(bep, LabelOffset=[1 0], Marker='^', ...
    MarkerEdgeColor='blue', MarkerFaceColor='cyan', DisplayName='Non-Ego Actors');
olPlotter = outlinePlotter(bep);
caPlotter = coverageAreaPlotter(bep, FaceColor=[0.6350 0.0780 0.1840]);
tsText = text(bevAx, 75, 12, "t=0.00s", FontSize=12, Color='b');

% Camera sensor coverage (approximate)
mountPosition = [1 0];
range = 60;
orientation = 0;
fieldOfView = 60;

numFrames = cameraData.NumSamples;

for j = 1:numFrames
    if ~isvalid(f)
        break;
    end

    % Read camera frame (image sequence or video)
    if isVideo
        if hasFrame(vidReader)
            img = readFrame(vidReader);
        else
            break;
        end
    else
        img = imread(cameraData.Frames(j));
    end

    % Display camera frame with timestamp
    camTs = cameraData.Timestamps(j);
    image(img, Parent=camAx);
    axis(camAx, "off");
    title(camAx, sprintf("Camera — t=%.2fs  (Frame %d/%d)", camTs, j, numFrames));

    % BEV actors (same index — data must be synchronized)
    positions = trackData.Position{j};
    trackIDs = trackData.TrackID{j};

    clearData(trPlotter);
    plotOutline(olPlotter, [0 0], 0, 4.7, 1.8, OriginOffset=[-1.35 0], Color=[0 0.447 0.741]);
    plotCoverageArea(caPlotter, mountPosition, range, orientation, fieldOfView);

    if ~isempty(positions)
        plotTrack(trPlotter, positions(:,1:2), string(trackIDs));
    end

    tsText.String = sprintf("t=%.2fs", camTs);

    drawnow;
    pause(0.03);
end

end

%% ----
% Copyright 2026 The MathWorks, Inc.
% ----
