function [gridPath, manifest] = buildBestCropGrid(trackData, cameraData, intrinsics, camHeight, outDir, opts)
% buildBestCropGrid  Project actor tracks to image bboxes, pick the best crop
% per track, and stitch into one labeled grid image for vision classification.
%
%   [gridPath, manifest] = buildBestCropGrid(trackData, cameraData, ...
%       intrinsics, camHeight, outDir)
%
%   trackData    scenariobuilder.ActorTrackData (ego-frame positions)
%   cameraData   scenariobuilder.CameraData (frame-by-frame image paths)
%   intrinsics   struct with fields fx, fy, cx, cy
%   camHeight    camera mounting height above road (m)
%   outDir       folder for crops + composite_grid.png + crops_manifest.csv
%
%   Returns the full path to the grid image and a table mapping
%   TrackID -> BestFrame, BestBbox, CropFile.
%
%   Optional name-value args (opts):
%     VehicleLength (m)  default 4.5
%     VehicleWidth  (m)  default 1.9
%     VehicleHeight (m)  default 1.6
%     MinSidePixels      default 8     (reject crops smaller than this)
%     CellSizePx         default 300
%     NumCols            default 4
%
%   The projection assumes the camera frame uses
%       Xc = -y_ego, Yc = -(z_ego - camHeight), Zc = x_ego
%   (the same convention used everywhere in this skill — see
%    references/visualization-patterns.md and plotActorCircles.m).

arguments
    trackData
    cameraData
    intrinsics struct
    camHeight (1,1) double
    outDir (1,1) string
    opts.VehicleLength (1,1) double = 4.5
    opts.VehicleWidth  (1,1) double = 1.9
    opts.VehicleHeight (1,1) double = 1.6
    opts.MinSidePixels (1,1) double = 8
    opts.CellSizePx    (1,1) double = 300
    opts.NumCols       (1,1) double = 4
end

if ~isfolder(outDir), mkdir(outDir); end
cropsDir = fullfile(outDir, "crops");
if ~isfolder(cropsDir), mkdir(cropsDir); end

K = [intrinsics.fx 0 intrinsics.cx; 0 intrinsics.fy intrinsics.cy; 0 0 1];
vehL = opts.VehicleLength; vehW = opts.VehicleWidth; vehH = opts.VehicleHeight;

% scenariobuilder.CameraData stores image paths in .Frames (N-by-1 string).
% Probe image size from the first frame.
firstImg = imread(cameraData.Frames(1));
H0 = size(firstImg,1); W0 = size(firstImg,2);

nFrames = min(cameraData.NumSamples, numel(trackData.Position));
allRows = struct('frame',{},'trackId',{},'bbox',{},'area',{});
for f = 1:nFrames
    P   = trackData.Position{f};
    ids = trackData.TrackID{f};
    if isempty(P), continue; end
    for t = 1:size(P,1)
        c = P(t,:); dx = vehL/2; dy = vehW/2;
        corners = [c(1)-dx c(2)-dy 0; c(1)+dx c(2)-dy 0;
                   c(1)+dx c(2)+dy 0; c(1)-dx c(2)+dy 0;
                   c(1)-dx c(2)-dy vehH; c(1)+dx c(2)-dy vehH;
                   c(1)+dx c(2)+dy vehH; c(1)-dx c(2)+dy vehH];
        Xc = -corners(:,2);
        Yc = -(corners(:,3) - camHeight);
        Zc =  corners(:,1);
        if any(Zc <= 0.5), continue; end
        uv = (K * [Xc Yc Zc].').';
        u = uv(:,1) ./ uv(:,3); v = uv(:,2) ./ uv(:,3);
        u1 = max(1, floor(min(u))); u2 = min(W0, ceil(max(u)));
        v1 = max(1, floor(min(v))); v2 = min(H0, ceil(max(v)));
        if u2 - u1 < opts.MinSidePixels || v2 - v1 < opts.MinSidePixels, continue; end
        bb = [u1 v1 u2-u1+1 v2-v1+1];
        allRows(end+1) = struct('frame',f,'trackId',string(ids(t)), ...
            'bbox',bb,'area',bb(3)*bb(4)); %#ok<AGROW>
    end
end

if isempty(allRows)
    error("buildBestCropGrid:NoCrops", ...
        "No projected boxes met the minimum size — check intrinsics, camHeight, and vehicle frame convention.");
end

allTids  = string({allRows.trackId});
uniqTids = unique(allTids);

manifest = strings(0, 4);
for k = 1:numel(uniqTids)
    sel = find(allTids == uniqTids(k));
    [~, idx] = max([allRows(sel).area]);
    r = allRows(sel(idx));
    img = imread(cameraData.Frames(r.frame));
    crop = img(r.bbox(2):r.bbox(2)+r.bbox(4)-1, ...
               r.bbox(1):r.bbox(1)+r.bbox(3)-1, :);
    fname = sprintf("track_%s_frame_%03d.png", uniqTids(k), r.frame);
    imwrite(crop, fullfile(cropsDir, fname));
    bboxStr = sprintf("[%d %d %d %d]", r.bbox);
    manifest(end+1, :) = [uniqTids(k), string(r.frame), bboxStr, fname]; %#ok<AGROW>
end

manifest = table(manifest(:,1), manifest(:,2), manifest(:,3), manifest(:,4), ...
    VariableNames=["TrackID","BestFrame","BestBbox","CropFile"]);
writetable(manifest, fullfile(cropsDir, "crops_manifest.csv"));

% Composite grid for one-shot multimodal classification.
nT = height(manifest);
cellSize = opts.CellSizePx;
nCols = opts.NumCols;
nRows = ceil(nT / nCols);
canvas = 255 * ones(nRows*cellSize, nCols*cellSize, 3, "uint8");
for k = 1:nT
    img = imread(fullfile(cropsDir, char(manifest.CropFile(k))));
    img = imresize(img, [cellSize-40, cellSize-10]);
    row = ceil(k / nCols);
    col = mod(k-1, nCols) + 1;
    y0 = (row-1)*cellSize + 35;
    x0 = (col-1)*cellSize + 5;
    canvas(y0:y0+size(img,1)-1, x0:x0+size(img,2)-1, :) = img;
    labelPos = [(col-1)*cellSize+10, (row-1)*cellSize+5];
    canvas = insertText(canvas, labelPos, sprintf("ID %s", manifest.TrackID(k)), ...
        FontSize=20, BoxColor="white", TextColor="black", BoxOpacity=1.0);
end
gridPath = fullfile(outDir, "composite_grid.png");
imwrite(canvas, gridPath);
end
%% ----
% Copyright 2026 The MathWorks, Inc.
% ----
